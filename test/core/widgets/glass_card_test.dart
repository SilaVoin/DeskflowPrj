import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/core/widgets/glass_card.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('GlassCard', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        buildApp(const GlassCard(child: Text('Hello'))),
      );

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildApp(
          GlassCard(
            onTap: () => tapped = true,
            child: const Text('Tap me'),
          ),
        ),
      );

      await tester.tap(find.text('Tap me'));
      await tester.pumpAndSettle();

      expect(tapped, true);
    });

    testWidgets('calls onLongPress', (tester) async {
      var longPressed = false;
      await tester.pumpWidget(
        buildApp(
          GlassCard(
            onLongPress: () => longPressed = true,
            child: const Text('Press me'),
          ),
        ),
      );

      await tester.longPress(find.text('Press me'));
      await tester.pumpAndSettle();

      expect(longPressed, true);
    });

    testWidgets('does not crash without onTap', (tester) async {
      await tester.pumpWidget(
        buildApp(const GlassCard(child: Text('No tap'))),
      );

      // Tapping should not throw
      await tester.tap(find.text('No tap'));
      await tester.pumpAndSettle();

      expect(find.text('No tap'), findsOneWidget);
    });

    testWidgets('applies custom padding', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const GlassCard(
            padding: EdgeInsets.all(32),
            child: Text('Padded'),
          ),
        ),
      );

      // Find the Padding widget with our custom padding
      final padding = tester.widget<Padding>(
        find.ancestor(
          of: find.text('Padded'),
          matching: find.byType(Padding),
        ).first,
      );
      expect(padding.padding, const EdgeInsets.all(32));
    });
  });
}
