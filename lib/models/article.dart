import 'package:app/utils/logger.dart';

class Article {
  final int id;
  final String englishHeadline;
  final String germanHeadline;
  final String englishArticle;
  final String germanArticle;
  final String? imageUrl;
  final DateTime? createdAt;
  final String? sourceAuthor;
  final String? team;
  final String? status;

  Article({
    required this.id,
    required this.englishHeadline,
    required this.germanHeadline,
    required this.englishArticle,
    required this.germanArticle,
    this.imageUrl,
    this.createdAt,
    this.sourceAuthor,
    this.team,
    this.status,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    int articleId = json['id'] is int ? json['id'] : (int.tryParse(json['id'].toString()) ?? 0);
    
    DateTime? dateTime;
    String? rawDate = json['createdAt']?.toString();
    AppLogger.debug('Article $articleId - Raw date value: $rawDate');
    
    if (rawDate != null) {
      try {
        dateTime = DateTime.parse(rawDate);
        AppLogger.debug('Successfully parsed date for article $articleId: $dateTime');
      } catch (e) {
        AppLogger.error('Error parsing date for article $articleId', e);
      }
    }

    return Article(
      id: articleId,
      englishHeadline: json['englishHeadline']?.toString() ?? '',
      germanHeadline: json['germanHeadline']?.toString() ?? '',
      englishArticle: json['ContentEnglish']?.toString() ?? '',
      germanArticle: json['ContentGerman']?.toString() ?? '',
      imageUrl: json['Image1']?.toString(),
      createdAt: dateTime,
      sourceAuthor: json['SourceName']?.toString(),
      team: json['teamId']?.toString(),
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'englishHeadline': englishHeadline,
      'germanHeadline': germanHeadline,
      'ContentEnglish': englishArticle,
      'ContentGerman': germanArticle,
      'Image1': imageUrl,
      'createdAt': createdAt?.toIso8601String(),
      'SourceName': sourceAuthor,
      'teamId': team,
      'status': status,
    };
  }
}
