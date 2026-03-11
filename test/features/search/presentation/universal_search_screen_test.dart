import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/customers/data/customer_repository.dart';
import 'package:deskflow/features/customers/domain/customer_providers.dart';
import 'package:deskflow/features/orders/data/order_repository.dart';
import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/orders/domain/order_providers.dart';
import 'package:deskflow/features/orders/domain/order_status.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';
import 'package:deskflow/features/products/data/product_repository.dart';
import 'package:deskflow/features/products/domain/product.dart';
import 'package:deskflow/features/products/domain/product_providers.dart';
import 'package:deskflow/features/search/data/search_history_repository.dart';
import 'package:deskflow/features/search/domain/search_history_entry.dart';
import 'package:deskflow/features/search/domain/search_providers.dart';
import 'package:deskflow/features/search/presentation/universal_search_screen.dart';

class _MockOrderRepository extends Mock implements OrderRepository {}

class _MockCustomerRepository extends Mock implements CustomerRepository {}

class _MockProductRepository extends Mock implements ProductRepository {}

class _MockSearchHistoryRepository extends Mock
    implements SearchHistoryRepository {}

class _TestCurrentOrgId extends CurrentOrgId {
  _TestCurrentOrgId(this._value);

  final String? _value;

  @override
  String? build() => _value;
}

User _makeUser() {
  return User(
    id: 'user-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime(2026, 3, 11).toIso8601String(),
    email: 'user@test.com',
  );
}

void main() {
  final now = DateTime(2026, 3, 11, 10);
  final order = Order(
    id: 'o1',
    organizationId: 'org-1',
    statusId: 'status-1',
    orderNumber: 17,
    totalAmount: 1500,
    createdBy: 'user-1',
    createdAt: now,
    updatedAt: now,
  );
  final customer = Customer(
    id: 'c1',
    organizationId: 'org-1',
    name: 'Иванов Иван',
    createdAt: now,
  );
  final product = Product(
    id: 'p1',
    organizationId: 'org-1',
    name: 'Виджет',
    price: 500,
    createdAt: now,
  );
  final historyEntry = SearchHistoryEntry(
    id: 'h1',
    userId: 'user-1',
    query: 'Иванов',
    normalizedQuery: 'иванов',
    createdAt: now.subtract(const Duration(days: 1)),
    lastUsedAt: now,
  );
  final extraHistory = List.generate(
    5,
    (index) => SearchHistoryEntry(
      id: 'hx$index',
      userId: 'user-1',
      query: 'Запрос $index',
      normalizedQuery: 'запрос $index',
      createdAt: now.subtract(Duration(days: index + 2)),
      lastUsedAt: now.subtract(Duration(hours: index + 1)),
    ),
  );
  const statuses = [
    OrderStatus(
      id: 'status-1',
      organizationId: 'org-1',
      name: 'Новый',
      color: '#3B82F6',
      sortOrder: 0,
      isDefault: true,
      isFinal: false,
    ),
    OrderStatus(
      id: 'status-2',
      organizationId: 'org-1',
      name: 'Доставка',
      color: '#06B6D4',
      sortOrder: 1,
      isDefault: false,
      isFinal: false,
    ),
  ];

  late _MockOrderRepository orderRepository;
  late _MockCustomerRepository customerRepository;
  late _MockProductRepository productRepository;
  late _MockSearchHistoryRepository searchHistoryRepository;

  setUp(() {
    orderRepository = _MockOrderRepository();
    customerRepository = _MockCustomerRepository();
    productRepository = _MockProductRepository();
    searchHistoryRepository = _MockSearchHistoryRepository();

    when(
      () => orderRepository.getPipeline('org-1'),
    ).thenAnswer((_) async => statuses);
    when(
      () => orderRepository.getOrders(orgId: 'org-1', limit: 20),
    ).thenAnswer((_) async => [order]);
    when(
      () => orderRepository.getOrders(
        orgId: 'org-1',
        statusId: 'status-1',
        limit: 20,
      ),
    ).thenAnswer((_) async => [order]);
    when(
      () => customerRepository.getCustomers(orgId: 'org-1', limit: 10),
    ).thenAnswer((_) async => [customer]);
    when(
      () => customerRepository.getCustomers(orgId: 'org-1', limit: 20),
    ).thenAnswer((_) async => [customer]);
    when(
      () => productRepository.getProducts(orgId: 'org-1', limit: 10),
    ).thenAnswer((_) async => [product]);
    when(
      () => productRepository.getProducts(orgId: 'org-1', limit: 20),
    ).thenAnswer((_) async => [product]);
    when(
      () => orderRepository.searchOrders(
        orgId: any(named: 'orgId'),
        query: any(named: 'query'),
        statusId: any(named: 'statusId'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => customerRepository.getCustomers(
        orgId: any(named: 'orgId'),
        search: any(named: 'search'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => productRepository.getProducts(
        orgId: any(named: 'orgId'),
        search: any(named: 'search'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => searchHistoryRepository.listRecent(userId: 'user-1'),
    ).thenAnswer((_) async => [historyEntry, ...extraHistory]);
    when(
      () => searchHistoryRepository.saveExecutedQuery(
        userId: any(named: 'userId'),
        query: any(named: 'query'),
      ),
    ).thenAnswer((_) async {});
  });

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        currentOrgIdProvider.overrideWith(() => _TestCurrentOrgId('org-1')),
        currentUserProvider.overrideWithValue(_makeUser()),
        orderRepositoryProvider.overrideWith((ref) => orderRepository),
        customerRepositoryProvider.overrideWith((ref) => customerRepository),
        productRepositoryProvider.overrideWith((ref) => productRepository),
        searchHistoryRepositoryProvider.overrideWith(
          (ref) => searchHistoryRepository,
        ),
      ],
      child: const MaterialApp(home: UniversalSearchScreen()),
    );
  }

  Future<void> enterQuery(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  testWidgets('browse mode shows history block below browse content', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search-browse-content')), findsOneWidget);
    expect(find.byKey(const Key('search-history-block')), findsOneWidget);

    final browseTop = tester
        .getTopLeft(find.byKey(const Key('search-browse-content')))
        .dy;
    final historyTop = tester
        .getTopLeft(find.byKey(const Key('search-history-block')))
        .dy;

    expect(historyTop, greaterThan(browseTop));
  });

  testWidgets('history block expands with Ещё', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Запрос 4'), findsNothing);

    await tester.tap(find.text('Ещё'));
    await tester.pumpAndSettle();

    expect(find.text('Запрос 4'), findsOneWidget);
  });

  testWidgets('tapping history row runs search and saves query', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('search-history-run-h1')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'Иванов');
    verify(
      () => searchHistoryRepository.saveExecutedQuery(
        userId: 'user-1',
        query: 'Иванов',
      ),
    ).called(greaterThanOrEqualTo(1));
  });

  testWidgets('history arrow inserts query text without saving', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('search-history-insert-h1')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'Иванов');
    verifyNever(
      () => searchHistoryRepository.saveExecutedQuery(
        userId: any(named: 'userId'),
        query: any(named: 'query'),
      ),
    );
  });

  testWidgets('status chips appear only in orders slice', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Новый'), findsNothing);

    await tester.tap(find.byKey(const Key('search-filter-orders')));
    await tester.pumpAndSettle();

    expect(find.text('Новый'), findsOneWidget);
    expect(find.text('Доставка'), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-filter-customers')));
    await tester.pumpAndSettle();

    expect(find.text('Новый'), findsNothing);
    expect(find.text('Доставка'), findsNothing);
  });

  testWidgets('clearing query keeps sticky orders filters selected', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('search-filter-orders')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Новый'));
    await tester.pumpAndSettle();

    await enterQuery(tester, 'Иванов');
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, isEmpty);
    expect(find.byKey(const Key('search-browse-content')), findsOneWidget);
    expect(find.text('Новый'), findsOneWidget);
    expect(find.text('Доставка'), findsOneWidget);
  });

  testWidgets(
    'typing alone does not save and no-results state appears until submit saves',
    (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await enterQuery(tester, 'zzz');

      expect(find.text('Ничего не найдено'), findsOneWidget);
      expect(
        find.text('Попробуйте изменить запрос или очистить фильтры'),
        findsOneWidget,
      );
      verifyNever(
        () => searchHistoryRepository.saveExecutedQuery(
          userId: any(named: 'userId'),
          query: any(named: 'query'),
        ),
      );

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      verify(
        () => searchHistoryRepository.saveExecutedQuery(
          userId: 'user-1',
          query: 'zzz',
        ),
      ).called(1);
    },
  );
}
