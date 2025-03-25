import 'package:app/utils/logger.dart';
import 'package:app/config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  static final supabase = Supabase.instance.client;

  static RealtimeChannel? _articleSubscription;

  /// Subscribe to realtime updates for articles
  static RealtimeChannel subscribeToArticles({
    String? team,
    bool archived = false,
    Function(List<Map<String, dynamic>>)? onArticlesUpdate,
  }) {
    // Unsubscribe from any existing subscription
    _articleSubscription?.unsubscribe();

    // Create a new subscription
    final channel = supabase
        .channel('public:NewsArticles')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'NewsArticles',
          filter:
              team != null
                  ? PostgresChangeFilter(
                    type: PostgresChangeFilterType.eq,
                    column: 'team',
                    value: team,
                  )
                  : null,
          callback: (payload) {
            AppLogger.debug('Realtime update received: $payload');
            if (onArticlesUpdate != null) {
              // Fetch fresh data when a change occurs
              getArticles(
                team: team,
                archived: archived,
              ).then(onArticlesUpdate);
            }
          },
        );

    // Subscribe to the channel
    channel.subscribe();

    _articleSubscription = channel;
    return channel;
  }

  /// Fetch all news articles from the edge function with retry logic
  static Future<List<Map<String, dynamic>>> getArticles({
    String? team,
    bool archived = false,
    List<int>? excludeIds,
  }) async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final http.Client client = http.Client();
        try {
          final queryParams = {
            'team': team?.toUpperCase() ?? '',
            'archived': archived.toString(),
            'excludeIds': excludeIds?.join(',') ?? '',
          };

          final uri = Uri.parse(
            AppConfig.edgeFunctionUrl,
          ).replace(queryParameters: queryParams);

          AppLogger.debug('Fetching articles from: $uri');

          final response = await client
              .get(
                uri,
                headers: {
                  'Authorization': 'Bearer ${AppConfig.apiKey}',
                  'Content-Type': 'application/json',
                },
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final List<dynamic> jsonData = jsonDecode(response.body);
            if (jsonData.isNotEmpty) {
              final firstArticle = jsonData.first;
              AppLogger.debug('First article raw JSON:');
              AppLogger.debug('Keys: ${firstArticle.keys.join(", ")}');
              AppLogger.debug('Values:');
              firstArticle.forEach((key, value) {
                AppLogger.debug('  $key: $value (${value?.runtimeType})');
              });
            }
            return jsonData.cast<Map<String, dynamic>>();
          } else if (response.statusCode >= 500) {
            throw Exception('Server error: ${response.statusCode}');
          } else {
            AppLogger.error(
              'Edge function error: ${response.statusCode}',
              response.body,
            );
            return [];
          }
        } finally {
          client.close();
        }
      } catch (e) {
        retryCount++;
        if (retryCount >= _maxRetries) {
          AppLogger.error(
            'Error fetching articles after $_maxRetries retries',
            e,
          );
          return [];
        }
        await Future.delayed(_retryDelay * retryCount);
      }
    }
    return [];
  }

  /// Cleanup method to be called when the app is disposed
  static void dispose() {
    _articleSubscription?.unsubscribe();
    _articleSubscription = null;
  }
}
