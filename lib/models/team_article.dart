import 'package:app/models/team.dart';
import 'package:app/utils/logger.dart';

class TeamArticle {
  final int? id;
  final String? headlineEnglish;
  final String? headlineGerman;
  final String? contentEnglish;
  final String? contentGerman;
  final String? summaryEnglish;
  final String? summaryGerman;
  final String? image1;
  final String? status;
  final String? createdAt;
  final Team? team;

  TeamArticle({
    this.id,
    this.headlineEnglish,
    this.headlineGerman,
    this.contentEnglish,
    this.contentGerman,
    this.summaryEnglish,
    this.summaryGerman,
    this.image1,
    this.status,
    this.createdAt,
    this.team,
  });

  factory TeamArticle.fromJson(Map<String, dynamic> json) {
    try {
      AppLogger.debug('Processing team article JSON: ${json.toString()}');

      // Handle team property which could be a teamId string or object
      Team? team;
      if (json['team'] != null) {
        if (json['team'] is Map<String, dynamic>) {
          team = Team.fromJson(json['team']);
        } else {
          AppLogger.debug(
            'Team field is not an object, received: ${json['team']}',
          );
          // Handle string or numeric team ID
          team = Team(
            teamId: json['team'].toString(),
            fullName: '',
            division: '',
            conference: '',
          );
        }
      }

      return TeamArticle(
        id: json['id'],
        headlineEnglish: json['headlineEnglish'],
        headlineGerman: json['headlineGerman'],
        contentEnglish: json['contentEnglish'],
        contentGerman: json['contentGerman'],
        summaryEnglish: json['summaryEnglish'],
        summaryGerman: json['summaryGerman'],
        image1: json['image1'],
        status: json['status'],
        createdAt: json['createdAt'] ?? json['created_at'],
        team: team,
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error parsing team article: $e\nStack trace: $stackTrace\nJSON data: ${json.toString()}',
      );
      rethrow;
    }
  }

  // Adapter method to convert TeamArticle to a format compatible with the NewsTicker model
  Map<String, dynamic> toNewsTickerJson(bool isEnglish) {
    return {
      'id': id ?? 0,
      'Image': image1,
      'EnglishInformation': summaryEnglish,
      'GermanInformation': summaryGerman,
      'HeadlineEnglish': headlineEnglish,
      'HeadlineGerman': headlineGerman,
      'created_at': createdAt,
      'Team': team?.teamId,
    };
  }
}
