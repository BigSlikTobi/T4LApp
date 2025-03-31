import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for HapticFeedback
import 'package:app/models/news_ticker.dart';
import 'package:app/models/article.dart';
import 'package:app/article_page.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';
import 'package:app/utils/logger.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:app/slideshow_card.dart'; // Import the SlideShowCard component

/// A version of TickerSlideshowPage that can be embedded within other widgets
/// without its own Scaffold and AppBar
class EmbeddedTickerSlideshow extends StatefulWidget {
  final List<NewsTicker> tickers;
  const EmbeddedTickerSlideshow({super.key, required this.tickers});

  @override
  State<EmbeddedTickerSlideshow> createState() =>
      _EmbeddedTickerSlideshowState();
}

class _EmbeddedTickerSlideshowState extends State<EmbeddedTickerSlideshow> {
  late PageController _pageController;
  final int _currentPage = 0;
  final bool _isUserInteracting = false;

  @override
  void initState() {
    super.initState();
    // Sort tickers by created_at date (newest first)
    widget.tickers.sort((a, b) {
      final aCreatedDate = DateTime.tryParse(a.createdAt ?? '');
      final bCreatedDate = DateTime.tryParse(b.createdAt ?? '');
      if (aCreatedDate != null && bCreatedDate != null) {
        return bCreatedDate.compareTo(aCreatedDate); // newest first
      }
      return 0; // no valid dates to compare
    });
    _pageController = PageController(initialPage: 0);

    // Auto-advance slides if we have more than one
    if (widget.tickers.length > 1) {
      Future.delayed(const Duration(seconds: 10), _nextPage);
    }

    AppLogger.debug(
      'EmbeddedTickerSlideshow initialized with ${widget.tickers.length} tickers',
    );
  }

  void _nextPage() {
    if (!mounted || _isUserInteracting) return;
    final int nextPage =
        _currentPage + 1 == widget.tickers.length ? 0 : _currentPage + 1;
    _pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
    // Schedule the next slide
    Future.delayed(const Duration(seconds: 10), _nextPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Navigate to the article page using the ticker's source article ID
  void _navigateToArticlePage(
    BuildContext context,
    NewsTicker ticker,
    bool isEnglish,
  ) {
    // Add detailed logging about the ticker and its source article
    AppLogger.debug('Attempting to navigate to article page');
    AppLogger.debug('Ticker ID: ${ticker.id}');
    AppLogger.debug('Ticker sourceArticle: ${ticker.sourceArticle}');

    if (ticker.sourceArticle != null) {
      AppLogger.debug('SourceArticle ID: ${ticker.sourceArticle!.id}');
    } else {
      AppLogger.debug('SourceArticle is null');
    }

    // Try to extract any available identifier for the article
    int articleId;

    // First check the sourceArticle ID (conventional path)
    if (ticker.sourceArticle?.id != null) {
      articleId = ticker.sourceArticle!.id!;
      AppLogger.debug('Using sourceArticle ID: $articleId');
    }
    // If no sourceArticle ID, use the ticker ID as a fallback
    else {
      articleId = ticker.id;
      AppLogger.debug('Falling back to ticker ID: $articleId');
    }

    try {
      // Create an Article object from the ticker's data
      final article = Article(
        id: articleId, // Now we're always passing a non-nullable int
        englishHeadline: ticker.headlineEnglish ?? '',
        germanHeadline: ticker.headlineGerman ?? '',
        englishArticle: ticker.englishInformation ?? '',
        germanArticle: ticker.germanInformation ?? '',
        imageUrl: ticker.imageUrl,
        createdAt:
            ticker.createdAt != null ? DateTime.parse(ticker.createdAt!) : null,
        teamId: ticker.team?.teamId,
      );

      AppLogger.debug('Created article object with ID: ${article.id}');
      AppLogger.debug(
        'Article headline: ${isEnglish ? article.englishHeadline : article.germanHeadline}',
      );

      // Verify article has substantive content before navigating
      bool hasContent =
          (article.englishArticle.isNotEmpty ||
              article.germanArticle.isNotEmpty) &&
          (article.englishHeadline.isNotEmpty ||
              article.germanHeadline.isNotEmpty);

      if (hasContent) {
        // Navigate to the article page
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ArticlePage(article: article),
          ),
        );
        AppLogger.debug('Navigated to article page for ticker ${ticker.id}');
      } else {
        // Only show "no article" message if we truly have no content
        AppLogger.debug('Article has no content to display');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEnglish
                  ? 'This news item has no article content'
                  : 'Dieser Nachrichtenartikel hat keinen Inhalt',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error navigating to article page', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEnglish
                ? 'Unable to open article'
                : 'Artikel konnte nicht geöffnet werden',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish =
        languageProvider.currentLanguage == LanguageProvider.english;
    final theme = Theme.of(context);

    // Log number of tickers being displayed
    AppLogger.debug(
      'Building EmbeddedTickerSlideshow with ${widget.tickers.length} tickers',
    );

    if (widget.tickers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            isEnglish
                ? 'No team news available'
                : 'Keine Team-Neuigkeiten verfügbar',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    // Create slides from tickers
    List<Widget> slides =
        widget.tickers
            .map((ticker) => _buildSlide(ticker, isEnglish, theme))
            .toList();

    // Use the reusable SlideShowCard with Facility.png logo
    Widget slideContent = SlideShowCard(
      slides: slides,
      logoImagePath: 'assets/images/Facility.png',
      autoplayInterval: const Duration(seconds: 10),
      onTap:
          widget.tickers.isNotEmpty
              ? () {
                HapticFeedback.lightImpact();
                _navigateToArticlePage(
                  context,
                  widget.tickers[_currentPage],
                  isEnglish,
                );
              }
              : null,
    );

    // For web, we adapt the width based on screen size
    if (kIsWeb) {
      return LayoutBuilder(
        builder: (context, constraints) {
          // Calculate the width factor based on available width
          double widthFactor;
          if (constraints.maxWidth > 1200) {
            widthFactor = 2 / 3; // For larger screens
          } else if (constraints.maxWidth > 800) {
            widthFactor = 3 / 4; // For medium screens
          } else {
            widthFactor = 1.0; // For smaller screens
          }

          return Center(
            child: FractionallySizedBox(
              widthFactor: widthFactor,
              child: slideContent,
            ),
          );
        },
      );
    }

    return slideContent;
  }

  Widget _buildGlassmorphicContainer(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSlide(NewsTicker ticker, bool isEnglish, ThemeData theme) {
    final headlineText = ticker.getDisplayText(isEnglish);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Adjust text size based on available width
        double fontSize = constraints.maxWidth > 600 ? 18.0 : 16.0;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _navigateToArticlePage(context, ticker, isEnglish);
          },
          child: Stack(
            fit: StackFit.expand, // Ensure stack fills available space
            children: [
              // Image background with 70/30 cropping ratio
              Positioned.fill(
                child: Container(
                  color: Colors.black, // Background color for empty areas
                  child:
                      ticker.imageUrl != null && ticker.imageUrl!.isNotEmpty
                          ? Image.network(
                            ticker.imageUrl!,
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, -0.4),
                            errorBuilder: (_, __, ___) => _buildFallbackImage(),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
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

              // Gradient overlay for better text readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2), // Subtle darkness at top
                        Colors.black.withOpacity(
                          0.8,
                        ), // Darker at bottom for text contrast
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),

              // Headline with glassmorphic container - adjusted positioning
              Positioned(
                bottom: constraints.maxWidth > 600 ? 16 : 8,
                left: constraints.maxWidth > 600 ? 16 : 8,
                right: constraints.maxWidth > 600 ? 16 : 8,
                child: _buildGlassmorphicContainer(
                  Text(
                    headlineText,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: fontSize,
                      shadows: const [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(0, 1),
                          blurRadius: 3,
                        ),
                        Shadow(
                          color: Colors.black54,
                          offset: Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              // Page indicator with a more attractive styling
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    '${_currentPage + 1}/${widget.tickers.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),

              // Team logo if available
              if (ticker.team?.teamId != null)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/logos/${ticker.team!.teamId!.toLowerCase()}.png',
                        height: 40,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),

              // Add a subtle overlay to indicate clickability
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.8,
                      colors: [
                        Colors.white.withOpacity(0.0),
                        Colors.white.withOpacity(0.05),
                      ],
                      stops: const [0.7, 1.0],
                    ),
                  ),
                ),
              ),

              // Add a small icon to indicate this is tappable
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.touch_app,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFallbackImage() {
    return Image.asset(
      'assets/images/noHuddle.jpg',
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.4),
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
}
