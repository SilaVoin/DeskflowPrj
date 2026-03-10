import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/features/products/domain/product.dart';

void main() {
  group('Product', () {
    final now = DateTime(2025, 1, 15);
    final json = {
      'id': 'prod-1',
      'organization_id': 'org-1',
      'name': 'Виджет Делюкс',
      'price': 4500.0,
      'sku': 'WDG-DLX-001',
      'description': 'Премиум виджет для клиентов',
      'image_url': 'https://example.com/image.jpg',
      'is_active': true,
      'created_at': now.toIso8601String(),
    };

    test('fromJson parses all fields', () {
      final product = Product.fromJson(json);

      expect(product.id, 'prod-1');
      expect(product.name, 'Виджет Делюкс');
      expect(product.price, 4500.0);
      expect(product.sku, 'WDG-DLX-001');
      expect(product.description, 'Премиум виджет для клиентов');
      expect(product.imageUrl, 'https://example.com/image.jpg');
      expect(product.isActive, true);
    });

    test('fromJson handles missing optional fields', () {
      final minimalJson = {
        'id': 'prod-2',
        'organization_id': 'org-1',
        'name': 'Базовый',
        'price': 100,
        'created_at': now.toIso8601String(),
      };

      final product = Product.fromJson(minimalJson);
      expect(product.sku, isNull);
      expect(product.description, isNull);
      expect(product.imageUrl, isNull);
      expect(product.isActive, true); // Default
    });

    test('formattedPrice formats correctly', () {
      final product = Product.fromJson(json);
      expect(product.formattedPrice, '4 500 ₽');
    });

    test('formattedPrice with decimal price', () {
      final decimalJson = Map<String, dynamic>.from(json);
      decimalJson['price'] = 1234.56;
      final product = Product.fromJson(decimalJson);
      expect(product.formattedPrice, '1 234,56 ₽');
    });

    test('toJson includes all required fields', () {
      final product = Product.fromJson(json);
      final output = product.toJson();

      expect(output['organization_id'], 'org-1');
      expect(output['name'], 'Виджет Делюкс');
      expect(output['price'], 4500.0);
      expect(output['sku'], 'WDG-DLX-001');
      expect(output['is_active'], true);
    });

    test('toJson omits null optional fields', () {
      final minimalProduct = Product(
        id: 'p',
        organizationId: 'o',
        name: 'Test',
        price: 100,
        createdAt: now,
      );
      final output = minimalProduct.toJson();

      expect(output.containsKey('sku'), false);
      expect(output.containsKey('description'), false);
      expect(output.containsKey('image_url'), false);
    });

    test('copyWith replaces fields', () {
      final product = Product.fromJson(json);
      final updated = product.copyWith(
        name: 'Обновлённый',
        price: 9999.0,
        isActive: false,
      );

      expect(updated.name, 'Обновлённый');
      expect(updated.price, 9999.0);
      expect(updated.isActive, false);
      expect(updated.sku, product.sku); // Unchanged
    });
  });
}
