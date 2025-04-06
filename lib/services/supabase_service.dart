import 'package:app/utils/logger.dart';
import 'package:app/config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/models/team.dart' as team_model;
import 'package:app/models/article_ticker.dart';
import 'package:app/models/roster.dart';

class SupabaseService {
  static const bool _enableDebugLogs =
      false; // Toggle for controlling debug logs
  static const String _debugPrefix =
      '[SupabaseService] '; // Prefix for debug logs
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
      if (_enableDebugLogs) {
        AppLogger.debug(
          '${_debugPrefix}Cleaning up existing article subscription',
        );
      }
      _articleSubscription?.unsubscribe();
      _articleSubscription = null;
    }

    // Use a more stable channel name without timestamp to avoid creating too many channels
    final channelName =
        team != null
            ? 'public:NewsArticles:${team.toUpperCase()}'
            : 'public:NewsArticles:all';

    if (_enableDebugLogs) {
      AppLogger.debug(
        '${_debugPrefix}Creating new article subscription on channel: $channelName',
      );
    }

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
              if (_enableDebugLogs) {
                AppLogger.debug(
                  '${_debugPrefix}Realtime update received: ${payload.eventType} on ${payload.table}',
                );
              }
              if (onArticlesUpdate != null) {
                getArticles(team: team, archived: archived)
                    .then((articles) {
                      if (_enableDebugLogs) {
                        AppLogger.debug(
                          '${_debugPrefix}Fetched ${articles.length} articles after realtime update',
                        );
                      }
                      onArticlesUpdate(articles);
                    })
                    .catchError((error) {
                      AppLogger.error(
                        '${_debugPrefix}Error fetching articles after realtime update',
                        error,
                      );
                    });
              }
            },
          );

      // Subscribe with robust error handling and reconnection logic
      channel.subscribe((status, [error]) {
        if (_enableDebugLogs) {
          AppLogger.debug(
            '${_debugPrefix}Channel $channelName status: $status',
          );
        }

        if (status == RealtimeSubscribeStatus.subscribed) {
          if (_enableDebugLogs) {
            AppLogger.debug(
              '${_debugPrefix}Successfully subscribed to $channelName',
            );
          }
        }

        if (error != null) {
          AppLogger.error(
            '${_debugPrefix}Subscription error on $channelName',
            error,
          );
          AppLogger.error('${_debugPrefix}Error details: ${error.toString()}');

          // Attempt to reconnect with exponential backoff
          Future.delayed(Duration(seconds: 5), () {
            if (_articleSubscription == channel &&
                supabase.auth.currentSession != null) {
              if (_enableDebugLogs) {
                AppLogger.debug(
                  '${_debugPrefix}Attempting to reconnect channel: $channelName',
                );
              }

              // Try to refresh the Supabase session if applicable
              try {
                if (supabase.auth.currentSession?.accessToken != null) {
                  if (_enableDebugLogs) {
                    AppLogger.debug(
                      '${_debugPrefix}Refreshing Supabase session before reconnecting',
                    );
                  }
                  supabase.auth.refreshSession();
                }
              } catch (refreshError) {
                AppLogger.error(
                  '${_debugPrefix}Error refreshing session',
                  refreshError,
                );
              }

              channel.subscribe((newStatus, [newError]) {
                if (_enableDebugLogs) {
                  AppLogger.debug(
                    '${_debugPrefix}Reconnection status: $newStatus, error: ${newError != null ? newError.toString() : "none"}',
                  );
                }
              });
            }
          });
        }
      });

      _articleSubscription = channel;
      return channel;
    } catch (e) {
      AppLogger.error('${_debugPrefix}Error creating channel $channelName', e);
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
      if (_enableDebugLogs) {
        AppLogger.debug(
          '${_debugPrefix}Cleaning up existing team article subscription',
        );
      }
      _teamArticleSubscription?.unsubscribe();
      _teamArticleSubscription = null;
    }

    // Use a more stable channel name without timestamp
    final channelName =
        team != null
            ? 'public:TeamNewsArticles:${team.toUpperCase()}'
            : 'public:TeamNewsArticles:all';

    if (_enableDebugLogs) {
      AppLogger.debug(
        '${_debugPrefix}Creating new team articles subscription on channel: $channelName',
      );
    }

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
              if (_enableDebugLogs) {
                AppLogger.debug(
                  '${_debugPrefix}Team article realtime update received: ${payload.eventType} on ${payload.table}',
                );
              }
              if (onTeamArticlesUpdate != null) {
                getTeamArticles(teamId: team)
                    .then((teamArticles) {
                      if (_enableDebugLogs) {
                        AppLogger.debug(
                          '${_debugPrefix}Fetched ${teamArticles.length} team articles after realtime update',
                        );
                      }
                      onTeamArticlesUpdate(teamArticles);
                    })
                    .catchError((error) {
                      AppLogger.error(
                        '${_debugPrefix}Error fetching team articles after realtime update',
                        error,
                      );
                    });
              }
            },
          );

      // Subscribe with robust error handling and reconnection logic
      channel.subscribe((status, [error]) {
        if (_enableDebugLogs) {
          AppLogger.debug(
            '${_debugPrefix}Team articles channel $channelName status: $status',
          );
        }

        if (status == RealtimeSubscribeStatus.subscribed) {
          if (_enableDebugLogs) {
            AppLogger.debug(
              '${_debugPrefix}Successfully subscribed to team articles channel $channelName',
            );
          }
        }

        if (error != null) {
          AppLogger.error(
            '${_debugPrefix}Team articles subscription error on $channelName',
            error,
          );
          AppLogger.error('${_debugPrefix}Error details: ${error.toString()}');

          // Attempt to reconnect with exponential backoff
          Future.delayed(Duration(seconds: 5), () {
            if (_teamArticleSubscription == channel &&
                supabase.auth.currentSession != null) {
              if (_enableDebugLogs) {
                AppLogger.debug(
                  '${_debugPrefix}Attempting to reconnect team articles channel: $channelName',
                );
              }

              // Try to refresh the Supabase session if applicable
              try {
                if (supabase.auth.currentSession?.accessToken != null) {
                  if (_enableDebugLogs) {
                    AppLogger.debug(
                      '${_debugPrefix}Refreshing Supabase session before reconnecting team channel',
                    );
                  }
                  supabase.auth.refreshSession();
                }
              } catch (refreshError) {
                AppLogger.error(
                  '${_debugPrefix}Error refreshing session for team channel',
                  refreshError,
                );
              }

              channel.subscribe((newStatus, [newError]) {
                if (_enableDebugLogs) {
                  AppLogger.debug(
                    '${_debugPrefix}Team articles reconnection status: $newStatus, error: ${newError != null ? newError.toString() : "none"}',
                  );
                }
              });
            }
          });
        }
      });

      _teamArticleSubscription = channel;
      return channel;
    } catch (e) {
      AppLogger.error(
        '${_debugPrefix}Error creating team articles channel $channelName',
        e,
      );
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
      if (_enableDebugLogs) {
        AppLogger.debug(
          '${_debugPrefix}Cleaning up existing article ticker subscription',
        );
      }
      _articleTickerSubscription?.unsubscribe();
      _articleTickerSubscription = null;
    }

    // Use a more stable channel name without timestamp
    final channelName =
        teamId != null
            ? 'public:ArticleTickers:${teamId.toUpperCase()}'
            : 'public:ArticleTickers:all';

    if (_enableDebugLogs) {
      AppLogger.debug(
        '${_debugPrefix}Creating new article tickers subscription on channel: $channelName',
      );
    }

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
              if (_enableDebugLogs) {
                AppLogger.debug(
                  '${_debugPrefix}Article ticker realtime update received: ${payload.eventType} on ${payload.table}',
                );
              }
              if (onArticleTickersUpdate != null) {
                getArticleTickers(teamId: teamId)
                    .then((tickers) {
                      if (_enableDebugLogs) {
                        AppLogger.debug(
                          '${_debugPrefix}Fetched ${tickers.length} article tickers after realtime update',
                        );
                      }
                      onArticleTickersUpdate(tickers);
                    })
                    .catchError((error) {
                      AppLogger.error(
                        '${_debugPrefix}Error fetching article tickers after realtime update',
                        error,
                      );
                    });
              }
            },
          );

      // Subscribe with robust error handling and reconnection logic
      channel.subscribe((status, [error]) {
        if (_enableDebugLogs) {
          AppLogger.debug(
            '${_debugPrefix}Article tickers channel $channelName status: $status',
          );
        }

        if (status == RealtimeSubscribeStatus.subscribed) {
          if (_enableDebugLogs) {
            AppLogger.debug(
              '${_debugPrefix}Successfully subscribed to article tickers channel $channelName',
            );
          }
        }

        if (error != null) {
          AppLogger.error(
            '${_debugPrefix}Article tickers subscription error on $channelName',
            error,
          );
          AppLogger.error('${_debugPrefix}Error details: ${error.toString()}');

          // Attempt to reconnect with exponential backoff
          Future.delayed(Duration(seconds: 5), () {
            if (_articleTickerSubscription == channel &&
                supabase.auth.currentSession != null) {
              if (_enableDebugLogs) {
                AppLogger.debug(
                  '${_debugPrefix}Attempting to reconnect article tickers channel: $channelName',
                );
              }

              // Try to refresh the Supabase session if applicable
              try {
                if (supabase.auth.currentSession?.accessToken != null) {
                  if (_enableDebugLogs) {
                    AppLogger.debug(
                      '${_debugPrefix}Refreshing Supabase session before reconnecting tickers channel',
                    );
                  }
                  supabase.auth.refreshSession();
                }
              } catch (refreshError) {
                AppLogger.error(
                  '${_debugPrefix}Error refreshing session for tickers channel',
                  refreshError,
                );
              }

              channel.subscribe((newStatus, [newError]) {
                if (_enableDebugLogs) {
                  AppLogger.debug(
                    '${_debugPrefix}Article tickers reconnection status: $newStatus, error: ${newError != null ? newError.toString() : "none"}',
                  );
                }
              });
            }
          });
        }
      });

      _articleTickerSubscription = channel;
      return channel;
    } catch (e) {
      AppLogger.error(
        '${_debugPrefix}Error creating article tickers channel $channelName',
        e,
      );
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
          if (_enableDebugLogs) {
            AppLogger.debug('${_debugPrefix}Starting getArticles request...');
            AppLogger.debug(
              '${_debugPrefix}Parameters: team=$team, archived=$archived, excludeIds=$excludeIds',
            );
          }

          final queryParams = <String, String>{'archived': archived.toString()};
          if (team?.isNotEmpty == true) {
            final normalizedTeamId = team!.toUpperCase();
            queryParams['teamId'] = normalizedTeamId;
            if (_enableDebugLogs) {
              AppLogger.debug(
                '${_debugPrefix}Added team filter: $normalizedTeamId',
              );
            }
          }

          if (excludeIds?.isNotEmpty == true) {
            queryParams['excludeIds'] = excludeIds!.join(',');
          }

          final uri = Uri.parse(
            AppConfig.edgeFunctionUrl,
          ).replace(queryParameters: queryParams);

          if (_enableDebugLogs) {
            AppLogger.debug('${_debugPrefix}Making request to: $uri');
            AppLogger.debug(
              '${_debugPrefix}Headers: Authorization: Bearer ${AppConfig.apiKey.substring(0, 4)}... (truncated)',
            );
          }

          final response = await client
              .get(
                uri,
                headers: {
                  'Authorization': 'Bearer ${AppConfig.apiKey}',
                  'Content-Type': 'application/json',
                },
              )
              .timeout(const Duration(seconds: 10));

          if (_enableDebugLogs) {
            AppLogger.debug(
              '${_debugPrefix}Response status code: ${response.statusCode}',
            );
            AppLogger.debug(
              '${_debugPrefix}Response headers: ${response.headers}',
            );
          }

          if (response.statusCode == 200) {
            if (_enableDebugLogs) {
              AppLogger.debug(
                '${_debugPrefix}Raw API response: ${response.body}',
              );
            }
            final List<dynamic> jsonData = jsonDecode(response.body);
            if (_enableDebugLogs) {
              AppLogger.debug('${_debugPrefix}Successfully parsed JSON data');
              AppLogger.debug(
                '${_debugPrefix}Received ${jsonData.length} articles from API',
              );
            }

            // Log first article as sample if available
            if (jsonData.isNotEmpty) {
              if (_enableDebugLogs) {
                AppLogger.debug(
                  '${_debugPrefix}Sample article data: ${jsonData[0]}',
                );
              }
            } else {
              if (_enableDebugLogs) {
                AppLogger.debug('${_debugPrefix}No articles received from API');
              }
            }

            // Validate teamId filter if applicable
            if (team?.isNotEmpty == true) {
              final filteredCount =
                  jsonData
                      .where(
                        (article) =>
                            article['teamId']?.toString().toUpperCase() ==
                            team!.toUpperCase(),
                      )
                      .length;
              if (_enableDebugLogs) {
                AppLogger.debug(
                  '${_debugPrefix}Found $filteredCount articles matching teamId: $team',
                );
              }
            }

            return jsonData.cast<Map<String, dynamic>>();
          } else {
            AppLogger.error(
              '${_debugPrefix}API error ${response.statusCode}',
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
        AppLogger.error(
          '${_debugPrefix}Error in attempt $retryCount: ${e.toString()}',
          e,
        );
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
          if (_enableDebugLogs) {
            AppLogger.debug('${_debugPrefix}Starting getTeams request...');
          }

          final uri = Uri.parse(
            'https://yqtiuzhedkfacwgormhn.supabase.co/functions/v1/teams',
          );

          if (_enableDebugLogs) {
            AppLogger.debug('${_debugPrefix}Making request to: $uri');
          }

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

          if (_enableDebugLogs) {
            AppLogger.debug(
              '${_debugPrefix}Response status code: ${response.statusCode}',
            );
          }

          if (response.statusCode == 200) {
            if (_enableDebugLogs) {
              AppLogger.debug(
                '${_debugPrefix}Raw API response: ${response.body}',
              );
            }
            final jsonResponse = jsonDecode(response.body);

            if (jsonResponse is Map<String, dynamic> &&
                jsonResponse.containsKey('data')) {
              final List<dynamic> teamsData = jsonResponse['data'];
              if (_enableDebugLogs) {
                AppLogger.debug('${_debugPrefix}Successfully parsed JSON data');
                AppLogger.debug(
                  '${_debugPrefix}Received ${teamsData.length} teams from API',
                );
              }

              final teams =
                  teamsData
                      .whereType<Map<String, dynamic>>()
                      .map((json) => team_model.Team.fromJson(json))
                      .toList();

              if (_enableDebugLogs) {
                AppLogger.debug(
                  '${_debugPrefix}Successfully created ${teams.length} Team objects',
                );
                if (teams.isNotEmpty) {
                  AppLogger.debug('${_debugPrefix}Sample team: ${teams.first}');
                }
              }

              return teams;
            } else {
              AppLogger.error(
                '${_debugPrefix}Unexpected response format',
                jsonResponse,
              );
              throw Exception(
                'Unexpected response format: ${jsonResponse.runtimeType}',
              );
            }
          } else {
            AppLogger.error(
              '${_debugPrefix}API error ${response.statusCode}',
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
        AppLogger.error(
          '${_debugPrefix}Error in attempt $retryCount: ${e.toString()}',
          e,
        );
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
          if (_enableDebugLogs) {
            AppLogger.debug(
              '${_debugPrefix}Starting getTeamArticles request...',
            );
          }

          final uri = Uri.parse(
            'https://yqtiuzhedkfacwgormhn.supabase.co/functions/v1/teamArticles',
          );

          // Add team filter if specified
          Map<String, dynamic> requestBody = {"name": "Functions"};
          if (teamId?.isNotEmpty == true) {
            requestBody["team"] = teamId!.toUpperCase();
            if (_enableDebugLogs) {
              AppLogger.debug(
                '${_debugPrefix}Added team filter for team articles: ${teamId.toUpperCase()}',
              );
            }
          }

          if (_enableDebugLogs) {
            AppLogger.debug(
              '${_debugPrefix}Making request to: $uri with body: $requestBody',
            );
          }

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

          if (_enableDebugLogs) {
            AppLogger.debug(
              '${_debugPrefix}Response status code: ${response.statusCode}',
            );
          }

          if (response.statusCode == 200) {
            if (_enableDebugLogs) {
              AppLogger.debug(
                '${_debugPrefix}Raw API response: ${response.body}',
              );
            }
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

            if (_enableDebugLogs) {
              AppLogger.debug('${_debugPrefix}Successfully parsed JSON data');
              AppLogger.debug(
                '${_debugPrefix}Received ${articlesData.length} team articles from API',
              );
            }

            return articlesData.cast<Map<String, dynamic>>();
          } else {
            AppLogger.error(
              '${_debugPrefix}API error ${response.statusCode}',
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
        AppLogger.error(
          '${_debugPrefix}Error in attempt $retryCount: ${e.toString()}',
          e,
        );
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
          if (_enableDebugLogs) {
            AppLogger.debug(
              '${_debugPrefix}Starting getArticleTickers request...',
            );
          }

          // Build URI with query parameters if teamId is provided
          final uri = Uri.parse(
            'https://yqtiuzhedkfacwgormhn.supabase.co/functions/v1/articleTicker',
          ).replace(
            queryParameters:
                teamId?.isNotEmpty == true
                    ? {'teamId': teamId!.toUpperCase()}
                    : null,
          );

          if (_enableDebugLogs) {
            AppLogger.debug('${_debugPrefix}Making GET request to: $uri');
          }

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
          if (_enableDebugLogs) {
            AppLogger.debug(
              '${_debugPrefix}API response preview: $responsePreview',
            );
          }

          if (response.statusCode == 200) {
            final jsonResponse = jsonDecode(response.body);
            List<dynamic> tickersData;

            // Handle different response formats with more robust checking
            if (jsonResponse is Map<String, dynamic>) {
              // Check for nested data structure
              if (jsonResponse.containsKey('data')) {
                tickersData =
                    jsonResponse['data'] is List ? jsonResponse['data'] : [];
                if (_enableDebugLogs) {
                  AppLogger.debug(
                    '${_debugPrefix}Found data in nested format with ${tickersData.length} items',
                  );
                }
              } else {
                // Try to extract array items from the map
                final entries =
                    jsonResponse.entries
                        .where((e) => e.value is Map)
                        .map((e) => e.value)
                        .toList();
                if (entries.isNotEmpty) {
                  tickersData = entries;
                  if (_enableDebugLogs) {
                    AppLogger.debug(
                      '${_debugPrefix}Extracted ${tickersData.length} map entries as tickers',
                    );
                  }
                } else {
                  // If no entries found, use the map itself as a single item
                  tickersData = [jsonResponse];
                  if (_enableDebugLogs) {
                    AppLogger.debug(
                      '${_debugPrefix}Using entire response as a single ticker',
                    );
                  }
                }
              }
            } else if (jsonResponse is List) {
              tickersData = jsonResponse;
              if (_enableDebugLogs) {
                AppLogger.debug(
                  '${_debugPrefix}Response is directly a list with ${tickersData.length} items',
                );
              }
            } else {
              AppLogger.error(
                '${_debugPrefix}Unexpected response type: ${jsonResponse.runtimeType}',
              );
              throw Exception(
                'Unexpected response format: ${jsonResponse.runtimeType}',
              );
            }

            if (_enableDebugLogs) {
              AppLogger.debug('${_debugPrefix}Successfully parsed JSON data');
              AppLogger.debug(
                '${_debugPrefix}Received ${tickersData.length} article tickers from API',
              );
            }

            if (tickersData.isEmpty) {
              if (_enableDebugLogs) {
                AppLogger.debug(
                  '${_debugPrefix}WARNING: Empty ticker data from API',
                );
              }
              return [];
            }

            // Log sample of first ticker for debugging
            if (tickersData.isNotEmpty) {
              if (_enableDebugLogs) {
                AppLogger.debug(
                  '${_debugPrefix}Sample ticker data: ${tickersData.first}',
                );
              }
            }

            // Convert JSON to ArticleTicker objects with better error handling
            final tickers = <ArticleTicker>[];
            for (final json in tickersData) {
              try {
                if (json is Map<String, dynamic>) {
                  final ticker = ArticleTicker.fromJson(json);
                  tickers.add(ticker);
                } else {
                  if (_enableDebugLogs) {
                    AppLogger.debug(
                      '${_debugPrefix}Skipping non-map ticker data: $json',
                    );
                  }
                }
              } catch (e) {
                AppLogger.error(
                  '${_debugPrefix}Error parsing individual article ticker',
                  e,
                );
                // Continue processing other tickers even if one fails
              }
            }

            if (_enableDebugLogs) {
              AppLogger.debug(
                '${_debugPrefix}Successfully created ${tickers.length} ArticleTicker objects',
              );
            }
            return tickers;
          } else {
            AppLogger.error(
              '${_debugPrefix}API error ${response.statusCode}',
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
        AppLogger.error(
          '${_debugPrefix}Error in attempt $retryCount: ${e.toString()}',
          e,
        );
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

  /// Fetch roster information from the edge function with retry logic
  static Future<List<Roster>> getRoster({
    String? teamId,
    int page = 1,
    int pageSize = 100,
  }) async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final http.Client client = http.Client();
        try {
          if (_enableDebugLogs) {
            AppLogger.debug('${_debugPrefix}Starting getRoster request');
            AppLogger.debug(
              '${_debugPrefix}Parameters: teamId=$teamId, page=$page, pageSize=$pageSize',
            );
          }

          final String normalizedTeamId = teamId?.toString() ?? '';
          if (_enableDebugLogs && normalizedTeamId.isNotEmpty) {
            AppLogger.debug(
              '${_debugPrefix}Using normalized teamId: $normalizedTeamId',
            );
          }

          final uri = Uri.parse(
            'https://yqtiuzhedkfacwgormhn.supabase.co/functions/v1/roster',
          ).replace(
            queryParameters: {
              if (normalizedTeamId.isNotEmpty) 'teamId': normalizedTeamId,
              'page': page.toString(),
              'page_size': pageSize.toString(),
            },
          );

          if (_enableDebugLogs) {
            AppLogger.debug('${_debugPrefix}Making request to: $uri');
            AppLogger.debug(
              '${_debugPrefix}Request headers: Authorization=Bearer ${AppConfig.apiKey.substring(0, 4)}... (truncated)',
            );
          }

          final response = await client
              .get(
                uri,
                headers: {
                  'Authorization': 'Bearer ${AppConfig.apiKey}',
                  'Content-Type': 'application/json',
                },
              )
              .timeout(const Duration(seconds: 15));

          if (_enableDebugLogs) {
            AppLogger.debug(
              '${_debugPrefix}Response status: ${response.statusCode}',
            );
            AppLogger.debug(
              '${_debugPrefix}Response headers: ${response.headers}',
            );
          }

          if (response.statusCode == 200) {
            final responseBody = response.body;
            if (_enableDebugLogs) {
              // Log preview of response for debugging
              final preview =
                  responseBody.length > 200
                      ? "${responseBody.substring(0, 200)}..."
                      : responseBody;
              AppLogger.debug('${_debugPrefix}Response preview: $preview');
            }

            final jsonResponse = jsonDecode(responseBody);
            List<dynamic> rosterData;

            if (jsonResponse is Map<String, dynamic> &&
                jsonResponse.containsKey('data')) {
              rosterData = jsonResponse['data'];
              if (_enableDebugLogs) {
                AppLogger.debug(
                  '${_debugPrefix}Found nested data with ${rosterData.length} entries',
                );
              }
            } else if (jsonResponse is List) {
              rosterData = jsonResponse;
              if (_enableDebugLogs) {
                AppLogger.debug(
                  '${_debugPrefix}Found direct list with ${rosterData.length} entries',
                );
              }
            } else {
              throw Exception(
                'Unexpected response format: ${jsonResponse.runtimeType}',
              );
            }

            if (_enableDebugLogs && rosterData.isNotEmpty) {
              AppLogger.debug(
                '${_debugPrefix}Sample roster entry: ${rosterData.first}',
              );
            }

            final roster =
                rosterData
                    .map((json) {
                      try {
                        if (json is! Map<String, dynamic>) {
                          if (_enableDebugLogs) {
                            AppLogger.debug(
                              '${_debugPrefix}Skipping invalid roster entry: $json',
                            );
                          }
                          return null;
                        }
                        final result = Roster.fromJson(json);
                        if (_enableDebugLogs) {
                          AppLogger.debug(
                            '${_debugPrefix}Parsed roster entry: ID=${result.id}, TeamID=${result.teamId}',
                          );
                        }
                        return result;
                      } catch (e) {
                        AppLogger.error(
                          '${_debugPrefix}Error parsing roster entry',
                          e,
                        );
                        return null;
                      }
                    })
                    .where((r) => r != null)
                    .cast<Roster>()
                    .toList();

            if (_enableDebugLogs) {
              AppLogger.debug(
                '${_debugPrefix}Successfully processed ${roster.length} roster entries',
              );
              AppLogger.debug(
                '${_debugPrefix}Memory usage stats: ${roster.length} objects created',
              );
            }

            return roster;
          } else {
            AppLogger.error(
              '${_debugPrefix}API error ${response.statusCode}',
              'Response: ${response.body}\nHeaders: ${response.headers}',
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
        AppLogger.error(
          '${_debugPrefix}Error in attempt $retryCount: ${e.toString()}',
          e,
        );
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
    if (_enableDebugLogs) {
      AppLogger.debug('${_debugPrefix}Starting cleanup of subscriptions');
    }

    if (_articleSubscription != null) {
      if (_enableDebugLogs) {
        AppLogger.debug(
          '${_debugPrefix}Unsubscribing from article subscription',
        );
      }
      _articleSubscription?.unsubscribe();
      _articleSubscription = null;
    }

    if (_teamArticleSubscription != null) {
      if (_enableDebugLogs) {
        AppLogger.debug(
          '${_debugPrefix}Unsubscribing from team article subscription',
        );
      }
      _teamArticleSubscription?.unsubscribe();
      _teamArticleSubscription = null;
    }

    if (_articleTickerSubscription != null) {
      if (_enableDebugLogs) {
        AppLogger.debug(
          '${_debugPrefix}Unsubscribing from article ticker subscription',
        );
      }
      _articleTickerSubscription?.unsubscribe();
      _articleTickerSubscription = null;
    }

    if (_enableDebugLogs) AppLogger.debug('${_debugPrefix}Cleanup completed');
  }
}
