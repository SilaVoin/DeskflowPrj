import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/features/orders/domain/customer.dart';

void main() {
  group('Customer', () {
    final now = DateTime(2025, 1, 15);
    final json = {
      'id': 'cust-1',
      'organization_id': 'org-1',
      'name': 'Иванов Иван Петрович',
      'phone': '+7 700 123 4567',
      'email': 'ivan@example.com',
      'address': 'ул. Абая 1',
      'notes': 'VIP клиент',
      'created_at': now.toIso8601String(),
      'order_count': 5,
      'total_spent': 25000.0,
    };

    test('fromJson parses all fields', () {
      final customer = Customer.fromJson(json);

      expect(customer.id, 'cust-1');
      expect(customer.name, 'Иванов Иван Петрович');
      expect(customer.phone, '+7 700 123 4567');
      expect(customer.email, 'ivan@example.com');
      expect(customer.address, 'ул. Абая 1');
      expect(customer.notes, 'VIP клиент');
      expect(customer.orderCount, 5);
      expect(customer.totalSpent, 25000.0);
    });

    test('fromJson handles missing optional fields', () {
      final minimalJson = {
        'id': 'cust-2',
        'organization_id': 'org-1',
        'name': 'Петров',
        'created_at': now.toIso8601String(),
      };

      final customer = Customer.fromJson(minimalJson);
      expect(customer.phone, isNull);
      expect(customer.email, isNull);
      expect(customer.address, isNull);
      expect(customer.notes, isNull);
      expect(customer.orderCount, 0);
      expect(customer.totalSpent, 0);
    });

    test('initials from two-word name', () {
      final customer = Customer.fromJson(json);
      expect(customer.initials, 'ИИ');
    });

    test('initials from single-word name', () {
      final singleJson = Map<String, dynamic>.from(json);
      singleJson['name'] = 'Иван';
      final customer = Customer.fromJson(singleJson);
      expect(customer.initials, 'И');
    });

    test('initials from empty name', () {
      final emptyJson = Map<String, dynamic>.from(json);
      emptyJson['name'] = '';
      final customer = Customer.fromJson(emptyJson);
      expect(customer.initials, '?');
    });

    test('toJson includes required fields', () {
      final customer = Customer.fromJson(json);
      final output = customer.toJson();

      expect(output['organization_id'], 'org-1');
      expect(output['name'], 'Иванов Иван Петрович');
      expect(output['phone'], '+7 700 123 4567');
      expect(output.containsKey('id'), false); // id not in toJson
    });

    test('copyWith replaces fields', () {
      final customer = Customer.fromJson(json);
      final updated = customer.copyWith(name: 'Сидоров', phone: '+7 777 0000');

      expect(updated.name, 'Сидоров');
      expect(updated.phone, '+7 777 0000');
      expect(updated.email, customer.email); // Unchanged
      expect(updated.id, customer.id); // Unchanged
    });
  });
}
