import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:deskflow/features/orders/data/order_repository.dart';
import 'package:deskflow/features/orders/domain/order_composition.dart';
import 'package:deskflow/features/orders/domain/orders_list_controls.dart';
import '../../../helpers/supabase_fakes.dart';

void main() {
  late MockSupabaseClient mockClient;
  late OrderRepository repo;

  setUp(() {
    mockClient = MockSupabaseClient();
    repo = OrderRepository(mockClient);
  });


  group('getPipeline', () {
    test('returns parsed OrderStatus list', () async {
      final fakeData = [
        {
          'id': 'st-1',
          'organization_id': 'org-1',
          'name': 'Новый',
          'color': '#3B82F6',
          'sort_order': 0,
          'is_default': true,
          'is_final': false,
        },
        {
          'id': 'st-2',
          'organization_id': 'org-1',
          'name': 'В работе',
          'color': '#F59E0B',
          'sort_order': 1,
          'is_default': false,
          'is_final': false,
        },
      ];

      when(
        () => mockClient.from('order_statuses'),
      ).thenAnswer((_) => FakeQueryBuilder(fakeData));

      final result = await repo.getPipeline('org-1');

      expect(result.length, 2);
      expect(result[0].name, 'Новый');
      expect(result[0].isDefault, true);
      expect(result[1].name, 'В работе');
      expect(result[1].sortOrder, 1);
    });

    test('returns empty list when no statuses', () async {
      when(
        () => mockClient.from('order_statuses'),
      ).thenAnswer((_) => FakeQueryBuilder(<Map<String, dynamic>>[]));

      final result = await repo.getPipeline('org-1');
      expect(result, isEmpty);
    });
  });


  group('getDefaultStatus', () {
    test('returns single default status', () async {
      final fakeData = {
        'id': 'st-1',
        'organization_id': 'org-1',
        'name': 'Новый',
        'color': '#3B82F6',
        'sort_order': 0,
        'is_default': true,
        'is_final': false,
      };

      when(
        () => mockClient.from('order_statuses'),
      ).thenAnswer((_) => FakeQueryBuilder([fakeData]));

      final result = await repo.getDefaultStatus('org-1');

      expect(result.id, 'st-1');
      expect(result.name, 'Новый');
      expect(result.isDefault, true);
    });
  });


  group('getOrders', () {
    final sampleOrderJson = {
      'id': 'ord-1',
      'organization_id': 'org-1',
      'customer_id': 'cust-1',
      'status_id': 'st-1',
      'order_number': 42,
      'total_amount': 5000.0,
      'delivery_cost': 500.0,
      'notes': null,
      'created_by': 'user-1',
      'created_at': '2026-01-15T00:00:00.000',
      'updated_at': '2026-01-15T00:00:00.000',
      'order_statuses': {
        'id': 'st-1',
        'organization_id': 'org-1',
        'name': 'Новый',
        'color': '#3B82F6',
        'sort_order': 0,
        'is_default': true,
        'is_final': false,
      },
      'customers': {'name': 'Иванов Иван'},
    };

    test('returns parsed orders list', () async {
      when(
        () => mockClient.from('orders'),
      ).thenAnswer((_) => FakeQueryBuilder([sampleOrderJson]));

      final result = await repo.getOrders(orgId: 'org-1');

      expect(result.length, 1);
      expect(result.first.id, 'ord-1');
      expect(result.first.orderNumber, 42);
      expect(result.first.totalAmount, 5000.0);
      expect(result.first.customerName, 'Иванов Иван');
      expect(result.first.status?.name, 'Новый');
    });

    test('returns empty list when no orders', () async {
      when(
        () => mockClient.from('orders'),
      ).thenAnswer((_) => FakeQueryBuilder(<Map<String, dynamic>>[]));

      final result = await repo.getOrders(orgId: 'org-1');
      expect(result, isEmpty);
    });

    test('accepts exact-date and amount-range filters while returning parsed orders', () async {
      when(
        () => mockClient.from('orders'),
      ).thenAnswer((_) => FakeQueryBuilder([sampleOrderJson]));

      final result = await repo.getOrders(
        orgId: 'org-1',
        periodPreset: OrdersPeriodPreset.all,
        selectedDate: DateTime(2026, 3, 12),
        selectedDateRange: null,
        amountRange: const OrderAmountRange(min: 1000, max: 7000),
      );

      expect(result.length, 1);
      expect(result.first.id, 'ord-1');
    });

    test('orders stay sorted by created_at descending', () async {
      final builder = RecordingQueryBuilder([sampleOrderJson]);
      when(() => mockClient.from('orders')).thenAnswer((_) => builder);

      await repo.getOrders(orgId: 'org-1');

      final orderInvocations = builder.invocations
          .where((invocation) => invocation.memberName == #order)
          .toList();

      expect(orderInvocations, isNotEmpty);
      expect(
        orderInvocations.any(
          (invocation) => invocation.positionalArguments.first == 'created_at',
        ),
        isTrue,
      );
    });

    test('selected date sends UTC day boundaries to backend', () async {
      final builder = RecordingQueryBuilder([sampleOrderJson]);
      when(() => mockClient.from('orders')).thenAnswer((_) => builder);

      await repo.getOrders(
        orgId: 'org-1',
        periodPreset: OrdersPeriodPreset.all,
        selectedDate: DateTime(2026, 3, 12, 14, 30),
        selectedDateRange: null,
      );

      final gteInvocation = builder.invocations.firstWhere(
        (invocation) => invocation.memberName == #gte,
      );
      final ltInvocation = builder.invocations.firstWhere(
        (invocation) => invocation.memberName == #lt,
      );
      final startBoundary = gteInvocation.positionalArguments[1] as String;
      final endBoundary = ltInvocation.positionalArguments[1] as String;

      expect(startBoundary.endsWith('Z'), isTrue);
      expect(endBoundary.endsWith('Z'), isTrue);
    });

    test('amount range sends gte and lte boundaries to backend', () async {
      final builder = RecordingQueryBuilder([sampleOrderJson]);
      when(() => mockClient.from('orders')).thenAnswer((_) => builder);

      await repo.getOrders(
        orgId: 'org-1',
        periodPreset: OrdersPeriodPreset.all,
        selectedDateRange: null,
        amountRange: const OrderAmountRange(min: 2000, max: 9000),
      );

      expect(
        builder.invocations.any(
          (invocation) =>
              invocation.memberName == #gte &&
              invocation.positionalArguments.first == 'total_amount',
        ),
        isTrue,
      );
      expect(
        builder.invocations.any(
          (invocation) =>
              invocation.memberName == #lte &&
              invocation.positionalArguments.first == 'total_amount',
        ),
        isTrue,
      );
    });

    test('period preset sends trailing UTC boundaries to backend', () async {
      final builder = RecordingQueryBuilder([sampleOrderJson]);
      when(() => mockClient.from('orders')).thenAnswer((_) => builder);

      await repo.getOrders(
        orgId: 'org-1',
        periodPreset: OrdersPeriodPreset.last7Days,
        selectedDateRange: null,
      );

      final gteInvocation = builder.invocations.firstWhere(
        (invocation) => invocation.memberName == #gte,
      );
      final ltInvocation = builder.invocations.firstWhere(
        (invocation) => invocation.memberName == #lt,
      );

      expect(gteInvocation.positionalArguments.first, 'created_at');
      expect(ltInvocation.positionalArguments.first, 'created_at');
      expect(
        (gteInvocation.positionalArguments[1] as String).endsWith('Z'),
        isTrue,
      );
      expect(
        (ltInvocation.positionalArguments[1] as String).endsWith('Z'),
        isTrue,
      );
    });

    test('selected date range sends inclusive UTC window to backend', () async {
      final builder = RecordingQueryBuilder([sampleOrderJson]);
      when(() => mockClient.from('orders')).thenAnswer((_) => builder);

      await repo.getOrders(
        orgId: 'org-1',
        periodPreset: OrdersPeriodPreset.all,
        selectedDateRange: OrderDateRange(
          start: DateTime(2026, 3, 12),
          end: DateTime(2026, 3, 18),
        ),
      );

      final gteInvocation = builder.invocations.firstWhere(
        (invocation) => invocation.memberName == #gte,
      );
      final ltInvocation = builder.invocations.firstWhere(
        (invocation) => invocation.memberName == #lt,
      );
      final startBoundary =
          DateTime.parse(gteInvocation.positionalArguments[1] as String);
      final endBoundary =
          DateTime.parse(ltInvocation.positionalArguments[1] as String);

      expect(gteInvocation.positionalArguments.first, 'created_at');
      expect(ltInvocation.positionalArguments.first, 'created_at');
      expect(startBoundary.isUtc, isTrue);
      expect(endBoundary.isUtc, isTrue);
      expect(endBoundary.difference(startBoundary), const Duration(days: 7));
    });
  });


  group('getOrder', () {
    test('returns single parsed order with items', () async {
      final fakeData = [
        {
          'id': 'ord-1',
          'organization_id': 'org-1',
          'customer_id': 'cust-1',
          'status_id': 'st-1',
          'order_number': 7,
          'total_amount': 3000.0,
          'delivery_cost': 0.0,
          'notes': 'Тестовый заказ',
          'created_by': 'user-1',
          'created_at': '2026-02-01T12:00:00.000',
          'updated_at': '2026-02-01T12:00:00.000',
          'order_statuses': {
            'id': 'st-1',
            'organization_id': 'org-1',
            'name': 'Готов',
            'color': '#10B981',
            'sort_order': 2,
            'is_default': false,
            'is_final': true,
          },
          'customers': {
            'name': 'Петров Пётр',
            'phone': '+79001234567',
            'email': 'petrov@test.com',
          },
          'order_items': [
            {
              'id': 'item-1',
              'order_id': 'ord-1',
              'product_id': 'prod-1',
              'product_name': 'Виджет А',
              'unit_price': 1000.0,
              'quantity': 3,
              'created_at': '2026-02-01T12:00:00.000',
            },
          ],
        },
      ];

      when(
        () => mockClient.from('orders'),
      ).thenAnswer((_) => FakeQueryBuilder(fakeData));

      final order = await repo.getOrder('ord-1');

      expect(order.id, 'ord-1');
      expect(order.notes, 'Тестовый заказ');
      expect(order.status?.name, 'Готов');
      expect(order.status?.isFinal, true);
      expect(order.customerName, 'Петров Пётр');
      expect(order.items.length, 1);
      expect(order.items.first.productName, 'Виджет А');
      expect(order.items.first.quantity, 3);
    });
  });


  group('searchOrders', () {
    test('returns matching orders', () async {
      final orderJson = {
        'id': 'ord-5',
        'organization_id': 'org-1',
        'customer_id': null,
        'status_id': 'st-1',
        'order_number': 5,
        'total_amount': 1500.0,
        'delivery_cost': 0.0,
        'notes': 'Срочная доставка',
        'created_by': 'user-1',
        'created_at': '2026-03-01T00:00:00.000',
        'updated_at': '2026-03-01T00:00:00.000',
        'order_statuses': {
          'id': 'st-1',
          'organization_id': 'org-1',
          'name': 'Новый',
          'color': '#3B82F6',
          'sort_order': 0,
          'is_default': true,
          'is_final': false,
        },
        'customers': {'name': null},
      };

      when(
        () => mockClient.from('customers'),
      ).thenAnswer((_) => FakeQueryBuilder(<Map<String, dynamic>>[]));
      when(
        () => mockClient.from('orders'),
      ).thenAnswer((_) => FakeQueryBuilder([orderJson]));

      final result = await repo.searchOrders(orgId: 'org-1', query: 'Срочная');

      expect(result.length, 1);
      expect(result.first.notes, 'Срочная доставка');
    });

    test('applies status filter when provided', () async {
      final ordersBuilder = RecordingQueryBuilder(<Map<String, dynamic>>[]);

      when(
        () => mockClient.from('customers'),
      ).thenAnswer((_) => FakeQueryBuilder(<Map<String, dynamic>>[]));
      when(() => mockClient.from('orders')).thenAnswer((_) => ordersBuilder);

      await repo.searchOrders(
        orgId: 'org-1',
        query: 'Срочная',
        statusId: 'st-1',
      );

      expect(
        ordersBuilder.invocations.any(
          (invocation) =>
              invocation.memberName == #eq &&
              invocation.positionalArguments[0] == 'status_id' &&
              invocation.positionalArguments[1] == 'st-1',
        ),
        true,
      );
    });
  });


  group('searchCustomers', () {
    test('returns matching customers', () async {
      final customerJson = {
        'id': 'cust-1',
        'organization_id': 'org-1',
        'name': 'Иванов Иван',
        'phone': '+79001111111',
        'email': 'ivanov@test.com',
        'address': 'Москва',
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      };

      when(
        () => mockClient.from('customers'),
      ).thenAnswer((_) => FakeQueryBuilder([customerJson]));

      final result = await repo.searchCustomers(
        orgId: 'org-1',
        query: 'Иванов',
      );

      expect(result.length, 1);
      expect(result.first.name, 'Иванов Иван');
      expect(result.first.phone, '+79001111111');
    });
  });


  group('getOrderAuditLog', () {
    test('returns parsed audit events', () async {
      final auditJson = {
        'id': 'ae-1',
        'organization_id': 'org-1',
        'entity_type': 'order',
        'entity_id': 'ord-1',
        'action': 'order_created',
        'user_id': 'user-1',
        'old_value': null,
        'new_value': {'order_number': 1},
        'created_at': '2026-01-01T00:00:00.000',
        'profiles': {'full_name': 'Admin User'},
      };

      when(
        () => mockClient.from('audit_events'),
      ).thenAnswer((_) => FakeQueryBuilder([auditJson]));

      final result = await repo.getOrderAuditLog('ord-1');

      expect(result.length, 1);
      expect(result.first.action, 'order_created');
      expect(result.first.userName, 'Admin User');
    });
  });


  group('templates', () {
    test('fetches organization templates', () async {
      final templateJson = {
        'id': 'tpl-1',
        'organization_id': 'org-1',
        'name': 'Повторный заказ',
        'created_at': '2026-03-10T00:00:00.000',
        'updated_at': '2026-03-10T00:00:00.000',
        'items': [
          {
            'product_id': 'prod-1',
            'product_name': 'Виджет А',
            'unit_price': 1000.0,
            'quantity': 2,
          },
        ],
      };

      when(
        () => mockClient.from('order_templates'),
      ).thenAnswer((_) => FakeQueryBuilder([templateJson]));

      final result = await repo.getOrderTemplates(orgId: 'org-1');

      expect(result, hasLength(1));
      expect(result.first.name, 'Повторный заказ');
      expect(result.first.composition.items.single.productName, 'Виджет А');
    });

    test('saves template and returns parsed entity', () async {
      final templateJson = {
        'id': 'tpl-1',
        'organization_id': 'org-1',
        'name': 'Шаблон',
        'created_at': '2026-03-10T00:00:00.000',
        'updated_at': '2026-03-10T00:00:00.000',
        'items': [
          {
            'product_id': 'prod-1',
            'product_name': 'Виджет А',
            'unit_price': 1000.0,
            'quantity': 2,
          },
        ],
      };

      when(
        () => mockClient.from('order_templates'),
      ).thenAnswer((_) => FakeQueryBuilder([templateJson]));

      final result = await repo.saveOrderTemplate(
        orgId: 'org-1',
        name: 'Шаблон',
        composition: const OrderComposition(
          items: [
            OrderCompositionItem(
              productId: 'prod-1',
              productName: 'Виджет А',
              unitPrice: 1000,
              quantity: 2,
            ),
          ],
        ),
      );

      expect(result.id, 'tpl-1');
      expect(result.name, 'Шаблон');
    });

    test('deletes template without throwing', () async {
      when(
        () => mockClient.from('order_templates'),
      ).thenAnswer((_) => FakeQueryBuilder(<Map<String, dynamic>>[]));

      await repo.deleteOrderTemplate('tpl-1');
    });
  });

  group('recents', () {
    test(
      'fetches recent customers from latest orders and deduplicates them',
      () async {
        final recentOrders = [
          {
            'customer_id': 'cust-1',
            'customers': {
              'id': 'cust-1',
              'organization_id': 'org-1',
              'name': 'Иванов Иван',
              'phone': '+79001111111',
              'created_at': '2026-03-10T00:00:00.000',
            },
          },
          {
            'customer_id': 'cust-1',
            'customers': {
              'id': 'cust-1',
              'organization_id': 'org-1',
              'name': 'Иванов Иван',
              'phone': '+79001111111',
              'created_at': '2026-03-09T00:00:00.000',
            },
          },
          {
            'customer_id': 'cust-2',
            'customers': {
              'id': 'cust-2',
              'organization_id': 'org-1',
              'name': 'Петров Пётр',
              'phone': '+79002222222',
              'created_at': '2026-03-08T00:00:00.000',
            },
          },
        ];

        when(
          () => mockClient.from('orders'),
        ).thenAnswer((_) => FakeQueryBuilder(recentOrders));

        final result = await repo.getRecentCustomers(orgId: 'org-1');

        expect(result, hasLength(2));
        expect(result.first.name, 'Иванов Иван');
        expect(result.last.name, 'Петров Пётр');
      },
    );

    test(
      'fetches recent products from latest order items and deduplicates them',
      () async {
        final recentOrders = [
          {
            'order_items': [
              {
                'product_id': 'prod-1',
                'products': {
                  'id': 'prod-1',
                  'organization_id': 'org-1',
                  'name': 'Виджет А',
                  'price': 1000.0,
                  'is_active': true,
                  'created_at': '2026-03-10T00:00:00.000',
                },
              },
              {
                'product_id': 'prod-1',
                'products': {
                  'id': 'prod-1',
                  'organization_id': 'org-1',
                  'name': 'Виджет А',
                  'price': 1000.0,
                  'is_active': true,
                  'created_at': '2026-03-10T00:00:00.000',
                },
              },
            ],
          },
          {
            'order_items': [
              {
                'product_id': 'prod-2',
                'products': {
                  'id': 'prod-2',
                  'organization_id': 'org-1',
                  'name': 'Гаджет Б',
                  'price': 2500.0,
                  'is_active': true,
                  'created_at': '2026-03-09T00:00:00.000',
                },
              },
            ],
          },
        ];

        when(
          () => mockClient.from('orders'),
        ).thenAnswer((_) => FakeQueryBuilder(recentOrders));

        final result = await repo.getRecentProducts(orgId: 'org-1');

        expect(result, hasLength(2));
        expect(result.first.name, 'Виджет А');
        expect(result.last.name, 'Гаджет Б');
      },
    );
  });

  group('duplicate order', () {
    test(
      'loads duplicate composition from existing order items only',
      () async {
        final fakeData = [
          {
            'id': 'ord-1',
            'organization_id': 'org-1',
            'customer_id': 'cust-1',
            'status_id': 'st-1',
            'order_number': 7,
            'total_amount': 3000.0,
            'delivery_cost': 100.0,
            'notes': 'Не копировать как обязательное поле',
            'created_by': 'user-1',
            'created_at': '2026-02-01T12:00:00.000',
            'updated_at': '2026-02-01T12:00:00.000',
            'order_statuses': null,
            'customers': {'name': 'Петров Пётр'},
            'order_items': [
              {
                'id': 'item-1',
                'order_id': 'ord-1',
                'product_id': 'prod-1',
                'product_name': 'Виджет А',
                'unit_price': 1000.0,
                'quantity': 3,
                'created_at': '2026-02-01T12:00:00.000',
              },
            ],
          },
        ];

        when(
          () => mockClient.from('orders'),
        ).thenAnswer((_) => FakeQueryBuilder(fakeData));

        final composition = await repo.getDuplicateOrderComposition('ord-1');

        expect(composition.items, hasLength(1));
        expect(composition.items.single.productName, 'Виджет А');
        expect(composition.items.single.quantity, 3);
      },
    );
  });
}
