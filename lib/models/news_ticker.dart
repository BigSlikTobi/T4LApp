import 'package:app/utils/logger.dart';

class NewsTicker {
  final int id;
  final String? headline;
  final String? imageUrl;
  final String? englishInformation;
  final String? germanInformation;
  final SourceArticle? sourceArticle;
  final Team? team;

  NewsTicker({
    required this.id,
    this.headline,
    this.imageUrl,
    this.englishInformation,
    this.germanInformation,
    this.sourceArticle,
    this.team,
  });

  factory NewsTicker.fromJson(Map<String, dynamic> json) {
    AppLogger.debug('Processing news ticker JSON: ${json.toString()}');

    return NewsTicker(
      id: json['id'] ?? 0,
      headline: json['Headline'],
      imageUrl: json['Image'],
      englishInformation: json['EnglishInformation'],
      germanInformation: json['GermanInformation'],
      sourceArticle:
          json['SourceArticle'] != null
              ? SourceArticle.fromJson(json['SourceArticle'])
              : null,
      team: json['Team'] != null ? Team.fromJson(json['Team']) : null,
    );
  }

  // Get display text based on language, falling back to appropriate content
  String getDisplayText(bool isEnglish) {
    if (headline != null && headline!.isNotEmpty) {
      return headline!;
    }

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

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(teamId: json['teamId'], fullName: json['fullName']);
  }
}
