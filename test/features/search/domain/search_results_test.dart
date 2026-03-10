import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/products/domain/product.dart';
import 'package:deskflow/features/search/domain/search_providers.dart';

void main() {
  group('SearchResults', () {
    final now = DateTime(2025, 1, 15);

    final order = Order(
      id: 'o1',
      organizationId: 'org-1',
      statusId: 'st-1',
      orderNumber: 1,
      totalAmount: 1000,
      createdBy: 'u1',
      createdAt: now,
      updatedAt: now,
    );

    final customer = Customer(
      id: 'c1',
      organizationId: 'org-1',
      name: 'Тест',
      createdAt: now,
    );

    final product = Product(
      id: 'p1',
      organizationId: 'org-1',
      name: 'Товар',
      price: 500,
      createdAt: now,
    );

    test('empty constructor creates empty results', () {
      const results = SearchResults.empty();
      expect(results.isEmpty, true);
      expect(results.totalCount, 0);
      expect(results.orders, isEmpty);
      expect(results.customers, isEmpty);
      expect(results.products, isEmpty);
    });

    test('non-empty results has correct count', () {
      final results = SearchResults(
        orders: [order],
        customers: [customer, customer],
        products: [product],
      );

      expect(results.isEmpty, false);
      expect(results.totalCount, 4);
    });

    test('isEmpty is false with only orders', () {
      final results = SearchResults(
        orders: [order],
        customers: const [],
        products: const [],
      );

      expect(results.isEmpty, false);
    });

    test('isEmpty is false with only customers', () {
      final results = SearchResults(
        orders: const [],
        customers: [customer],
        products: const [],
      );

      expect(results.isEmpty, false);
    });
  });

  group('SearchFilter', () {
    test('has all expected values', () {
      expect(SearchFilter.values.length, 4);
      expect(SearchFilter.values, contains(SearchFilter.all));
      expect(SearchFilter.values, contains(SearchFilter.orders));
      expect(SearchFilter.values, contains(SearchFilter.customers));
      expect(SearchFilter.values, contains(SearchFilter.products));
    });
  });
}
