import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:deskflow/features/orders/data/order_repository.dart';
import '../../../helpers/supabase_fakes.dart';

void main() {
  late MockSupabaseClient mockClient;
  late OrderRepository repo;

  setUp(() {
    mockClient = MockSupabaseClient();
    repo = OrderRepository(mockClient);
  });

  // ─────────────────────── getPipeline ────────────────────────────────

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

      when(() => mockClient.from('order_statuses'))
          .thenAnswer((_) => FakeQueryBuilder(fakeData));

      final result = await repo.getPipeline('org-1');

      expect(result.length, 2);
      expect(result[0].name, 'Новый');
      expect(result[0].isDefault, true);
      expect(result[1].name, 'В работе');
      expect(result[1].sortOrder, 1);
    });

    test('returns empty list when no statuses', () async {
      when(() => mockClient.from('order_statuses'))
          .thenAnswer((_) => FakeQueryBuilder(<Map<String, dynamic>>[]));

      final result = await repo.getPipeline('org-1');
      expect(result, isEmpty);
    });
  });

  // ─────────────────────── getDefaultStatus ──────────────────────────

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

      when(() => mockClient.from('order_statuses'))
          .thenAnswer((_) => FakeQueryBuilder([fakeData]));

      final result = await repo.getDefaultStatus('org-1');

      expect(result.id, 'st-1');
      expect(result.name, 'Новый');
      expect(result.isDefault, true);
    });
  });

  // ─────────────────────── getOrders ─────────────────────────────────

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
      when(() => mockClient.from('orders'))
          .thenAnswer((_) => FakeQueryBuilder([sampleOrderJson]));

      final result = await repo.getOrders(orgId: 'org-1');

      expect(result.length, 1);
      expect(result.first.id, 'ord-1');
      expect(result.first.orderNumber, 42);
      expect(result.first.totalAmount, 5000.0);
      expect(result.first.customerName, 'Иванов Иван');
      expect(result.first.status?.name, 'Новый');
    });

    test('returns empty list when no orders', () async {
      when(() => mockClient.from('orders'))
          .thenAnswer((_) => FakeQueryBuilder(<Map<String, dynamic>>[]));

      final result = await repo.getOrders(orgId: 'org-1');
      expect(result, isEmpty);
    });
  });

  // ─────────────────────── getOrder ──────────────────────────────────

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

      when(() => mockClient.from('orders'))
          .thenAnswer((_) => FakeQueryBuilder(fakeData));

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

  // ─────────────────────── searchOrders ──────────────────────────────

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

      // searchOrders first queries customers table, then orders table
      when(() => mockClient.from('customers'))
          .thenAnswer((_) => FakeQueryBuilder(<Map<String, dynamic>>[]));
      when(() => mockClient.from('orders'))
          .thenAnswer((_) => FakeQueryBuilder([orderJson]));

      final result =
          await repo.searchOrders(orgId: 'org-1', query: 'Срочная');

      expect(result.length, 1);
      expect(result.first.notes, 'Срочная доставка');
    });
  });

  // ─────────────────────── searchCustomers ───────────────────────────

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

      when(() => mockClient.from('customers'))
          .thenAnswer((_) => FakeQueryBuilder([customerJson]));

      final result =
          await repo.searchCustomers(orgId: 'org-1', query: 'Иванов');

      expect(result.length, 1);
      expect(result.first.name, 'Иванов Иван');
      expect(result.first.phone, '+79001111111');
    });
  });

  // ─────────────────────── getOrderAuditLog ──────────────────────────

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

      when(() => mockClient.from('audit_events'))
          .thenAnswer((_) => FakeQueryBuilder([auditJson]));

      final result = await repo.getOrderAuditLog('ord-1');

      expect(result.length, 1);
      expect(result.first.action, 'order_created');
      expect(result.first.userName, 'Admin User');
    });
  });
}
