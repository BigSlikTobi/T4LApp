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
  final String? sourceName; // Added source name field
  final String? sourceUrl; // Added source URL field

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
    this.sourceName, // Added to constructor
    this.sourceUrl, // Added to constructor
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
        sourceName:
            json['sourceName'] ?? json['source_name'], // Parse source name
        sourceUrl: json['sourceUrl'] ?? json['source_url'], // Parse source URL
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error parsing team article: $e\nStack trace: $stackTrace\nJSON data: ${json.toString()}',
      );
      rethrow;
    }
  }

  // Convert TeamArticle to ArticleTicker format
  Map<String, dynamic> toArticleTickerJson() {
    return {
      'id': id ?? 0,
      'englishHeadline': headlineEnglish,
      'germanHeadline': headlineGerman,
      'SummaryEnglish':
          summaryEnglish, // Changed from 'summaryEnglish' to 'SummaryEnglish' to match expected format
      'SummaryGerman':
          summaryGerman, // Changed from 'summaryGerman' to 'SummaryGerman' to match expected format
      'Image2':
          image1, // Changed from 'image2' to 'Image2' to match the capitalization in ArticleTicker.toJson()
      'createdAt': createdAt,
      'teamId': team?.teamId,
      'SourceName':
          sourceName, // Changed from 'sourceName' to 'SourceName' to match capitalization
      'sourceUrl': sourceUrl,
      'status': status,
    };
  }
}
