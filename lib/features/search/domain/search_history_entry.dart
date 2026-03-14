String normalizeSearchHistoryQuery(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String searchHistoryQueryKey(String value) {
  return normalizeSearchHistoryQuery(value).toLowerCase();
}

class SearchHistoryEntry {
  final String id;
  final String userId;
  final String query;
  final String normalizedQuery;
  final DateTime createdAt;
  final DateTime lastUsedAt;

  const SearchHistoryEntry({
    required this.id,
    required this.userId,
    required this.query,
    required this.normalizedQuery,
    required this.createdAt,
    required this.lastUsedAt,
  });

  factory SearchHistoryEntry.create({
    required String id,
    required String userId,
    required String query,
    required DateTime now,
  }) {
    final normalizedText = normalizeSearchHistoryQuery(query);
    if (normalizedText.isEmpty) {
      throw ArgumentError.value(query, 'query', 'Query cannot be empty');
    }

    return SearchHistoryEntry(
      id: id,
      userId: userId,
      query: normalizedText,
      normalizedQuery: normalizedText.toLowerCase(),
      createdAt: now,
      lastUsedAt: now,
    );
  }

  bool isMoreRecentThan(SearchHistoryEntry other) {
    return lastUsedAt.isAfter(other.lastUsedAt);
  }

  factory SearchHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SearchHistoryEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      query: (json['query_text'] ?? json['query'] ?? '') as String,
      normalizedQuery: json['normalized_query'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastUsedAt: DateTime.parse(json['last_used_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'query_text': query,
      'normalized_query': normalizedQuery,
      'created_at': createdAt.toIso8601String(),
      'last_used_at': lastUsedAt.toIso8601String(),
    };
  }
}
