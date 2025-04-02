import 'package:app/utils/logger.dart';

class ArticleTicker {
  final int id;
  final String englishHeadline;
  final String germanHeadline;
  final String summaryEnglish;
  final String summaryGerman;
  final String? image2;
  final String? createdAt;
  final String? sourceName;
  final String? sourceUrl;
  final String? teamId;
  final String? status;

  ArticleTicker({
    required this.id,
    required this.englishHeadline,
    required this.germanHeadline,
    required this.summaryEnglish,
    required this.summaryGerman,
    this.image2,
    this.createdAt,
    this.sourceName,
    this.sourceUrl,
    this.teamId,
    this.status,
  });

  factory ArticleTicker.fromJson(Map<String, dynamic> json) {
    try {
      AppLogger.debug('Processing article ticker JSON: ${json.toString()}');

      // Validate required fields
      if (json['id'] == null) {
        throw FormatException('Missing required field: id');
      }

      // Handle potential integer parsing issues for ID
      final int tickerId;
      if (json['id'] is int) {
        tickerId = json['id'];
      } else {
        tickerId = int.tryParse(json['id'].toString()) ?? 0;
      }

      // Helper function to get case-insensitive field value
      T? getField<T>(String fieldName, [T? defaultValue]) {
        final camelCase = fieldName;
        final pascalCase = fieldName[0].toUpperCase() + fieldName.substring(1);

        return json[pascalCase] ?? json[camelCase] ?? defaultValue;
      }

      // Extract fields using case-insensitive helper
      final englishHeadline = getField<String>('englishHeadline', '')!;
      final germanHeadline = getField<String>('germanHeadline', '')!;
      final summaryEnglish = getField<String>('summaryEnglish', '')!;
      final summaryGerman = getField<String>('summaryGerman', '')!;
      final image2 = getField<String>('image2');
      final createdAt = getField<String>('createdAt');
      final sourceName = getField<String>('sourceName');
      final sourceUrl = getField<String>('sourceUrl');
      final teamId = getField<String>('teamId');
      final status = getField<String>('status');

      AppLogger.debug('Parsed article ticker fields:');
      AppLogger.debug('- ID: $tickerId');
      AppLogger.debug('- English Headline: $englishHeadline');
      AppLogger.debug('- German Headline: $germanHeadline');
      AppLogger.debug('- Image URL: $image2');
      AppLogger.debug('- Team ID: $teamId');

      return ArticleTicker(
        id: tickerId,
        englishHeadline: englishHeadline,
        germanHeadline: germanHeadline,
        summaryEnglish: summaryEnglish,
        summaryGerman: summaryGerman,
        image2: image2,
        createdAt: createdAt,
        sourceName: sourceName,
        sourceUrl: sourceUrl,
        teamId: teamId,
        status: status,
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error parsing article ticker: $e\nStack trace: $stackTrace\nJSON data: ${json.toString()}',
      );
      rethrow;
    }
  }

  // Get display text based on language
  String getDisplayText(bool isEnglish) {
    if (isEnglish) {
      return englishHeadline;
    } else {
      return germanHeadline;
    }
  }

  // Convert to Article model
  Map<String, dynamic> toArticleJson() {
    return {
      'id': id,
      'englishHeadline': englishHeadline,
      'germanHeadline': germanHeadline,
      'ContentEnglish': summaryEnglish,
      'ContentGerman': summaryGerman,
      'Image1': image2,
      'createdAt': createdAt,
      'SourceName': sourceName,
      'sourceUrl': sourceUrl,
      'teamId': teamId,
      'status': status,
    };
  }

  // Convert to a regular Map (JSON)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'englishHeadline': englishHeadline,
      'germanHeadline': germanHeadline,
      'SummaryEnglish': summaryEnglish,
      'SummaryGerman': summaryGerman,
      'Image2': image2,
      'createdAt': createdAt,
      'SourceName': sourceName,
      'sourceUrl': sourceUrl,
      'teamId': teamId,
      'status': status,
    };
  }
}
