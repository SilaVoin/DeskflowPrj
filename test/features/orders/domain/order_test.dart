import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/orders/domain/order_item.dart';

void main() {
  group('Order', () {
    final now = DateTime(2025, 1, 15);
    final json = {
      'id': 'ord-1',
      'organization_id': 'org-1',
      'customer_id': 'cust-1',
      'status_id': 'st-1',
      'order_number': 42,
      'total_amount': 5000.0,
      'delivery_cost': 500.0,
      'notes': 'Доставить до 18:00',
      'created_by': 'user-1',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
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
      'order_items': [
        {
          'id': 'item-1',
          'order_id': 'ord-1',
          'product_id': 'prod-1',
          'product_name': 'Виджет А',
          'unit_price': 1000.0,
          'quantity': 5,
          'created_at': now.toIso8601String(),
        },
      ],
    };

    test('fromJson parses all fields correctly', () {
      final order = Order.fromJson(json);

      expect(order.id, 'ord-1');
      expect(order.organizationId, 'org-1');
      expect(order.customerId, 'cust-1');
      expect(order.statusId, 'st-1');
      expect(order.orderNumber, 42);
      expect(order.totalAmount, 5000.0);
      expect(order.deliveryCost, 500.0);
      expect(order.notes, 'Доставить до 18:00');
      expect(order.createdBy, 'user-1');
    });

    test('fromJson parses joined status', () {
      final order = Order.fromJson(json);

      expect(order.status, isNotNull);
      expect(order.status!.name, 'Новый');
      expect(order.status!.isDefault, true);
    });

    test('fromJson parses customer name', () {
      final order = Order.fromJson(json);
      expect(order.customerName, 'Иванов Иван');
    });

    test('fromJson parses items', () {
      final order = Order.fromJson(json);

      expect(order.items.length, 1);
      expect(order.items.first.productName, 'Виджет А');
      expect(order.items.first.quantity, 5);
    });

    test('fromJson handles missing optional fields', () {
      final minimalJson = {
        'id': 'ord-2',
        'organization_id': 'org-1',
        'status_id': 'st-1',
        'created_by': 'user-1',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final order = Order.fromJson(minimalJson);
      expect(order.customerId, isNull);
      expect(order.notes, isNull);
      expect(order.status, isNull);
      expect(order.customerName, isNull);
      expect(order.items, isEmpty);
      expect(order.orderNumber, 0);
      expect(order.totalAmount, 0);
    });

    test('grandTotal sums totalAmount and deliveryCost', () {
      final order = Order.fromJson(json);
      expect(order.grandTotal, 5500.0);
    });

    test('formattedNumber formats with leading zeros', () {
      final order = Order.fromJson(json);
      expect(order.formattedNumber, '#042');
    });

    test('formattedNumber with 3+ digit number', () {
      final orderJson = Map<String, dynamic>.from(json);
      orderJson['order_number'] = 1234;
      final order = Order.fromJson(orderJson);
      expect(order.formattedNumber, '#1234');
    });
  });

  group('OrderItem', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'item-1',
        'order_id': 'ord-1',
        'product_id': 'prod-1',
        'product_name': 'Виджет Б',
        'unit_price': 250.0,
        'quantity': 3,
        'created_at': DateTime(2025, 1, 15).toIso8601String(),
      };

      final item = OrderItem.fromJson(json);
      expect(item.id, 'item-1');
      expect(item.productName, 'Виджет Б');
      expect(item.unitPrice, 250.0);
      expect(item.quantity, 3);
    });
  });
}
