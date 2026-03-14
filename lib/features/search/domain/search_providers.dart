import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:deskflow/core/providers/supabase_provider.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/customers/domain/customer_providers.dart';
import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/orders/domain/order_providers.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';
import 'package:deskflow/features/products/domain/product.dart';
import 'package:deskflow/features/products/domain/product_providers.dart';
import 'package:deskflow/features/search/data/search_history_repository.dart';
import 'package:deskflow/features/search/domain/search_controls.dart';
import 'package:deskflow/features/search/domain/search_history_entry.dart';

export 'package:deskflow/features/search/domain/search_controls.dart';

part 'search_providers.g.dart';

@Riverpod(keepAlive: true)
SearchHistoryRepository searchHistoryRepository(Ref ref) {
  return SearchHistoryRepository(ref.watch(supabaseClientProvider));
}

@riverpod
class SearchControlsNotifier extends _$SearchControlsNotifier {
  @override
  SearchControls build() => const SearchControls();

  void setQuery(String query) {
    state = state.withQuery(query);
  }

  void clearQuery() {
    state = state.withQuery('');
  }

  void switchEntityFilter(SearchFilter filter) {
    state = state.switchEntityFilter(filter);
  }

  void setOrderStatus(String? statusId) {
    state = state.setOrderStatus(statusId);
  }

  void setHistoryExpanded(bool expanded) {
    state = state.toggleHistoryExpanded(expanded);
  }

  void toggleHistoryExpanded() {
    state = state.toggleHistoryExpanded();
  }

  Future<void> saveExecutedQuery([String? query]) async {
    final user = ref.read(currentUserProvider);
    final queryToSave = normalizeSearchQuery(query ?? state.query);
    if (user == null || queryToSave.isEmpty) {
      return;
    }

    await ref
        .read(searchHistoryRepositoryProvider)
        .saveExecutedQuery(userId: user.id, query: queryToSave);
    ref.invalidate(searchHistoryProvider);
  }
}

final searchControlsProvider = searchControlsNotifierProvider;

@riverpod
Future<List<SearchHistoryEntry>> searchHistory(Ref ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return [];
  }

  return ref.watch(searchHistoryRepositoryProvider).listRecent(userId: user.id);
}

@riverpod
Future<SearchResults> browseCategory(Ref ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) {
    return const SearchResults.empty();
  }

  final filter = ref.watch(
    searchControlsProvider.select((value) => value.entityFilter),
  );
  final orderStatusId = ref.watch(
    searchControlsProvider.select(
      (value) => value.showsOrderStatusFilters ? value.orderStatusId : null,
    ),
  );
  final orderRepo = ref.watch(orderRepositoryProvider);
  final customerRepo = ref.watch(customerRepositoryProvider);
  final productRepo = ref.watch(productRepositoryProvider);

  switch (filter) {
    case SearchFilter.all:
      final results = await Future.wait([
        orderRepo.getOrders(orgId: orgId, limit: 20),
        customerRepo.getCustomers(orgId: orgId, limit: 10),
        productRepo.getProducts(orgId: orgId, limit: 10),
      ]);
      return SearchResults(
        orders: results[0] as List<Order>,
        customers: results[1] as List<Customer>,
        products: results[2] as List<Product>,
      );
    case SearchFilter.orders:
      final orders = await orderRepo.getOrders(
        orgId: orgId,
        statusId: orderStatusId,
        limit: 20,
      );
      return SearchResults(
        orders: orders,
        customers: const [],
        products: const [],
      );
    case SearchFilter.customers:
      final customers = await customerRepo.getCustomers(
        orgId: orgId,
        limit: 20,
      );
      return SearchResults(
        orders: const [],
        customers: customers,
        products: const [],
      );
    case SearchFilter.products:
      final products = await productRepo.getProducts(orgId: orgId, limit: 20);
      return SearchResults(
        orders: const [],
        customers: const [],
        products: products,
      );
  }
}

@riverpod
Future<SearchResults> universalSearch(Ref ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  final controls = ref.watch(searchControlsProvider);
  if (orgId == null || !controls.hasRunnableQuery) {
    return const SearchResults.empty();
  }

  final orderRepo = ref.watch(orderRepositoryProvider);
  final customerRepo = ref.watch(customerRepositoryProvider);
  final productRepo = ref.watch(productRepositoryProvider);
  final query = controls.query;

  switch (controls.entityFilter) {
    case SearchFilter.all:
      final results = await Future.wait([
        orderRepo.searchOrders(orgId: orgId, query: query),
        customerRepo.getCustomers(orgId: orgId, search: query, limit: 10),
        productRepo.getProducts(orgId: orgId, search: query, limit: 10),
      ]);
      return SearchResults(
        orders: results[0] as List<Order>,
        customers: results[1] as List<Customer>,
        products: results[2] as List<Product>,
      );
    case SearchFilter.orders:
      final orders = await orderRepo.searchOrders(
        orgId: orgId,
        query: query,
        statusId: controls.orderStatusId,
      );
      return SearchResults(
        orders: orders,
        customers: const [],
        products: const [],
      );
    case SearchFilter.customers:
      final customers = await customerRepo.getCustomers(
        orgId: orgId,
        search: query,
        limit: 10,
      );
      return SearchResults(
        orders: const [],
        customers: customers,
        products: const [],
      );
    case SearchFilter.products:
      final products = await productRepo.getProducts(
        orgId: orgId,
        search: query,
        limit: 10,
      );
      return SearchResults(
        orders: const [],
        customers: const [],
        products: products,
      );
  }
}

class SearchResults {
  final List<Order> orders;
  final List<Customer> customers;
  final List<Product> products;

  const SearchResults({
    required this.orders,
    required this.customers,
    required this.products,
  });

  const SearchResults.empty()
    : orders = const [],
      customers = const [],
      products = const [];

  bool get isEmpty => orders.isEmpty && customers.isEmpty && products.isEmpty;

  int get totalCount => orders.length + customers.length + products.length;
}
