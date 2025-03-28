import 'package:app/utils/logger.dart';

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
    // Enhanced logging of the full article JSON for debugging
    // AppLogger.debug('Processing article JSON: ${json.toString()}');

    // Check multiple possible ID field names
    final possibleIdFields = ['id', 'articleId', 'article_id', 'ID'];
    var rawId;

    // Try each possible ID field
    for (var field in possibleIdFields) {
      if (json.containsKey(field) && json[field] != null) {
        rawId = json[field];
        break;
      }
    }

    // AppLogger.debug(
    //   'Raw article ID from JSON: $rawId (type: ${rawId?.runtimeType}, field: $usedField)',
    // );

    int articleId;
    if (rawId == null) {
      // If no valid ID field found, generate a unique temporary ID
      // Use current timestamp + counter to ensure uniqueness
      final tempId = DateTime.now().millisecondsSinceEpoch + (_tempIdCounter++);
      AppLogger.error(
        'No valid ID found in article JSON. Using temporary ID: $tempId\n'
        'Available fields: ${json.keys.join(', ')}',
      );
      articleId = tempId;
    } else if (rawId is int) {
      articleId = rawId;
      // AppLogger.debug('Using integer ID: $articleId');
    } else if (rawId is String) {
      if (rawId.contains('-')) {
        // UUID format - take last segment and parse as int if possible
        final lastPart = rawId.split('-').last;
        var parsedId = int.tryParse(lastPart);
        if (parsedId != null) {
          articleId = parsedId;
          // AppLogger.debug(
          //   'Parsed UUID last segment as ID: $articleId from $rawId',
          // );
        } else {
          articleId = rawId.hashCode;
          // AppLogger.debug('Using hash of UUID as ID: $articleId from $rawId');
        }
      } else {
        // Try parsing numeric string
        var parsedId = int.tryParse(rawId);
        if (parsedId != null) {
          articleId = parsedId;
          // AppLogger.debug('Parsed numeric ID from string: $articleId');
        } else {
          // If parsing fails, use hash of the string
          articleId = rawId.hashCode;
          // AppLogger.debug('Using hash of string ID: $articleId from $rawId');
        }
      }
    } else {
      // For any other type, use toString() and hash + counter to ensure uniqueness
      articleId = rawId.toString().hashCode + (_tempIdCounter++);
      // AppLogger.debug(
      //   'Using unique hash of non-string ID: $articleId from $rawId (type: ${rawId.runtimeType})',
      // );
    }

    DateTime? dateTime;
    String? rawDate =
        json['created_at']?.toString() ?? json['createdAt']?.toString();
    // AppLogger.debug('Article $articleId - Raw date value: $rawDate');

    if (rawDate != null) {
      try {
        dateTime = DateTime.parse(rawDate);
      } catch (e) {
        AppLogger.error('Error parsing date for article $articleId', e);
      }
    }

    // Ensure we get the teamId value and log it
    String? teamIdValue = json['teamId']?.toString();
    // AppLogger.debug('Article $articleId - TeamId from JSON: $teamIdValue');

    return Article(
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
