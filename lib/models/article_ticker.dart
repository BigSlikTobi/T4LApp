import 'package:app/utils/logger.dart';

// Global debug toggle for ArticleTicker class
const bool _enableArticleTickerDebug = false;

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
      if (_enableArticleTickerDebug) {
        AppLogger.debug(
          '[ArticleTicker] Processing article ticker JSON: ${json.toString()}',
        );
      }

      // Validate required fields
      if (json['id'] == null) {
        if (_enableArticleTickerDebug) {
          AppLogger.debug('[ArticleTicker] Missing required field: id');
        }
        throw FormatException('Missing required field: id');
      }

      // Handle potential integer parsing issues for ID
      final int tickerId;
      if (json['id'] is int) {
        tickerId = json['id'];
      } else {
        tickerId = int.tryParse(json['id'].toString()) ?? 0;
        if (_enableArticleTickerDebug) {
          AppLogger.debug(
            '[ArticleTicker] Converted string ID to integer: ${json['id']} -> $tickerId',
          );
        }
      }

      // Helper function to get case-insensitive field value
      T? getField<T>(String fieldName, [T? defaultValue]) {
        final camelCase = fieldName;
        final pascalCase = fieldName[0].toUpperCase() + fieldName.substring(1);
        final value = json[pascalCase] ?? json[camelCase] ?? defaultValue;
        if (_enableArticleTickerDebug) {
          AppLogger.debug('[ArticleTicker] Field "$fieldName" value: $value');
        }
        return value;
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

      if (_enableArticleTickerDebug) {
        AppLogger.debug(
          '[ArticleTicker] Article ticker fields parsed successfully:',
        );
        AppLogger.debug('[ArticleTicker] - ID: $tickerId');
        AppLogger.debug('[ArticleTicker] - English Headline: $englishHeadline');
        AppLogger.debug('[ArticleTicker] - German Headline: $germanHeadline');
        AppLogger.debug('[ArticleTicker] - Image URL: $image2');
        AppLogger.debug('[ArticleTicker] - Team ID: $teamId');
        AppLogger.debug('[ArticleTicker] - Created At: $createdAt');
        AppLogger.debug('[ArticleTicker] - Status: $status');
      }

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
        '[ArticleTicker] Error parsing article ticker: $e\nStack trace: $stackTrace\nJSON data: ${json.toString()}',
      );
      rethrow;
    }
  }

  // Get display text based on language
  String getDisplayText(bool isEnglish) {
    if (_enableArticleTickerDebug) {
      AppLogger.debug(
        '[ArticleTicker] Getting display text in ${isEnglish ? 'English' : 'German'}',
      );
    }
    return isEnglish ? englishHeadline : germanHeadline;
  }

  // Convert to Article model
  Map<String, dynamic> toArticleJson() {
    if (_enableArticleTickerDebug) {
      AppLogger.debug(
        '[ArticleTicker] Converting article ticker $id to Article format',
      );
    }
    final json = {
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
    if (_enableArticleTickerDebug) {
      AppLogger.debug('[ArticleTicker] Converted to Article JSON: $json');
    }
    return json;
  }

  // Convert to a regular Map (JSON)
  Map<String, dynamic> toJson() {
    if (_enableArticleTickerDebug) {
      AppLogger.debug(
        '[ArticleTicker] Converting article ticker $id to JSON format',
      );
    }
    final json = {
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
    if (_enableArticleTickerDebug) {
      AppLogger.debug('[ArticleTicker] Converted to JSON: $json');
    }
    return json;
  }
}
