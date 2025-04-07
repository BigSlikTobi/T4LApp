import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:app/models/article_ticker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';
import 'package:app/utils/logger.dart';
import 'package:app/widgets/custom_app_bar.dart';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vector;
import 'dart:ui';
import 'dart:ui' as ui;

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
  Map<int, PageController> _imageControllers = {};
  late AnimationController _kenBurnsController;
  late Animation<Offset> _panAnimation;
  late Animation<double> _scaleAnimation;
  int _currentPage = 0;
  Map<int, int> _articleImageIndices = {}; // Track image index for each article
  late List<ArticleTicker> _articles;
  double _dragOffset = 0;
  final double _bottomPadding = 80.0;
  final _random = math.Random();
  Map<int, TransformationController> _transformationControllers = {};
  late final AnimationController _animationController;
  late final AnimationController _imageTransitionController;
  Animation<Matrix4>? _animation;
  final double _minScale = 1.05; // Increased from 1.0 to ensure full coverage
  final double _maxScale = 3.0; // Increased max scale for more zoom range
  final double _panResistance = 2.5; // Added pan resistance factor
  bool _isImageInteractionEnabled = false;
  Timer? _imageTransitionTimer;
  late AnimationController _blurAnimationController;
  late Animation<double> _blurAnimation;

  @override
  void initState() {
    super.initState();
    _articles = widget.articles;
    _pageController = PageController(viewportFraction: 0.999);

    // Initialize controllers for each article
    for (var i = 0; i < _articles.length; i++) {
      _imageControllers[i] = PageController();
      _articleImageIndices[i] = 0;
      _transformationControllers[i] = TransformationController();
    }

    _kenBurnsController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _imageTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _blurAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _blurAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(
        parent: _blurAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _setupKenBurnsAnimation();
    _kenBurnsController.forward();
    _startImageTransitionTimer();

    if (_debugVerticalFeed) {
      AppLogger.debug(
        '[VerticalFeedPage] Initialized with ${_articles.length} articles',
      );
    }
  }

  void _setupKenBurnsAnimation() {
    final startScale = 1.1; // Increased from 1.1
    final endScale = 1.4; // Slightly increased for more dramatic effect

    // Calculate max safe translation based on scale to prevent black edges
    final maxTranslation = (endScale - 1.0) / 3.0; // Reduced from 2.0

    // Add some padding to the translation range to ensure coverage
    final safeMaxTranslation = maxTranslation + 0.03;

    final startOffset = Offset(
      _random.nextDouble() * safeMaxTranslation * 2 - safeMaxTranslation,
      _random.nextDouble() * safeMaxTranslation * 2 - safeMaxTranslation,
    );

    final endOffset = Offset(
      _random.nextDouble() * safeMaxTranslation * 2 - safeMaxTranslation,
      _random.nextDouble() * safeMaxTranslation * 2 - safeMaxTranslation,
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
    _blurAnimationController.dispose();
    _pageController.dispose();
    // Dispose all controllers
    for (var controller in _imageControllers.values) {
      controller.dispose();
    }
    for (var controller in _transformationControllers.values) {
      controller.dispose();
    }
    _kenBurnsController.dispose();
    _animationController.dispose();
    _imageTransitionController.dispose();
    _imageTransitionTimer?.cancel();
    super.dispose();
  }

  void _startImageTransitionTimer() {
    _imageTransitionTimer?.cancel();
    _imageTransitionTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isImageInteractionEnabled && mounted) {
        final images = _getAvailableImages(_articles[_currentPage]);
        if (images.length > 1) {
          final currentIndex = _articleImageIndices[_currentPage] ?? 0;
          final nextIndex = (currentIndex + 1) % images.length;

          if (_debugVerticalFeed) {
            AppLogger.debug(
              '[VerticalFeedPage] Transitioning images for article ${_articles[_currentPage].id}',
            );
          }

          // Start blur transition
          _blurAnimationController.forward().then((_) {
            // Change page when blur is at maximum
            final controller = _imageControllers[_currentPage];
            if (controller != null && mounted) {
              controller
                  .animateToPage(
                    nextIndex,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  )
                  .then((_) {
                    // Reverse blur after page change
                    if (mounted) {
                      _blurAnimationController.reverse();
                    }
                  });
            }
          });
        }
      }
    });
  }

  void _onPageChanged(int page) {
    HapticFeedback.lightImpact();

    // Reset controllers and state for the new page
    if (_debugVerticalFeed) {
      AppLogger.debug('[VerticalFeedPage] Page changed to $page');
    }

    // Reset transformation controller for the new page
    _transformationControllers[page]?.value = Matrix4.identity();

    setState(() {
      _currentPage = page;
      _dragOffset = 0;

      // Reset image index for the new page if not already set
      if (!_articleImageIndices.containsKey(page)) {
        _articleImageIndices[page] = 0;
      }
    });

    // Reset Ken Burns effect
    _kenBurnsController.reset();
    _setupKenBurnsAnimation();
    _kenBurnsController.forward();

    // Restart image transition timer with a small delay to allow page transition to complete
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _startImageTransitionTimer();
      }
    });

    if (_debugVerticalFeed) {
      final images = _getAvailableImages(_articles[page]);
      AppLogger.debug('[VerticalFeedPage] New page setup complete:');
      AppLogger.debug(
        '[VerticalFeedPage] - Available images: ${images.length}',
      );
      AppLogger.debug(
        '[VerticalFeedPage] - Current image index: ${_articleImageIndices[page]}',
      );
    }
  }

  void _onInteractionStart(ScaleStartDetails details, int articleIndex) {
    _kenBurnsController.stop();
    _isImageInteractionEnabled = true;
    // Cancel any running animations
    _animationController.stop();
    _animation?.removeListener(() => _onAnimateTransform(articleIndex));
    _animation = null;
  }

  void _onInteractionUpdate(ScaleUpdateDetails details, int articleIndex) {
    if (!_isImageInteractionEnabled) return;

    final controller = _transformationControllers[articleIndex];
    if (controller == null) return;

    final Matrix4 matrix = Matrix4.copy(controller.value);
    final size = MediaQuery.of(context).size;

    // Get current scale before applying new transformation
    final currentScale = _getCurrentScale(matrix);
    final nextScale = currentScale * details.scale;

    // Enhanced scale calculation with smoother progression
    final scale = nextScale.clamp(_minScale, _maxScale);
    final scaleFactor = scale / currentScale;

    // Apply scale from focal point with enhanced precision
    final focalPoint = details.localFocalPoint;
    matrix.translate(focalPoint.dx, focalPoint.dy);
    matrix.scale(scaleFactor, scaleFactor);
    matrix.translate(-focalPoint.dx, -focalPoint.dy);

    // Apply translation with increased resistance as scale decreases
    // This makes panning harder when zoomed out and easier when zoomed in
    final resistance =
        _panResistance * (_maxScale - scale) / (_maxScale - _minScale);
    final adjustedDelta = Offset(
      details.focalPointDelta.dx / (scale * resistance),
      details.focalPointDelta.dy / (scale * resistance),
    );

    // Get current translation
    final translation = vector.Vector3(
      matrix.getColumn(3).x,
      matrix.getColumn(3).y,
      0.0,
    );

    // Calculate maximum allowed translation based on current scale
    // Increased bounds to allow more movement with blur effect
    final maxTranslationX = size.width * (scale - 1.0) / (1.8 * scale);
    final maxTranslationY = size.height * (scale - 1.0) / (1.8 * scale);

    // Calculate new translation while respecting tighter bounds
    final newX = (translation.x + adjustedDelta.dx).clamp(
      -maxTranslationX,
      maxTranslationX,
    );
    final newY = (translation.y + adjustedDelta.dy).clamp(
      -maxTranslationY,
      maxTranslationY,
    );

    // Apply bounded translation
    matrix.setTranslation(vector.Vector3(newX, newY, 0.0));

    controller.value = matrix;
  }

  void _onInteractionEnd(ScaleEndDetails details, int articleIndex) {
    _isImageInteractionEnabled = false;
    final controller = _transformationControllers[articleIndex];
    if (controller == null) return;

    final Matrix4 matrix = Matrix4.copy(controller.value);
    final currentScale = _getCurrentScale(matrix);

    // If scale is out of bounds, animate back to nearest bound
    if (currentScale < _minScale) {
      _animateScale(_minScale, articleIndex);
    } else if (currentScale > _maxScale) {
      _animateScale(_maxScale, articleIndex);
    } else if (!_isTransformationWithinBounds(matrix)) {
      _animateBackToBounds(articleIndex);
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
    final size = MediaQuery.of(context).size;

    // Get current translation
    final translation = vector.Vector3(
      matrix.getColumn(3).x,
      matrix.getColumn(3).y,
      0.0,
    );

    // Calculate maximum allowed translation based on current scale and viewport
    // Adjust bounds to match the new translation limits
    final maxTranslationX = size.width * (scale - 1.0) / (1.8 * scale);
    final maxTranslationY = size.height * (scale - 1.0) / (1.8 * scale);

    return translation.x.abs() <= maxTranslationX &&
        translation.y.abs() <= maxTranslationY;
  }

  void _animateScale(double targetScale, int articleIndex) {
    final controller = _transformationControllers[articleIndex];
    if (controller == null) return;

    final Matrix4 endMatrix = Matrix4.copy(controller.value);
    final currentScale = _getCurrentScale(endMatrix);
    final double factor = targetScale / currentScale;
    endMatrix.scale(factor, factor, 1.0);

    _animateMatrix(endMatrix, articleIndex);
  }

  void _animateBackToBounds(int articleIndex) {
    final controller = _transformationControllers[articleIndex];
    if (controller == null) return;

    final matrix = Matrix4.copy(controller.value);
    final scale = _getCurrentScale(matrix);
    final size = MediaQuery.of(context).size;

    // Get current translation
    final translation = vector.Vector3(
      matrix.getColumn(3).x,
      matrix.getColumn(3).y,
      0.0,
    );

    // Calculate maximum allowed translation based on current scale and viewport
    // Adjust bounds to match the new translation limits
    final maxTranslationX = size.width * (scale - 1.0) / (1.8 * scale);
    final maxTranslationY = size.height * (scale - 1.0) / (1.8 * scale);

    // Clamp translation to bounds
    final clampedX = translation.x.clamp(-maxTranslationX, maxTranslationX);
    final clampedY = translation.y.clamp(-maxTranslationY, maxTranslationY);

    // Create new matrix with bounded translation
    final boundedMatrix = Matrix4.copy(matrix)
      ..setTranslation(vector.Vector3(clampedX, clampedY, 0.0));

    _animateMatrix(boundedMatrix, articleIndex);
  }

  void _animateMatrix(Matrix4 end, int articleIndex) {
    final controller = _transformationControllers[articleIndex];
    if (controller == null) return;

    _animation?.removeListener(() => _onAnimateTransform(articleIndex));

    _animation = Matrix4Tween(begin: controller.value, end: end).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animation!.addListener(() => _onAnimateTransform(articleIndex));
    _animationController.forward(from: 0);
  }

  void _onAnimateTransform(int articleIndex) {
    final controller = _transformationControllers[articleIndex];
    if (controller != null && _animation != null) {
      controller.value = _animation!.value;
    }
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

  List<String> _getAvailableImages(ArticleTicker article) {
    final images = [
      if (article.image1 != null && article.image1!.isNotEmpty) article.image1!,
      if (article.image2 != null && article.image2!.isNotEmpty) article.image2!,
      if (article.image3 != null && article.image3!.isNotEmpty) article.image3!,
    ];

    if (_debugVerticalFeed) {
      AppLogger.debug(
        '[VerticalFeedPage] Available images for article ${article.id}:',
      );
      AppLogger.debug(
        '[VerticalFeedPage] - Image1: ${article.image1 ?? "null"}',
      );
      AppLogger.debug(
        '[VerticalFeedPage] - Image2: ${article.image2 ?? "null"}',
      );
      AppLogger.debug(
        '[VerticalFeedPage] - Image3: ${article.image3 ?? "null"}',
      );
    }

    return images;
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
            final availableImages = _getAvailableImages(article);

            return Container(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (availableImages.isNotEmpty)
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onScaleStart:
                                (details) =>
                                    _onInteractionStart(details, index),
                            onScaleUpdate:
                                (details) =>
                                    _onInteractionUpdate(details, index),
                            onScaleEnd:
                                (details) => _onInteractionEnd(details, index),
                            child: AnimatedBuilder(
                              animation: _blurAnimation,
                              builder: (context, child) {
                                return BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: _blurAnimation.value,
                                    sigmaY: _blurAnimation.value,
                                  ),
                                  child: child,
                                );
                              },
                              child: ClipRect(
                                child: PageView.builder(
                                  controller: _imageControllers[index],
                                  onPageChanged: (imageIndex) {
                                    setState(() {
                                      _articleImageIndices[index] = imageIndex;
                                    });
                                  },
                                  itemCount: availableImages.length,
                                  itemBuilder: (context, imageIndex) {
                                    return Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // Blurred background that extends the image
                                        Positioned.fill(
                                          child: ValueListenableBuilder<
                                            Matrix4
                                          >(
                                            valueListenable:
                                                _transformationControllers[index]!,
                                            builder: (context, matrix, child) {
                                              final scale = _getCurrentScale(
                                                matrix,
                                              );
                                              return ShaderMask(
                                                shaderCallback: (Rect bounds) {
                                                  return LinearGradient(
                                                    begin: Alignment.center,
                                                    end: Alignment.topCenter,
                                                    colors: [
                                                      Colors.white,
                                                      Colors.white.withOpacity(
                                                        0.9,
                                                      ),
                                                    ],
                                                  ).createShader(bounds);
                                                },
                                                child: Transform.scale(
                                                  scale:
                                                      1.0 +
                                                      (scale - _minScale) * 0.1,
                                                  child: ImageFiltered(
                                                    imageFilter: ui
                                                        .ImageFilter.blur(
                                                      sigmaX: 15.0,
                                                      sigmaY: 15.0,
                                                    ),
                                                    child: Image.network(
                                                      availableImages[imageIndex],
                                                      fit: BoxFit.cover,
                                                      alignment:
                                                          Alignment.center,
                                                      errorBuilder:
                                                          (_, __, ___) =>
                                                              _buildFallbackImage(),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        // Main image with InteractiveViewer
                                        InteractiveViewer(
                                          transformationController:
                                              _transformationControllers[index],
                                          minScale: _minScale,
                                          maxScale: _maxScale,
                                          panEnabled: false,
                                          scaleEnabled: false,
                                          clipBehavior: Clip.none,
                                          child: AnimatedBuilder(
                                            animation: _kenBurnsController,
                                            builder: (context, child) {
                                              return !_isImageInteractionEnabled
                                                  ? Transform.scale(
                                                    scale:
                                                        _scaleAnimation.value,
                                                    child: Transform.translate(
                                                      offset: Offset(
                                                        _panAnimation.value.dx *
                                                            constraints
                                                                .maxWidth,
                                                        _panAnimation.value.dy *
                                                            constraints
                                                                .maxHeight,
                                                      ),
                                                      child: child,
                                                    ),
                                                  )
                                                  : child!;
                                            },
                                            child: Hero(
                                              tag:
                                                  'article-image-${article.id}-$imageIndex',
                                              child: Container(
                                                width: constraints.maxWidth,
                                                height: constraints.maxHeight,
                                                child: Image.network(
                                                  availableImages[imageIndex],
                                                  fit: BoxFit.cover,
                                                  alignment: Alignment.center,
                                                  errorBuilder:
                                                      (_, __, ___) =>
                                                          _buildFallbackImage(),
                                                  loadingBuilder: (
                                                    context,
                                                    child,
                                                    loadingProgress,
                                                  ) {
                                                    if (loadingProgress == null)
                                                      return child;
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
                                                        color: Colors.white,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
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
