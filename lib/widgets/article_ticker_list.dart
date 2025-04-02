import 'package:flutter/material.dart';
import 'package:app/models/article_ticker.dart';
import 'package:app/services/supabase_service.dart';
import 'package:app/utils/logger.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';

class ArticleTickerList extends StatefulWidget {
  final String? teamId;

  const ArticleTickerList({super.key, this.teamId});

  @override
  State<ArticleTickerList> createState() => _ArticleTickerListState();
}

class _ArticleTickerListState extends State<ArticleTickerList> {
  List<ArticleTicker> _articleTickers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadArticleTickers();
  }

  Future<void> _loadArticleTickers() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      AppLogger.debug('Loading article tickers for team: ${widget.teamId}');
      final tickers = await SupabaseService.getArticleTickers(
        teamId: widget.teamId,
      );

      setState(() {
        _articleTickers = tickers;
        _isLoading = false;
      });

      AppLogger.debug('Loaded ${tickers.length} article tickers');
    } catch (e) {
      AppLogger.error('Error loading article tickers', e);
      setState(() {
        _errorMessage = 'Failed to load tickers: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish =
        languageProvider.currentLanguage == LanguageProvider.english;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red[700], size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[700]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadArticleTickers,
                child: Text(isEnglish ? 'Retry' : 'Wiederholen'),
              ),
            ],
          ),
        ),
      );
    }

    if (_articleTickers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 48),
              const SizedBox(height: 16),
              Text(
                isEnglish
                    ? 'No article tickers available'
                    : 'Keine Artikelticker verfügbar',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blue[700]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadArticleTickers,
                child: Text(isEnglish ? 'Refresh' : 'Aktualisieren'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _articleTickers.length,
      itemBuilder: (context, index) {
        final ticker = _articleTickers[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16.0),
            title: Text(
              isEnglish ? ticker.englishHeadline : ticker.germanHeadline,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  isEnglish ? ticker.summaryEnglish : ticker.summaryGerman,
                  style: theme.textTheme.bodyMedium,
                ),
                if (ticker.sourceName != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Source: ${ticker.sourceName}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
            onTap: () {
              // Handle tap event (you could navigate to a detailed view)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isEnglish
                        ? 'Selected ticker: ${ticker.englishHeadline}'
                        : 'Ausgewählter Ticker: ${ticker.germanHeadline}',
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
