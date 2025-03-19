class ArticleVector {
  final int id;
  final List<double> embedding;
  final int sourceArticleId;
  final List<int> update;
  final List<int> related;
  final List<int>? identical;

  ArticleVector({
    required this.id,
    required this.embedding,
    required this.sourceArticleId,
    required this.update,
    required this.related,
    this.identical,
  });

  // Factory constructor to create ArticleVector from a Map (JSON)
  factory ArticleVector.fromJson(Map<String, dynamic> json) {
    // Parse embedding array from string if needed
    List<double> parseEmbedding(dynamic embeddingData) {
      if (embeddingData is String) {
        try {
          // Remove brackets and parse as list of doubles
          final String cleanString = embeddingData
              .replaceAll('[', '')
              .replaceAll(']', '')
              .replaceAll(' ', '');
          return cleanString
              .split(',')
              .where((s) => s.isNotEmpty)
              .map((s) => double.tryParse(s) ?? 0.0)
              .toList();
        } catch (e) {
          return [];
        }
      } else if (embeddingData is List) {
        return embeddingData
            .map((item) => item is num ? item.toDouble() : 0.0)
            .toList();
      }
      return [];
    }

    // Parse array of integers from various formats
    List<int> parseIntArray(dynamic arrayData) {
      if (arrayData == null) return [];

      if (arrayData is String) {
        try {
          // Try to parse as JSON string
          final String cleanString = arrayData
              .replaceAll('[', '')
              .replaceAll(']', '')
              .replaceAll(' ', '');
          return cleanString
              .split(',')
              .where((s) => s.isNotEmpty)
              .map((s) => int.tryParse(s) ?? 0)
              .toList();
        } catch (e) {
          return [];
        }
      } else if (arrayData is List) {
        return arrayData.map((item) => item is num ? item.toInt() : 0).toList();
      }
      return [];
    }

    return ArticleVector(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id'].toString()) ?? 0,
      embedding: parseEmbedding(json['embedding']),
      sourceArticleId:
          json['SourceArticle'] is int
              ? json['SourceArticle']
              : int.tryParse(json['SourceArticle']?.toString() ?? '0') ?? 0,
      update: parseIntArray(json['update']),
      related: parseIntArray(json['related']),
      identical: parseIntArray(json['identical']),
    );
  }

  // Convert to a Map (JSON)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'embedding': embedding,
      'SourceArticle': sourceArticleId,
      'update': update,
      'related': related,
      'identical': identical,
    };
  }
}
