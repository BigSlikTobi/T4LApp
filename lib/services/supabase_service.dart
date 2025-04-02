import 'package:app/utils/logger.dart';
import 'package:app/config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/models/team.dart' as team_model;
import 'package:app/models/article_ticker.dart';

class SupabaseService {
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  static final supabase = Supabase.instance.client;

  static RealtimeChannel? _articleSubscription;
  static RealtimeChannel? _teamArticleSubscription;
  static RealtimeChannel? _articleTickerSubscription;

  /// Subscribe to realtime updates for articles
  static RealtimeChannel subscribeToArticles({
    String? team,
    bool archived = false,
    Function(List<Map<String, dynamic>>)? onArticlesUpdate,
  }) {
    // Clean up existing subscription
    if (_articleSubscription != null) {
      AppLogger.debug('Cleaning up existing article subscription');
      _articleSubscription?.unsubscribe();
      _articleSubscription = null;
    }

    // Use a more stable channel name without timestamp to avoid creating too many channels
    final channelName =
        team != null
            ? 'public:NewsArticles:${team.toUpperCase()}'
            : 'public:NewsArticles:all';

    AppLogger.debug(
      'Creating new article subscription on channel: $channelName',
    );

    try {
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

      // Subscribe with robust error handling and reconnection logic
      channel.subscribe((status, [error]) {
        AppLogger.debug('Channel $channelName status: $status');

        if (status == RealtimeSubscribeStatus.subscribed) {
          AppLogger.debug('Successfully subscribed to $channelName');
        }

        if (error != null) {
          AppLogger.error('Subscription error on $channelName', error);
          AppLogger.error('Error details: ${error.toString()}');

          // Attempt to reconnect with exponential backoff
          Future.delayed(Duration(seconds: 5), () {
            if (_articleSubscription == channel &&
                supabase.auth.currentSession != null) {
              AppLogger.debug('Attempting to reconnect channel: $channelName');

              // Try to refresh the Supabase session if applicable
              try {
                if (supabase.auth.currentSession?.accessToken != null) {
                  AppLogger.debug(
                    'Refreshing Supabase session before reconnecting',
                  );
                  supabase.auth.refreshSession();
                }
              } catch (refreshError) {
                AppLogger.error('Error refreshing session', refreshError);
              }

              channel.subscribe((newStatus, [newError]) {
                AppLogger.debug(
                  'Reconnection status: $newStatus, error: ${newError != null ? newError.toString() : "none"}',
                );
              });
            }
          });
        }
      });

      _articleSubscription = channel;
      return channel;
    } catch (e) {
      AppLogger.error('Error creating channel $channelName', e);
      rethrow;
    }
  }

  /// Subscribe to realtime updates for team articles
  static RealtimeChannel subscribeToTeamArticles({
    String? team,
    Function(List<Map<String, dynamic>>)? onTeamArticlesUpdate,
  }) {
    // Clean up existing subscription
    if (_teamArticleSubscription != null) {
      AppLogger.debug('Cleaning up existing team article subscription');
      _teamArticleSubscription?.unsubscribe();
      _teamArticleSubscription = null;
    }

    // Use a more stable channel name without timestamp
    final channelName =
        team != null
            ? 'public:TeamNewsArticles:${team.toUpperCase()}'
            : 'public:TeamNewsArticles:all';

    AppLogger.debug(
      'Creating new team articles subscription on channel: $channelName',
    );

    try {
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

      // Subscribe with robust error handling and reconnection logic
      channel.subscribe((status, [error]) {
        AppLogger.debug('Team articles channel $channelName status: $status');

        if (status == RealtimeSubscribeStatus.subscribed) {
          AppLogger.debug(
            'Successfully subscribed to team articles channel $channelName',
          );
        }

        if (error != null) {
          AppLogger.error(
            'Team articles subscription error on $channelName',
            error,
          );
          AppLogger.error('Error details: ${error.toString()}');

          // Attempt to reconnect with exponential backoff
          Future.delayed(Duration(seconds: 5), () {
            if (_teamArticleSubscription == channel &&
                supabase.auth.currentSession != null) {
              AppLogger.debug(
                'Attempting to reconnect team articles channel: $channelName',
              );

              // Try to refresh the Supabase session if applicable
              try {
                if (supabase.auth.currentSession?.accessToken != null) {
                  AppLogger.debug(
                    'Refreshing Supabase session before reconnecting team channel',
                  );
                  supabase.auth.refreshSession();
                }
              } catch (refreshError) {
                AppLogger.error(
                  'Error refreshing session for team channel',
                  refreshError,
                );
              }

              channel.subscribe((newStatus, [newError]) {
                AppLogger.debug(
                  'Team articles reconnection status: $newStatus, error: ${newError != null ? newError.toString() : "none"}',
                );
              });
            }
          });
        }
      });

      _teamArticleSubscription = channel;
      return channel;
    } catch (e) {
      AppLogger.error('Error creating team articles channel $channelName', e);
      rethrow;
    }
  }

  /// Subscribe to realtime updates for article tickers
  static RealtimeChannel subscribeToArticleTickers({
    String? teamId,
    Function(List<ArticleTicker>)? onArticleTickersUpdate,
  }) {
    // Clean up existing subscription
    if (_articleTickerSubscription != null) {
      AppLogger.debug('Cleaning up existing article ticker subscription');
      _articleTickerSubscription?.unsubscribe();
      _articleTickerSubscription = null;
    }

    // Use a more stable channel name without timestamp
    final channelName =
        teamId != null
            ? 'public:ArticleTickers:${teamId.toUpperCase()}'
            : 'public:ArticleTickers:all';

    AppLogger.debug(
      'Creating new article tickers subscription on channel: $channelName',
    );

    try {
      final channel = supabase
          .channel(channelName)
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'ArticleTickers',
            filter:
                teamId?.isNotEmpty == true
                    ? PostgresChangeFilter(
                      type: PostgresChangeFilterType.eq,
                      column: 'teamId',
                      value: teamId!.toUpperCase(),
                    )
                    : null,
            callback: (payload) {
              AppLogger.debug(
                'Article ticker realtime update received: ${payload.eventType} on ${payload.table}',
              );
              if (onArticleTickersUpdate != null) {
                getArticleTickers(teamId: teamId)
                    .then((tickers) {
                      AppLogger.debug(
                        'Fetched ${tickers.length} article tickers after realtime update',
                      );
                      onArticleTickersUpdate(tickers);
                    })
                    .catchError((error) {
                      AppLogger.error(
                        'Error fetching article tickers after realtime update',
                        error,
                      );
                    });
              }
            },
          );

      // Subscribe with robust error handling and reconnection logic
      channel.subscribe((status, [error]) {
        AppLogger.debug('Article tickers channel $channelName status: $status');

        if (status == RealtimeSubscribeStatus.subscribed) {
          AppLogger.debug(
            'Successfully subscribed to article tickers channel $channelName',
          );
        }

        if (error != null) {
          AppLogger.error(
            'Article tickers subscription error on $channelName',
            error,
          );
          AppLogger.error('Error details: ${error.toString()}');

          // Attempt to reconnect with exponential backoff
          Future.delayed(Duration(seconds: 5), () {
            if (_articleTickerSubscription == channel &&
                supabase.auth.currentSession != null) {
              AppLogger.debug(
                'Attempting to reconnect article tickers channel: $channelName',
              );

              // Try to refresh the Supabase session if applicable
              try {
                if (supabase.auth.currentSession?.accessToken != null) {
                  AppLogger.debug(
                    'Refreshing Supabase session before reconnecting tickers channel',
                  );
                  supabase.auth.refreshSession();
                }
              } catch (refreshError) {
                AppLogger.error(
                  'Error refreshing session for tickers channel',
                  refreshError,
                );
              }

              channel.subscribe((newStatus, [newError]) {
                AppLogger.debug(
                  'Article tickers reconnection status: $newStatus, error: ${newError != null ? newError.toString() : "none"}',
                );
              });
            }
          });
        }
      });

      _articleTickerSubscription = channel;
      return channel;
    } catch (e) {
      AppLogger.error('Error creating article tickers channel $channelName', e);
      rethrow;
    }
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

  /// Fetch article tickers from the edge function with retry logic
  static Future<List<ArticleTicker>> getArticleTickers({String? teamId}) async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final http.Client client = http.Client();
        try {
          AppLogger.debug('Starting getArticleTickers request...');
          
          // Build URI with query parameters if teamId is provided
          final uri = Uri.parse(
            'https://yqtiuzhedkfacwgormhn.supabase.co/functions/v1/articleTicker',
          ).replace(
            queryParameters: teamId?.isNotEmpty == true 
              ? {'teamId': teamId!.toUpperCase()}
              : null,
          );
          
          AppLogger.debug('Making GET request to: $uri');
          
          final response = await client
              .get(
                uri,
                headers: {
                  'Authorization': 'Bearer ${AppConfig.apiKey}',
                  'Content-Type': 'application/json',
                },
              )
              .timeout(const Duration(seconds: 10));
              
          // Log the first 200 characters of response for debugging
          final responsePreview =
              response.body.length > 200
                  ? "${response.body.substring(0, 200)}..."
                  : response.body;
          AppLogger.debug('API response preview: $responsePreview');

          if (response.statusCode == 200) {
            final jsonResponse = jsonDecode(response.body);
            List<dynamic> tickersData;

            // Handle different response formats with more robust checking
            if (jsonResponse is Map<String, dynamic>) {
              // Check for nested data structure
              if (jsonResponse.containsKey('data')) {
                tickersData =
                    jsonResponse['data'] is List ? jsonResponse['data'] : [];
                AppLogger.debug(
                  'Found data in nested format with ${tickersData.length} items',
                );
              } else {
                // Try to extract array items from the map
                final entries =
                    jsonResponse.entries
                        .where((e) => e.value is Map)
                        .map((e) => e.value)
                        .toList();
                if (entries.isNotEmpty) {
                  tickersData = entries;
                  AppLogger.debug(
                    'Extracted ${tickersData.length} map entries as tickers',
                  );
                } else {
                  // If no entries found, use the map itself as a single item
                  tickersData = [jsonResponse];
                  AppLogger.debug('Using entire response as a single ticker');
                }
              }
            } else if (jsonResponse is List) {
              tickersData = jsonResponse;
              AppLogger.debug(
                'Response is directly a list with ${tickersData.length} items',
              );
            } else {
              AppLogger.error(
                'Unexpected response type: ${jsonResponse.runtimeType}',
              );
              throw Exception(
                'Unexpected response format: ${jsonResponse.runtimeType}',
              );
            }

            AppLogger.debug('Successfully parsed JSON data');
            AppLogger.debug(
              'Received ${tickersData.length} article tickers from API',
            );

            if (tickersData.isEmpty) {
              AppLogger.debug('WARNING: Empty ticker data from API');
              return [];
            }

            // Log sample of first ticker for debugging
            if (tickersData.isNotEmpty) {
              AppLogger.debug('Sample ticker data: ${tickersData.first}');
            }

            // Convert JSON to ArticleTicker objects with better error handling
            final tickers = <ArticleTicker>[];
            for (final json in tickersData) {
              try {
                if (json is Map<String, dynamic>) {
                  final ticker = ArticleTicker.fromJson(json);
                  tickers.add(ticker);
                } else {
                  AppLogger.debug('Skipping non-map ticker data: $json');
                }
              } catch (e) {
                AppLogger.error('Error parsing individual article ticker', e);
                // Continue processing other tickers even if one fails
              }
            }

            AppLogger.debug(
              'Successfully created ${tickers.length} ArticleTicker objects',
            );
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

  /// Cleanup method to be called when the app is disposed
  static void dispose() {
    _articleSubscription?.unsubscribe();
    _articleSubscription = null;

    _teamArticleSubscription?.unsubscribe();
    _teamArticleSubscription = null;

    _articleTickerSubscription?.unsubscribe();
    _articleTickerSubscription = null;
  }
}
