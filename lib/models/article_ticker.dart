import 'package:flutter_test/flutter_test.dart';
import 'package:app/utils/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

      // Extract headline fields with detailed logging
      final englishHeadline = json['englishHeadline']?.toString() ?? '';
      final germanHeadline = json['germanHeadline']?.toString() ?? '';
      final summaryEnglish = json['SummaryEnglish']?.toString() ?? '';
      final summaryGerman = json['SummaryGerman']?.toString() ?? '';

      // Handle image field - check both capitalization variants
      final image2 = json['Image2']?.toString() ?? json['image2']?.toString();

      AppLogger.debug(
        'Parsed headlines - English: $englishHeadline, German: $germanHeadline',
      );
      AppLogger.debug('Parsed image2: $image2');
      AppLogger.debug(
        'Parsed summaries - English: ${summaryEnglish.length > 20 ? "${summaryEnglish.substring(0, 20)}..." : summaryEnglish}, '
        'German: ${summaryGerman.length > 20 ? "${summaryGerman.substring(0, 20)}..." : summaryGerman}',
      );

      // Handle potential integer parsing issues
      final int tickerId;
      if (json['id'] is int) {
        tickerId = json['id'];
      } else {
        tickerId = int.tryParse(json['id'].toString()) ?? 0;
        AppLogger.debug(
          'Converted string ID "${json['id']}" to integer: $tickerId',
        );
      }

      return ArticleTicker(
        id: tickerId,
        englishHeadline: englishHeadline,
        germanHeadline: germanHeadline,
        summaryEnglish: summaryEnglish,
        summaryGerman: summaryGerman,
        image2: image2,
        createdAt: json['createdAt']?.toString(),
        sourceName:
            json['SourceName']?.toString() ?? json['sourceName']?.toString(),
        sourceUrl: json['sourceUrl']?.toString(),
        teamId: json['teamId']?.toString(),
        status: json['status']?.toString(),
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

void main() {
  test(
    'ArticleTicker with real data',
    () async {
      try {
        AppLogger.debug('Starting real data test for ArticleTicker...');

        // Make direct HTTP request to the edge function
        final uri = Uri.parse(
          'https://yqtiuzhedkfacwgormhn.supabase.co/functions/v1/articleTicker',
        );

        final response = await http.get(
          uri,
          headers: {
            'Authorization':
                'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlxdGl1emhlZGtmYWN3Z29ybWhuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE4NzcwMDgsImV4cCI6MjA1NzQ1MzAwOH0.h2FYangQNOdEJWq8ExWBABiphzoLObWcj5B9Z-uIgQc',
            'Content-Type': 'application/json',
          },
        );

        expect(
          response.statusCode,
          equals(200),
          reason: 'API call should succeed. Response: ${response.body}',
        );

        final jsonResponse = jsonDecode(response.body);

        // Print raw data from first article
        print('\n📰 First Article Raw Data:');
        print('----------------------------------------');
        print('ID: ${jsonResponse[0]['id']}');
        print('English Headline: ${jsonResponse[0]['englishHeadline']}');
        print('German Headline: ${jsonResponse[0]['germanHeadline']}');
        print('Summary English: ${jsonResponse[0]['SummaryEnglish']}');
        print('Summary German: ${jsonResponse[0]['SummaryGerman']}');
        print('Image2: ${jsonResponse[0]['Image2']}');
        print('Created At: ${jsonResponse[0]['createdAt']}');
        print(
          'Source Name: ${jsonResponse[0]['SourceName'] ?? jsonResponse[0]['sourceName']}',
        );
        print('Source URL: ${jsonResponse[0]['sourceUrl']}');
        print('Team ID: ${jsonResponse[0]['teamId']}');
        print('Status: ${jsonResponse[0]['status']}');
        print('----------------------------------------\n');

        AppLogger.debug('Raw API response: ${response.body}');

        // Test parsing the response into ArticleTicker objects
        List<dynamic> tickersData;
        if (jsonResponse is Map<String, dynamic>) {
          // Handle nested data structure
          tickersData =
              jsonResponse['data'] is List ? jsonResponse['data'] : [];
          AppLogger.debug('Found data in nested format');
        } else if (jsonResponse is List) {
          tickersData = jsonResponse;
          AppLogger.debug('Response is directly a list');
        } else {
          throw FormatException(
            'Unexpected response format: ${jsonResponse.runtimeType}',
          );
        }

        AppLogger.debug('Processing ${tickersData.length} tickers');

        final tickers =
            tickersData.map((json) => ArticleTicker.fromJson(json)).toList();

        expect(
          tickers,
          isNotEmpty,
          reason: 'Should receive at least one ticker',
        );

        if (tickers.isNotEmpty) {
          final firstTicker = tickers.first;
          AppLogger.debug('\nFirst ticker details:');
          AppLogger.debug('ID: ${firstTicker.id}');
          AppLogger.debug('English Headline: ${firstTicker.englishHeadline}');
          AppLogger.debug('German Headline: ${firstTicker.germanHeadline}');
          AppLogger.debug('English Summary: ${firstTicker.summaryEnglish}');
          AppLogger.debug('German Summary: ${firstTicker.summaryGerman}');
          AppLogger.debug('Image URL: ${firstTicker.image2}');
          AppLogger.debug('Created At: ${firstTicker.createdAt}');
          AppLogger.debug('Source Name: ${firstTicker.sourceName}');
          AppLogger.debug('Source URL: ${firstTicker.sourceUrl}');
          AppLogger.debug('Team ID: ${firstTicker.teamId}');
          AppLogger.debug('Status: ${firstTicker.status}');

          // Validate data structure
          expect(firstTicker.id, isNotNull);
          expect(firstTicker.englishHeadline, isNotEmpty);
          expect(firstTicker.germanHeadline, isNotEmpty);
        }
      } catch (e, stackTrace) {
        AppLogger.error('Error in real data test', e);
        AppLogger.error('Stack trace:', stackTrace);
        fail('Test failed with error: $e');
      }
    },
    timeout: Timeout(Duration(seconds: 30)),
  ); // Increased timeout for network request
}
