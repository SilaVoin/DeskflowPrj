enum SearchFilter { all, orders, customers, products }

String normalizeSearchQuery(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

class SearchControls {
  final String query;
  final SearchFilter entityFilter;
  final String? orderStatusId;
  final bool isHistoryExpanded;

  const SearchControls({
    this.query = '',
    this.entityFilter = SearchFilter.all,
    this.orderStatusId,
    this.isHistoryExpanded = false,
  });

  bool get showsOrderStatusFilters => entityFilter == SearchFilter.orders;

  bool get hasRunnableQuery => query.length >= 2;

  SearchControls copyWith({
    String? query,
    SearchFilter? entityFilter,
    String? orderStatusId,
    bool clearOrderStatus = false,
    bool? isHistoryExpanded,
  }) {
    return SearchControls(
      query: query ?? this.query,
      entityFilter: entityFilter ?? this.entityFilter,
      orderStatusId: clearOrderStatus
          ? null
          : orderStatusId ?? this.orderStatusId,
      isHistoryExpanded: isHistoryExpanded ?? this.isHistoryExpanded,
    );
  }

  SearchControls withQuery(String value) {
    return copyWith(query: normalizeSearchQuery(value));
  }

  SearchControls switchEntityFilter(SearchFilter filter) {
    return copyWith(
      entityFilter: filter,
      clearOrderStatus: filter != SearchFilter.orders,
    );
  }

  SearchControls setOrderStatus(String? statusId) {
    if (!showsOrderStatusFilters) {
      return copyWith(clearOrderStatus: true);
    }

    final normalizedStatusId = normalizeSearchQuery(statusId ?? '');
    return copyWith(
      orderStatusId: normalizedStatusId.isEmpty ? null : normalizedStatusId,
    );
  }

  SearchControls toggleHistoryExpanded([bool? expanded]) {
    return copyWith(isHistoryExpanded: expanded ?? !isHistoryExpanded);
  }
}
