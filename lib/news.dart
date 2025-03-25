import 'package:flutter/material.dart';
import 'package:app/models/article.dart';
import 'package:app/services/supabase_service.dart';
import 'package:app/utils/logger.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'modern_news_card.dart';
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
    logo: '/logos/arizona_cardinals.png',
  ),
  'ATL': TeamInfo(
    id: 'ATL',
    fullName: 'Atlanta Falcons',
    logo: '/logos/atlanta_falcons.png',
  ),
  'BAL': TeamInfo(
    id: 'BAL',
    fullName: 'Baltimore Ravens',
    logo: '/logos/baltimore_ravens.png',
  ),
  'BUF': TeamInfo(
    id: 'BUF',
    fullName: 'Buffalo Bills',
    logo: '/logos/buffalo_bills.png',
  ),
  'CAR': TeamInfo(
    id: 'CAR',
    fullName: 'Carolina Panthers',
    logo: '/logos/carolina_panthers.png',
  ),
  'CHI': TeamInfo(
    id: 'CHI',
    fullName: 'Chicago Bears',
    logo: '/logos/chicago_bears.png',
  ),
  'CIN': TeamInfo(
    id: 'CIN',
    fullName: 'Cincinnati Bengals',
    logo: '/logos/cincinnati_bengals.png',
  ),
  'CLE': TeamInfo(
    id: 'CLE',
    fullName: 'Cleveland Browns',
    logo: '/logos/cleveland_browns.png',
  ),
  'DAL': TeamInfo(
    id: 'DAL',
    fullName: 'Dallas Cowboys',
    logo: '/logos/dallas_cowboys.png',
  ),
  'DEN': TeamInfo(
    id: 'DEN',
    fullName: 'Denver Broncos',
    logo: '/logos/denver_broncos.png',
  ),
  'DET': TeamInfo(
    id: 'DET',
    fullName: 'Detroit Lions',
    logo: '/logos/detroit_lions.png',
  ),
  'GB': TeamInfo(
    id: 'GB',
    fullName: 'Green Bay Packers',
    logo: '/logos/Green_bay_packers.png',
  ),
  'HOU': TeamInfo(
    id: 'HOU',
    fullName: 'Houston Texans',
    logo: '/logos/houston_texans.png',
  ),
  'IND': TeamInfo(
    id: 'IND',
    fullName: 'Indianapolis Colts',
    logo: '/logos/indianapolis_colts.png',
  ),
  'JAX': TeamInfo(
    id: 'JAX',
    fullName: 'Jacksonville Jaguars',
    logo: '/logos/jacksonville_jaguars.png',
  ),
  'KC': TeamInfo(
    id: 'KC',
    fullName: 'Kansas City Chiefs',
    logo: '/logos/kansas_city_chiefs.png',
  ),
  'LV': TeamInfo(
    id: 'LV',
    fullName: 'Las Vegas Raiders',
    logo: '/logos/las_vegas_raiders.png',
  ),
  'LAC': TeamInfo(
    id: 'LAC',
    fullName: 'Los Angeles Chargers',
    logo: '/logos/los_angeles_chargers.png',
  ),
  'LAR': TeamInfo(
    id: 'LAR',
    fullName: 'Los Angeles Rams',
    logo: '/logos/los_angeles_rams.png',
  ),
  'MIA': TeamInfo(
    id: 'MIA',
    fullName: 'Miami Dolphins',
    logo: '/logos/miami_dolphins.png',
  ),
  'MIN': TeamInfo(
    id: 'MIN',
    fullName: 'Minnesota Vikings',
    logo: '/logos/minnesota_vikings.png',
  ),
  'NE': TeamInfo(
    id: 'NE',
    fullName: 'New England Patriots',
    logo: '/logos/new_england_patriots.png',
  ),
  'NO': TeamInfo(
    id: 'NO',
    fullName: 'New Orleans Saints',
    logo: '/logos/new_orleans_saints.png',
  ),
  'NYG': TeamInfo(
    id: 'NYG',
    fullName: 'New York Giants',
    logo: '/logos/new_york_giants.png',
  ),
  'NYJ': TeamInfo(
    id: 'NYJ',
    fullName: 'New York Jets',
    logo: '/logos/new_york_jets.png',
  ),
  'PHI': TeamInfo(
    id: 'PHI',
    fullName: 'Philadelphia Eagles',
    logo: '/logos/philadelphia_eagles.png',
  ),
  'PIT': TeamInfo(
    id: 'PIT',
    fullName: 'Pittsburgh Steelers',
    logo: '/logos/pittsbourg_steelers.png',
  ),
  'SF': TeamInfo(
    id: 'SF',
    fullName: 'San Francisco 49ers',
    logo: '/logos/san_francisco_49ers.png',
  ),
  'SEA': TeamInfo(
    id: 'SEA',
    fullName: 'Seattle Seahawks',
    logo: '/logos/seattle_seahawks.png',
  ),
  'TB': TeamInfo(
    id: 'TB',
    fullName: 'Tampa Bay Buccaneers',
    logo: '/logos/tampa_bay_buccaneers.png',
  ),
  'TEN': TeamInfo(
    id: 'TEN',
    fullName: 'Tennessee Titans',
    logo: '/logos/tennessee_titans.png',
  ),
  'WAS': TeamInfo(
    id: 'WAS',
    fullName: 'Washington Commanders',
    logo: '/logos/washington_commanders.png',
  ),
};

class News extends StatefulWidget {
  const News({super.key});

  @override
  _NewsState createState() => _NewsState();
}

class _NewsState extends State<News> {
  String?
  selectedTeamId; // Changed from selectedTeam to selectedTeamId for clarity
  bool showArchived = false;
  Future<List<Article>>? articlesFuture;
  List<Article> articles = [];
  bool isLoading = false;
  String? errorMessage;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    articlesFuture = _fetchArticles();
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
      // Get articles from edge function
      final articlesData = await SupabaseService.getArticles(
        team: selectedTeamId,
        archived: showArchived,
      );

      AppLogger.debug('Received ${articlesData.length} articles from service');

      // Map the JSON data to Article objects
      final List<Article> fetchedArticles =
          articlesData.map((articleJson) {
            AppLogger.debug(
              'Processing article with teamId: ${articleJson['teamId']}',
            );
            return Article.fromJson(articleJson);
          }).toList();

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
          'Articles for team $selectedTeamId: ${fetchedArticles.where((a) => a.teamId == selectedTeamId).length}',
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

    // Re-setup realtime subscription with current filters
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
                                        selectedTeamId =
                                            null; // Use null instead of empty string
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
                                          selectedTeamId =
                                              team.id.toUpperCase();
                                        });
                                        _refreshArticles();
                                        Navigator.pop(context);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Image.asset(
                                          'assets/${team.logo}',
                                          height: 35,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return Image.asset(
                                              'assets/images/placeholder.jpeg',
                                              height: 35,
                                            );
                                          },
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
                          selectedTeamId == null
                              ? 'assets/logos/nfl.png'
                              : 'assets/${teamMapping[selectedTeamId]!.logo}',
                          height: 30,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/images/placeholder.jpeg',
                              height: 30,
                            );
                          },
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
              future: articlesFuture ?? Future.value([]),
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
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 600,
                                  mainAxisExtent: 120,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemBuilder: (context, index) {
                              return ModernNewsCard(
                                article: articles[index],
                                onArticleClick: _onArticleClick,
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
                      selectedTeamId != null
                          ? (isEnglish
                              ? 'No news available for ${teamMapping[selectedTeamId]?.fullName ?? ''}'
                              : 'Keine Nachrichten verfügbar für ${teamMapping[selectedTeamId]?.fullName ?? ''}')
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
