import 'package:flutter/material.dart';
import 'package:app/models/article_ticker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';
import 'package:app/utils/logger.dart';
import '../widgets/custom_app_bar.dart';

// Debug toggle for TickerSlideshowPage
const bool _debugTickerSlideshowPage = false;

class TickerSlideshowPage extends StatefulWidget {
  final List<ArticleTicker> articles;
  const TickerSlideshowPage({super.key, required this.articles});

  @override
  State<TickerSlideshowPage> createState() => _TickerSlideshowPageState();
}

class _TickerSlideshowPageState extends State<TickerSlideshowPage> {
  late PageController _pageController;
  int _currentPage = 0;
  late List<ArticleTicker> _articles;
  static const autoplayInterval = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    if (_debugTickerSlideshowPage) {
      AppLogger.debug(
        '[TickerSlideshowPage] Initializing with ${widget.articles.length} articles',
      );
    }
    _articles = widget.articles;
    _pageController = PageController();

    // Set up automatic sliding if there are multiple articles
    if (_articles.length > 1) {
      if (_debugTickerSlideshowPage) {
        AppLogger.debug(
          '[TickerSlideshowPage] Setting up autoplay with ${autoplayInterval.inSeconds}s interval',
        );
      }
      Future.delayed(autoplayInterval, _nextPage);
    }
  }

  void _nextPage() {
    if (!mounted) {
      if (_debugTickerSlideshowPage) {
        AppLogger.debug(
          '[TickerSlideshowPage] Skipping page transition - widget not mounted',
        );
      }
      return;
    }

    final nextPage =
        _currentPage + 1 == _articles.length ? 0 : _currentPage + 1;
    if (_debugTickerSlideshowPage) {
      AppLogger.debug('[TickerSlideshowPage] Transitioning to page $nextPage');
    }

    _pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );

    // Schedule the next slide
    Future.delayed(autoplayInterval, _nextPage);
  }

  @override
  void dispose() {
    if (_debugTickerSlideshowPage) {
      AppLogger.debug('[TickerSlideshowPage] Disposing page controller');
    }
    _pageController.dispose();
    super.dispose();
  }

  String _formatDate(String? dateInput, bool isEnglish) {
    if (dateInput == null) return isEnglish ? 'No date' : 'Kein Datum';
    try {
      final date = DateTime.parse(dateInput);
      final format =
          isEnglish ? DateFormat('MMM d, yyyy') : DateFormat('dd.MM.yyyy');
      return format.format(date);
    } catch (e) {
      AppLogger.error(
        '[TickerSlideshowPage] Error formatting date: $dateInput',
        e,
      );
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

    if (_debugTickerSlideshowPage) {
      AppLogger.debug(
        '[TickerSlideshowPage] Building with screenSize: ${screenSize.width}x${screenSize.height}, isWeb: $isWeb, language: ${isEnglish ? 'en' : 'de'}',
      );
    }

    if (_articles.isEmpty) {
      if (_debugTickerSlideshowPage) {
        AppLogger.debug(
          '[TickerSlideshowPage] No articles available to display',
        );
      }
      return Scaffold(
        appBar: const CustomAppBar(),
        body: Center(
          child: Text(
            isEnglish ? 'No articles available' : 'Keine Artikel verfügbar',
            style: theme.textTheme.titleLarge,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            if (isWeb) const SizedBox(height: 24),
            Expanded(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: _articles.length,
                    onPageChanged: (index) {
                      if (_debugTickerSlideshowPage) {
                        AppLogger.debug(
                          '[TickerSlideshowPage] Page changed to index: $index',
                        );
                      }
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      final article = _articles[index];
                      if (_debugTickerSlideshowPage) {
                        AppLogger.debug(
                          '[TickerSlideshowPage] Building article $index: ${article.englishHeadline}',
                        );
                      }
                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth:
                                isWeb
                                    ? screenSize.width * 0.5
                                    : double.infinity,
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Team logo and page indicator
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16.0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (article.teamId != null)
                                        Image.asset(
                                          'assets/logos/${article.teamId!.toLowerCase()}.png',
                                          height: isWeb ? 40 : 30,
                                          errorBuilder:
                                              (_, __, ___) =>
                                                  const SizedBox.shrink(),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Text(
                                          '${_currentPage + 1}/${_articles.length}',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Article Image
                                if (article.image2 != null &&
                                    article.image2!.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: AspectRatio(
                                      aspectRatio: 16 / 9,
                                      child: Image.network(
                                        article.image2!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          if (_debugTickerSlideshowPage) {
                                            AppLogger.debug(
                                              '[TickerSlideshowPage] Failed to load image for article $index: ${article.image2}',
                                            );
                                          }
                                          return _buildFallbackImage();
                                        },
                                        loadingBuilder: (
                                          context,
                                          child,
                                          loadingProgress,
                                        ) {
                                          if (loadingProgress == null) {
                                            if (_debugTickerSlideshowPage) {
                                              AppLogger.debug(
                                                '[TickerSlideshowPage] Successfully loaded image for article $index',
                                              );
                                            }
                                            return child;
                                          }
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
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                // Headline
                                Text(
                                  isEnglish
                                      ? article.englishHeadline
                                      : article.germanHeadline,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                // Date and Source
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDate(article.createdAt, isEnglish),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: Colors.grey[600]),
                                    ),
                                    if (article.sourceName != null)
                                      Text(
                                        article.sourceName!,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                // Content
                                Text(
                                  isEnglish
                                      ? article.summaryEnglish
                                      : article.summaryGerman,
                                  style: theme.textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    if (_debugTickerSlideshowPage) {
      AppLogger.debug('[TickerSlideshowPage] Using fallback image');
    }
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
      ),
    );
  }
}
