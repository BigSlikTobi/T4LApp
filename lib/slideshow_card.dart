import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:app/models/article.dart';

class SlideShowCard extends StatefulWidget {
  final List<Widget> slides;
  final Duration autoplayInterval;

  const SlideShowCard({
    Key? key,
    required this.slides,
    this.autoplayInterval = const Duration(seconds: 5),
  }) : super(key: key);

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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          elevation: 2,
          // Increase bottom margin significantly to provide more spacing for the cards underneath
          margin: const EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double goldenRatio = 1.618;
                    final double slideHeight =
                        constraints.maxWidth / goldenRatio;

                    return SizedBox(
                      height: slideHeight.clamp(180.0, 300.0),
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: widget.slides.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return widget.slides[index];
                        },
                      ),
                    );
                  },
                ),
              ),

              // Page indicator dots
              if (widget.slides.length > 1)
                Padding(
                  padding: const EdgeInsets.only(
                    top: 8.0,
                    left: 8.0,
                    right: 8.0,
                    bottom: 16.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.slides.length, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              index == _currentPage
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade300,
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),

        // NoHuddle image positioned in front of the card
        Positioned(
          // Move the image up further to create more overlap with the slider
          bottom: 35,
          left: 50,
          right: 50,
          child: Center(
            child: Container(
              height: 59,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    spreadRadius: 0,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    spreadRadius: -2,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/noHuddleCrop.jpg',
                  height: 50,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class QuickNewsSlideShow extends StatelessWidget {
  final List<Article> articles;

  const QuickNewsSlideShow({Key? key, required this.articles})
    : super(key: key);

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

    return SlideShowCard(slides: slides);
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
                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                stops: const [0.5, 1.0],
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
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
      errorBuilder: (context, error, stackTrace) {
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
