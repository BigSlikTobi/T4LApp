import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:app/models/news_ticker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';
import 'package:app/utils/logger.dart';

class TickerSlideshowPage extends StatefulWidget {
  final List<NewsTicker> tickers;

  const TickerSlideshowPage({Key? key, required this.tickers})
    : super(key: key);

  @override
  State<TickerSlideshowPage> createState() => _TickerSlideshowPageState();
}

class _TickerSlideshowPageState extends State<TickerSlideshowPage> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Sort tickers by publishedAt date (newest first)
    widget.tickers.sort((a, b) {
      final aDate = DateTime.tryParse(a.sourceArticle?.publishedAt ?? '');
      final bDate = DateTime.tryParse(b.sourceArticle?.publishedAt ?? '');
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate); // newest first
    });

    _pageController = PageController(initialPage: 0);

    AppLogger.debug(
      'TickerSlideshowPage initialized with ${widget.tickers.length} tickers',
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatDate(String? dateString, bool isEnglish) {
    if (dateString == null || dateString.isEmpty)
      return isEnglish ? 'No date' : 'Kein Datum';

    try {
      final date = DateTime.parse(dateString);
      final format =
          isEnglish ? DateFormat('MMM d, yyyy') : DateFormat('dd.MM.yyyy');
      return format.format(date);
    } catch (e) {
      AppLogger.error('Error formatting date: $dateString', e);
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

    // Log screen dimensions for debugging
    AppLogger.debug(
      'Building TickerSlideshowPage - Screen size: ${screenSize.width} x ${screenSize.height}',
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Image.asset(
          'assets/images/T4LLogo.png',
          height: 80,
          fit: BoxFit.contain,
        ),
        actions: [
          // Language toggle button with improved visibility
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () {
                languageProvider.toggleLanguage();
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      isEnglish ? 'EN' : 'DE',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.language,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Page header with image - responsive padding
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: screenSize.height * 0.015,
                horizontal: screenSize.width * 0.04,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/noHuddleCrop.jpg',
                        height: 40, // Match the previous text height
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Slideshow - remaining space
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.tickers.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final ticker = widget.tickers[index];
                  return _buildSlide(ticker, isEnglish, theme);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(NewsTicker ticker, bool isEnglish, ThemeData theme) {
    final displayContent =
        isEnglish ? ticker.englishInformation : ticker.germanInformation;
    final headlineText =
        ticker.headline ??
        (isEnglish ? ticker.englishInformation : ticker.germanInformation) ??
        '';
    final sourceName = ticker.sourceArticle?.source?.name;
    final dateString = _formatDate(
      ticker.sourceArticle?.publishedAt,
      isEnglish,
    );

    // Log for debugging
    AppLogger.debug(
      'Building slide for ticker: ${ticker.id} with headline: ${headlineText.substring(0, headlineText.length > 20 ? 20 : headlineText.length)}...',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Log constraints for debugging
        AppLogger.debug(
          'Slide constraints: ${constraints.maxWidth} x ${constraints.maxHeight}',
        );

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth * 0.04,
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
                      padding: EdgeInsets.all(constraints.maxWidth * 0.04),
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
                      height: constraints.maxHeight * 0.35,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child:
                            ticker.imageUrl != null &&
                                    ticker.imageUrl!.isNotEmpty
                                ? Image.network(
                                  ticker.imageUrl!,
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
                    if (displayContent != null && displayContent.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.all(constraints.maxWidth * 0.04),
                        child: Text(
                          displayContent,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),

                    // Date and Source with page indicator - responsive padding
                    Padding(
                      padding: EdgeInsets.all(constraints.maxWidth * 0.04),
                      child: Column(
                        children: [
                          // Date and source row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  dateString,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (sourceName != null && sourceName.isNotEmpty)
                                Flexible(
                                  child: Text(
                                    sourceName,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                  ),
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
                                '${_currentPage + 1}/${widget.tickers.length}',
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

                    // Team logo section
                    if (ticker.team?.teamId != null)
                      Padding(
                        padding: EdgeInsets.all(constraints.maxWidth * 0.02),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Image.asset(
                            'assets/logos/${ticker.team!.teamId!.toLowerCase()}.png',
                            height: constraints.maxHeight * 0.06,
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
      alignment: Alignment.topCenter, // Align from top
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
