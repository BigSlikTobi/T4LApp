import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app/models/article.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';
import 'package:app/utils/logger.dart';

class NewsCard extends StatelessWidget {
  final Article article;
  final Function(int) onArticleClick;
  final String variant;

  const NewsCard({
    super.key,
    required this.article,
    required this.onArticleClick,
    this.variant = 'vertical',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.currentLanguage == LanguageProvider.english;
    final headline = isEnglish ? article.englishHeadline : article.germanHeadline;
    
    String formattedDate = 'No date';
    if (article.createdAt != null) {
      try {
        formattedDate = DateFormat(isEnglish ? 'MMM d, yyyy' : 'dd.MM.yyyy')
            .format(article.createdAt!);
        AppLogger.debug('Formatted date for article ${article.id}: $formattedDate');
      } catch (e) {
        AppLogger.error('Error formatting date for article ${article.id}', e);
      }
    } else {
      AppLogger.debug('No date available for article ${article.id}');
    }

    return Card(
      child: ListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formattedDate,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              headline,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        onTap: () => onArticleClick(article.id),
      ),
    );
  }
}
