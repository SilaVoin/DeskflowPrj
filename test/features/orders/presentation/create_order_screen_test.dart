import 'dart:async';

import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/orders/domain/order_composition.dart';
import 'package:deskflow/features/orders/domain/order_notifier.dart';
import 'package:deskflow/features/orders/domain/order_template.dart';
import 'package:deskflow/features/orders/domain/order_providers.dart';
import 'package:deskflow/features/orders/presentation/create_order_screen.dart';
import 'package:deskflow/features/products/domain/product.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _FakeOrderNotifier extends OrderNotifier {
  int saveTemplateCallCount = 0;

  @override
  FutureOr<void> build() {}

  @override
  Future<OrderTemplate?> saveOrderTemplate({
    required String name,
    required OrderComposition composition,
    String? templateId,
  }) async {
    saveTemplateCallCount++;
    return OrderTemplate(
      id: 'tpl-saved',
      organizationId: 'org-1',
      name: name,
      createdAt: DateTime(2026, 3, 10),
      updatedAt: DateTime(2026, 3, 10),
      composition: composition,
    );
  }
}

Widget _buildScreen({
  List<OrderTemplate> templates = const [],
  List<Customer> recentCustomers = const [],
  List<Product> recentProducts = const [],
  OrderComposition? initialComposition,
  _FakeOrderNotifier? notifier,
}) {
  return ProviderScope(
    overrides: [
      orderNotifierProvider.overrideWith(
        () => notifier ?? _FakeOrderNotifier(),
      ),
      orderTemplatesProvider.overrideWith((ref) async => templates),
      recentOrderCustomersProvider.overrideWith((ref) async => recentCustomers),
      recentOrderProductsProvider.overrideWith((ref) async => recentProducts),
    ],
    child: MaterialApp(
      home: CreateOrderScreen(initialComposition: initialComposition),
    ),
  );
}

void main() {
  const templateComposition = OrderComposition(
    items: [
      OrderCompositionItem(
        productId: 'prod-template',
        productName: 'Шаблонный товар',
        unitPrice: 3200,
        quantity: 2,
      ),
    ],
  );

  final template = OrderTemplate(
    id: 'tpl-1',
    organizationId: 'org-1',
    name: 'Повторный заказ',
    createdAt: DateTime(2026, 3, 10),
    updatedAt: DateTime(2026, 3, 10),
    composition: templateComposition,
  );

  final customer = Customer(
    id: 'cust-1',
    organizationId: 'org-1',
    name: 'Иванов Иван',
    phone: '+79001111111',
    createdAt: DateTime(2026, 3, 10),
  );

  final product = Product(
    id: 'prod-1',
    organizationId: 'org-1',
    name: 'Виджет А',
    price: 1500,
    createdAt: DateTime(2026, 3, 10),
  );

  testWidgets('renders quick-source section with templates and recents', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildScreen(
        templates: [template],
        recentCustomers: [customer],
        recentProducts: [product],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Быстрые источники'), findsOneWidget);
    expect(find.text('Шаблоны'), findsOneWidget);
    expect(find.text('Последние клиенты'), findsOneWidget);
    expect(find.text('Последние товары'), findsOneWidget);
    expect(find.text('Повторный заказ'), findsOneWidget);
    expect(find.text('Иванов Иван'), findsOneWidget);
    expect(find.text('Виджет А'), findsOneWidget);
  });

  testWidgets(
    'applying template to non-empty composition asks confirmation and replaces items',
    (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          templates: [template],
          initialComposition: const OrderComposition(
            items: [
              OrderCompositionItem(
                productId: 'prod-old',
                productName: 'Старый товар',
                unitPrice: 900,
                quantity: 1,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Старый товар'), findsOneWidget);

      await tester.tap(find.text('Повторный заказ'));
      await tester.pumpAndSettle();

      expect(find.text('Заменить текущий состав заказа?'), findsOneWidget);

      await tester.tap(find.text('Применить'));
      await tester.pumpAndSettle();

      expect(find.text('Шаблонный товар'), findsOneWidget);
      expect(find.text('Старый товар'), findsNothing);
    },
  );

  testWidgets('recent customer fills customer only', (tester) async {
    await tester.pumpWidget(_buildScreen(recentCustomers: [customer]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Иванов Иван'));
    await tester.pumpAndSettle();

    expect(find.text('Иванов Иван'), findsWidgets);
    expect(find.text('+79001111111'), findsOneWidget);
    expect(find.text('Нет товаров'), findsOneWidget);
  });

  testWidgets('recent product adds item into composition', (tester) async {
    await tester.pumpWidget(_buildScreen(recentProducts: [product]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Виджет А'));
    await tester.pumpAndSettle();

    expect(find.text('Виджет А'), findsWidgets);
    expect(find.textContaining('1 ×'), findsOneWidget);
    expect(find.text('Нет товаров'), findsNothing);
  });

  testWidgets('can open save-template flow for current composition', (
    tester,
  ) async {
    final notifier = _FakeOrderNotifier();

    await tester.pumpWidget(
      _buildScreen(
        notifier: notifier,
        initialComposition: const OrderComposition(
          items: [
            OrderCompositionItem(
              productId: 'prod-1',
              productName: 'Виджет А',
              unitPrice: 1500,
              quantity: 1,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Сохранить как шаблон'), findsOneWidget);

    await tester.tap(find.text('Сохранить как шаблон'));
    await tester.pumpAndSettle();

    expect(find.text('Новый шаблон'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Частый заказ');
    await tester.tap(find.text('Сохранить шаблон'));
    await tester.pumpAndSettle();

    expect(notifier.saveTemplateCallCount, 1);
  });

  testWidgets('save-template dialog uses dense modal surface', (tester) async {
    await tester.pumpWidget(
      _buildScreen(
        initialComposition: const OrderComposition(
          items: [
            OrderCompositionItem(
              productId: 'prod-1',
              productName: 'Виджет А',
              unitPrice: 1500,
              quantity: 1,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сохранить как шаблон'));
    await tester.pumpAndSettle();

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.backgroundColor, DeskflowColors.modalSurface);
  });
}
