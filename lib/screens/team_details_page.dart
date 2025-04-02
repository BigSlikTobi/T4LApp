import 'package:flutter/material.dart';
import 'package:app/models/team.dart';
import 'package:app/models/article.dart';
import 'package:app/models/article_ticker.dart';
import 'package:app/models/team_article.dart';
import 'package:app/services/supabase_service.dart';
import 'package:app/modern_news_card.dart';
import 'package:app/article_page.dart';
import 'package:app/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/widgets/custom_app_bar.dart';
import 'package:app/widgets/team_articles_slideshow.dart';

class TeamDetailsPage extends StatefulWidget {
  final Team team;
  const TeamDetailsPage({super.key, required this.team});

  @override
  _TeamDetailsPageState createState() => _TeamDetailsPageState();
}

class _TeamDetailsPageState extends State<TeamDetailsPage> {
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
                articleTeamId = json['team'].toString().toUpperCase();
              }
            }
            AppLogger.debug(
              'Article teamId: $articleTeamId, Current teamId: $currentTeamId',
            );
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
                    AppLogger.debug(
                      'Converting article JSON to TeamArticle: ${json['id']}',
                    );
                    final article = TeamArticle.fromJson(json);
                    AppLogger.debug(
                      'Converting TeamArticle to ticker JSON - ID: ${article.id}, Headline: ${article.headlineEnglish}',
                    );
                    final tickerJson = article.toArticleTickerJson();
                    AppLogger.debug('Ticker JSON: $tickerJson');
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
      setState(() {
        _teamArticleTickers = [];
        _isLoadingTeamArticles = false;
        _teamArticlesErrorMessage =
            'Failed to process team articles: ${e.toString()}';
      });
    }
  }

  void _onArticleClick(int articleId) {
    final article = _articles.firstWhere((article) => article.id == articleId);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ArticlePage(article: article)),
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
    final isWeb = MediaQuery.of(context).size.width > 600;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: double.infinity,
          child:
              _articles.isEmpty
                  ? _buildEmptyState()
                  : Padding(
                    padding: const EdgeInsets.all(1.0),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _articles.length,
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: isWeb ? 600 : 600,
                        mainAxisExtent: 120,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemBuilder: (context, index) {
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
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
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
      return const SizedBox.shrink();
    }

    final isWeb = MediaQuery.of(context).size.width > 600;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth =
        isWeb
            ? (screenWidth < 1200 ? screenWidth / 3 : 400.0)
            : double.infinity;

    return Center(
      child: Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: TeamArticlesSlideshow(
              teamArticles: _teamArticleTickers,
              backgroundImage: 'assets/images/Facility.png',
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: const CustomAppBar(),
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadTeamArticles(), _loadArticles()]);
        },
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWeb ? 1200 : double.infinity,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isWeb ? 24.0 : 8.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 20,
                                left: 20,
                                right: 20,
                              ),
                              child: Hero(
                                tag: 'team-logo-${widget.team.teamId}',
                                child: Image.asset(
                                  widget.team.logoPath,
                                  height: 120,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.sports_football,
                                      size: 120,
                                      color: Colors.grey[400],
                                    );
                                  },
                                ),
                              ),
                            ),
                            _buildTeamArticlesSection(),
                            Divider(height: 1, color: Colors.grey.shade300),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14.0,
                                horizontal: 20.0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [],
                              ),
                            ),
                            if (_isLoading)
                              Center(
                                child: CircularProgressIndicator(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            else if (_errorMessage != null)
                              _buildErrorState()
                            else
                              _buildArticlesList(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
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
