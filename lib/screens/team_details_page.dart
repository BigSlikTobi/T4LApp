import 'package:flutter/material.dart';
import 'package:app/models/team.dart';
import 'package:app/models/article.dart';
import 'package:app/models/news_ticker.dart'
    hide Team; // Hide the Team class from news_ticker.dart
import 'package:app/models/team_article.dart';
import 'package:app/services/supabase_service.dart';
import 'package:app/modern_news_card.dart';
import 'package:app/article_page.dart';
import 'package:app/widgets/embedded_ticker_slideshow.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';
import 'package:app/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/widgets/custom_app_bar.dart';
import 'dart:math' as math;

class TeamDetailsPage extends StatefulWidget {
  final Team team;
  const TeamDetailsPage({super.key, required this.team});
  @override
  _TeamDetailsPageState createState() => _TeamDetailsPageState();
}

class _TeamDetailsPageState extends State<TeamDetailsPage> {
  List<Article> _articles = [];
  List<NewsTicker> _teamArticleTickers = [];
  bool _isLoading = true;
  bool _isLoadingTeamArticles = true;
  String? _errorMessage;
  String? _teamArticlesErrorMessage;
  RealtimeChannel? _teamArticlesSubscription;

  @override
  void initState() {
    super.initState();
    _loadTeamArticles();
    _loadArticles();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _teamArticlesSubscription?.unsubscribe();
    _teamArticlesSubscription = null;
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    // Set up realtime subscription for team articles
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
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      // Load articles filtered by team
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
    try {
      setState(() {
        _isLoadingTeamArticles = true;
        _teamArticlesErrorMessage = null;
      });

      // Load team articles from the edge function
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
    if (teamArticlesData.isEmpty) {
      // No articles found, set empty lists but no error
      setState(() {
        _teamArticleTickers = [];
        _isLoadingTeamArticles = false;
      });
      return;
    }

    AppLogger.debug('Processing ${teamArticlesData.length} team articles...');

    // Add client-side filtering to ensure only articles for this team are shown
    final String currentTeamId = widget.team.teamId.toUpperCase();
    final filteredArticlesData =
        teamArticlesData.where((json) {
          // Extract team ID from the json (could be in 'team' field as string or object)
          String? articleTeamId;
          if (json['team'] != null) {
            if (json['team'] is Map<String, dynamic> &&
                json['team']['teamId'] != null) {
              articleTeamId = json['team']['teamId'].toString().toUpperCase();
            } else {
              articleTeamId = json['team'].toString().toUpperCase();
            }
          }

          // Log filtering information for debugging
          AppLogger.debug(
            'Article teamId: $articleTeamId, Current teamId: $currentTeamId',
          );

          // Keep articles that match the current team
          return articleTeamId == currentTeamId;
        }).toList();

    AppLogger.debug(
      'Filtered team articles from ${teamArticlesData.length} to ${filteredArticlesData.length}',
    );

    if (mounted) {
      // Convert to TeamArticle objects and then directly to NewsTicker format
      final languageProvider = Provider.of<LanguageProvider>(
        context,
        listen: false,
      );
      final isEnglish =
          languageProvider.currentLanguage == LanguageProvider.english;
      final List<NewsTicker> tickers =
          filteredArticlesData.map((json) {
            // Convert JSON to TeamArticle and then to NewsTicker format in one step
            final article = TeamArticle.fromJson(json);
            final tickerJson = article.toNewsTickerJson(isEnglish);
            return NewsTicker.fromJson(tickerJson);
          }).toList();

      setState(() {
        _teamArticleTickers = tickers;
        _isLoadingTeamArticles = false;
      });

      AppLogger.debug(
        'Successfully updated ${_teamArticleTickers.length} team article tickers for team ${widget.team.teamId}',
      );
    }
  }

  void _onArticleClick(int articleId) {
    final article = _articles.firstWhere((article) => article.id == articleId);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ArticlePage(article: article)),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading articles...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadArticles,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_football, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No articles found for ${widget.team.fullName}',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticlesList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDeviceWide = constraints.maxWidth > 600;
        final horizontalPadding =
            constraints.maxWidth > 1200
                ? (constraints.maxWidth - 1200) / 2
                : constraints.maxWidth > 600
                ? 50.0
                : 16.0;
        return SizedBox(
          height: _articles.isEmpty ? 200 : null,
          child:
              _articles.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 16.0,
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _articles.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ModernNewsCard(
                          article: _articles[index],
                          onArticleClick: _onArticleClick,
                        ),
                      );
                    },
                  ),
        );
      },
    );
  }

  Widget _buildTeamArticlesSection() {
    if (_isLoadingTeamArticles) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                'Loading team news...',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    if (_teamArticlesErrorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 32, color: Colors.red[300]),
              const SizedBox(height: 8),
              Text(
                _teamArticlesErrorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadTeamArticles,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_teamArticleTickers.isEmpty) {
      return const SizedBox.shrink(); // No team articles to show
    }

    // Calculate appropriate height based on screen size
    final screenSize = MediaQuery.of(context).size;
    final isDeviceWide = screenSize.width > 600;
    final slideHeight =
        isDeviceWide ? 400.0 : math.min(360.0, screenSize.height * 0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Team News',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: slideHeight,
          child: EmbeddedTickerSlideshow(tickers: _teamArticleTickers),
        ),
        const Divider(thickness: 1.0, height: 32),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadTeamArticles(), _loadArticles()]);
        },
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Define the breakpoint for responsive layout
              final isDeviceWide = constraints.maxWidth > 600;

              // Use the responsive variable for horizontal padding
              final horizontalPadding =
                  isDeviceWide
                      ? (constraints.maxWidth > 1200 ? 24.0 : 16.0)
                      : 8.0;

              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDeviceWide ? 1200 : double.infinity,
                    ),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Team Articles Section
                          _buildTeamArticlesSection(),

                          // Regular Articles Section Header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Text(
                              'Latest Articles',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),

                          // Regular Articles Content
                          _isLoading
                              ? _buildLoadingState()
                              : _errorMessage != null
                              ? _buildErrorState()
                              : _buildArticlesList(),

                          // Bottom padding for better scrolling
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
