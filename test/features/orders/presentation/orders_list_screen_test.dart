import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/orders/data/order_repository.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/orders/domain/order_providers.dart';
import 'package:deskflow/features/orders/domain/order_status.dart';
import 'package:deskflow/features/orders/domain/orders_list_controls.dart';
import 'package:deskflow/features/orders/presentation/orders_list_screen.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

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
  final sampleOrder = Order(
    id: 'order-1',
    organizationId: 'org-1',
    customerId: 'cust-1',
    statusId: 'status-1',
    orderNumber: 12,
    totalAmount: 1500,
    deliveryCost: 200,
    notes: 'Тест',
    createdBy: 'user-1',
    createdAt: DateTime(2026, 3, 10),
    updatedAt: DateTime(2026, 3, 10),
    status: const OrderStatus(
      id: 'status-1',
      organizationId: 'org-1',
      name: 'Новый',
      color: '#3B82F6',
      sortOrder: 0,
      isDefault: true,
      isFinal: false,
    ),
    customerName: 'Иван Иванов',
  );

  setUpAll(() {
    registerFallbackValue(OrdersPeriodPreset.all);
  });

  setUp(() {
    repository = _MockOrderRepository();

    when(() => repository.getPipeline('org-1')).thenAnswer(
      (_) async => [
        const OrderStatus(
          id: 'status-1',
          organizationId: 'org-1',
          name: 'Новый',
          color: '#3B82F6',
          sortOrder: 0,
          isDefault: true,
          isFinal: false,
        ),
      ],
    );

    when(
      () => repository.getOrders(
        orgId: 'org-1',
        statusId: any(named: 'statusId'),
        periodPreset: any(named: 'periodPreset'),
        selectedDate: any(named: 'selectedDate'),
        selectedDateRange: any(named: 'selectedDateRange'),
        amountRange: any(named: 'amountRange'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer(
      (_) async => [sampleOrder],
    );
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        orderRepositoryProvider.overrideWith((ref) => repository),
        currentOrgIdProvider.overrideWith(() => _TestCurrentOrgId('org-1')),
        currentUserProvider.overrideWithValue(_makeUser()),
      ],
      child: const MaterialApp(
        home: OrdersListScreen(),
      ),
    );
  }

  testWidgets('shows compact sort and period triggers', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Сортировка'), findsOneWidget);
    expect(find.text('Период'), findsOneWidget);
    expect(find.text('По дате'), findsOneWidget);
    expect(find.text('Все время'), findsOneWidget);
    expect(find.text('По сумме'), findsNothing);
  });

  testWidgets('opens contextual actions for order card', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Открыть заказ'), findsOneWidget);
    expect(find.text('Редактировать'), findsOneWidget);
    expect(find.text('Сменить статус'), findsOneWidget);
    expect(find.text('Дублировать'), findsOneWidget);
  });

  testWidgets('sort sheet reveals amount section on demand without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сортировка'));
    await tester.pumpAndSettle();
    expect(find.byType(ModalBarrier), findsAtLeastNWidgets(1));
    expect(find.text('Март 2026'), findsOneWidget);
    expect(find.byType(RangeSlider), findsNothing);
    await tester.ensureVisible(find.text('По сумме').last);
    await tester.tap(find.text('По сумме'));
    await tester.pumpAndSettle();

    expect(find.byType(RangeSlider), findsOneWidget);
    expect(find.text('Март 2026'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sort trigger opens dismissible bottom sheet with compact date section', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сортировка'));
    await tester.pumpAndSettle();

    expect(find.byType(ModalBarrier), findsAtLeastNWidgets(1));
    expect(find.text('Март 2026'), findsOneWidget);
    expect(find.text('По сумме'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left_rounded), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.chevron_right_rounded), findsAtLeastNWidgets(1));
    expect(find.byType(DatePickerDialog), findsNothing);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.text('Март 2026'), findsNothing);
  });

  testWidgets('sort sheet keeps По сумме visible without clipping on compact height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сортировка'));
    await tester.pumpAndSettle();

    final byAmount = find.text('По сумме').last;
    expect(byAmount, findsOneWidget);
    expect(tester.getBottomLeft(byAmount).dy, lessThan(560));
  });

  testWidgets('sort sheet keeps calendar compact on wide layouts', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сортировка'));
    await tester.pumpAndSettle();

    final calendar = find.byKey(const Key('orders-sort-calendar'));
    expect(calendar, findsOneWidget);
    expect(tester.getSize(calendar).width, lessThan(420));
  });

  testWidgets('sort sheet keeps amount toggle visible on short desktop height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1180, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сортировка'));
    await tester.pumpAndSettle();

    final byAmount = find.text('По сумме').last;
    expect(byAmount, findsOneWidget);
    expect(tester.getBottomLeft(byAmount).dy, lessThan(460));
  });

  testWidgets('sort sheet closes date section on repeated tap', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сортировка'));
    await tester.pumpAndSettle();

    expect(find.text('Март 2026'), findsOneWidget);

    await tester.tap(find.text('По дате').last);
    await tester.pumpAndSettle();

    expect(find.text('Март 2026'), findsNothing);
  });

  testWidgets('period trigger opens bottom sheet and selecting preset updates state', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Период'));
    await tester.pumpAndSettle();

    expect(find.byType(ModalBarrier), findsAtLeastNWidgets(1));
    await tester.tap(find.text('7 дней'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OrdersListScreen)),
    );
    final controls = container.read(ordersListControlsProvider);

    expect(controls.selectedDate, isNull);
    expect(controls.periodPreset, OrdersPeriodPreset.last7Days);
  });

  testWidgets('period sheet keeps 30 days option above bottom nav on compact height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Период'));
    await tester.pumpAndSettle();

    final last30Days = find.text('30 дней').last;
    expect(last30Days, findsOneWidget);
    expect(tester.getBottomLeft(last30Days).dy, lessThan(560));
  });
}
