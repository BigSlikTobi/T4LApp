import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/ticker_slideshow_page.dart';
import 'package:app/services/supabase_service.dart';

class EmbeddedTickerSlideshow extends StatelessWidget {
  const EmbeddedTickerSlideshow({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isWeb = screenWidth > 600;

        // Calculate the width for each part
        final totalWidth = constraints.maxWidth;
        final middlePartWidth = isWeb ? totalWidth / 3 : totalWidth;
        final sidePartWidth = isWeb ? (totalWidth / 3).toDouble() : 0.0;

        Widget content = GestureDetector(
          onTap: () async {
            HapticFeedback.lightImpact();
            final tickers = await SupabaseService.getArticleTickers();

            if (context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TickerSlideshowPage(articles: tickers),
                ),
              );
            }
          },
          child: Container(
            width: middlePartWidth,
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
                    'assets/images/noHuddle.jpg',
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.cover,
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
                  // Headline text
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
                          ), // replaced: Colors.white.withOpacity(0.3)
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        "INSIDES FROM THE SIDELINE",
                        style: TextStyle(
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

        // If web, wrap content in Row with empty side containers
        if (isWeb) {
          content = Row(
            children: [
              SizedBox(width: sidePartWidth),
              content,
              SizedBox(width: sidePartWidth),
            ],
          );
        }

        return content;
      },
    );
  }
}
