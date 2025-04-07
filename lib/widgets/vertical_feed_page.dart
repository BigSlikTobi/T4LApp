import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
// --- Make sure these paths are correct for your project structure ---
import 'package:app/models/article_ticker.dart';
import 'package:app/providers/language_provider.dart';
import 'package:app/utils/logger.dart';
import 'package:app/widgets/custom_app_bar.dart';
// --- End Project Specific Imports ---
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vector;
import 'dart:ui';
import 'package:flutter/gestures.dart';

const bool _debugVerticalFeed = false; // Set to true for helpful debug logging

class VerticalFeedPage extends StatefulWidget {
  final List<ArticleTicker> articles;

  const VerticalFeedPage({super.key, required this.articles});

  @override
  State<VerticalFeedPage> createState() => _VerticalFeedPageState();
}

class _VerticalFeedPageState extends State<VerticalFeedPage>
    with TickerProviderStateMixin {
  // --- Page View State ---
  late PageController _pageController;
  int _currentPage = 0;
  double _dragOffset = 0; // Tracks vertical drag for UI fades

  // --- Article & Image State ---
  late List<ArticleTicker> _articles;
  final Map<int, int> _articleImageIndices =
      {}; // Tracks current image index per article page

  // --- Image Interaction & Transformation State ---
  final Map<int, TransformationController> _transformationControllers = {};
  final double _minScale = 1.05; // Min zoom scale
  final double _maxScale = 3.0; // Max zoom scale
  final double _panResistance =
      2.5; // How much panning slows down when zoomed out
  bool _isImageInteractionEnabled =
      false; // Is user currently pinching/panning?
  Animation<Matrix4>? _animation; // For snap-back animation after interaction
  late final AnimationController
  _animationController; // Controller for snap-back

  // --- Ken Burns Effect State ---
  late AnimationController _kenBurnsController;
  late Animation<Offset> _panAnimation;
  late Animation<double> _scaleAnimation;
  final _random = math.Random(); // For randomizing Ken Burns start/end points

  // --- Image Transition State (within an article) ---
  Timer? _imageTransitionTimer; // Timer for auto-advancing images
  bool _isTransitioningImages = false; // Is fade/blur between images active?
  late AnimationController _blurAnimationController;
  late Animation<double> _blurAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late final AnimationController
  _imageTransitionController; // Controller for duration reference
  String? _previousImageUrl; // URL of the image fading out
  Matrix4? _previousTransform; // Transform state of the image fading out

  // --- UI Constants ---
  final EdgeInsets _imageBoundaryMargin = const EdgeInsets.all(
    100.0,
  ); // InteractiveViewer boundary margin
  final double _blurredBorderSize =
      50.0; // Visual size of the blurred edge area

  @override
  void initState() {
    super.initState();
    _articles = widget.articles;

    _pageController = PageController(
      viewportFraction: 1.0, // Each page takes full viewport height
      keepPage: true, // Keep state of adjacent pages loaded
    );

    // Initialize controllers for each article page
    for (var i = 0; i < _articles.length; i++) {
      _articleImageIndices[i] = 0; // Start each article at the first image
      _transformationControllers[i] =
          TransformationController(); // Controller for zoom/pan state
    }

    // Initialize Animation Controllers
    _kenBurnsController = AnimationController(
      duration: const Duration(
        seconds: 8,
      ), // Ken Burns cycle duration (Adjusted)
      vsync: this,
    );

    _animationController = AnimationController(
      // Snap-back animation
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _imageTransitionController = AnimationController(
      // Transition duration reference
      vsync: this,
      duration: const Duration(
        milliseconds: 350,
      ), // Faster transition (was 500)
    );

    // Blur animation controller (Faster transition)
    _blurAnimationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _blurAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      // Blur intensity tween
      CurvedAnimation(
        parent: _blurAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Fade animation controller (Faster transition)
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    )..addStatusListener((status) {
      // Listener for fade completion
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        if (mounted) {
          setState(() {
            // Clean up transition state
            _previousImageUrl = null;
            _previousTransform = null;
            _isTransitioningImages = false;
          });
          if (!_isImageInteractionEnabled) {
            // Restart Ken Burns if idle
            _resetAndStartKenBurns();
          }
        }
      }
    });

    _setupKenBurnsAnimation(); // Calculate initial Ken Burns parameters

    // Apply Ken Burns effect to the TransformationController when idle
    _kenBurnsController.addListener(_applyKenBurnsToController);

    // Start Ken Burns only if there are articles and the first one has images
    if (_articles.isNotEmpty && _getAvailableImages(_articles[0]).isNotEmpty) {
      _kenBurnsController.forward();
    }
    _startImageTransitionTimer(); // Start the timer for automatic image cycling

    if (_debugVerticalFeed) {
      AppLogger.debug(
        '[VerticalFeedPage] Initialized with ${_articles.length} articles',
      );
    }
  }

  // Applies the current Ken Burns transform to the active TransformationController
  void _applyKenBurnsToController() {
    // Apply transform only when idle (not interacting, not transitioning) and controller is animating
    if (mounted &&
        !_isImageInteractionEnabled &&
        !_isTransitioningImages &&
        _kenBurnsController.isAnimating) {
      // Ensure current page and controller exist
      if (_currentPage >= 0 &&
          _currentPage < _transformationControllers.length) {
        final controller = _transformationControllers[_currentPage];
        if (controller != null) {
          // Calculate the target matrix based on current Ken Burns animation values
          // Using MediaQuery for constraints here is a simplification.
          // A more robust solution might involve LayoutBuilder if precise constraints are critical.
          final size = MediaQuery.of(context).size;
          final constraints = BoxConstraints(
            maxWidth: size.width,
            maxHeight: size.height,
          );
          final targetMatrix = _calculateKenBurnsMatrix(constraints);

          // Directly update the TransformationController's value
          // InteractiveViewer listens to this controller and will redraw accordingly
          controller.value = targetMatrix;
        }
      }
    }
  }

  // Resets Ken Burns parameters and restarts the animation
  void _resetAndStartKenBurns() {
    // Ensure widget is mounted and current page has images before starting
    if (mounted &&
        _articles.isNotEmpty &&
        _currentPage >= 0 &&
        _currentPage < _articles.length &&
        _getAvailableImages(_articles[_currentPage]).isNotEmpty) {
      if (!_kenBurnsController.isAnimating) {
        // Avoid restarting if already running
        _kenBurnsController.reset();
        _setupKenBurnsAnimation(); // Recalculate random pan/zoom targets
        _kenBurnsController.forward();
        if (_debugVerticalFeed) {
          AppLogger.debug(
            '[VerticalFeedPage] Ken Burns restarted for page $_currentPage',
          );
        }
      }
    } else if (_debugVerticalFeed) {
      AppLogger.debug(
        '[VerticalFeedPage] Ken Burns NOT restarted (mounted: $mounted, no images, invalid page, or controller issue)',
      );
    }
  }

  // Sets up random start/end points for Ken Burns pan and scale
  void _setupKenBurnsAnimation() {
    _kenBurnsController.stop(); // Stop previous animation

    // Define Ken Burns scale range (Adjusted for visibility)
    final startScale = 1.1;
    final endScale = 1.3;
    final maxTranslation = (endScale - 1.0) / 3.0; // Panning amount
    final safeMaxTranslation = maxTranslation + 0.03;

    Offset startOffset, endOffset;
    // Ensure start and end offsets are somewhat different for noticeable movement
    do {
      startOffset = Offset(
        _random.nextDouble() * safeMaxTranslation * 2 - safeMaxTranslation,
        _random.nextDouble() * safeMaxTranslation * 2 - safeMaxTranslation,
      );
      endOffset = Offset(
        _random.nextDouble() * safeMaxTranslation * 2 - safeMaxTranslation,
        _random.nextDouble() * safeMaxTranslation * 2 - safeMaxTranslation,
      );
    } while ((startOffset - endOffset).distanceSquared <
        0.01); // Check distance

    // Create tween animations for pan (offset) and scale
    _panAnimation = Tween<Offset>(begin: startOffset, end: endOffset).animate(
      CurvedAnimation(parent: _kenBurnsController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: startScale, end: endScale).animate(
      CurvedAnimation(parent: _kenBurnsController, curve: Curves.easeInOut),
    );

    // Set up listener for animation completion (for looping)
    _kenBurnsController.removeStatusListener(
      _kenBurnsStatusListener,
    ); // Clean up old listener
    _kenBurnsController.addStatusListener(
      _kenBurnsStatusListener,
    ); // Add new listener
    if (_debugVerticalFeed) {
      AppLogger.debug(
        '[VerticalFeedPage] Ken Burns setup complete. Start Scale: $startScale, End Scale: $endScale, Start Pan: $startOffset, End Pan: $endOffset',
      );
    }
  }

  // Listens to Ken Burns animation status (handles looping)
  void _kenBurnsStatusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (_debugVerticalFeed) {
        AppLogger.debug('[VerticalFeedPage] Ken Burns completed.');
      }
      // Loop only if widget is mounted and not interacting or transitioning images
      if (mounted && !_isImageInteractionEnabled && !_isTransitioningImages) {
        if (_debugVerticalFeed) {
          AppLogger.debug('[VerticalFeedPage] Ken Burns looping.');
        }
        _resetAndStartKenBurns(); // Restart the animation cycle
      } else if (_debugVerticalFeed) {
        AppLogger.debug(
          '[VerticalFeedPage] Ken Burns loop skipped (mounted: $mounted, interacting: $_isImageInteractionEnabled, transitioning: $_isTransitioningImages)',
        );
      }
    }
  }

  @override
  void dispose() {
    // Remove Ken Burns listener before disposing controller
    _kenBurnsController.removeListener(_applyKenBurnsToController);

    // Dispose all controllers and timers
    _blurAnimationController.dispose();
    _fadeController.dispose();
    _pageController.dispose();
    for (var controller in _transformationControllers.values) {
      controller.dispose();
    }
    _kenBurnsController.removeStatusListener(_kenBurnsStatusListener);
    _kenBurnsController.dispose();
    _animationController.dispose();
    _imageTransitionController.dispose();
    _imageTransitionTimer?.cancel();
    super.dispose();
  }

  // Starts or restarts the timer for automatic image transitions within an article
  void _startImageTransitionTimer() {
    _imageTransitionTimer?.cancel(); // Ensure no duplicate timers
    if (_debugVerticalFeed) {
      AppLogger.debug('[VerticalFeedPage] Starting image transition timer.');
    }
    _imageTransitionTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // Timer interval
      if (_debugVerticalFeed) {
        AppLogger.debug(
          '[VerticalFeedPage] Timer tick. Interacting: $_isImageInteractionEnabled, Transitioning: $_isTransitioningImages, Mounted: $mounted, CurrentPage: $_currentPage',
        );
      }

      // Check conditions before attempting transition
      if (mounted && !_isImageInteractionEnabled && !_isTransitioningImages) {
        // Validate current page index
        if (_currentPage < 0 || _currentPage >= _articles.length) {
          if (_debugVerticalFeed) {
            AppLogger.debug(
              '[VerticalFeedPage] Timer tick skipped: Invalid currentPage $_currentPage',
            );
          }
          _imageTransitionTimer?.cancel(); // Stop timer if state is invalid
          return;
        }
        final currentArticle = _articles[_currentPage];
        final images = _getAvailableImages(currentArticle);
        if (_debugVerticalFeed) {
          AppLogger.debug(
            '[VerticalFeedPage] Timer check passed for page $_currentPage. Images available: ${images.length}',
          );
        }

        // Only transition if there's more than one image
        if (images.length > 1) {
          final currentIndex = _articleImageIndices[_currentPage] ?? 0;
          // Validate current image index
          if (currentIndex < 0 || currentIndex >= images.length) {
            if (_debugVerticalFeed) {
              AppLogger.debug(
                '[VerticalFeedPage] Timer tick skipped: Invalid currentIndex $currentIndex for images length ${images.length}',
              );
            }
            _articleImageIndices[_currentPage] = 0; // Reset index if invalid
            return; // Skip transition this tick
          }

          final nextIndex =
              (currentIndex + 1) % images.length; // Cycle through images

          if (_debugVerticalFeed) {
            AppLogger.debug(
              '[VerticalFeedPage] Transitioning images for article ${currentArticle.id} (Page $_currentPage) from $currentIndex to $nextIndex',
            );
          }

          // Prepare state for the visual transition
          setState(() {
            _isTransitioningImages = true; // Mark transition as active
            _previousImageUrl =
                images[currentIndex]; // Store outgoing image URL
            // Capture current transform safely
            _previousTransform =
                _transformationControllers[_currentPage]?.value != null
                    ? Matrix4.copy(
                      _transformationControllers[_currentPage]!.value,
                    )
                    : Matrix4.identity();
            if (_debugVerticalFeed) {
              AppLogger.debug(
                '[VerticalFeedPage] Stopping Ken Burns for transition.',
              );
            }
            if (mounted) {
              _kenBurnsController.stop(); // Stop Ken Burns during transition
            }
          });

          // Start fade and blur animations
          if (mounted) {
            _blurAnimationController.forward(from: 0.0);
            _fadeController.forward(from: 0.0);
          }

          // Update image index and reset transform for the *new* image
          if (mounted) {
            setState(() {
              _articleImageIndices[_currentPage] = nextIndex;
              _transformationControllers[_currentPage]?.value =
                  Matrix4.identity(); // Start new image fresh
              if (_debugVerticalFeed) {
                AppLogger.debug(
                  '[VerticalFeedPage] Image index for page $_currentPage updated to $nextIndex. Transform reset.',
                );
              }
            });
          }

          // Schedule the blur animation reversal after the *faster* transition duration
          Future.delayed(const Duration(milliseconds: 350), () {
            // Match faster controller duration
            if (mounted) {
              // Check mounted again before animation call
              _blurAnimationController.reverse();
            }
          });
        } else if (_debugVerticalFeed) {
          AppLogger.debug(
            '[VerticalFeedPage] Not enough images (${images.length}) on page $_currentPage to transition.',
          );
        }
      } else if (_debugVerticalFeed) {
        AppLogger.debug(
          '[VerticalFeedPage] Timer check failed or not mounted.',
        );
      }
    });
  }

  // Called by PageView when the user swipes to a different page
  void _onPageChanged(int page) {
    HapticFeedback.lightImpact();
    final previousPage = _currentPage;
    if (_debugVerticalFeed) {
      AppLogger.debug(
        '[VerticalFeedPage] Page changed from $previousPage to $page',
      );
    }

    _imageTransitionTimer?.cancel();
    _isTransitioningImages = false;
    if (mounted) {
      _fadeController.reset();
      _blurAnimationController.reset();
      _kenBurnsController.stop();
    }
    _previousImageUrl = null;
    _previousTransform = null;

    if (!_transformationControllers.containsKey(page)) {
      _transformationControllers[page] = TransformationController();
    }
    _transformationControllers[page]?.value = Matrix4.identity();

    setState(() {
      _currentPage = page;
      _dragOffset = 0;
      if (!_articleImageIndices.containsKey(page)) {
        _articleImageIndices[page] = 0;
      }
      _isImageInteractionEnabled = false;
    });

    if (page >= 0 &&
        page < _articles.length &&
        _getAvailableImages(_articles[page]).isNotEmpty) {
      _resetAndStartKenBurns();
    }
    _startImageTransitionTimer();
    if (_debugVerticalFeed) {
      /* ... logging ... */
    }
  }

  // Called when user starts scaling/panning the image
  void _onInteractionStart(ScaleStartDetails details, int articleIndex) {
    if (_isTransitioningImages) return;
    if (_debugVerticalFeed) {
      AppLogger.debug(
        '[VerticalFeedPage] Interaction Start on page $articleIndex',
      );
    }

    if (mounted) {
      _kenBurnsController.stop();
      _animationController.stop();
    } // Stop animations
    _imageTransitionTimer?.cancel(); // Stop timer
    _isImageInteractionEnabled = true; // Set flag

    // Clean up previous snap-back animation
    _animation?.removeListener(() => _onAnimateTransform(articleIndex));
    _animation?.removeStatusListener(_onAnimationStatusChange);
    _animation = null;

    if (mounted) setState(() {});
  }

  // Called continuously while user is scaling/panning
  void _onInteractionUpdate(ScaleUpdateDetails details, int articleIndex) {
    if (!_isImageInteractionEnabled || _isTransitioningImages) return;
    final controller = _transformationControllers[articleIndex];
    if (controller == null) return;
    final Matrix4 matrix = Matrix4.copy(controller.value);
    final size = MediaQuery.of(context).size;
    // Scale logic
    final currentScale = _getCurrentScale(matrix);
    final scaleDelta = details.scale.clamp(0.5, 2.0);
    final nextScale = currentScale * scaleDelta;
    final scale = nextScale.clamp(_minScale, _maxScale);
    final scaleFactor = (currentScale > 0.001) ? scale / currentScale : 1.0;
    final focalPoint = details.localFocalPoint;
    matrix.translate(focalPoint.dx, focalPoint.dy);
    matrix.scale(scaleFactor, scaleFactor);
    matrix.translate(-focalPoint.dx, -focalPoint.dy);
    // Pan logic with resistance
    final resistanceFactor =
        1.0 +
        (_panResistance *
            (1 - ((scale - _minScale) / (_maxScale - _minScale))));
    final effectiveResistance = math.max(1.0, resistanceFactor);
    final adjustedDelta = Offset(
      details.focalPointDelta.dx / effectiveResistance,
      details.focalPointDelta.dy / effectiveResistance,
    );
    final currentTranslation = matrix.getTranslation();
    final translationVec = vector.Vector3(
      currentTranslation.x,
      currentTranslation.y,
      0.0,
    );
    final maxOverpanX =
        (size.width * (scale - 1.0)) / 2.0 + (_blurredBorderSize * 1.5);
    final maxOverpanY =
        (size.height * (scale - 1.0)) / 2.0 + (_blurredBorderSize * 1.5);
    final newX = (translationVec.x + adjustedDelta.dx).clamp(
      -maxOverpanX,
      maxOverpanX,
    );
    final newY = (translationVec.y + adjustedDelta.dy).clamp(
      -maxOverpanY,
      maxOverpanY,
    );
    matrix.setTranslation(vector.Vector3(newX, newY, 0.0));
    controller.value = matrix; // Update controller
  }

  // Called when user ends scaling/panning interaction
  void _onInteractionEnd(ScaleEndDetails details, int articleIndex) {
    if (!_isImageInteractionEnabled) return;
    if (_debugVerticalFeed) {
      AppLogger.debug(
        '[VerticalFeedPage] Interaction End on page $articleIndex',
      );
    }
    _isImageInteractionEnabled = false; // Reset flag
    if (mounted) setState(() {});

    // Snap-back logic
    final controller = _transformationControllers[articleIndex];
    if (controller == null) {
      _startImageTransitionTimer();
      return;
    }
    final Matrix4 matrix = Matrix4.copy(controller.value);
    final currentScale = _getCurrentScale(matrix);
    final size = MediaQuery.of(context).size;
    Matrix4 targetMatrix = Matrix4.copy(matrix);
    bool needsAnimation = false;
    // Check scale
    double targetScale = currentScale.clamp(_minScale, _maxScale);
    if ((targetScale - currentScale).abs() > 0.01) {
      final center = Offset(size.width / 2, size.height / 2);
      targetMatrix =
          Matrix4.identity()
            ..translate(center.dx, center.dy)
            ..scale(targetScale, targetScale)
            ..translate(-center.dx, -center.dy)
            ..translate(matrix.getTranslation().x, matrix.getTranslation().y);
      needsAnimation = true;
    }
    // Check translation
    final finalScale = targetScale;
    final maxSnapBackX = (size.width * (finalScale - 1.0)) / 2.0;
    final maxSnapBackY = (size.height * (finalScale - 1.0)) / 2.0;
    final currentTranslation = targetMatrix.getTranslation();
    final clampedX = currentTranslation.x.clamp(-maxSnapBackX, maxSnapBackX);
    final clampedY = currentTranslation.y.clamp(-maxSnapBackY, maxSnapBackY);
    if ((currentTranslation.x - clampedX).abs() > 0.1 ||
        (currentTranslation.y - clampedY).abs() > 0.1) {
      targetMatrix.setTranslation(vector.Vector3(clampedX, clampedY, 0.0));
      needsAnimation = true;
    }

    // Execute animation or restart effects
    if (needsAnimation) {
      _animateMatrix(targetMatrix, articleIndex);
    } else {
      if (!_isTransitioningImages) {
        _resetAndStartKenBurns();
      }
      _startImageTransitionTimer();
    }
  }

  // Helper to calculate the current scale factor from a Matrix4
  double _getCurrentScale(Matrix4 matrix) {
    return vector.Vector3(matrix.row0.x, matrix.row0.y, matrix.row0.z).length;
  }

  // Animates the TransformationController value smoothly to a target matrix state
  void _animateMatrix(Matrix4 end, int articleIndex) {
    final controller = _transformationControllers[articleIndex];
    if (controller == null) return;
    _animation?.removeListener(() => _onAnimateTransform(articleIndex));
    _animation?.removeStatusListener(_onAnimationStatusChange);
    _animation = null;
    _animation = Matrix4Tween(begin: controller.value, end: end).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animation!.addListener(() => _onAnimateTransform(articleIndex));
    _animation!.addStatusListener(_onAnimationStatusChange);
    if (mounted) {
      _animationController.forward(from: 0);
    }
  }

  // Listener called when the snap-back animation status changes
  void _onAnimationStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      final finishedAnimation = _animation;
      _animation = null;
      if (!mounted) {
        finishedAnimation?.removeListener(
          () => _onAnimateTransform(_currentPage),
        );
        finishedAnimation?.removeStatusListener(_onAnimationStatusChange);
        return;
      }
      finishedAnimation?.removeListener(
        () => _onAnimateTransform(_currentPage),
      );
      finishedAnimation?.removeStatusListener(_onAnimationStatusChange);
      if (!_isImageInteractionEnabled && !_isTransitioningImages) {
        _resetAndStartKenBurns();
        _startImageTransitionTimer();
      }
    }
  }

  // Listener called each frame during snap-back animation to update controller
  void _onAnimateTransform(int articleIndex) {
    if (mounted && _animation != null && _animationController.isAnimating) {
      final controller = _transformationControllers[articleIndex];
      if (controller != null) {
        if (_animation != null) {
          controller.value = _animation!.value;
        }
      } else {
        if (mounted) _animationController.stop();
        _onAnimationStatusChange(AnimationStatus.dismissed);
      }
    } else if (_animationController.isAnimating) {
      if (mounted) _animationController.stop();
      _onAnimationStatusChange(AnimationStatus.dismissed);
    }
  }

  // Formats a date string into a displayable format
  String _formatDate(String? dateInput, bool isEnglish) {
    if (dateInput == null) return isEnglish ? 'No date' : 'Kein Datum';
    try {
      final date = DateTime.parse(dateInput);
      final locale = isEnglish ? 'en_US' : 'de_DE';
      final format = DateFormat('MMM d, yyyy', locale);
      return format.format(date);
    } catch (e) {
      AppLogger.error(
        '[VerticalFeedPage] Error formatting date: $dateInput',
        e,
      );
      return isEnglish ? 'Invalid date' : 'Ungültiges Datum';
    }
  }

  // Retrieves a list of valid, non-empty image URLs for a given article
  List<String> _getAvailableImages(ArticleTicker article) {
    final images = <String>[];
    if (article.image1 != null && article.image1!.isNotEmpty) {
      images.add(article.image1!);
    }
    if (article.image2 != null && article.image2!.isNotEmpty) {
      images.add(article.image2!);
    }
    if (article.image3 != null && article.image3!.isNotEmpty) {
      images.add(article.image3!);
    }
    return images;
  }

  // Builds the layered image widget: blurred background + sharp foreground with faded edges
  Widget _buildImageWithBlurredEdges({
    required String imageUrl,
    required BoxConstraints constraints,
    Widget? child,
    Matrix4? transform, // Static transform for background or previous image
  }) {
    // --- Blur amount and fade radius (Adjusted) ---
    const double blurBackgroundScale = 1.15;
    const double blurSigma = 10.0;
    const double fadeEdgeStartRadius = 0.8;

    final List<double> fadeStops = [0.0, fadeEdgeStartRadius, 1.0];
    final List<Color> fadeColors = [
      Colors.white,
      Colors.white,
      Colors.transparent,
    ];

    // Core image widget
    Widget imageContent =
        child ??
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => _buildFallbackImage(),
          loadingBuilder: (context, imgChild, loadingProgress) {
            if (loadingProgress == null) return imgChild;
            return Center(
              child: CircularProgressIndicator(
                value:
                    loadingProgress.expectedTotalBytes != null
                        ? (loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!)
                            .toDouble()
                        : null,
                color: Colors.white.withOpacity(0.7),
                strokeWidth: 2.0,
              ),
            );
          },
        );

    // Apply static transform if provided
    if (transform != null) {
      imageContent = Transform(
        transform: transform,
        alignment: Alignment.center,
        child: imageContent,
      );
    }

    // Build the layered widget
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        // Layer 1: Blurred Background
        Positioned.fill(
          left: -_blurredBorderSize * 1.5,
          right: -_blurredBorderSize * 1.5,
          top: -_blurredBorderSize * 1.5,
          bottom: -_blurredBorderSize * 1.5,
          child: Transform.scale(
            scale: blurBackgroundScale,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
              ),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => Container(color: Colors.black),
              ),
            ),
          ),
        ),
        // Layer 2: Sharp Foreground with Faded Edges
        Positioned.fill(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (Rect bounds) {
              return RadialGradient(
                center: Alignment.center,
                radius: fadeEdgeStartRadius,
                colors: fadeColors,
                stops: fadeStops,
                tileMode: TileMode.clamp,
              ).createShader(bounds);
            },
            child: imageContent,
          ),
        ),
      ],
    );
  }

  // --- Build Method: Constructs the main UI ---
  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish =
        languageProvider.currentLanguage == LanguageProvider.english;
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final isWeb = screenSize.width > 600;
    final bottomSafeArea =
        MediaQuery.of(context).padding.bottom; // Get bottom safe area inset

    // Fallback UI if no articles
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

    // Main page structure
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true, // Content behind AppBar
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: AnimatedOpacity(
            opacity:
                _dragOffset < 20 && !_isImageInteractionEnabled ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: const CustomAppBar(),
          ),
        ),
        body: NotificationListener<ScrollNotification>(
          // Listen for scroll offset
          onNotification: (notification) {
            if (!_isImageInteractionEnabled && _pageController.hasClients) {
              final metrics = notification.metrics;
              if (notification.depth == 0 && metrics is PageMetrics) {
                if (notification is ScrollUpdateNotification) {
                  final double pixelsRelativeToPage =
                      metrics.pixels -
                      (metrics.page?.floorToDouble() ?? 0.0) *
                          metrics.viewportDimension;
                  if ((metrics.page?.round() ?? -1) == _currentPage) {
                    final newOffset = pixelsRelativeToPage.abs();
                    if ((newOffset - _dragOffset).abs() > 1.0) {
                      if (mounted) setState(() => _dragOffset = newOffset);
                    }
                  } else {
                    if (_dragOffset != 0) {
                      if (mounted) setState(() => _dragOffset = 0);
                    }
                  }
                } else if (notification is ScrollEndNotification) {
                  if (_dragOffset != 0) {
                    if (mounted) setState(() => _dragOffset = 0);
                  }
                }
              }
            }
            return false;
          },
          child: PageView.builder(
            // Vertical pages
            physics:
                _isImageInteractionEnabled || _isTransitioningImages
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
            scrollDirection: Axis.vertical,
            controller: _pageController,
            itemCount: _articles.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              // Build each page
              final article = _articles[index];
              final availableImages = _getAvailableImages(article);
              final currentImageIndex = _articleImageIndices[index] ?? 0;
              final currentImageUrl =
                  availableImages.isNotEmpty &&
                          currentImageIndex < availableImages.length
                      ? availableImages[currentImageIndex]
                      : null;

              return Container(
                // Page container
                color: Colors.black,
                child: ClipRect(
                  // Clip content
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // --- Image Layers ---
                      if (currentImageUrl != null)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // Calculate background transform (static or Ken Burns)
                            Matrix4 backgroundTransform =
                                _calculateKenBurnsMatrix(
                                  constraints,
                                ); // Use helper
                            // If interacting or transitioning, use the controller's value instead of Ken Burns
                            if (_isImageInteractionEnabled ||
                                _isTransitioningImages) {
                              final currentController =
                                  _transformationControllers[index];
                              backgroundTransform =
                                  currentController?.value ??
                                  Matrix4.identity();
                            }

                            // Build image stack
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                // Background Layer
                                if (_previousImageUrl != null &&
                                    index == _currentPage)
                                  FadeTransition(
                                    opacity: ReverseAnimation(_fadeAnimation),
                                    child: _buildImageWithBlurredEdges(
                                      imageUrl: _previousImageUrl!,
                                      constraints: constraints,
                                      transform: _previousTransform,
                                    ),
                                  )
                                else
                                  _buildImageWithBlurredEdges(
                                    imageUrl: currentImageUrl,
                                    constraints: constraints,
                                    transform: backgroundTransform,
                                  ),
                                // Foreground Layer (InteractiveViewer's content updates via controller listener)
                                FadeTransition(
                                  opacity:
                                      _isTransitioningImages &&
                                              index == _currentPage
                                          ? _fadeAnimation
                                          : const AlwaysStoppedAnimation(1.0),
                                  child: GestureDetector(
                                    onScaleStart:
                                        (d) => _onInteractionStart(d, index),
                                    onScaleUpdate:
                                        (d) => _onInteractionUpdate(d, index),
                                    onScaleEnd:
                                        (d) => _onInteractionEnd(d, index),
                                    child: InteractiveViewer(
                                      transformationController:
                                          _transformationControllers[index], // Controller updated by Ken Burns listener
                                      minScale: _minScale,
                                      maxScale: _maxScale,
                                      panEnabled: true,
                                      scaleEnabled: true,
                                      boundaryMargin: _imageBoundaryMargin,
                                      clipBehavior: Clip.none,
                                      onInteractionStart: null,
                                      onInteractionUpdate: null,
                                      onInteractionEnd: null,
                                      child: _buildImageWithBlurredEdges(
                                        imageUrl: currentImageUrl,
                                        constraints: constraints,
                                        child: Hero(
                                          tag:
                                              'article-image-${article.id}-$currentImageIndex',
                                          child: Image.network(
                                            currentImageUrl,
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
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return const Center(
                                                child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2.0,
                                                        color: Colors.white54,
                                                      ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Blur Overlay (During transitions)
                                if (_isTransitioningImages &&
                                    index == _currentPage)
                                  Positioned.fill(
                                    child: AnimatedBuilder(
                                      animation: _blurAnimation,
                                      builder:
                                          (context, child) => BackdropFilter(
                                            filter: ImageFilter.blur(
                                              sigmaX: _blurAnimation.value,
                                              sigmaY: _blurAnimation.value,
                                            ),
                                            child: Container(
                                              color: Colors.transparent,
                                            ),
                                          ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        )
                      else
                        _buildFallbackImage(), // Fallback if no image
                      // --- Content Overlay Layer (Stack Layout) ---
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring:
                              _isImageInteractionEnabled, // Ignore pointer events during interaction
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Gradient Layer
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                height:
                                    screenSize.height * 0.6, // Gradient height
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.5),
                                        Colors.black.withOpacity(0.95),
                                      ],
                                      stops: const [0.0, 0.4, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              // Text Content Layer
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: 16.0,
                                    right: 16.0,
                                    bottom: bottomSafeArea + 16.0,
                                  ), // Padding + Safe Area
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // --- Text Content Widgets ---
                                      if (article.teamId != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 16.0,
                                          ),
                                          child: Hero(
                                            tag: 'team-logo-${article.id}',
                                            child: Image.asset(
                                              'assets/logos/${article.teamId!.toLowerCase()}.png',
                                              height: isWeb ? 40 : 30,
                                              errorBuilder:
                                                  (_, __, ___) =>
                                                      const SizedBox.shrink(),
                                            ),
                                          ),
                                        ),
                                      Text(
                                        isEnglish
                                            ? article.englishHeadline
                                            : article.germanHeadline,
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              shadows: const [
                                                Shadow(
                                                  color: Colors.black54,
                                                  offset: Offset(0, 1),
                                                  blurRadius: 2,
                                                ),
                                              ],
                                            ),
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          color: Colors.black.withOpacity(0.3),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _formatDate(
                                                article.createdAt,
                                                isEnglish,
                                              ),
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: Colors.white70,
                                                  ),
                                            ),
                                            if (article.sourceName != null)
                                              Text(
                                                article.sourceName!,
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        isEnglish
                                            ? article.summaryEnglish
                                            : article.summaryGerman,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              color: Colors.white.withOpacity(
                                                0.9,
                                              ),
                                              height: 1.5,
                                              shadows: const [
                                                Shadow(
                                                  color: Colors.black87,
                                                  offset: Offset(0, 1),
                                                  blurRadius: 1,
                                                ),
                                              ],
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // --- Swipe Indicator ---
                      if (!_isImageInteractionEnabled &&
                          _dragOffset < 50 &&
                          _currentPage < _articles.length - 1)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom:
                              20 + bottomSafeArea, // Position above safe area
                          child: IgnorePointer(
                            child: AnimatedOpacity(
                              opacity:
                                  (_dragOffset < 10 &&
                                          !_isImageInteractionEnabled)
                                      ? 1.0
                                      : 0.0,
                              duration: const Duration(milliseconds: 150),
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
                                      ),
                                      Text(
                                        '${_currentPage + 1}/${_articles.length}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: Colors.white.withOpacity(
                                                0.9,
                                              ),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Helper calculates the target Matrix4 for Ken Burns based on current animation values
  Matrix4 _calculateKenBurnsMatrix(BoxConstraints constraints) {
    final scale =
        _kenBurnsController.isAnimating
            ? _scaleAnimation.value
            : 1.05; // Use start scale if not animating
    final offset =
        _kenBurnsController.isAnimating ? _panAnimation.value : Offset.zero;

    final matrix = Matrix4.identity();
    if (constraints.hasBoundedWidth && constraints.hasBoundedHeight) {
      final center = Offset(
        constraints.maxWidth / 2,
        constraints.maxHeight / 2,
      );
      matrix.translate(center.dx, center.dy);
      matrix.scale(scale, scale);
      matrix.translate(-center.dx, -center.dy);
      matrix.translate(
        offset.dx * constraints.maxWidth,
        offset.dy * constraints.maxHeight,
      );
    }
    return matrix;
  }

  // Builds a fallback widget for missing/failed images
  Widget _buildFallbackImage() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Icon(Icons.sports_soccer, size: 60, color: Colors.grey[700]),
      ),
    );
  }
}
