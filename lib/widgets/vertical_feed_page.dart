import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/models/article_ticker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';
import 'package:app/utils/logger.dart';
import 'package:app/widgets/custom_app_bar.dart';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vector;

const bool _debugVerticalFeed = false;

class VerticalFeedPage extends StatefulWidget {
  final List<ArticleTicker> articles;

  const VerticalFeedPage({super.key, required this.articles});

  @override
  State<VerticalFeedPage> createState() => _VerticalFeedPageState();
}

class _VerticalFeedPageState extends State<VerticalFeedPage>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _kenBurnsController;
  late Animation<Offset> _panAnimation;
  late Animation<double> _scaleAnimation;
  int _currentPage = 0;
  late List<ArticleTicker> _articles;
  double _dragOffset = 0;
  final double _bottomPadding = 80.0;
  final _random = math.Random();
  final _transformationController = TransformationController();
  late final AnimationController _animationController;
  Animation<Matrix4>? _animation;
  final double _minScale = 1.0;
  final double _maxScale = 2.0;
  bool _isImageInteractionEnabled = false;

  @override
  void initState() {
    super.initState();
    _articles = widget.articles;
    _pageController = PageController(
      viewportFraction: 0.999,
    ); // Prevents peek of next page

    // Initialize Ken Burns animation controller
    _kenBurnsController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _setupKenBurnsAnimation();
    _kenBurnsController.forward();

    if (_debugVerticalFeed) {
      AppLogger.debug(
        '[VerticalFeedPage] Initialized with ${_articles.length} articles',
      );
    }
  }

  void _setupKenBurnsAnimation() {
    final startScale = 1.1;
    final endScale = 1.2;

    // Calculate max safe translation based on scale to prevent black edges
    final maxTranslation = (endScale - 1.0) / 2;

    final startOffset = Offset(
      _random.nextDouble() * maxTranslation * 2 - maxTranslation,
      _random.nextDouble() * maxTranslation * 2 - maxTranslation,
    );

    final endOffset = Offset(
      _random.nextDouble() * maxTranslation * 2 - maxTranslation,
      _random.nextDouble() * maxTranslation * 2 - maxTranslation,
    );

    _panAnimation = Tween<Offset>(begin: startOffset, end: endOffset).animate(
      CurvedAnimation(parent: _kenBurnsController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: startScale, end: endScale).animate(
      CurvedAnimation(parent: _kenBurnsController, curve: Curves.easeInOut),
    );

    // Loop the animation
    _kenBurnsController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _kenBurnsController.reset();
        _setupKenBurnsAnimation();
        _kenBurnsController.forward();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _kenBurnsController.dispose();
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    HapticFeedback.lightImpact();
    setState(() {
      _currentPage = page;
      _dragOffset = 0; // Reset drag offset when changing pages
    });

    // Reset and restart Ken Burns effect on page change
    _kenBurnsController.reset();
    _setupKenBurnsAnimation();
    _kenBurnsController.forward();

    if (_debugVerticalFeed) {
      AppLogger.debug('[VerticalFeedPage] Swiped to article $page');
    }
  }

  void _onInteractionStart(ScaleStartDetails details) {
    _kenBurnsController.stop();
    _isImageInteractionEnabled = true;
    // Cancel any running animations
    _animationController.stop();
    _animation?.removeListener(_onAnimateTransform);
    _animation = null;
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    if (!_isImageInteractionEnabled) return;

    final Matrix4 matrix = Matrix4.copy(_transformationController.value);

    // Handle scale
    matrix.scale(details.scale, details.scale, 1.0);

    // Get current scale to check bounds
    final currentScale = _getCurrentScale(matrix);

    if (currentScale >= _minScale && currentScale <= _maxScale) {
      // Apply translation only if scale is within bounds
      matrix.translate(
        details.focalPointDelta.dx / currentScale,
        details.focalPointDelta.dy / currentScale,
      );

      // Check if the translation keeps the image within bounds
      if (_isTransformationWithinBounds(matrix)) {
        _transformationController.value = matrix;
      }
    }
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    _isImageInteractionEnabled = false;
    final Matrix4 matrix = Matrix4.copy(_transformationController.value);
    final currentScale = _getCurrentScale(matrix);

    // If scale is out of bounds, animate back to nearest bound
    if (currentScale < _minScale) {
      _animateScale(_minScale);
    } else if (currentScale > _maxScale) {
      _animateScale(_maxScale);
    } else if (!_isTransformationWithinBounds(matrix)) {
      _animateBackToBounds();
    }

    // Restart Ken Burns effect
    _kenBurnsController.forward();
  }

  double _getCurrentScale(Matrix4 matrix) {
    return vector.Vector3(
      matrix.getColumn(0).x,
      matrix.getColumn(1).y,
      1.0,
    ).length;
  }

  bool _isTransformationWithinBounds(Matrix4 matrix) {
    final scale = _getCurrentScale(matrix);
    final translation = vector.Vector3(
      matrix.getColumn(3).x,
      matrix.getColumn(3).y,
      0.0,
    );

    // Calculate maximum allowed translation based on scale
    final maxTranslation = (scale - 1.0) / 2;

    return translation.x.abs() <= maxTranslation &&
        translation.y.abs() <= maxTranslation;
  }

  void _animateScale(double targetScale) {
    final Matrix4 endMatrix = Matrix4.copy(_transformationController.value);
    final currentScale = _getCurrentScale(endMatrix);
    final double factor = targetScale / currentScale;
    endMatrix.scale(factor, factor, 1.0);

    _animateMatrix(endMatrix);
  }

  void _animateBackToBounds() {
    final Matrix4 matrix = Matrix4.copy(_transformationController.value);
    final scale = _getCurrentScale(matrix);
    final translation = vector.Vector3(
      matrix.getColumn(3).x,
      matrix.getColumn(3).y,
      0.0,
    );

    // Calculate maximum allowed translation based on current scale
    final maxTranslation = (scale - 1.0) / 2;

    // Clamp translation to bounds
    final clampedX = translation.x.clamp(-maxTranslation, maxTranslation);
    final clampedY = translation.y.clamp(-maxTranslation, maxTranslation);

    matrix.setColumn(3, vector.Vector4(clampedX, clampedY, 0.0, 1.0));

    _animateMatrix(matrix);
  }

  void _animateMatrix(Matrix4 end) {
    _animation?.removeListener(_onAnimateTransform);

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: end,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animation!.addListener(_onAnimateTransform);
    _animationController.forward(from: 0);
  }

  void _onAnimateTransform() {
    _transformationController.value = _animation!.value;
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
        '[VerticalFeedPage] Error formatting date: $dateInput',
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

    if (_articles.isEmpty) {
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
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedOpacity(
          opacity: _dragOffset < 20 ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: const CustomAppBar(),
        ),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (!_isImageInteractionEnabled) {
            if (notification is ScrollUpdateNotification) {
              final newOffset = notification.metrics.pixels.abs();
              // Only update drag offset if the change is significant
              if ((newOffset - _dragOffset).abs() > 1) {
                setState(() {
                  _dragOffset = newOffset;
                });
              }
            } else if (notification is ScrollEndNotification) {
              // Reset drag offset when scroll ends
              setState(() {
                _dragOffset = 0;
              });
            }
          }
          return false;
        },
        child: PageView.builder(
          physics:
              _isImageInteractionEnabled
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
          scrollDirection: Axis.vertical,
          controller: _pageController,
          itemCount: _articles.length,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            final article = _articles[index];
            return Container(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Animated background with Ken Burns effect and gesture handling
                  if (article.image2 != null && article.image2!.isNotEmpty)
                    Positioned.fill(
                      child: GestureDetector(
                        onScaleStart: _onInteractionStart,
                        onScaleUpdate: _onInteractionUpdate,
                        onScaleEnd: _onInteractionEnd,
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: _minScale,
                          maxScale: _maxScale,
                          panEnabled: false,
                          scaleEnabled: false,
                          child: AnimatedBuilder(
                            animation: _kenBurnsController,
                            builder: (context, child) {
                              return !_isImageInteractionEnabled
                                  ? Transform.scale(
                                    scale: _scaleAnimation.value,
                                    child: Transform.translate(
                                      offset: Offset(
                                        _panAnimation.value.dx *
                                            MediaQuery.of(context).size.width,
                                        _panAnimation.value.dy *
                                            MediaQuery.of(context).size.height,
                                      ),
                                      child: child,
                                    ),
                                  )
                                  : child!;
                            },
                            child: Hero(
                              tag: 'article-image-${article.id}',
                              child: Image.network(
                                article.image2!,
                                fit: BoxFit.cover,
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
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Enhanced gradient overlay for better text readability
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.4),
                            Colors.black.withOpacity(0.9),
                          ],
                          stops: const [0.3, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Content with slide-up animation
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: _bottomPadding,
                    child: SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (article.teamId != null)
                            Container(
                              padding: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Hero(
                                tag: 'team-logo-${article.id}',
                                child: Image.asset(
                                  'assets/logos/${article.teamId!.toLowerCase()}.png',
                                  height: isWeb ? 40 : 30,
                                  errorBuilder:
                                      (_, __, ___) => const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          Text(
                            isEnglish
                                ? article.englishHeadline
                                : article.germanHeadline,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.8),
                                  offset: const Offset(0, 2),
                                  blurRadius: 4,
                                ),
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.black.withOpacity(0.3),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDate(article.createdAt, isEnglish),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.8),
                                        offset: const Offset(0, 1),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                if (article.sourceName != null)
                                  Text(
                                    article.sourceName!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.8),
                                          offset: const Offset(0, 1),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.black.withOpacity(0.4),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              isEnglish
                                  ? article.summaryEnglish
                                  : article.summaryGerman,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white,
                                height: 1.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.8),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Swipe indicator with enhanced visibility
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 20,
                    child: AnimatedOpacity(
                      opacity: _dragOffset < 50 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.keyboard_arrow_up,
                                color: Colors.white.withOpacity(0.9),
                                size: 32,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.5),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              Text(
                                '${_currentPage + 1}/${_articles.length}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.5),
                                      offset: const Offset(0, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
      ),
    );
  }
}
