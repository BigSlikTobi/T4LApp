import 'package:app/utils/logger.dart';
import 'package:app/config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/models/news_ticker.dart';
import 'package:app/models/team.dart' as team_model;

class SupabaseService {
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  static final supabase = Supabase.instance.client;

  static RealtimeChannel? _articleSubscription;
  static RealtimeChannel? _teamArticleSubscription;

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
    //AppLogger.debug('Creating new subscription on channel: $channelName');

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

  /// Subscribe to realtime updates for team articles
  static RealtimeChannel subscribeToTeamArticles({
    String? team,
    Function(List<Map<String, dynamic>>)? onTeamArticlesUpdate,
  }) {
    // Clean up existing subscription
    _teamArticleSubscription?.unsubscribe();

    final channelName =
        'public:TeamNewsArticles:${DateTime.now().millisecondsSinceEpoch}';
    AppLogger.debug(
      'Creating new team articles subscription on channel: $channelName',
    );

    final channel = supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'TeamNewsArticles',
          filter:
              team?.isNotEmpty == true
                  ? PostgresChangeFilter(
                    type: PostgresChangeFilterType.eq,
                    column: 'team',
                    value: team!.toUpperCase(),
                  )
                  : null,
          callback: (payload) {
            AppLogger.debug(
              'Team article realtime update received: ${payload.eventType} on ${payload.table}',
            );
            if (onTeamArticlesUpdate != null) {
              getTeamArticles(teamId: team)
                  .then((teamArticles) {
                    AppLogger.debug(
                      'Fetched ${teamArticles.length} team articles after realtime update',
                    );
                    onTeamArticlesUpdate(teamArticles);
                  })
                  .catchError((error) {
                    AppLogger.error(
                      'Error fetching team articles after realtime update',
                      error,
                    );
                  });
            }
          },
        );

    // Subscribe with robust error handling and auto-reconnect
    channel.subscribe((status, [error]) {
      AppLogger.debug('Team articles channel $channelName status: $status');
      if (error != null) {
        AppLogger.error(
          'Team articles subscription error on $channelName',
          error,
        );
        // Attempt to reconnect on error
        Future.delayed(Duration(seconds: 5), () {
          if (_teamArticleSubscription == channel) {
            AppLogger.debug(
              'Attempting to reconnect team articles channel: $channelName',
            );
            channel.subscribe((newStatus, [newError]) {
              AppLogger.debug(
                'Team articles reconnection status: $newStatus, error: $newError',
              );
            });
          }
        });
      }
    });

    _teamArticleSubscription = channel;
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
          //AppLogger.debug('Starting getArticles request...');
          //AppLogger.debug(
          //  'Parameters: team=$team, archived=$archived, excludeIds=$excludeIds',
          //);

          final queryParams = <String, String>{'archived': archived.toString()};
          if (team?.isNotEmpty == true) {
            final normalizedTeamId = team!.toUpperCase();
            queryParams['teamId'] = normalizedTeamId;
            //AppLogger.debug('Added team filter: $normalizedTeamId');
          }

          if (excludeIds?.isNotEmpty == true) {
            queryParams['excludeIds'] = excludeIds!.join(',');
          }

          final uri = Uri.parse(
            AppConfig.edgeFunctionUrl,
          ).replace(queryParameters: queryParams);

          //AppLogger.debug('Making request to: $uri');
          //AppLogger.debug(
          //  'Headers: Authorization: Bearer ${AppConfig.apiKey.substring(0, 4)}... (truncated)',
          //);

          final response = await client
              .get(
                uri,
                headers: {
                  'Authorization': 'Bearer ${AppConfig.apiKey}',
                  'Content-Type': 'application/json',
                },
              )
              .timeout(const Duration(seconds: 10));

          //AppLogger.debug('Response status code: ${response.statusCode}');
          //AppLogger.debug('Response headers: ${response.headers}');

          if (response.statusCode == 200) {
            //AppLogger.debug('Raw API response: ${response.body}');
            final List<dynamic> jsonData = jsonDecode(response.body);
            //AppLogger.debug('Successfully parsed JSON data');
            //AppLogger.debug('Received ${jsonData.length} articles from API');

            // Log first article as sample if available
            if (jsonData.isNotEmpty) {
              //AppLogger.debug('Sample article data: ${jsonData[0]}');
            } else {
              //AppLogger.debug('No articles received from API');
            }

            // Validate teamId filter if applicable
            if (team?.isNotEmpty == true) {
              jsonData
                  .where(
                    (article) =>
                        article['teamId']?.toString().toUpperCase() ==
                        team!.toUpperCase(),
                  )
                  .length;
              //AppLogger.debug(
              //  'Found $filteredCount articles matching teamId: $team',
              //);
            }

            return jsonData.cast<Map<String, dynamic>>();
          } else {
            AppLogger.error(
              'API error ${response.statusCode}',
              'Response body: ${response.body}\nHeaders: ${response.headers}',
            );
            throw Exception(
              'API error: ${response.statusCode} - ${response.body}',
            );
          }
        } finally {
          client.close();
        }
      } catch (e) {
        retryCount++;
        AppLogger.error('Error in attempt $retryCount: ${e.toString()}', e);
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

  /// Fetch all news tickers with retry logic
  static Future<List<NewsTicker>> getNewsTickers({String? team}) async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final http.Client client = http.Client();
        try {
          //AppLogger.debug('Starting news tickers fetch...');

          // Build the URI with team query parameter if provided
          final uri = Uri.parse(
            'https://yqtiuzhedkfacwgormhn.supabase.co/functions/v1/news-ticker',
          );

          // Add team filter if specified
          Map<String, String> queryParams = {};
          if (team?.isNotEmpty == true) {
            queryParams['teamId'] = team!.toUpperCase();
            //AppLogger.debug(
            //  'Added team filter for news tickers: ${team.toUpperCase()}',
            //);
          }

          // Add parameter to indicate we're using the new headline fields
          queryParams['useNewHeadlineFields'] = 'true';
          //AppLogger.debug('Added useNewHeadlineFields flag to API request');

          final filteredUri = uri.replace(queryParameters: queryParams);
          //AppLogger.debug('Making request to: $filteredUri');

          final response = await client
              .get(
                filteredUri,
                headers: {
                  'Authorization': 'Bearer ${AppConfig.apiKey}',
                  'Content-Type': 'application/json',
                },
              )
              .timeout(const Duration(seconds: 10));

          //AppLogger.debug(
          //  'News tickers response status: ${response.statusCode}',
          //);
          //AppLogger.debug('News tickers response headers: ${response.headers}');

          if (response.statusCode == 200) {
            final String rawResponse = response.body;
            //AppLogger.debug('Raw news tickers response: $rawResponse');

            final dynamic decodedData = jsonDecode(rawResponse);
            List<dynamic> jsonData;

            // Handle response with nested data array
            if (decodedData is Map<String, dynamic> &&
                decodedData.containsKey('data')) {
              if (decodedData['data'] is List) {
                jsonData = decodedData['data'];
              } else {
                jsonData = [decodedData['data']];
              }
            } else if (decodedData is List) {
              jsonData = decodedData;
            } else if (decodedData is Map<String, dynamic>) {
              jsonData = [decodedData];
            } else {
              throw Exception(
                'Unexpected response format: ${decodedData.runtimeType}',
              );
            }

            //AppLogger.debug('Parsed ${jsonData.length} news tickers from JSON');

            // Log each ticker for debugging
            for (var _ in jsonData) {
              //AppLogger.debug('Processing ticker: ${ticker.toString()}');
            }

            final tickers =
                jsonData.map((json) {
                  try {
                    return NewsTicker.fromJson(json);
                  } catch (e) {
                    AppLogger.error('Error parsing ticker: $json', e);
                    rethrow;
                  }
                }).toList();

            //AppLogger.debug(
            //  'Successfully created ${tickers.length} NewsTicker objects',
            //);
            return tickers;
          } else {
            AppLogger.error(
              'API error ${response.statusCode}',
              'Response body: ${response.body}\nHeaders: ${response.headers}',
            );
            throw Exception(
              'API error: ${response.statusCode} - ${response.body}',
            );
          }
        } finally {
          client.close();
        }
      } catch (e) {
        retryCount++;
        AppLogger.error('Error in attempt $retryCount: ${e.toString()}', e);
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

  /// Fetch all teams from the edge function with retry logic
  static Future<List<team_model.Team>> getTeams() async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final http.Client client = http.Client();
        try {
          AppLogger.debug('Starting getTeams request...');

          final uri = Uri.parse(
            'https://yqtiuzhedkfacwgormhn.supabase.co/functions/v1/teams',
          );

          AppLogger.debug('Making request to: $uri');

          final response = await client
              .post(
                uri,
                headers: {
                  'Authorization': 'Bearer ${AppConfig.apiKey}',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({"name": "Functions"}),
              )
              .timeout(const Duration(seconds: 10));

          AppLogger.debug('Response status code: ${response.statusCode}');

          if (response.statusCode == 200) {
            AppLogger.debug('Raw API response: ${response.body}');
            final jsonResponse = jsonDecode(response.body);

            if (jsonResponse is Map<String, dynamic> &&
                jsonResponse.containsKey('data')) {
              final List<dynamic> teamsData = jsonResponse['data'];
              AppLogger.debug('Successfully parsed JSON data');
              AppLogger.debug('Received ${teamsData.length} teams from API');

              final teams =
                  teamsData
                      .whereType<Map<String, dynamic>>()
                      .map((json) => team_model.Team.fromJson(json))
                      .toList();

              AppLogger.debug(
                'Successfully created ${teams.length} Team objects',
              );

              // Log sample team data for debugging
              if (teams.isNotEmpty) {
                AppLogger.debug('Sample team: ${teams.first}');
              }

              return teams;
            } else {
              AppLogger.error('Unexpected response format', jsonResponse);
              throw Exception(
                'Unexpected response format: ${jsonResponse.runtimeType}',
              );
            }
          } else {
            AppLogger.error(
              'API error ${response.statusCode}',
              'Response body: ${response.body}\nHeaders: ${response.headers}',
            );
            throw Exception(
              'API error: ${response.statusCode} - ${response.body}',
            );
          }
        } finally {
          client.close();
        }
      } catch (e) {
        retryCount++;
        AppLogger.error('Error in attempt $retryCount: ${e.toString()}', e);
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

  /// Fetch team articles from the edge function with retry logic
  static Future<List<Map<String, dynamic>>> getTeamArticles({
    String? teamId,
  }) async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final http.Client client = http.Client();
        try {
          AppLogger.debug('Starting getTeamArticles request...');

          final uri = Uri.parse(
            'https://yqtiuzhedkfacwgormhn.supabase.co/functions/v1/teamArticles',
          );

          // Add team filter if specified
          Map<String, dynamic> requestBody = {"name": "Functions"};
          if (teamId?.isNotEmpty == true) {
            requestBody["team"] = teamId!.toUpperCase();
            AppLogger.debug(
              'Added team filter for team articles: ${teamId.toUpperCase()}',
            );
          }

          AppLogger.debug('Making request to: $uri with body: $requestBody');

          final response = await client
              .post(
                uri,
                headers: {
                  'Authorization': 'Bearer ${AppConfig.apiKey}',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode(requestBody),
              )
              .timeout(const Duration(seconds: 10));

          AppLogger.debug('Response status code: ${response.statusCode}');

          if (response.statusCode == 200) {
            AppLogger.debug('Raw API response: ${response.body}');
            final jsonResponse = jsonDecode(response.body);

            List<dynamic> articlesData;
            if (jsonResponse is Map<String, dynamic> &&
                jsonResponse.containsKey('data')) {
              articlesData = jsonResponse['data'];
            } else if (jsonResponse is List) {
              articlesData = jsonResponse;
            } else {
              throw Exception(
                'Unexpected response format: ${jsonResponse.runtimeType}',
              );
            }

            AppLogger.debug('Successfully parsed JSON data');
            AppLogger.debug(
              'Received ${articlesData.length} team articles from API',
            );

            return articlesData.cast<Map<String, dynamic>>();
          } else {
            AppLogger.error(
              'API error ${response.statusCode}',
              'Response body: ${response.body}\nHeaders: ${response.headers}',
            );
            throw Exception(
              'API error: ${response.statusCode} - ${response.body}',
            );
          }
        } finally {
          client.close();
        }
      } catch (e) {
        retryCount++;
        AppLogger.error('Error in attempt $retryCount: ${e.toString()}', e);
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

    _teamArticleSubscription?.unsubscribe();
    _teamArticleSubscription = null;
  }
}
