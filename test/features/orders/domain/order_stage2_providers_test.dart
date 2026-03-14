import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/orders/data/order_repository.dart';
import 'package:deskflow/features/orders/domain/order_composition.dart';
import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/orders/domain/order_providers.dart';
import 'package:deskflow/features/orders/domain/order_template.dart';
import 'package:deskflow/features/orders/domain/orders_list_controls.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';
import 'package:deskflow/features/products/domain/product.dart';

class _MockOrderRepository extends Mock implements OrderRepository {}

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
    createdAt: DateTime(2026, 3, 10).toIso8601String(),
    email: 'user@test.com',
  );
}

void main() {
  late _MockOrderRepository repository;

  setUp(() {
    repository = _MockOrderRepository();
  });

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        orderRepositoryProvider.overrideWith((ref) => repository),
        currentOrgIdProvider.overrideWith(() => _TestCurrentOrgId('org-1')),
        currentUserProvider.overrideWithValue(_makeUser()),
      ],
    );
  }

  test('ordersListControlsProvider defaults to empty date/amount filters', () {
    final container = buildContainer();
    addTearDown(container.dispose);

    final controls = container.read(ordersListControlsProvider);

    expect(controls.periodPreset, OrdersPeriodPreset.all);
    expect(controls.selectedDate, isNull);
    expect(controls.selectedDateRange, isNull);
    expect(controls.amountRange, isNull);
  });

  test('orders list provider forwards selected date and amount range', () async {
    when(
      () => repository.getOrders(
        orgId: 'org-1',
        statusId: null,
        periodPreset: OrdersPeriodPreset.all,
        selectedDate: DateTime(2026, 3, 12),
        selectedDateRange: null,
        amountRange: const OrderAmountRange(min: 1000, max: 4000),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => []);

    final container = buildContainer();
    addTearDown(container.dispose);

    container.read(ordersListControlsProvider.notifier).state =
        OrdersListControls(
      selectedDate: DateTime(2026, 3, 12),
      amountRange: const OrderAmountRange(min: 1000, max: 4000),
    );

    await container.read(ordersListProvider(statusId: null).future);

    verify(
      () => repository.getOrders(
        orgId: 'org-1',
        statusId: null,
        periodPreset: OrdersPeriodPreset.all,
        selectedDate: DateTime(2026, 3, 12),
        selectedDateRange: null,
        amountRange: const OrderAmountRange(min: 1000, max: 4000),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).called(1);
  });

  test('orders list provider forwards selected period when date is empty', () async {
    when(
      () => repository.getOrders(
        orgId: 'org-1',
        statusId: null,
        periodPreset: OrdersPeriodPreset.last7Days,
        selectedDate: null,
        selectedDateRange: null,
        amountRange: null,
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => []);

    final container = buildContainer();
    addTearDown(container.dispose);

    container.read(ordersListControlsProvider.notifier).state =
        const OrdersListControls(
      periodPreset: OrdersPeriodPreset.last7Days,
    );

    await container.read(ordersListProvider(statusId: null).future);

    verify(
      () => repository.getOrders(
        orgId: 'org-1',
        statusId: null,
        periodPreset: OrdersPeriodPreset.last7Days,
        selectedDate: null,
        selectedDateRange: null,
        amountRange: null,
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).called(1);
  });

  test('orders list provider forwards selected date range', () async {
    final range = OrderDateRange(
      start: DateTime(2026, 3, 12),
      end: DateTime(2026, 3, 18),
    );

    when(
      () => repository.getOrders(
        orgId: 'org-1',
        statusId: null,
        periodPreset: OrdersPeriodPreset.all,
        selectedDate: null,
        selectedDateRange: range,
        amountRange: null,
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => []);

    final container = buildContainer();
    addTearDown(container.dispose);

    container.read(ordersListControlsProvider.notifier).state =
        OrdersListControls(
      selectedDateRange: range,
    );

    await container.read(ordersListProvider(statusId: null).future);

    verify(
      () => repository.getOrders(
        orgId: 'org-1',
        statusId: null,
        periodPreset: OrdersPeriodPreset.all,
        selectedDate: null,
        selectedDateRange: range,
        amountRange: null,
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).called(1);
  });

  test('orderTemplatesProvider returns org-scoped templates', () async {
    when(() => repository.getOrderTemplates(orgId: 'org-1')).thenAnswer(
      (_) async => [
        OrderTemplate(
          id: 'tpl-1',
          organizationId: 'org-1',
          name: 'Повторный заказ',
          createdAt: DateTime(2026, 3, 10),
          updatedAt: DateTime(2026, 3, 10),
          composition: const OrderComposition(),
        ),
      ],
    );

    final container = buildContainer();
    addTearDown(container.dispose);

    final templates = await container.read(orderTemplatesProvider.future);

    expect(templates, hasLength(1));
    expect(templates.single.name, 'Повторный заказ');
  });

  test('duplicateOrderCompositionProvider returns repository composition', () async {
    const composition = OrderComposition(
      items: [
        OrderCompositionItem(
          productId: 'prod-1',
          productName: 'Виджет А',
          unitPrice: 1000,
          quantity: 2,
        ),
      ],
    );

    when(
      () => repository.getDuplicateOrderComposition('order-1'),
    ).thenAnswer((_) async => composition);

    final container = buildContainer();
    addTearDown(container.dispose);

    final result = await container.read(
      duplicateOrderCompositionProvider('order-1').future,
    );

    expect(result.items, hasLength(1));
    expect(result.items.single.productName, 'Виджет А');
  });

  test('recentOrderCustomersProvider returns organization recent customers', () async {
    when(() => repository.getRecentCustomers(orgId: 'org-1')).thenAnswer(
      (_) async => [
        Customer(
          id: 'cust-1',
          organizationId: 'org-1',
          name: 'Иванов Иван',
          createdAt: DateTime(2026, 3, 10),
        ),
      ],
    );

    final container = buildContainer();
    addTearDown(container.dispose);

    final customers = await container.read(
      recentOrderCustomersProvider.future,
    );

    expect(customers, hasLength(1));
    expect(customers.single.name, 'Иванов Иван');
  });

  test('recentOrderProductsProvider returns organization recent products', () async {
    when(() => repository.getRecentProducts(orgId: 'org-1')).thenAnswer(
      (_) async => [
        Product(
          id: 'prod-1',
          organizationId: 'org-1',
          name: 'Виджет А',
          price: 1500,
          isActive: true,
          createdAt: DateTime(2026, 3, 10),
        ),
      ],
    );

    final container = buildContainer();
    addTearDown(container.dispose);

    final products = await container.read(
      recentOrderProductsProvider.future,
    );

    expect(products, hasLength(1));
    expect(products.single.name, 'Виджет А');
  });
}
