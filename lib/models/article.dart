class Article {
  final int id;
  final String englishHeadline;
  final String germanHeadline;
  final String englishArticle;
  final String germanArticle;
  final String? imageUrl;
  final String? imageUrl2;
  final String? imageUrl3;
  final DateTime? createdAt;
  final String? sourceAuthor;
  final String? team;
  final String? status;
  final bool isUpdate; // Changed field name to isUpdate

  Article({
    required this.id,
    required this.englishHeadline,
    required this.germanHeadline,
    required this.englishArticle,
    required this.germanArticle,
    this.imageUrl,
    this.imageUrl2,
    this.imageUrl3,
    this.createdAt,
    this.sourceAuthor,
    this.team,
    this.status,
    this.isUpdate = false, // Updated parameter name
  });

  // Factory constructor to create an Article from a Map (JSON)
  factory Article.fromJson(Map<String, dynamic> json) {
    // Handle ID - can be int or String
    int articleId;
    if (json['id'] is int) {
      articleId = json['id'];
    } else if (json['id'] is String) {
      articleId = int.tryParse(json['id']) ?? 0;
    } else {
      articleId = 0; // Default ID if missing or invalid
    }

    // Safely handle all String fields
    String safeString(dynamic value) => value?.toString() ?? '';

    // Handle DateTime
    DateTime? dateTime;
    if (json['created_at'] != null) {
      try {
        dateTime = DateTime.parse(json['created_at'].toString());
      } catch (e) {
        dateTime = null;
      }
    }

    return Article(
      id: articleId,
      englishHeadline: safeString(json['headlineEnglish']),
      germanHeadline: safeString(json['headlineGerman']),
      englishArticle: safeString(json['ContentEnglish']),
      germanArticle: safeString(json['ContentGerman']),
      imageUrl: json['Image1']?.toString(),
      imageUrl2: json['Image2']?.toString(),
      imageUrl3: json['Image3']?.toString(),
      createdAt: dateTime,
      sourceAuthor: json['SourceArticle']?.toString(),
      team: json['team']?.toString(),
      status: null, // Status doesn't seem to be in the schema
      isUpdate: json['isUpdate'] == true, // Updated to use isUpdate field
    );
  }

  // Convert Article to a Map (JSON)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'headlineEnglish': englishHeadline,
      'headlineGerman': germanHeadline,
      'ContentEnglish': englishArticle,
      'ContentGerman': germanArticle,
      'Image1': imageUrl,
      'Image2': imageUrl2,
      'Image3': imageUrl3,
      'created_at': createdAt?.toIso8601String(),
      'SourceArticle': sourceAuthor,
      'team': team,
      'isUpdate': isUpdate, // Updated field name in JSON
    };
  }
}
