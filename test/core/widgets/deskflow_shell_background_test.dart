import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/deskflow_shell_background.dart';

final _oneByOneTransparentPng = Uint8List.fromList(const <int>[
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1,
  0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84,
  120, 156, 99, 248, 255, 255, 255, 127, 0, 9, 251, 3, 253, 46, 37, 9, 155, 0,
  0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

void main() {
  testWidgets('renders shell image background without exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDeskflowTheme(),
        home: Scaffold(
          body: SizedBox.expand(
            child: DeskflowShellBackground(
              image: MemoryImage(_oneByOneTransparentPng),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(DeskflowShellBackground), findsOneWidget);
    expect(find.byType(DecoratedBox), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });
}
