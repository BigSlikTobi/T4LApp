import 'package:flutter/material.dart';
import 'package:app/models/article.dart';
import 'package:app/models/article_ticker.dart'; // Changed to use ArticleTicker
import 'package:app/models/team.dart';
import 'package:app/services/supabase_service.dart';
import 'package:app/utils/logger.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'modern_news_card.dart';
import 'article_page.dart';
import 'widgets/embedded_ticker_slideshow.dart'; // Added import

// Import the team logo mapping from the Team model
final teamLogoMap = {
  'ARI': 'arizona_cardinals',
  'ATL': 'atlanta_falcons',
  'BAL': 'baltimore_ravens',
  'BUF': 'buffalo_bills',
  'CAR': 'carolina_panthers',
  'CHI': 'chicago_bears',
  'CIN': 'cincinnati_bengals',
  'CLE': 'cleveland_browns',
  'DAL': 'dallas_cowboys',
  'DEN': 'denver_broncos',
  'DET': 'detroit_lions',
  'GB': 'Green_bay_packers',
  'HOU': 'houston_texans',
  'IND': 'indianapolis_colts',
  'JAC': 'jacksonville_jaguars',
  'JAX': 'jacksonville_jaguars',
  'KC': 'kansas_city_chiefs',
  'LV': 'las_vegas_raiders',
  'LAC': 'los_angeles_chargers',
  'LAR': 'los_angeles_rams',
  'MIA': 'miami_dolphins',
  'MIN': 'minnesota_vikings',
  'NE': 'new_england_patriots',
  'NO': 'new_orleans_saints',
  'NYG': 'new_york_giants',
  'NYJ': 'new_york_jets',
  'PHI': 'philadelphia_eagles',
  'PIT': 'pittsbourg_steelers',
  'SF': 'san_francisco_49ers',
  'SEA': 'seattle_seahawks',
  'TB': 'tampa_bay_buccaneers',
  'TEN': 'tennessee_titans',
  'WAS': 'washington_commanders',
  'WSH': 'washington_commanders',
};

class News extends StatefulWidget {
  const News({super.key});

  @override
  State<News> createState() => _NewsState();
}

class _NewsState extends State<News> {
  String?
  selectedTeamId; // Changed from selectedTeam to selectedTeamId for clarity
  bool showArchived = false;
  Future<List<Article>>? articlesFuture;
  List<Article> articles = [];
  List<ArticleTicker> articleTickers = []; // Changed to ArticleTicker
  bool isLoading = false;
  String? errorMessage;
  RealtimeChannel? _subscription;
  RealtimeChannel? _tickerSubscription; // Added for article ticker subscription

  @override
  void initState() {
    super.initState();
    articlesFuture = _fetchArticles();
    _fetchArticleTickers(); // Changed to fetch article tickers
    _setupRealtimeSubscription();
    _setupTickerRealtimeSubscription(); // Added for real-time ticker updates
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _subscription = null;
    _tickerSubscription?.unsubscribe();
    _tickerSubscription = null;
    SupabaseService.dispose();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    // Clean up existing subscription
    _subscription?.unsubscribe();
    _subscription = null;

    // Create new subscription
    _subscription = SupabaseService.subscribeToArticles(
      team: selectedTeamId, // Use selectedTeamId
      archived: showArchived,
      onArticlesUpdate: (articles) {
        if (mounted) {
          setState(() {
            AppLogger.debug(
              'Received realtime update with ${articles.length} articles',
            );
            this.articles =
                articles
                    .map((articleJson) => Article.fromJson(articleJson))
                    .toList()
                  ..sort(
                    (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
                      a.createdAt ?? DateTime.now(),
                    ),
                  );
          });
        }
      },
    );
  }

  // Added method to setup realtime subscription for article tickers
  void _setupTickerRealtimeSubscription() {
    // Clean up existing subscription
    _tickerSubscription?.unsubscribe();
    _tickerSubscription = null;

    // Create new subscription
    _tickerSubscription = SupabaseService.subscribeToArticleTickers(
      teamId: selectedTeamId,
      onArticleTickersUpdate: (tickers) {
        if (mounted) {
          setState(() {
            AppLogger.debug(
              'Received realtime update with ${tickers.length} article tickers',
            );
            articleTickers = tickers;
          });
        }
      },
    );
  }

  Future<List<Article>> _fetchArticles() async {
    AppLogger.debug('Fetching articles with teamId filter: "$selectedTeamId"');
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Get articles from edge function with team filter
      final articlesData = await SupabaseService.getArticles(
        team: selectedTeamId?.toUpperCase(), // Ensure team ID is uppercase
        archived: showArchived,
      );

      AppLogger.debug('Received ${articlesData.length} articles from service');
      AppLogger.debug('Filtering for team: ${selectedTeamId ?? "all teams"}');

      // Map the JSON data to Article objects and filter by team if selected
      final List<Article> fetchedArticles =
          articlesData
              .map((articleJson) => Article.fromJson(articleJson))
              .where(
                (article) =>
                    selectedTeamId == null ||
                    article.teamId?.toUpperCase() ==
                        selectedTeamId?.toUpperCase(),
              )
              .toList();

      // Sort by date
      fetchedArticles.sort(
        (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
          a.createdAt ?? DateTime.now(),
        ),
      );

      // Log the filtered articles
      AppLogger.debug('Filtered articles count: ${fetchedArticles.length}');
      if (selectedTeamId != null) {
        AppLogger.debug(
          'Articles for team $selectedTeamId: ${fetchedArticles.length}',
        );
      }

      // Update the articles list
      setState(() {
        articles = fetchedArticles;
      });

      return fetchedArticles;
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load articles: ${e.toString()}';
      });
      AppLogger.error('Error fetching articles from edge function', e);
      return [];
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Changed to fetch article tickers with retry mechanism
  Future<void> _fetchArticleTickers() async {
    AppLogger.debug('Starting to fetch article tickers in News widget');

    // Use a retry mechanism with exponential backoff
    const maxRetries = 3;
    int retryCount = 0;
    bool success = false;

    while (!success && retryCount < maxRetries) {
      try {
        // Add more detailed logging about the request
        AppLogger.debug(
          'Calling SupabaseService.getArticleTickers with teamId: ${selectedTeamId ?? "null"} (attempt ${retryCount + 1})',
        );

        final tickers = await SupabaseService.getArticleTickers(
          teamId: selectedTeamId,
        );

        // More comprehensive logging of the response
        AppLogger.debug('Received ${tickers.length} tickers from service');

        if (tickers.isEmpty) {
          AppLogger.debug('WARNING: Received empty tickers list from Supabase');

          // Only retry if this wasn't our last attempt
          if (retryCount < maxRetries - 1) {
            retryCount++;
            AppLogger.debug(
              'Will retry fetching tickers (attempt ${retryCount + 1} of $maxRetries)',
            );
            await Future.delayed(
              Duration(seconds: retryCount * 2),
            ); // Exponential backoff
            continue;
          }
        } else {
          // Log first ticker details to verify data structure
          final firstTicker = tickers.first;
          AppLogger.debug('First ticker details:');
          AppLogger.debug('- ID: ${firstTicker.id}');
          AppLogger.debug('- Image2: ${firstTicker.image2 ?? "null"}');
          AppLogger.debug('- EnglishHeadline: ${firstTicker.englishHeadline}');
          AppLogger.debug('- GermanHeadline: ${firstTicker.germanHeadline}');
          AppLogger.debug('- TeamId: ${firstTicker.teamId ?? "null"}');

          // Log raw JSON for debugging
          AppLogger.debug('DEBUGGING: First ticker raw JSON:');
          AppLogger.debug(firstTicker.toJson().toString());
        }

        // Sort by createdAt date
        final sortedTickers =
            tickers.toList()..sort((a, b) {
              final aDate = DateTime.tryParse(a.createdAt ?? '');
              final bDate = DateTime.tryParse(b.createdAt ?? '');
              if (aDate == null || bDate == null) return 0;
              return bDate.compareTo(aDate); // newest first
            });

        if (mounted) {
          setState(() {
            articleTickers = sortedTickers;
            AppLogger.debug(
              'Updated articleTickers state with ${sortedTickers.length} items',
            );
          });
        }

        success = true; // Mark operation as successful
      } catch (e, stackTrace) {
        retryCount++;
        final waitTime = retryCount * 2; // Exponential backoff

        AppLogger.error(
          'Error fetching article tickers (attempt $retryCount of $maxRetries)',
          e,
        );
        AppLogger.error('Stack trace:', stackTrace);

        if (retryCount < maxRetries) {
          AppLogger.debug('Retrying after $waitTime seconds...');
          await Future.delayed(Duration(seconds: waitTime));
        }
      }
    }

    // If we still have no tickers after all retries, try an alternate approach
    if (success == false && mounted && articleTickers.isEmpty) {
      AppLogger.debug(
        'All fetch attempts failed, trying alternate approach with delay',
      );

      // Try one more time after a longer delay
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          SupabaseService.getArticleTickers(teamId: selectedTeamId)
              .then((newTickers) {
                if (mounted && newTickers.isNotEmpty) {
                  setState(() {
                    articleTickers = newTickers;
                    AppLogger.debug(
                      'Fetch successful on final attempt with ${newTickers.length} tickers',
                    );
                  });
                }
              })
              .catchError((error) {
                AppLogger.error(
                  'Final attempt to fetch tickers also failed',
                  error,
                );
              });
        }
      });
    }
  }

  void _onArticleClick(int id) {
    AppLogger.debug('Navigating to article with ID: $id');
    final article = articles.firstWhere((article) {
      AppLogger.debug('Checking article ID: ${article.id}');
      return article.id == id;
    });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ArticlePage(article: article)),
    ).then((_) {
      _refreshArticles();
    });
    AppLogger.debug('Navigating to article $id');
  }

  void _refreshArticles() {
    AppLogger.debug('Refreshing articles with teamId: "$selectedTeamId"');
    setState(() {
      articlesFuture = _fetchArticles();
    });

    // Also refresh article tickers when articles are refreshed
    _fetchArticleTickers();

    // Re-setup realtime subscriptions with current filters
    _setupRealtimeSubscription();
    _setupTickerRealtimeSubscription();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish =
        languageProvider.currentLanguage == LanguageProvider.english;
    final isWeb = MediaQuery.of(context).size.width > 600;

    // Log MediaQuery size and isWeb flag to validate layout constraints
    AppLogger.debug(
      'News build: isWeb=$isWeb, MediaQuery size=${MediaQuery.of(context).size}',
    );

    // Get team data for dropdown
    final allTeams =
        teamLogoMap.entries
            .map(
              (entry) => Team(
                teamId: entry.key,
                fullName: '', // Not needed for logo display
                division: '',
                conference: '',
              ),
            )
            .toList();
    allTeams.sort((a, b) => a.teamId.compareTo(b.teamId));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isWeb ? 1200 : double.infinity,
            ),
            child: Column(
              children: [
                Expanded(
                  child: FutureBuilder<List<Article>>(
                    future: articlesFuture ?? Future.value([]),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting ||
                          isLoading) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        );
                      } else if (articles.isNotEmpty ||
                          articleTickers.isNotEmpty) {
                        return Container(
                          color: Colors.white,
                          child: SingleChildScrollView(
                            physics: AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isWeb ? 24.0 : 8.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Replace heading and subheader
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 20,
                                      left: 20,
                                      right: 20,
                                    ),
                                    child: Container(),
                                  ),
                                  // Changed to use EmbeddedTickerSlideshow
                                  const EmbeddedTickerSlideshow(),
                                  SizedBox(height: 24),
                                  // Add dividing line and team picker with headline
                                  Divider(
                                    height: 1,
                                    color: Colors.grey.shade300,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14.0,
                                      horizontal: 20.0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'NFL News',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                  color: const Color.fromARGB(
                                                    221,
                                                    32,
                                                    68,
                                                    43,
                                                  ),
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return Dialog(
                                                  backgroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Container(
                                                    width: 80,
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical: 8,
                                                        ),
                                                    child: SingleChildScrollView(
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          InkWell(
                                                            onTap: () {
                                                              setState(() {
                                                                selectedTeamId =
                                                                    null;
                                                              });
                                                              _refreshArticles();
                                                              Navigator.pop(
                                                                context,
                                                              );
                                                            },
                                                            child: Center(
                                                              child: Padding(
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      1.0,
                                                                    ),
                                                                child: Image.asset(
                                                                  'assets/logos/nfl.png',
                                                                  height: 40,
                                                                  alignment:
                                                                      Alignment
                                                                          .center,
                                                                  fit:
                                                                      BoxFit
                                                                          .contain,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          Divider(height: 1),
                                                          ...allTeams.map(
                                                            (team) => InkWell(
                                                              onTap: () {
                                                                setState(() {
                                                                  selectedTeamId =
                                                                      team.teamId;
                                                                });
                                                                _refreshArticles();
                                                                Navigator.pop(
                                                                  context,
                                                                );
                                                              },
                                                              child: Center(
                                                                child: Padding(
                                                                  padding:
                                                                      const EdgeInsets.all(
                                                                        8.0,
                                                                      ),
                                                                  child: Image.asset(
                                                                    team.logoPath,
                                                                    height: 40,
                                                                    fit:
                                                                        BoxFit
                                                                            .contain,
                                                                    errorBuilder: (
                                                                      context,
                                                                      error,
                                                                      stackTrace,
                                                                    ) {
                                                                      return Image.asset(
                                                                        'assets/images/placeholder.jpeg',
                                                                        height:
                                                                            40,
                                                                      );
                                                                    },
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12.0,
                                              vertical: 8.0,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withAlpha(
                                                    26,
                                                  ), // equivalent to 10% opacity
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Image.asset(
                                                  selectedTeamId == null
                                                      ? 'assets/logos/nfl.png'
                                                      : Team(
                                                        teamId: selectedTeamId!,
                                                        fullName: '',
                                                        division: '',
                                                        conference: '',
                                                      ).logoPath,
                                                  height: 32,
                                                  fit: BoxFit.contain,
                                                ),
                                                SizedBox(width: 8),
                                                Icon(Icons.arrow_drop_down),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Continue with the grid view
                                  Padding(
                                    padding: const EdgeInsets.all(1.0),
                                    child: GridView.builder(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount:
                                          showArchived
                                              ? articles.length
                                              : articles.where((article) {
                                                // First filter by date
                                                if (article.createdAt == null) {
                                                  return false;
                                                }
                                                final cutoffDate =
                                                    DateTime.now().subtract(
                                                      const Duration(hours: 36),
                                                    );
                                                return article.createdAt!
                                                    .isAfter(cutoffDate);
                                              }).length,
                                      gridDelegate:
                                          SliverGridDelegateWithMaxCrossAxisExtent(
                                            maxCrossAxisExtent:
                                                isWeb ? 600 : 600,
                                            mainAxisExtent: 120,
                                            crossAxisSpacing: 16,
                                            mainAxisSpacing: 16,
                                          ),
                                      itemBuilder: (context, index) {
                                        final displayedArticles =
                                            showArchived
                                                ? articles
                                                : articles.where((article) {
                                                  if (article.createdAt ==
                                                      null) {
                                                    return false;
                                                  }
                                                  final cutoffDate =
                                                      DateTime.now().subtract(
                                                        const Duration(
                                                          hours: 36,
                                                        ),
                                                      );
                                                  return article.createdAt!
                                                      .isAfter(cutoffDate);
                                                }).toList();

                                        return ModernNewsCard(
                                          article: displayedArticles[index],
                                          onArticleClick: _onArticleClick,
                                        );
                                      },
                                    ),
                                  ),
                                  // Button to toggle archived articles.
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16.0,
                                    ),
                                    child: Center(
                                      child: TextButton(
                                        onPressed: () {
                                          setState(() {
                                            showArchived = !showArchived;
                                          });
                                          _refreshArticles();
                                        },
                                        child: Text(
                                          showArchived
                                              ? (isEnglish
                                                  ? "Hide Older Articles..."
                                                  : "Ältere Artikel ausblenden...")
                                              : (isEnglish
                                                  ? "Load Older Articles..."
                                                  : "Ältere Artikel laden..."),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.copyWith(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      } else {
                        // If no articles are available.
                        String noNewsText =
                            isEnglish
                                ? 'No news available${selectedTeamId != null ? " for $selectedTeamId" : ""}'
                                : 'Keine Nachrichten verfügbar${selectedTeamId != null ? " für $selectedTeamId" : ""}';
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                noNewsText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              if (!showArchived)
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      showArchived = true;
                                    });
                                    _refreshArticles();
                                  },
                                  child: Text(
                                    isEnglish
                                        ? "Load Older Articles..."
                                        : "Ältere Artikel laden...",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
