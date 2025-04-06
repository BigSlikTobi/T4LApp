import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/ticker_slideshow_page.dart';
import 'package:app/models/article_ticker.dart';
import 'package:app/utils/logger.dart';

// Global debug toggle for TeamArticlesSlideshow
const bool _enableTeamArticlesSlideshowDebug = false;

class TeamArticlesSlideshow extends StatelessWidget {
  final List<ArticleTicker> teamArticles;
  final String backgroundImage;

  const TeamArticlesSlideshow({
    super.key,
    required this.teamArticles,
    this.backgroundImage = 'assets/images/noHuddle.jpg',
  });

  @override
  Widget build(BuildContext context) {
    if (_enableTeamArticlesSlideshowDebug) {
      AppLogger.debug(
        '[TeamArticlesSlideshow] Building widget with ${teamArticles.length} articles',
      );
    }

    return GestureDetector(
      onTap: () {
        if (teamArticles.isEmpty) {
          if (_enableTeamArticlesSlideshowDebug) {
            AppLogger.debug(
              '[TeamArticlesSlideshow] Attempted to open empty articles list',
            );
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No team articles available'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        HapticFeedback.lightImpact();
        if (_enableTeamArticlesSlideshowDebug) {
          AppLogger.debug(
            '[TeamArticlesSlideshow] Navigating to TickerSlideshowPage with ${teamArticles.length} articles',
          );
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TickerSlideshowPage(articles: teamArticles),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.2),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Image background
              Image.asset(
                backgroundImage,
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  if (_enableTeamArticlesSlideshowDebug) {
                    AppLogger.debug(
                      '[TeamArticlesSlideshow] Error loading background image: $error',
                    );
                  }
                  AppLogger.error(
                    '[TeamArticlesSlideshow] Error loading background image: $error',
                    stackTrace,
                  );
                  return Container(
                    height: 300,
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.image_not_supported,
                      size: 50,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color.fromRGBO(0, 0, 0, 0.7),
                      ],
                      stops: const [0.6, 1.0],
                    ),
                  ),
                ),
              ),
              // Content box
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(0, 0, 0, 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Color.fromRGBO(
                        255,
                        255,
                        255,
                        0.3,
                      ), // replaced Colors.white.withOpacity(0.3)
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'INSIDES FROM THE LOCKER ROOM',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (teamArticles.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${teamArticles.length} articles available',
                          style: TextStyle(
                            color: Color.fromRGBO(
                              255,
                              255,
                              255,
                              0.7,
                            ), // replaced Colors.white.withOpacity(0.7)
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Tap indicator icon
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(0, 0, 0, 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    teamArticles.isEmpty
                        ? Icons.error_outline
                        : Icons.touch_app,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
