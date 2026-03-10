import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

void main() {
  testWidgets('DeskflowTheme renders correctly', (WidgetTester tester) async {
    final theme = buildDeskflowTheme();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: Center(child: Text('Deskflow')),
        ),
      ),
    );

    expect(find.text('Deskflow'), findsOneWidget);
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, DeskflowColors.background);
  });
}
