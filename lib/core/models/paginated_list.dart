/// Generic wrapper for paginated list data.
///
/// Used by list providers that support infinite scroll.
class PaginatedList<T> {
  final List<T> items;

  /// Whether the server may have more items beyond what is loaded.
  final bool hasMore;

  /// True while a subsequent page is being fetched.
  final bool isLoadingMore;

  const PaginatedList({
    required this.items,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  PaginatedList<T> copyWith({
    List<T>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) =>
      PaginatedList(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      );
}
