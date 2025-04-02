import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/ticker_slideshow_page.dart';
import 'package:app/models/article_ticker.dart';
import 'package:app/models/article.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';

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
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.currentLanguage == LanguageProvider.english;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Convert ArticleTicker to Article using toArticleJson
        final articles = teamArticles
            .map((ticker) => Article.fromJson(ticker.toArticleJson()))
            .toList();
            
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TickerSlideshowPage(articles: articles),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
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
              ),
              // Gradient overlay for better text readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: const [0.6, 1.0],
                    ),
                  ),
                ),
              ),
              // Latest article headline
              if (teamArticles.isNotEmpty) ...[
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
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isEnglish 
                        ? teamArticles.first.englishHeadline 
                        : teamArticles.first.germanHeadline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
              // Tap indicator icon
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
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
        ),
      ),
    );
  }
}