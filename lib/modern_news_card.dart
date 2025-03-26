import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app/models/article.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';
import 'package:app/utils/logger.dart';
import 'package:app/news.dart'; // Import for teamMapping

class ModernNewsCard extends StatelessWidget {
  final Article article;
  final Function(int) onArticleClick;

  const ModernNewsCard({
    super.key,
    required this.article,
    required this.onArticleClick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish =
        languageProvider.currentLanguage == LanguageProvider.english;
    final isWeb = MediaQuery.of(context).size.width > 600;
    final headline =
        isEnglish ? article.englishHeadline : article.germanHeadline;

    String formattedDate = 'No date';
    if (article.createdAt != null) {
      try {
        formattedDate = DateFormat(
          isEnglish ? 'MMM d, yyyy' : 'dd.MM.yyyy',
        ).format(article.createdAt!);
      } catch (e) {
        AppLogger.error('Error formatting date for article ${article.id}', e);
      }
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: isWeb ? 1 : 2,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => onArticleClick(article.id),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardHeight = constraints.maxWidth * 0.3;
              return Container(
                constraints: BoxConstraints(
                  minHeight: 80,
                  maxHeight: isWeb ? 160 : 120,
                ),
                height: cardHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side - Image with status badge
                    Expanded(
                      flex: isWeb ? 3 : 1,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (article.imageUrl != null)
                            Image.network(
                              article.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                AppLogger.error(
                                  'Error loading article image: ${article.imageUrl}',
                                  error,
                                );
                                return Image.asset(
                                  'assets/images/placeholder.jpeg',
                                  fit: BoxFit.cover,
                                );
                              },
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
                                    color: theme.colorScheme.primary,
                                  ),
                                );
                              },
                            )
                          else
                            Image.asset(
                              'assets/images/placeholder.jpeg',
                              fit: BoxFit.cover,
                            ),
                          // Status badge overlay
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(article.status),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getStatusText(article.status, isEnglish),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Right side - Content
                    Expanded(
                      flex: isWeb ? 4 : 2,
                      child: Padding(
                        padding: EdgeInsets.all(isWeb ? 20.0 : 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (article.teamId != null)
                              Align(
                                alignment: Alignment.centerRight,
                                child: SizedBox(
                                  height: 16,
                                  child: Builder(
                                    builder: (context) {
                                      final teamId =
                                          article.teamId!.toUpperCase();
                                      if (!teamMapping.containsKey(teamId)) {
                                        AppLogger.error(
                                          'No team mapping found for teamId: $teamId',
                                        );
                                        return const SizedBox.shrink();
                                      }
                                      return Image.asset(
                                        'assets${teamMapping[teamId]!.logo}',
                                        fit: BoxFit.contain,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return const SizedBox.shrink();
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                headline ?? '',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  height: 1.3,
                                ),
                                maxLines: isWeb ? 3 : 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              formattedDate,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'new':
        return Colors.green;
      case 'update':
        return Colors.orange;
      case 'old':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status, bool isEnglish) {
    switch (status?.toLowerCase()) {
      case 'new':
        return isEnglish ? 'NEW' : 'NEU';
      case 'update':
        return 'UPDATE';
      case 'old':
        return isEnglish ? 'OLD' : 'ALT';
      default:
        return '';
    }
  }
}
