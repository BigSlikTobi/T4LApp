import 'package:flutter/material.dart';
import 'package:app/models/article.dart';
import 'package:app/models/news_ticker.dart'
    hide Team; // Hide Team from news_ticker
import 'package:app/models/team.dart';
import 'package:app/services/supabase_service.dart';
import 'package:app/utils/logger.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'modern_news_card.dart';
import 'article_page.dart';
import 'slideshow_card.dart';

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
  List<NewsTicker> newsTickers = [];
  bool isLoading = false;
  String? errorMessage;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    articlesFuture = _fetchArticles();
    _fetchNewsTickers();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _subscription = null;
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
      final List<Article> fetchedArticles = articlesData
          .map((articleJson) => Article.fromJson(articleJson))
          .where((article) => selectedTeamId == null || 
                article.teamId?.toUpperCase() == selectedTeamId?.toUpperCase())
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

  Future<void> _fetchNewsTickers() async {
    AppLogger.debug('Starting to fetch news tickers in News widget');
    try {
      final tickers = await SupabaseService.getNewsTickers(
        team: selectedTeamId,
      );
      AppLogger.debug('Received ${tickers.length} tickers from service');

      // Sort by publishedAt date
      final sortedTickers =
          tickers.toList()..sort((a, b) {
            final aDate = DateTime.tryParse(a.sourceArticle?.publishedAt ?? '');
            final bDate = DateTime.tryParse(b.sourceArticle?.publishedAt ?? '');
            if (aDate == null || bDate == null) return 0;
            return bDate.compareTo(aDate); // newest first
          });

      if (mounted) {
        setState(() {
          newsTickers = sortedTickers;
          AppLogger.debug(
            'Updated newsTickers state with ${sortedTickers.length} items',
          );
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching news tickers', e);
      AppLogger.error('Stack trace:', stackTrace);
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

    // Also refresh news tickers when articles are refreshed
    _fetchNewsTickers();

    // Re-setup realtime subscription with current filters
    _setupRealtimeSubscription();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish =
        languageProvider.currentLanguage == LanguageProvider.english;
    final isWeb = MediaQuery.of(context).size.width > 600;

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
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWeb ? 1200 : double.infinity),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isWeb ? 24.0 : 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    Spacer(),
                    GestureDetector(
                      onTap: () {
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
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            selectedTeamId = null;
                                          });
                                          _refreshArticles();
                                          Navigator.pop(context);
                                        },
                                        child: Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Image.asset(
                                              'assets/logos/nfl.png',
                                              height: 40,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Divider(height: 1),
                                      ...allTeams.map(
                                        (team) => InkWell(
                                          onTap: () {
                                            setState(() {
                                              selectedTeamId = team.teamId;
                                            });
                                            _refreshArticles();
                                            Navigator.pop(context);
                                          },
                                          child: Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Image.asset(
                                                team.logoPath,
                                                height: 40,
                                                fit: BoxFit.contain,
                                                errorBuilder: (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) {
                                                  return Image.asset(
                                                    'assets/images/placeholder.jpeg',
                                                    height: 40,
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
                          vertical: 10.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Center(
                              child: Image.asset(
                                selectedTeamId == null
                                    ? 'assets/logos/nfl.png'
                                    : Team(
                                        teamId: selectedTeamId!,
                                        fullName: '',
                                        division: '',
                                        conference: '',
                                      ).logoPath,
                                height: 40,
                                fit: BoxFit.contain,
                              ),
                            ),
                            SizedBox(width: 12),
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
                  future: articlesFuture ?? Future.value([]),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting ||
                        isLoading) {
                      // Show a progress indicator while loading
                      return Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
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
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _refreshArticles,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
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
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _refreshArticles,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                              ),
                              child: Text(isEnglish ? 'Retry' : 'Wiederholen'),
                            ),
                          ],
                        ),
                      );
                    } else if (articles.isNotEmpty || newsTickers.isNotEmpty) {
                      return SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWeb ? 24.0 : 8.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Show news tickers
                              NewsTickerSlideShow(
                                tickers: newsTickers,
                                isEnglish: isEnglish,
                              ),

                              // Grid view for displaying articles.
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: showArchived 
                                      ? articles.length 
                                      : articles.where((article) {
                                          // First filter by date
                                          if (article.createdAt == null) return false;
                                          final cutoffDate = DateTime.now().subtract(const Duration(hours: 36));
                                          return article.createdAt!.isAfter(cutoffDate);
                                        }).length,
                                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: isWeb ? 600 : 600,
                                    mainAxisExtent: 120,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                                  itemBuilder: (context, index) {
                                    final displayedArticles = showArchived
                                        ? articles
                                        : articles.where((article) {
                                            if (article.createdAt == null) return false;
                                            final cutoffDate = DateTime.now().subtract(const Duration(hours: 36));
                                            return article.createdAt!.isAfter(cutoffDate);
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
                      );
                    } else {
                      // If no articles are available.
                      String noNewsText =
                          isEnglish
                              ? 'No news available${selectedTeamId != null ? " for ${selectedTeamId}" : ""}'
                              : 'Keine Nachrichten verfügbar${selectedTeamId != null ? " für ${selectedTeamId}" : ""}';
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
    );
  }
}
