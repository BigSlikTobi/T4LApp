import 'package:flutter/material.dart';
import 'package:app/models/article.dart';
import 'package:app/utils/image_utils.dart';
import 'package:app/utils/logger.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app/widgets/custom_app_bar.dart';

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

  String _formatDate(DateTime? date, bool isEnglish) {
    if (date == null) return isEnglish ? 'No date' : 'Kein Datum';
    final format =
        isEnglish ? DateFormat('MMM d, yyyy') : DateFormat('dd.MM.yyyy');
    return format.format(date);
  }

  Future<void> _launchURL(String? url) async {
    if (url == null || url.isEmpty) return;

    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      AppLogger.error('Could not launch URL: $url');
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

  Widget _buildFallbackImage() {
    return Image.asset(
      'assets/images/placeholder.jpg',
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      errorBuilder: (context, error, stackTrace) {
        AppLogger.error('Error loading fallback image', error);
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(
              Icons.image_not_supported,
              size: 50,
              color: Colors.grey,
            ),
          ),
        );
      },
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
    final screenSize = MediaQuery.of(context).size;
    final isWeb = screenSize.width > 600;

    Widget content = SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Image
              if (_processedImageUrl != null)
                SizedBox(
                  height: isWeb ? 400 : screenSize.height * 0.35,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _processedImageUrl!,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, __, ___) => _buildFallbackImage(),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return _buildLoadingPlaceholder(theme);
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // 2. Date and Source
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      _formatDate(widget.article.createdAt, isEnglish),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.article.sourceAuthor != null)
                    Flexible(
                      child: Text(
                        widget.article.sourceAuthor!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Headline
              Text(
                isEnglish
                    ? widget.article.englishHeadline
                    : widget.article.germanHeadline,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // 4. Source Link
              if (widget.article.sourceUrl != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () => _launchURL(widget.article.sourceUrl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.article.sourceAuthor ??
                            (isEnglish ? 'Source' : 'Quelle'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // 5. Article Content
              Html(
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
            ],
          ),
        ),
      ),
    );

    if (isWeb) {
      // Center content with constrained width for web
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenSize.width * 0.5, // 50% of screen width
          ),
          child: content,
        ),
      );
    }

    return Scaffold(appBar: const CustomAppBar(), body: content);
  }
}
