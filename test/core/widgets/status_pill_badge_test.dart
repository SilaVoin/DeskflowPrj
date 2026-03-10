import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/core/widgets/status_pill_badge.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('StatusPillBadge', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        buildApp(const StatusPillBadge(label: 'Новый')),
      );

      expect(find.text('Новый'), findsOneWidget);
    });

    testWidgets('renders with custom color', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const StatusPillBadge(
            label: 'Active',
            color: Colors.green,
          ),
        ),
      );

      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('applies rounded border radius', (tester) async {
      await tester.pumpWidget(
        buildApp(const StatusPillBadge(label: 'Test')),
      );

      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('Test'),
          matching: find.byType(Container),
        ).first,
      );

      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, isNotNull);
    });
  });
}
