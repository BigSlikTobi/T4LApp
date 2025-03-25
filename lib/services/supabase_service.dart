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
    // Clean up existing subscription
    _articleSubscription?.unsubscribe();

    final channelName =
        'public:NewsArticles:${DateTime.now().millisecondsSinceEpoch}';
    AppLogger.debug('Creating new subscription on channel: $channelName');

    final channel = supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'NewsArticles',
          filter:
              team?.isNotEmpty == true
                  ? PostgresChangeFilter(
                    type: PostgresChangeFilterType.eq,
                    column: 'teamId',
                    value: team!.toUpperCase(),
                  )
                  : null,
          callback: (payload) {
            AppLogger.debug(
              'Realtime update received: ${payload.eventType} on ${payload.table}',
            );
            if (onArticlesUpdate != null) {
              getArticles(team: team, archived: archived)
                  .then((articles) {
                    AppLogger.debug(
                      'Fetched ${articles.length} articles after realtime update',
                    );
                    onArticlesUpdate(articles);
                  })
                  .catchError((error) {
                    AppLogger.error(
                      'Error fetching articles after realtime update',
                      error,
                    );
                  });
            }
          },
        );

    // Subscribe with robust error handling and auto-reconnect
    channel.subscribe((status, [error]) {
      AppLogger.debug('Channel $channelName status: $status');
      if (error != null) {
        AppLogger.error('Subscription error on $channelName', error);
        // Attempt to reconnect on error
        Future.delayed(Duration(seconds: 5), () {
          if (_articleSubscription == channel) {
            AppLogger.debug('Attempting to reconnect channel: $channelName');
            channel.subscribe((newStatus, [newError]) {
              AppLogger.debug(
                'Reconnection status: $newStatus, error: $newError',
              );
            });
          }
        });
      }
    });

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
          AppLogger.debug('Fetching articles with teamId: $team');

          final queryParams = <String, String>{'archived': archived.toString()};

          if (team?.isNotEmpty == true) {
            final normalizedTeamId = team!.toUpperCase();
            queryParams['teamId'] = normalizedTeamId;
            AppLogger.debug('Adding team filter: $normalizedTeamId');
          }

          if (excludeIds?.isNotEmpty == true) {
            queryParams['excludeIds'] = excludeIds!.join(',');
          }

          final uri = Uri.parse(
            AppConfig.edgeFunctionUrl,
          ).replace(queryParameters: queryParams);

          AppLogger.debug('Making request to: $uri');

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
            AppLogger.debug('Received ${jsonData.length} articles from API');

            // Validate teamId filter is working
            if (team?.isNotEmpty == true) {
              final filteredCount =
                  jsonData
                      .where(
                        (article) =>
                            article['teamId']?.toString().toUpperCase() ==
                            team!.toUpperCase(),
                      )
                      .length;
              AppLogger.debug(
                'Found $filteredCount articles matching teamId: $team',
              );
            }

            return jsonData.cast<Map<String, dynamic>>();
          } else {
            AppLogger.error('API error: ${response.statusCode}', response.body);
            throw Exception('API error: ${response.statusCode}');
          }
        } finally {
          client.close();
        }
      } catch (e) {
        retryCount++;
        AppLogger.error('Error in attempt $retryCount: ${e.toString()}', null);
        if (retryCount >= _maxRetries) {
          throw Exception(
            'Failed after $_maxRetries attempts: ${e.toString()}',
          );
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
