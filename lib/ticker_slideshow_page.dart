import 'package:flutter/material.dart';
import 'package:app/models/article.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';
import 'package:app/utils/logger.dart';
import '../widgets/custom_app_bar.dart';

class TickerSlideshowPage extends StatefulWidget {
  final List<Article> articles;

  const TickerSlideshowPage({super.key, required this.articles});

  @override
  State<TickerSlideshowPage> createState() => _TickerSlideshowPageState();
}

class _TickerSlideshowPageState extends State<TickerSlideshowPage> {
  late PageController _pageController;
  int _currentPage = 0;
  late List<Article> _articles;

  @override
  void initState() {
    super.initState();

    _articles = List.from(widget.articles);

    // Sort articles by created_at date (newest first)
    _articles.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;
      if (aDate != null && bDate != null) {
        return bDate.compareTo(aDate); // newest first
      }
      if (aDate != null) return -1;
      if (bDate != null) return 1;
      return 0;
    });

    AppLogger.debug(
      'TickerSlideshowPage initialized with ${_articles.length} articles',
    );

    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatDate(dynamic dateInput, bool isEnglish) {
    if (dateInput == null) {
      return isEnglish ? 'No date' : 'Kein Datum';
    }

    try {
      DateTime date;
      if (dateInput is DateTime) {
        date = dateInput;
      } else if (dateInput is String) {
        if (dateInput.isEmpty) {
          return isEnglish ? 'No date' : 'Kein Datum';
        }
        date = DateTime.parse(dateInput);
      } else {
        return isEnglish ? 'Invalid date' : 'Ungültiges Datum';
      }

      final format =
          isEnglish ? DateFormat('MMM d, yyyy') : DateFormat('dd.MM.yyyy');
      return format.format(date);
    } catch (e) {
      AppLogger.error('Error formatting date: $dateInput', e);
      return isEnglish ? 'Invalid date' : 'Ungültiges Datum';
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish =
        languageProvider.currentLanguage == LanguageProvider.english;
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final isWeb = screenSize.width > 600;

    return Scaffold(
      appBar: const CustomAppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWeb ? 1200 : double.infinity),
          child: SafeArea(
            child: Column(
              children: [
                // Page header with image - responsive padding
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: screenSize.height * 0.015,
                    horizontal: isWeb ? 24.0 : screenSize.width * 0.04,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/noHuddle.jpg',
                            height: 150, // Match the previous text height
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Slideshow with responsive width
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWeb ? 24.0 : 16.0,
                    ),
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _articles.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        return _buildArticleSlide(
                          _articles[index],
                          isEnglish,
                          theme,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArticleSlide(Article article, bool isEnglish, ThemeData theme) {
    final displayContent =
        isEnglish ? article.englishArticle : article.germanArticle;
    final headlineText =
        isEnglish ? article.englishHeadline : article.germanHeadline;
    final sourceName = article.sourceAuthor;
    final createdDate = _formatDate(article.createdAt, isEnglish);

    final isWeb = MediaQuery.of(context).size.width > 600;

    // Add detailed logging
    AppLogger.debug(
      'Building article slide for ${article.id}: ${isEnglish ? 'English' : 'German'} headline: ${headlineText.substring(0, headlineText.length > 20 ? 20 : headlineText.length)}...',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Log constraints for debugging
        AppLogger.debug(
          'Slide constraints: ${constraints.maxWidth} x ${constraints.maxHeight}',
        );

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isWeb ? 24.0 : constraints.maxWidth * 0.04,
            vertical: constraints.maxHeight * 0.02,
          ),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight * 0.95,
              ),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Headline - responsive padding
                    Padding(
                      padding: EdgeInsets.all(
                        isWeb ? 24.0 : constraints.maxWidth * 0.04,
                      ),
                      child: Text(
                        headlineText,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Image - responsive height with top alignment
                    SizedBox(
                      height: isWeb ? 400 : constraints.maxHeight * 0.35,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child:
                            article.imageUrl != null &&
                                    article.imageUrl!.isNotEmpty
                                ? Image.network(
                                  article.imageUrl!,
                                  fit: BoxFit.cover,
                                  alignment:
                                      Alignment.topCenter, // Align from top
                                  errorBuilder:
                                      (_, __, ___) => _buildFallbackImage(),
                                  loadingBuilder: (
                                    context,
                                    child,
                                    loadingProgress,
                                  ) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value:
                                            loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                                : null,
                                        color: theme.colorScheme.primary,
                                      ),
                                    );
                                  },
                                )
                                : _buildFallbackImage(),
                      ),
                    ),
                    // Information - responsive padding
                    if (displayContent.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.all(
                          isWeb ? 24.0 : constraints.maxWidth * 0.04,
                        ),
                        child: Text(
                          displayContent,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    // Date and Source with page indicator - responsive padding
                    Padding(
                      padding: EdgeInsets.all(
                        isWeb ? 24.0 : constraints.maxWidth * 0.04,
                      ),
                      child: Column(
                        children: [
                          // Date and source row
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      '${isEnglish ? 'Created' : 'Erstellt'}: $createdDate',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: Colors.grey[600]),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (sourceName != null &&
                                      sourceName.isNotEmpty)
                                    Flexible(
                                      child: Text(
                                        sourceName,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.end,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          // Page indicator below source
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${_currentPage + 1}/${_articles.length}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Team ID section
                    if (article.teamId != null)
                      Padding(
                        padding: EdgeInsets.all(constraints.maxWidth * 0.02),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Image.asset(
                            'assets/logos/${article.teamId!.toLowerCase()}.png',
                            height: isWeb ? 60 : constraints.maxHeight * 0.06,
                            errorBuilder:
                                (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallbackImage() {
    return Image.asset(
      'assets/images/noHuddle.jpg',
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      errorBuilder:
          (context, error, stackTrace) => Container(
            color: Colors.grey[300],
            child: const Center(
              child: Icon(
                Icons.image_not_supported,
                size: 50,
                color: Colors.grey,
              ),
            ),
          ),
    );
  }
}
