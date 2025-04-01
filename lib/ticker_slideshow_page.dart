import 'package:flutter/material.dart';
import 'package:app/models/news_ticker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';
import 'package:app/utils/logger.dart';
import '../widgets/custom_app_bar.dart';

class TickerSlideshowPage extends StatefulWidget {
  final List<NewsTicker> tickers;

  const TickerSlideshowPage({super.key, required this.tickers});

  @override
  State<TickerSlideshowPage> createState() => _TickerSlideshowPageState();
}

class _TickerSlideshowPageState extends State<TickerSlideshowPage> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Sort tickers by created_at or publishedAt date (newest first)
    widget.tickers.sort((a, b) {
      // Try created_at first
      final aCreatedDate = DateTime.tryParse(a.createdAt ?? '');
      final bCreatedDate = DateTime.tryParse(b.createdAt ?? '');

      // If both have created_at dates, compare them
      if (aCreatedDate != null && bCreatedDate != null) {
        return bCreatedDate.compareTo(aCreatedDate); // newest first
      }

      // Fall back to publishedAt if created_at is not available
      final aPublishedDate = DateTime.tryParse(
        a.sourceArticle?.publishedAt ?? '',
      );
      final bPublishedDate = DateTime.tryParse(
        b.sourceArticle?.publishedAt ?? '',
      );

      // If both have published dates, compare them
      if (aPublishedDate != null && bPublishedDate != null) {
        return bPublishedDate.compareTo(aPublishedDate); // newest first
      }

      // If only one has a created_at date, prioritize it
      if (aCreatedDate != null) return -1; // a comes first
      if (bCreatedDate != null) return 1; // b comes first

      // If only one has a published date, prioritize it
      if (aPublishedDate != null) return -1; // a comes first
      if (bPublishedDate != null) return 1; // b comes first

      return 0; // no valid dates to compare
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
    if (dateString == null || dateString.isEmpty) {
      return isEnglish ? 'No date' : 'Kein Datum';
    }

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
    final isWeb = screenSize.width > 600;

    return Scaffold(
      appBar: CustomAppBar(),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(NewsTicker ticker, bool isEnglish, ThemeData theme) {
    final displayContent =
        isEnglish ? ticker.englishInformation : ticker.germanInformation;

    // Use getDisplayText to get the appropriate headline based on language
    final headlineText = ticker.getDisplayText(isEnglish);

    final sourceName = ticker.sourceArticle?.source?.name;

    // Format both dates
    final createdDate = _formatDate(ticker.createdAt, isEnglish);
    final publishedDate = _formatDate(
      ticker.sourceArticle?.publishedAt,
      isEnglish,
    );

    final isWeb = MediaQuery.of(context).size.width > 600;

    // Add more detailed logging
    AppLogger.debug(
      'Building slide for ticker ${ticker.id}: ${isEnglish ? 'English' : 'German'} headline: ${headlineText.substring(0, headlineText.length > 20 ? 20 : headlineText.length)}...',
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
                              if (ticker.sourceArticle?.publishedAt != null)
                                Text(
                                  '${isEnglish ? 'Published' : 'Veröffentlicht'}: $publishedDate',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
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
