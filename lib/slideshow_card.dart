import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:app/models/article.dart';

class SlideShowCard extends StatefulWidget {
  final List<Widget> slides;
  final Duration autoplayInterval;
  final VoidCallback? onTap;
  final String? logoImagePath; // Added parameter for configurable logo image

  const SlideShowCard({
    super.key,
    required this.slides,
    this.autoplayInterval = const Duration(seconds: 10),
    this.onTap,
    this.logoImagePath, // Optional logo path that can be passed
  });

  @override
  State<SlideShowCard> createState() => _SlideShowCardState();
}

class _SlideShowCardState extends State<SlideShowCard> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Set up automatic sliding if there are multiple slides
    if (widget.slides.length > 1) {
      Future.delayed(widget.autoplayInterval, _nextPage);
    }
  }

  void _nextPage() {
    if (!mounted) return;

    final int nextPage =
        _currentPage + 1 == widget.slides.length ? 0 : _currentPage + 1;

    _pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );

    // Schedule the next slide
    Future.delayed(widget.autoplayInterval, _nextPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        // Add splash effect to make card visibly clickable
        splashColor: Theme.of(context).primaryColor.withOpacity(0.3),
        highlightColor: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Logo positioned at the top
            if (widget.logoImagePath != null)
              Positioned(
                top: 8,
                right: 8,
                child: Image.asset(
                  widget.logoImagePath!,
                  height: 40,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),

            // PageView for slides
            SizedBox(
              height: 200, // Fixed height for slides
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: widget.slides,
              ),
            ),

            // Page indicator dots
            if (widget.slides.length > 1)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.slides.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            _currentPage == index
                                ? Theme.of(context).primaryColor
                                : Colors.grey.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (kIsWeb) {
      return LayoutBuilder(
        builder: (context, constraints) {
          double widthFactor;
          if (constraints.maxWidth > 1200) {
            widthFactor = 2 / 3;
          } else if (constraints.maxWidth > 800) {
            widthFactor = 3 / 4;
          } else {
            widthFactor = 1.0;
          }

          return Center(
            child: FractionallySizedBox(
              widthFactor: widthFactor,
              child: cardContent,
            ),
          );
        },
      );
    }

    return cardContent;
  }
}

class QuickNewsSlideShow extends StatelessWidget {
  final List<Article> articles;

  const QuickNewsSlideShow({super.key, required this.articles});

  @override
  Widget build(BuildContext context) {
    // Use actual articles if available, otherwise use a placeholder
    List<Widget> slides =
        articles.isNotEmpty
            ? articles
                .take(5)
                .map((article) => _buildArticleSlide(article, context))
                .toList()
            : [_buildPlaceholderSlide()];
    return SlideShowCard(
      slides: slides,
      logoImagePath: 'assets/images/noHuddle.jpg',
    );
  }

  Widget _buildArticleSlide(Article article, BuildContext context) {
    return Stack(
      children: [
        // Article image or fallback
        Positioned.fill(
          child:
              article.imageUrl != null && article.imageUrl!.isNotEmpty
                  ? Image.network(
                    article.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildFallbackImage(),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value:
                              loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                        ),
                      );
                    },
                  )
                  : _buildFallbackImage(),
        ),

        // Gradient overlay for better text readability
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.2), // Added subtle darkness at top
                  Colors.black.withOpacity(0.8), // Made bottom gradient darker
                ],
                stops: const [0.4, 1.0],
              ),
            ),
          ),
        ),
        // Article headline
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              article.englishHeadline,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.8),
                    offset: const Offset(0, 1),
                    blurRadius: 3,
                  ),
                  Shadow(
                    color: Colors.black.withOpacity(0.6),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderSlide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Expanded placeholder image
        Expanded(child: _buildFallbackImage()),

        // Text placeholder
        Container(
          padding: const EdgeInsets.all(12.0),
          color: Colors.black.withOpacity(0.7),
          child: const Text(
            'Quick news from the NFL',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
