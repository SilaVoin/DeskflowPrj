import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/core/widgets/pill_button.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('PillButton', () {
    testWidgets('renders label', (tester) async {
      await tester.pumpWidget(
        buildApp(PillButton(label: 'Save', onPressed: () {})),
      );

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        buildApp(PillButton(label: 'Go', onPressed: () => pressed = true)),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(pressed, true);
    });

    testWidgets('shows icon when provided', (tester) async {
      await tester.pumpWidget(
        buildApp(
          PillButton(
            label: 'Add',
            icon: Icons.add,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows loading indicator when isLoading', (tester) async {
      await tester.pumpWidget(
        buildApp(
          PillButton(
            label: 'Loading',
            isLoading: true,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(
        buildApp(const PillButton(label: 'Disabled')),
      );

      final button = tester.widget<MaterialButton>(
        find.byType(MaterialButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('does not fire onPressed when loading', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        buildApp(
          PillButton(
            label: 'Loading',
            isLoading: true,
            onPressed: () => pressed = true,
          ),
        ),
      );

      await tester.tap(find.byType(MaterialButton));
      await tester.pump();

      expect(pressed, false);
    });
  });

  group('PillButton.secondary', () {
    testWidgets('renders with label', (tester) async {
      await tester.pumpWidget(
        buildApp(PillButton.secondary(label: 'Cancel', onPressed: () {})),
      );

      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('PillButton.destructive', () {
    testWidgets('renders with label and icon', (tester) async {
      await tester.pumpWidget(
        buildApp(
          PillButton.destructive(
            label: 'Delete',
            icon: Icons.delete,
            onPressed: () {},
          ),
        ),
      );

      expect(find.text('Delete'), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });
  });
}
