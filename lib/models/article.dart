import 'package:app/utils/logger.dart';

// Global debug toggle for Article model logging
bool articleDebugLogging = false;

class Article {
  final int id;
  final String englishHeadline;
  final String germanHeadline;
  final String englishArticle;
  final String germanArticle;
  final String? imageUrl;
  final DateTime? createdAt;
  final String? sourceAuthor;
  final String? sourceUrl; // Added source URL field
  final String? teamId; // Changed from team to teamId to match database
  final String? status;

  // Static counter for generating unique IDs
  static int _tempIdCounter = 0;

  Article({
    required this.id,
    required this.englishHeadline,
    required this.germanHeadline,
    required this.englishArticle,
    required this.germanArticle,
    this.imageUrl,
    this.createdAt,
    this.sourceAuthor,
    this.sourceUrl, // Added source URL parameter
    this.teamId, // Changed from team to teamId
    this.status,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    if (articleDebugLogging) {
      AppLogger.debug('[Article] Processing article JSON: ${json.toString()}');
    }

    final possibleIdFields = ['id', 'articleId', 'article_id', 'ID'];
    dynamic rawId;
    String? usedField;

    for (var field in possibleIdFields) {
      if (json.containsKey(field) && json[field] != null) {
        rawId = json[field];
        usedField = field;
        break;
      }
    }

    if (articleDebugLogging) {
      AppLogger.debug(
        '[Article] Raw article ID from JSON: $rawId (type: ${rawId?.runtimeType}, field: $usedField)',
      );
    }

    int articleId;
    if (rawId == null) {
      final tempId = DateTime.now().millisecondsSinceEpoch + (_tempIdCounter++);
      AppLogger.error(
        '[Article] No valid ID found in article JSON. Using temporary ID: $tempId\n'
        'Available fields: ${json.keys.join(', ')}',
      );
      articleId = tempId;
    } else if (rawId is int) {
      articleId = rawId;
      if (articleDebugLogging) {
        AppLogger.debug('[Article] Using integer ID: $articleId');
      }
    } else if (rawId is String) {
      if (rawId.contains('-')) {
        final lastPart = rawId.split('-').last;
        var parsedId = int.tryParse(lastPart);
        if (parsedId != null) {
          articleId = parsedId;
          if (articleDebugLogging) {
            AppLogger.debug(
              '[Article] Parsed UUID last segment as ID: $articleId from $rawId',
            );
          }
        } else {
          articleId = rawId.hashCode;
          if (articleDebugLogging) {
            AppLogger.debug(
              '[Article] Using hash of UUID as ID: $articleId from $rawId',
            );
          }
        }
      } else {
        var parsedId = int.tryParse(rawId);
        if (parsedId != null) {
          articleId = parsedId;
          if (articleDebugLogging) {
            AppLogger.debug(
              '[Article] Parsed numeric ID from string: $articleId',
            );
          }
        } else {
          articleId = rawId.hashCode;
          if (articleDebugLogging) {
            AppLogger.debug(
              '[Article] Using hash of string ID: $articleId from $rawId',
            );
          }
        }
      }
    } else {
      articleId = rawId.toString().hashCode + (_tempIdCounter++);
      if (articleDebugLogging) {
        AppLogger.debug(
          '[Article] Using unique hash of non-string ID: $articleId from $rawId (type: ${rawId.runtimeType})',
        );
      }
    }

    DateTime? dateTime;
    String? rawDate =
        json['created_at']?.toString() ?? json['createdAt']?.toString();

    if (articleDebugLogging) {
      AppLogger.debug(
        '[Article] Article $articleId - Raw date value: $rawDate',
      );
    }

    if (rawDate != null) {
      try {
        dateTime = DateTime.parse(rawDate);
        if (articleDebugLogging) {
          AppLogger.debug(
            '[Article] Successfully parsed date: $dateTime for article $articleId',
          );
        }
      } catch (e) {
        AppLogger.error(
          '[Article] Error parsing date for article $articleId',
          e,
        );
      }
    }

    String? teamIdValue = json['teamId']?.toString();
    if (articleDebugLogging) {
      AppLogger.debug(
        '[Article] Article $articleId - TeamId from JSON: $teamIdValue',
      );
    }

    final article = Article(
      id: articleId,
      englishHeadline: json['englishHeadline']?.toString() ?? '',
      germanHeadline: json['germanHeadline']?.toString() ?? '',
      englishArticle: json['ContentEnglish']?.toString() ?? '',
      germanArticle: json['ContentGerman']?.toString() ?? '',
      imageUrl: json['Image1']?.toString(),
      createdAt: dateTime,
      sourceAuthor: json['SourceName']?.toString(),
      sourceUrl: json['sourceUrl']?.toString(), // Added source URL from JSON
      teamId:
          teamIdValue, // Don't force uppercase here since we handle it in the service
      status: json['status']?.toString(),
    );

    if (articleDebugLogging) {
      AppLogger.debug(
        '[Article] Created article with ID: $articleId and status: ${article.status}',
      );
    }

    return article;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'englishHeadline': englishHeadline,
      'germanHeadline': germanHeadline,
      'ContentEnglish': englishArticle,
      'ContentGerman': germanArticle,
      'Image1': imageUrl,
      'created_at': createdAt?.toIso8601String(),
      'SourceName': sourceAuthor,
      'sourceUrl': sourceUrl, // Added source URL to JSON
      'teamId': teamId,
      'status': status,
    };
  }
}
