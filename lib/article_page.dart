import 'package:flutter/material.dart';
import 'package:app/models/article.dart';
import 'package:app/utils/image_utils.dart';
import 'package:app/utils/logger.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';

class ArticlePage extends StatefulWidget {
  final Article article;

  const ArticlePage({super.key, required this.article});

  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  String? _processedImageUrl;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _processImageUrls();
  }

  Future<void> _processImageUrls() async {
    // Process the main image
    if (widget.article.imageUrl != null &&
        widget.article.imageUrl!.isNotEmpty) {
      try {
        final processed = await getProxiedImageUrl(widget.article.imageUrl!);
        if (mounted) {
          setState(() {
            _processedImageUrl = processed;
          });
        }
      } catch (e) {
        AppLogger.error('Error processing main image', e);
        if (mounted) {
          setState(() {
            _processedImageUrl = widget.article.imageUrl;
          });
        }
      }
    }
  }

  Widget _buildLoadingPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface,
      child: Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish =
        languageProvider.currentLanguage == LanguageProvider.english;
    final articleContent =
        isEnglish
            ? widget.article.englishArticle
            : widget.article.germanArticle;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEnglish
              ? widget.article.englishHeadline
              : widget.article.germanHeadline,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date and source
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Text(
                        widget.article.createdAt != null
                            ? DateFormat(
                              'MMM d, yyyy',
                            ).format(widget.article.createdAt!)
                            : '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      if (widget.article.sourceAuthor != null &&
                          widget.article.sourceAuthor!.isNotEmpty)
                        Text(
                          ' | ${widget.article.sourceAuthor}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),

                // Main image
                if (_processedImageUrl != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _processedImageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          AppLogger.error(
                            'Error loading article image: ${widget.article.imageUrl}',
                            error,
                          );
                          return Image.asset(
                            'assets/images/placeholder.jpeg',
                            fit: BoxFit.cover,
                            width: double.infinity,
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildLoadingPlaceholder(theme);
                        },
                      ),
                    ),
                  ),

                // HTML content
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Html(
                    data: articleContent,
                    style: {
                      "body": Style(
                        fontSize: FontSize(16.0),
                        fontFamily: 'Roboto',
                        lineHeight: LineHeight(1.6),
                      ),
                      "h1": Style(
                        fontSize: FontSize(24.0),
                        fontWeight: FontWeight.bold,
                        margin: Margins(top: Margin(16), bottom: Margin(16)),
                      ),
                      "h2": Style(
                        fontSize: FontSize(20.0),
                        fontWeight: FontWeight.bold,
                        margin: Margins(top: Margin(12), bottom: Margin(12)),
                      ),
                      "h3": Style(
                        fontSize: FontSize(18.0),
                        fontWeight: FontWeight.bold,
                        margin: Margins(top: Margin(8), bottom: Margin(8)),
                      ),
                      "p": Style(
                        margin: Margins(top: Margin(8), bottom: Margin(8)),
                      ),
                      "blockquote": Style(
                        margin: Margins(
                          left: Margin(16),
                          right: Margin(16),
                          top: Margin(16),
                          bottom: Margin(16),
                        ),
                        padding: HtmlPaddings(left: HtmlPadding(16)),
                        border: Border(
                          left: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 4,
                          ),
                        ),
                        fontStyle: FontStyle.italic,
                      ),
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
