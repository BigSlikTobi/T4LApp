import 'package:flutter/material.dart';
import 'package:app/models/team.dart';
import 'package:app/models/article.dart';
import 'package:app/models/article_ticker.dart';
import 'package:app/models/team_article.dart';
import 'package:app/services/supabase_service.dart';
import 'package:app/modern_news_card.dart'; // Assuming this widget adapts or is styled internally
import 'package:app/article_page.dart'; // Assuming this page adapts or is styled internally
import 'package:app/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/widgets/custom_app_bar.dart'; // Assuming this uses the theme
import 'package:app/widgets/team_articles_slideshow.dart'; // Assuming this adapts or is styled internally
import 'package:app/widgets/roster_tab_view.dart'; // Already styled

// --- Reusing Color Constants for Consistency ---
const Color t4lPrimaryGreen = Color(0xFF20452b);
const Color t4lDarkGrey = Color(0xFF333333);
const Color t4lBlack = Color(0xFF000000);
const Color t4lSecondaryGreyText = Color(0xFF616161); // Colors.grey[700]
const Color t4lLightGreyDivider = Color(0xFFE0E0E0); // Colors.grey[300]
const Color t4lErrorRed = Color(0xFFD32F2F); // Colors.red[700]
const Color t4lSubtleGrey = Color(
  0xFFBDBDBD,
); // Colors.grey[400] - For subtle icons/placeholders

class TeamDetailsPage extends StatefulWidget {
  final Team team;
  const TeamDetailsPage({super.key, required this.team});

  @override
  TeamDetailsPageState createState() => TeamDetailsPageState();
}

class TeamDetailsPageState extends State<TeamDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Article> _articles = [];
  List<ArticleTicker> _teamArticleTickers = [];
  bool _isLoading = true;
  bool _isLoadingTeamArticles = true;
  String? _errorMessage;
  String? _teamArticlesErrorMessage;
  RealtimeChannel? _teamArticlesSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTeamArticles();
    _loadArticles();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _teamArticlesSubscription?.unsubscribe();
    _teamArticlesSubscription = null;
    super.dispose();
  }

  // --- Data Loading and Processing Logic (Unchanged) ---
  void _setupRealtimeSubscription() {
    _teamArticlesSubscription = SupabaseService.subscribeToTeamArticles(
      team: widget.team.teamId,
      onTeamArticlesUpdate: (teamArticlesData) {
        AppLogger.debug(
          'Received realtime update with ${teamArticlesData.length} team articles',
        );
        _processTeamArticles(teamArticlesData);
      },
    );
    AppLogger.debug(
      'Set up realtime subscription for team articles for ${widget.team.teamId}',
    );
  }

  Future<void> _loadArticles() async {
    // ... (logic remains the same) ...
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final articlesData = await SupabaseService.getArticles(
        team: widget.team.teamId,
      );
      setState(() {
        _articles =
            articlesData
                .map((articleJson) => Article.fromJson(articleJson))
                .where(
                  (article) =>
                      article.teamId?.toUpperCase() ==
                      widget.team.teamId.toUpperCase(),
                )
                .toList()
              ..sort(
                (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
                  a.createdAt ?? DateTime.now(),
                ),
              );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load articles: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTeamArticles() async {
    // ... (logic remains the same) ...
    try {
      setState(() {
        _isLoadingTeamArticles = true;
        _teamArticlesErrorMessage = null;
      });

      final teamArticlesData = await SupabaseService.getTeamArticles(
        teamId: widget.team.teamId,
      );

      _processTeamArticles(teamArticlesData);
    } catch (e) {
      AppLogger.error('Error loading team articles', e);
      setState(() {
        _teamArticlesErrorMessage =
            'Failed to load team articles: ${e.toString()}';
        _isLoadingTeamArticles = false;
      });
    }
  }

  void _processTeamArticles(List<Map<String, dynamic>> teamArticlesData) {
    // ... (logic remains the same) ...
    if (teamArticlesData.isEmpty) {
      AppLogger.debug('No team articles data received');
      setState(() {
        _teamArticleTickers = [];
        _isLoadingTeamArticles = false;
      });
      return;
    }

    AppLogger.debug('Processing ${teamArticlesData.length} team articles...');
    final String currentTeamId = widget.team.teamId.toUpperCase();

    try {
      final filteredArticlesData =
          teamArticlesData.where((json) {
            String? articleTeamId;
            if (json['team'] != null) {
              if (json['team'] is Map<String, dynamic> &&
                  json['team']['teamId'] != null) {
                articleTeamId = json['team']['teamId'].toString().toUpperCase();
              } else {
                // Handle case where 'team' might just be the ID string directly
                articleTeamId = json['team'].toString().toUpperCase();
              }
            }
            // Optional: Log comparison for debugging
            // AppLogger.debug(
            //   'Comparing Article teamId: $articleTeamId with Current teamId: $currentTeamId',
            // );
            return articleTeamId == currentTeamId;
          }).toList();

      AppLogger.debug(
        'Filtered ${teamArticlesData.length} articles to ${filteredArticlesData.length} for team ${widget.team.teamId}',
      );

      if (mounted) {
        final List<ArticleTicker> tickers =
            filteredArticlesData
                .map((json) {
                  try {
                    // AppLogger.debug(
                    //   'Converting article JSON to TeamArticle: ${json['id']}',
                    // );
                    final article = TeamArticle.fromJson(json);
                    // AppLogger.debug(
                    //   'Converting TeamArticle to ticker JSON - ID: ${article.id}, Headline: ${article.headlineEnglish}',
                    // );
                    final tickerJson = article.toArticleTickerJson();
                    // AppLogger.debug('Ticker JSON: $tickerJson');
                    return ArticleTicker.fromJson(tickerJson);
                  } catch (e, stack) {
                    AppLogger.error(
                      'Error processing article: ${json['id']}',
                      e,
                      stack,
                    );
                    return null;
                  }
                })
                .whereType<ArticleTicker>()
                .toList();

        setState(() {
          _teamArticleTickers = tickers;
          _isLoadingTeamArticles = false;
        });
        AppLogger.debug(
          'Successfully processed ${tickers.length} team article tickers for team ${widget.team.teamId}',
        );
      }
    } catch (e, stack) {
      AppLogger.error('Error processing team articles', e, stack);
      if (mounted) {
        // Check mounted before calling setState in catch block
        setState(() {
          _teamArticleTickers = [];
          _isLoadingTeamArticles = false;
          _teamArticlesErrorMessage =
              'Failed to process team articles: ${e.toString()}';
        });
      }
    }
  }

  void _onArticleClick(int articleId) {
    // ... (logic remains the same) ...
    final article = _articles.firstWhere((article) => article.id == articleId);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ArticlePage(article: article)),
    );
  }

  // --- Styled Helper Widgets ---

  Widget _buildErrorState() {
    // Apply light theme styles
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: t4lErrorRed,
            ), // Error color
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: t4lErrorRed,
                fontSize: 16,
              ), // Error color
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadArticles,
              icon: const Icon(
                Icons.refresh,
                color: Colors.white,
              ), // White icon
              label: const Text(
                'Retry',
                style: TextStyle(color: Colors.white),
              ), // White text
              style: ElevatedButton.styleFrom(
                backgroundColor: t4lPrimaryGreen, // Green background
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    // Apply light theme styles
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.sports_football,
              size: 64,
              color: t4lSubtleGrey,
            ), // Subtle grey icon
            const SizedBox(height: 16),
            Text(
              'No articles found for ${widget.team.fullName}',
              style: const TextStyle(
                fontSize: 18,
                color: t4lSecondaryGreyText,
              ), // Grey text
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticlesList() {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: double.infinity,
          child:
              _articles.isEmpty
                  ? _buildEmptyState()
                  : Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16.0,
                    ), // Add some vertical padding
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _articles.length,
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 600, // Consistent max width
                        mainAxisExtent: 120, // Height of cards
                        crossAxisSpacing: isWeb ? 16 : 8, // Spacing
                        mainAxisSpacing: isWeb ? 16 : 8,
                      ),
                      itemBuilder: (context, index) {
                        // Assuming ModernNewsCard uses Theme or is styled internally for light mode
                        return ModernNewsCard(
                          article: _articles[index],
                          onArticleClick: _onArticleClick,
                        );
                      },
                    ),
                  ),
        );
      },
    );
  }

  Widget _buildTeamArticlesSection() {
    if (_isLoadingTeamArticles) {
      return const Center(
        child: Padding(
          // Add padding around indicator
          padding: EdgeInsets.symmetric(vertical: 32.0),
          child: CircularProgressIndicator(
            color: t4lPrimaryGreen, // Green indicator
          ),
        ),
      );
    }

    if (_teamArticlesErrorMessage != null) {
      // Style the error message for team articles section
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                size: 32,
                color: t4lErrorRed,
              ), // Error color
              const SizedBox(height: 8),
              Text(
                _teamArticlesErrorMessage!,
                style: const TextStyle(
                  color: t4lErrorRed,
                  fontSize: 14,
                ), // Error color
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                // Use outlined button for secondary retry
                onPressed: _loadTeamArticles,
                icon: const Icon(
                  Icons.refresh,
                  size: 18,
                  color: t4lPrimaryGreen,
                ), // Green icon
                label: const Text(
                  'Retry',
                  style: TextStyle(color: t4lPrimaryGreen),
                ), // Green text
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: t4lPrimaryGreen,
                  ), // Green border
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_teamArticleTickers.isEmpty) {
      return const SizedBox.shrink(); // No need to show anything if empty
    }

    // --- Layout logic for slideshow (unchanged) ---
    final isWeb = MediaQuery.of(context).size.width > 600;
    final screenWidth = MediaQuery.of(context).size.width;
    // Adjust max width for better appearance on web if needed
    final maxWidth =
        isWeb ? (screenWidth * 0.6).clamp(400.0, 800.0) : double.infinity;

    return Center(
      child: Column(
        children: [
          const SizedBox(height: 16), // Add space above slideshow
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            // Assuming TeamArticlesSlideshow adapts to light theme or is styled internally
            child: TeamArticlesSlideshow(
              teamArticles: _teamArticleTickers,
              backgroundImage:
                  'assets/images/Facility.png', // Keep background image if desired
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;
    final horizontalPadding =
        isWeb ? 24.0 : 16.0; // Slightly more padding on mobile

    return Scaffold(
      appBar: const CustomAppBar(), // Assuming this is styled for light theme
      backgroundColor: Colors.white, // Main background white
      body: RefreshIndicator(
        onRefresh: () async {
          // Use Future.wait to refresh both concurrently
          await Future.wait([_loadTeamArticles(), _loadArticles()]);
        },
        color: t4lPrimaryGreen, // Color of the indicator spinner
        backgroundColor: Colors.white, // Background of the indicator circle
        child: SafeArea(
          child: Center(
            // Center the constrained content
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWeb ? 1200 : double.infinity, // Max width for web
              ),
              child: Column(
                children: [
                  // Header Section (Logo + Tabs)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 24,
                            bottom: 16,
                          ), // Adjusted padding
                          child: Hero(
                            tag: 'team-logo-${widget.team.teamId}',
                            child: Image.asset(
                              widget.team.logoPath,
                              height: isWeb ? 100 : 80, // Slightly smaller logo
                              errorBuilder: (context, error, stackTrace) {
                                // Style the error placeholder
                                return Icon(
                                  Icons.sports_football,
                                  size: isWeb ? 100 : 80,
                                  color:
                                      t4lSubtleGrey, // Subtle grey placeholder
                                );
                              },
                            ),
                          ),
                        ),
                        // Style the TabBar
                        TabBar(
                          controller: _tabController,
                          indicatorColor:
                              t4lPrimaryGreen, // Green indicator line
                          labelColor: t4lPrimaryGreen, // Green selected text
                          unselectedLabelColor:
                              t4lSecondaryGreyText, // Grey unselected text
                          indicatorWeight:
                              3.0, // Make indicator slightly thicker
                          labelStyle: const TextStyle(
                            // Optional: bold selected label
                            fontWeight: FontWeight.w600,
                            fontSize: 14, // Adjust font size if needed
                          ),
                          unselectedLabelStyle: const TextStyle(
                            // Optional: normal unselected label
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          tabs: const [Tab(text: 'NEWS'), Tab(text: 'ROSTER')],
                        ),
                      ],
                    ),
                  ),
                  // Divider below TabBar
                  Divider(height: 1, thickness: 1, color: Colors.grey[200]),

                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // News Tab
                        SingleChildScrollView(
                          physics:
                              const AlwaysScrollableScrollPhysics(), // Ensures refresh works
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                            ),
                            child: Column(
                              children: [
                                _buildTeamArticlesSection(),
                                if (_isLoading)
                                  const Center(
                                    // Add padding around indicator
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 48.0,
                                      ),
                                      child: CircularProgressIndicator(
                                        color:
                                            t4lPrimaryGreen, // Green indicator
                                      ),
                                    ),
                                  )
                                else if (_errorMessage != null)
                                  _buildErrorState() // Already styled
                                else
                                  _buildArticlesList(), // Already styled (check ModernNewsCard)
                                const SizedBox(height: 32), // Bottom padding
                              ],
                            ),
                          ),
                        ),

                        // Roster Tab (Already styled)
                        RosterTabView(teamId: widget.team.teamId),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
