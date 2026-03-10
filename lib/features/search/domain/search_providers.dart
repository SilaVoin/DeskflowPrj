import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:deskflow/core/providers/supabase_provider.dart';
import 'package:deskflow/features/customers/data/customer_repository.dart';
import 'package:deskflow/features/orders/data/order_repository.dart';
import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';
import 'package:deskflow/features/products/data/product_repository.dart';
import 'package:deskflow/features/products/domain/product.dart';

part 'search_providers.g.dart';

/// Search filter enum.
enum SearchFilter { all, orders, customers, products }

/// Browse a specific category without a search query.
///
/// Returns all items from the selected category (orders/customers/products).
/// Returns empty when [filter] is [SearchFilter.all].
@riverpod
Future<SearchResults> browseCategory(Ref ref, SearchFilter filter) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) {
    return const SearchResults.empty();
  }

  final client = ref.watch(supabaseClientProvider);
  final orderRepo = OrderRepository(client);
  final customerRepo = CustomerRepository(client);
  final productRepo = ProductRepository(client);

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
      final orders = await orderRepo.getOrders(orgId: orgId, limit: 20);
      return SearchResults(
        orders: orders,
        customers: const [],
        products: const [],
      );
    case SearchFilter.customers:
      final customers =
          await customerRepo.getCustomers(orgId: orgId, limit: 20);
      return SearchResults(
        orders: const [],
        customers: customers,
        products: const [],
      );
    case SearchFilter.products:
      final products =
          await productRepo.getProducts(orgId: orgId, limit: 20);
      return SearchResults(
        orders: const [],
        customers: const [],
        products: products,
      );
  }
}

/// Universal search results across orders, customers, and products.
@riverpod
Future<SearchResults> universalSearch(Ref ref, String query) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null || query.length < 2) {
    return const SearchResults.empty();
  }

  final client = ref.watch(supabaseClientProvider);
  final orderRepo = OrderRepository(client);
  final customerRepo = CustomerRepository(client);
  final productRepo = ProductRepository(client);

  // Run all searches in parallel
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
}

/// Universal search result container.
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
