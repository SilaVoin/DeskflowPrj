class PaginatedList<T> {
  final List<T> items;
  final bool hasMore;
  final bool isLoadingMore;

  const PaginatedList({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  PaginatedList<T> copyWith({
    List<T>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return PaginatedList<T>(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}
