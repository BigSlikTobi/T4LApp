import 'package:flutter/material.dart';
import 'package:app/models/team.dart';
import 'package:app/models/article.dart';
import 'package:app/services/supabase_service.dart';
import 'package:app/modern_news_card.dart';
import 'package:app/article_page.dart';

class TeamDetailsPage extends StatefulWidget {
  final Team team;

  const TeamDetailsPage({super.key, required this.team});

  @override
  _TeamDetailsPageState createState() => _TeamDetailsPageState();
}

class _TeamDetailsPageState extends State<TeamDetailsPage> {
  List<Article> _articles = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTeamArticles();
  }

  Future<void> _loadTeamArticles() async {
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
              onPressed: _loadTeamArticles,
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
        final isWeb = constraints.maxWidth > 600;
        final horizontalPadding =
            constraints.maxWidth > 1200
                ? (constraints.maxWidth - 1200) / 2
                : constraints.maxWidth > 600
                ? 50.0
                : 16.0;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isWeb ? 1200 : double.infinity,
            ),
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16.0,
              ),
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Hero(
              tag: 'team-logo-${widget.team.teamId}',
              child: Image.asset(widget.team.logoPath, height: 32, width: 32),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                widget.team.fullName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTeamArticles,
        child:
            _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                ? _buildErrorState()
                : _articles.isEmpty
                ? _buildEmptyState()
                : _buildArticlesList(),
      ),
    );
  }
}
