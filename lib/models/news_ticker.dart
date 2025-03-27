import 'package:app/utils/logger.dart';

class NewsTicker {
  final int id;
  final String? imageUrl;
  final String? englishInformation;
  final String? germanInformation;
  final SourceArticle? sourceArticle;
  final Team? team;
  final String? headlineEnglish;
  final String? headlineGerman;
  final String? createdAt;

  NewsTicker({
    required this.id,
    this.imageUrl,
    this.englishInformation,
    this.germanInformation,
    this.sourceArticle,
    this.team,
    this.headlineEnglish,
    this.headlineGerman,
    this.createdAt,
  });

  factory NewsTicker.fromJson(Map<String, dynamic> json) {
    try {
      AppLogger.debug('Processing news ticker JSON: ${json.toString()}');

      // Validate required fields
      if (json['id'] == null) {
        throw FormatException('Missing required field: id');
      }

      // Handle Team field which might be an ID or an object
      Team? team;
      if (json['Team'] != null) {
        if (json['Team'] is Map<String, dynamic>) {
          team = Team.fromJson(json['Team']);
        } else {
          AppLogger.debug(
            'Team field is not an object, received: ${json['Team']}',
          );
          // Handle numeric team ID by creating a basic Team object
          team = Team(teamId: json['Team'].toString(), fullName: null);
        }
      }

      // Handle SourceArticle field which might be an ID or an object
      SourceArticle? sourceArticle;
      if (json['SourceArticle'] != null) {
        if (json['SourceArticle'] is Map<String, dynamic>) {
          sourceArticle = SourceArticle.fromJson(json['SourceArticle']);
        } else {
          AppLogger.debug(
            'SourceArticle field is not an object, received: ${json['SourceArticle']}',
          );
          // Handle numeric source article ID by creating a basic SourceArticle object
          sourceArticle = SourceArticle(
            id: int.tryParse(json['SourceArticle'].toString()),
          );
        }
      }

      // Create the NewsTicker object with validated fields
      return NewsTicker(
        id: json['id'],
        imageUrl: json['Image']?.toString(),
        englishInformation: json['EnglishInformation']?.toString(),
        germanInformation: json['GermanInformation']?.toString(),
        sourceArticle: sourceArticle,
        team: team,
        headlineEnglish: json['HeadlineEnglish']?.toString(),
        headlineGerman: json['HeadlineGerman']?.toString(),
        createdAt: json['created_at']?.toString(),
      );
    } catch (e, stackTrace) {
      AppLogger.debug(
        'Error parsing news ticker: $e\nStack trace: $stackTrace\nJSON data: ${json.toString()}',
      );
      rethrow;
    }
  }

  // Get display text based on language, using the new headline fields
  String getDisplayText(bool isEnglish) {
    // First try to use the language-specific headline
    if (isEnglish && headlineEnglish != null && headlineEnglish!.isNotEmpty) {
      return headlineEnglish!;
    } else if (!isEnglish &&
        headlineGerman != null &&
        headlineGerman!.isNotEmpty) {
      return headlineGerman!;
    }

    // Fall back to information fields if headlines are not available
    if (isEnglish) {
      return englishInformation ?? '';
    } else {
      return germanInformation ?? '';
    }
  }
}

class SourceArticle {
  final int? id;
  final Source? source;
  final String? publishedAt;

  SourceArticle({this.id, this.source, this.publishedAt});

  factory SourceArticle.fromJson(Map<String, dynamic> json) {
    return SourceArticle(
      id: json['id'],
      source: json['source'] != null ? Source.fromJson(json['source']) : null,
      publishedAt: json['publishedAt'],
    );
  }
}

class Source {
  final String? name;

  Source({this.name});

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(name: json['Name']);
  }
}

class Team {
  final String? teamId;
  final String? fullName;

  Team({this.teamId, this.fullName});

  factory Team.fromJson(dynamic json) {
    try {
      // Handle case where json is just a team ID (number or string)
      if (json is! Map<String, dynamic>) {
        return Team(teamId: json.toString(), fullName: null);
      }
      return Team(
        teamId: json['teamId']?.toString(),
        fullName: json['fullName']?.toString(),
      );
    } catch (e, stackTrace) {
      AppLogger.debug(
        'Error parsing team: $e\nStack trace: $stackTrace\nJSON data: $json',
      );
      rethrow;
    }
  }
}
