import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/features/orders/domain/order_status.dart';

void main() {
  group('OrderStatus', () {
    final json = {
      'id': 'st-1',
      'organization_id': 'org-1',
      'name': 'В обработке',
      'color': '#F59E0B',
      'sort_order': 1,
      'is_default': false,
      'is_final': false,
    };

    test('fromJson parses all fields', () {
      final status = OrderStatus.fromJson(json);

      expect(status.id, 'st-1');
      expect(status.organizationId, 'org-1');
      expect(status.name, 'В обработке');
      expect(status.color, '#F59E0B');
      expect(status.sortOrder, 1);
      expect(status.isDefault, false);
      expect(status.isFinal, false);
    });

    test('fromJson uses defaults for missing fields', () {
      final minimalJson = {
        'id': 'st-2',
        'organization_id': 'org-1',
        'name': 'Тест',
      };

      final status = OrderStatus.fromJson(minimalJson);
      expect(status.color, '#6B7280');
      expect(status.sortOrder, 0);
      expect(status.isDefault, false);
      expect(status.isFinal, false);
    });

    test('materialColor parses hex correctly', () {
      final status = OrderStatus.fromJson(json);

      expect(status.materialColor, const Color(0xFFF59E0B));
    });

    test('materialColor with default color', () {
      final status = OrderStatus.fromJson({
        'id': 'st-3',
        'organization_id': 'org-1',
        'name': 'Default',
      });

      expect(status.materialColor, const Color(0xFF6B7280));
    });
  });
}
