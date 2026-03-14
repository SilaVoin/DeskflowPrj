import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/floating_island_nav.dart';

void main() {
  Widget buildApp({required int currentIndex}) {
    return MaterialApp(
      theme: buildDeskflowTheme(),
      home: Scaffold(
        bottomNavigationBar: FloatingIslandNav(
          currentIndex: currentIndex,
          onTap: (_) {},
        ),
      ),
    );
  }

  group('FloatingIslandNav', () {
    testWidgets('active profile label is ellipsized to stay inside island', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp(currentIndex: 3));

      final label = tester.widget<Text>(find.text('Профиль'));

      expect(label.overflow, TextOverflow.ellipsis);
    });

    testWidgets('active pill remains within floating island bounds', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildApp(currentIndex: 3));

      final islandRect = tester.getRect(find.byType(ClipRRect));
      final pillRect = tester.getRect(
        find
            .ancestor(
              of: find.byIcon(Icons.person_rounded),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );

      expect(pillRect.left, greaterThanOrEqualTo(islandRect.left));
      expect(pillRect.right, lessThanOrEqualTo(islandRect.right));
    });

    testWidgets('keeps inactive tabs icon-only', (tester) async {
      await tester.pumpWidget(buildApp(currentIndex: 3));

      expect(find.text('Заказы'), findsNothing);
      expect(find.text('Поиск'), findsNothing);
      expect(find.text('Клиенты'), findsNothing);
      expect(find.text('Профиль'), findsOneWidget);
    });

    testWidgets('compact widths keep all icons visible without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildApp(currentIndex: 0));

      expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.people_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
