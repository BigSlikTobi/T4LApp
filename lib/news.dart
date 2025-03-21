import 'package:flutter/material.dart';
import 'package:app/models/article.dart';
import 'package:app/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/utils/logger.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';
import 'news_card.dart';
import 'article_page.dart';

// Simulated Team info (as in your teamMapping)
class TeamInfo {
  final String id;
  final String fullName;
  final String logo; // URL for the team logo

  TeamInfo({required this.id, required this.fullName, required this.logo});
}

// Dummy team mapping for demo purposes
final Map<String, TeamInfo> teamMapping = {
  'ARI': TeamInfo(
    id: 'ARI',
    fullName: 'Arizona Cardinals',
    logo: 'assets/logos/arizona_cardinals.png',
  ),
  'ATL': TeamInfo(
    id: 'ATL',
    fullName: 'Atlanta Falcons',
    logo: 'assets/logos/atlanta_falcons.png',
  ),
  'BAL': TeamInfo(
    id: 'BAL',
    fullName: 'Baltimore Ravens',
    logo: 'assets/logos/baltimore_ravens.png',
  ),
  'BUF': TeamInfo(
    id: 'BUF',
    fullName: 'Buffalo Bills',
    logo: 'assets/logos/buffalo_bills.png',
  ),
  'CAR': TeamInfo(
    id: 'CAR',
    fullName: 'Carolina Panthers',
    logo: 'assets/logos/carolina_panthers.png',
  ),
  'CHI': TeamInfo(
    id: 'CHI',
    fullName: 'Chicago Bears',
    logo: 'assets/logos/chicago_bears.png',
  ),
  'CIN': TeamInfo(
    id: 'CIN',
    fullName: 'Cincinnati Bengals',
    logo: 'assets/logos/cincinnati_bengals.png',
  ),
  'CLE': TeamInfo(
    id: 'CLE',
    fullName: 'Cleveland Browns',
    logo: 'assets/logos/cleveland_browns.png',
  ),
  'DAL': TeamInfo(
    id: 'DAL',
    fullName: 'Dallas Cowboys',
    logo: 'assets/logos/dallas_cowboys.png',
  ),
  'DEN': TeamInfo(
    id: 'DEN',
    fullName: 'Denver Broncos',
    logo: 'assets/logos/denver_broncos.png',
  ),
  'DET': TeamInfo(
    id: 'DET',
    fullName: 'Detroit Lions',
    logo: 'assets/logos/detroit_lions.png',
  ),
  'GB': TeamInfo(
    id: 'GB',
    fullName: 'Green Bay Packers',
    logo: 'assets/logos/Green_bay_packers.png',
  ),
  'HOU': TeamInfo(
    id: 'HOU',
    fullName: 'Houston Texans',
    logo: 'assets/logos/houston_texans.png',
  ),
  'IND': TeamInfo(
    id: 'IND',
    fullName: 'Indianapolis Colts',
    logo: 'assets/logos/indianapolis_colts.png',
  ),
  'JAX': TeamInfo(
    id: 'JAX',
    fullName: 'Jacksonville Jaguars',
    logo: 'assets/logos/jacksonville_jaguars.png',
  ),
  'KC': TeamInfo(
    id: 'KC',
    fullName: 'Kansas City Chiefs',
    logo: 'assets/logos/kansas_city_chiefs.png',
  ),
  'LV': TeamInfo(
    id: 'LV',
    fullName: 'Las Vegas Raiders',
    logo: 'assets/logos/las_vegas_raiders.png',
  ),
  'LAC': TeamInfo(
    id: 'LAC',
    fullName: 'Los Angeles Chargers',
    logo: 'assets/logos/los_angeles_chargers.png',
  ),
  'LAR': TeamInfo(
    id: 'LAR',
    fullName: 'Los Angeles Rams',
    logo: 'assets/logos/los_angeles_rams.png',
  ),
  'MIA': TeamInfo(
    id: 'MIA',
    fullName: 'Miami Dolphins',
    logo: 'assets/logos/miami_dolphins.png',
  ),
  'MIN': TeamInfo(
    id: 'MIN',
    fullName: 'Minnesota Vikings',
    logo: 'assets/logos/minnesota_vikings.png',
  ),
  'NE': TeamInfo(
    id: 'NE',
    fullName: 'New England Patriots',
    logo: 'assets/logos/new_england_patriots.png',
  ),
  'NO': TeamInfo(
    id: 'NO',
    fullName: 'New Orleans Saints',
    logo: 'assets/logos/new_orleans_saints.png',
  ),
  'NYG': TeamInfo(
    id: 'NYG',
    fullName: 'New York Giants',
    logo: 'assets/logos/new_york_giants.png',
  ),
  'NYJ': TeamInfo(
    id: 'NYJ',
    fullName: 'New York Jets',
    logo: 'assets/logos/new_york_jets.png',
  ),
  'PHI': TeamInfo(
    id: 'PHI',
    fullName: 'Philadelphia Eagles',
    logo: 'assets/logos/philadelphia_eagles.png',
  ),
  'PIT': TeamInfo(
    id: 'PIT',
    fullName: 'Pittsburgh Steelers',
    logo: 'assets/logos/pittsbourg_steelers.png',
  ),
  'SF': TeamInfo(
    id: 'SF',
    fullName: 'San Francisco 49ers',
    logo: 'assets/logos/san_francisco_49ers.png',
  ),
  'SEA': TeamInfo(
    id: 'SEA',
    fullName: 'Seattle Seahawks',
    logo: 'assets/logos/seattle_seahawks.png',
  ),
  'TB': TeamInfo(
    id: 'TB',
    fullName: 'Tampa Bay Buccaneers',
    logo: 'assets/logos/tampa_bay_buccaneers.png',
  ),
  'TEN': TeamInfo(
    id: 'TEN',
    fullName: 'Tennessee Titans',
    logo: 'assets/logos/tennessee_titans.png',
  ),
  'WAS': TeamInfo(
    id: 'WAS',
    fullName: 'Washington Commanders',
    logo: 'assets/logos/washington_commanders.png',
  ),
};

class News extends StatefulWidget {
  const News({super.key});

  @override
  _NewsState createState() => _NewsState();
}

class _NewsState extends State<News> {
  String selectedTeam =
      ""; // Now stores team code (e.g., "ARI") or empty for no filter
  bool showArchived = false;
  late Future<List<Article>> articlesFuture;
  List<Article> articles = [];
  // Track articles to be excluded (articles that are already updated by newer articles)
  List<int> excludedArticleIds = [];
  bool isLoading = false;
  String? errorMessage;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _fetchExcludedArticleIds().then((_) {
      articlesFuture = _fetchArticlesFromSupabase();
      _setupRealtimeSubscription();
    });
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  // Fetch articles IDs that are already updated by other articles
  Future<void> _fetchExcludedArticleIds() async {
    try {
      // Get all article vectors that have updates
      final articleVectors = await SupabaseService.client
          .from('ArticleVector')
          .select()
          .not('isUpdate', 'is', null);

      // Extract all the article IDs that are being updated
      List<int> excludedIds = [];
      for (var vector in articleVectors) {
        // Parse the update array from various possible formats
        var updateField = vector['isUpdate'];
        if (updateField is String) {
          try {
            final String cleanString = updateField
                .replaceAll('[', '')
                .replaceAll(']', '')
                .replaceAll(' ', '');

            final List<int> updateIds =
                cleanString
                    .split(',')
                    .where((s) => s.isNotEmpty)
                    .map((s) => int.tryParse(s) ?? 0)
                    .where((id) => id > 0)
                    .toList();

            excludedIds.addAll(updateIds);
          } catch (e) {
            AppLogger.error('Error parsing update array', e);
          }
        } else if (updateField is List) {
          final List<int> updateIds =
              updateField
                  .map((item) => item is num ? item.toInt() : 0)
                  .where((id) => id > 0)
                  .toList();

          excludedIds.addAll(updateIds);
        }
      }

      // Update state with excluded article IDs
      if (mounted) {
        setState(() {
          excludedArticleIds = excludedIds;
        });
      }
    } catch (e) {
      AppLogger.error('Error fetching excluded article IDs', e);
    }
  }

  // Update setupRealtimeSubscription to handle team codes
  void _setupRealtimeSubscription() async {
    _subscription?.unsubscribe();

    _subscription = await SupabaseService.subscribeToArticles(
      team: selectedTeam.isNotEmpty ? selectedTeam : null,
      onInsert: (newArticles, _) {
        // Handle new articles being added
        if (mounted) {
          setState(() {
            // Convert new articles to Article objects
            final newArticleObjects =
                newArticles
                    .map((articleJson) => Article.fromJson(articleJson))
                    .toList();

            // Only add to the list if we're showing current articles
            // or if we're showing archived as well
            bool shouldAddArticle = true;
            if (!showArchived) {
              final cutoffDate = DateTime.now().subtract(
                const Duration(days: 30),
              );
              shouldAddArticle = newArticleObjects.every(
                (article) =>
                    article.createdAt != null &&
                    article.createdAt!.isAfter(cutoffDate),
              );
            }

            if (shouldAddArticle) {
              // Filter out articles that are in the excluded list
              final filteredArticles =
                  newArticleObjects
                      .where(
                        (article) => !excludedArticleIds.contains(article.id),
                      )
                      .toList();

              if (filteredArticles.isNotEmpty) {
                // Add the new articles to the beginning since they're newest
                articles.insertAll(0, filteredArticles);
                // Sort by created_at
                articles.sort(
                  (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
                    a.createdAt ?? DateTime.now(),
                  ),
                );

                // Show notification for new articles
                _showNewArticleNotification(filteredArticles.length);
              }
            }
          });
        }
      },
      onUpdate: (updatedArticles, _) {
        // Handle articles being updated
        if (mounted) {
          setState(() {
            for (var updatedArticle in updatedArticles) {
              final updatedObj = Article.fromJson(updatedArticle);
              final index = articles.indexWhere((a) => a.id == updatedObj.id);
              if (index != -1) {
                articles[index] = updatedObj;

                // If the article now has update flag set to true, we need to refetch excluded articles
                if (updatedObj.isUpdate) {
                  _fetchExcludedArticleIds().then((_) => _refreshArticles());
                }
              }
            }
          });
        }
      },
      onDelete: (deletedArticles, _) {
        // Handle articles being deleted
        if (mounted) {
          setState(() {
            for (var deletedArticle in deletedArticles) {
              final deletedId = deletedArticle['id'];
              articles.removeWhere((a) => a.id == deletedId);
            }
          });
        }
      },
    );
  }

  void _showNewArticleNotification(int count) {
    // Show a snackbar notification when new articles arrive
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '$count new ${count == 1 ? 'article' : 'articles'} available!',
        ),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            // Scroll to top to show the new articles
            // Implementation depends on your scroll controller setup
          },
        ),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(8),
        duration: Duration(seconds: 5),
      ),
    );
  }

  Future<List<Article>> _fetchArticlesFromSupabase() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Call the Supabase service to get articles, excluding the ones that are updated
      final articlesData = await SupabaseService.getArticles(
        team: selectedTeam.isNotEmpty ? selectedTeam : null,
        archived: showArchived,
        excludeIds: excludedArticleIds,
      );

      // Map the JSON data to Article objects
      final List<Article> fetchedArticles =
          articlesData
              .map((articleJson) => Article.fromJson(articleJson))
              .toList();

      // Update the articles list for realtime changes
      setState(() {
        articles = fetchedArticles;
      });

      return fetchedArticles;
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load articles: ${e.toString()}';
      });
      AppLogger.error('Error fetching articles', e);
      return []; // Return empty list on error
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _onArticleClick(int id) {
    // Find the article with the given ID
    final article = articles.firstWhere((article) => article.id == id);

    // Navigate to the article page
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ArticlePage(article: article)),
    ).then((_) {
      // When coming back from article page, we might need to refresh
      // in case there were updates to any articles
      _fetchExcludedArticleIds().then((_) => _refreshArticles());
    });

    AppLogger.debug('Navigating to article $id');
  }

  // Refresh articles whenever state changes (team filter or archived toggle).
  void _refreshArticles() {
    setState(() {
      articlesFuture = _fetchArticlesFromSupabase();
    });

    // Update the realtime subscription with new filter
    _setupRealtimeSubscription();
  }

  @override
  Widget build(BuildContext context) {
    List<TeamInfo> allTeams = teamMapping.values.toList();
    allTeams.sort((a, b) => a.fullName.compareTo(b.fullName));
    final theme = Theme.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish =
        languageProvider.currentLanguage == LanguageProvider.english;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/T4LLogo.png',
          height: 80,
          fit: BoxFit.contain,
        ),
        actions: [
          // Language toggle button with improved visibility
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () {
                languageProvider.toggleLanguage();
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      isEnglish ? 'EN' : 'DE',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.language,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Text(
                  isEnglish ? 'NFL News' : 'NFL Nachrichten',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                // Custom dropdown-like widget instead of PopupMenuButton
                GestureDetector(
                  onTap: () {
                    // Show custom dialog with team logos
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return Dialog(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            width: 80,
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // All Teams option (NFL logo)
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        selectedTeam = ""; // Clear filter
                                      });
                                      _refreshArticles();
                                      Navigator.pop(context);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Image.asset(
                                        'assets/logos/nfl.png',
                                        height: 35,
                                      ),
                                    ),
                                  ),
                                  Divider(height: 1),
                                  // Individual team logos
                                  ...allTeams.map(
                                    (team) => InkWell(
                                      onTap: () {
                                        setState(() {
                                          selectedTeam =
                                              team.id; // Store team code
                                        });
                                        _refreshArticles();
                                        Navigator.pop(context);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Image.asset(
                                          team.logo,
                                          height: 35,
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
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.primary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.filter_list),
                        const SizedBox(width: 8),
                        Image.asset(
                          selectedTeam.isEmpty
                              ? 'assets/logos/nfl.png'
                              : teamMapping[selectedTeam]!.logo,
                          height: 30,
                        ),
                        Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Article>>(
              future: articlesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting ||
                    isLoading) {
                  // Show a progress indicator while loading
                  return Center(
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                    ),
                  );
                } else if (errorMessage != null) {
                  // Show error message if there was a problem
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          errorMessage!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshArticles,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                          ),
                          child: Text(isEnglish ? 'Retry' : 'Wiederholen'),
                        ),
                      ],
                    ),
                  );
                } else if (snapshot.hasError) {
                  // Handle specific Future error
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isEnglish
                              ? 'Error loading articles: ${snapshot.error}'
                              : 'Fehler beim Laden der Artikel: ${snapshot.error}',
                          style: theme.textTheme.bodyLarge,
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshArticles,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                          ),
                          child: Text(isEnglish ? 'Retry' : 'Wiederholen'),
                        ),
                      ],
                    ),
                  );
                } else if (articles.isNotEmpty) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Grid view for displaying articles.
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: articles.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      MediaQuery.of(context).size.width > 800
                                          ? 3
                                          : MediaQuery.of(context).size.width >
                                              600
                                          ? 2
                                          : 1,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 1,
                                ),
                            itemBuilder: (context, index) {
                              return NewsCard(
                                article: articles[index],
                                onArticleClick: _onArticleClick,
                                variant: 'vertical',
                              );
                            },
                          ),
                        ),
                        // Button to toggle archived articles.
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
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
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  // If no articles are available.
                  String noNewsText =
                      selectedTeam.isNotEmpty
                          ? (isEnglish
                              ? 'No news available for ${teamMapping[selectedTeam]?.fullName ?? ''}'
                              : 'Keine Nachrichten verfügbar für ${teamMapping[selectedTeam]?.fullName ?? ''}')
                          : (isEnglish
                              ? 'No news available'
                              : 'Keine Nachrichten verfügbar');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(noNewsText, style: theme.textTheme.bodyLarge),
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
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.primary,
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
    );
  }
}
