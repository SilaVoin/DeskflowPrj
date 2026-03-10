import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:deskflow/core/router/deskflow_transitions.dart';

void main() {
  group('DeskflowTransitions', () {
    testWidgets('slideUp renders child with transition', (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, _) {
              return ElevatedButton(
                onPressed: () => GoRouter.of(context).go('/detail'),
                child: const Text('Go'),
              );
            },
          ),
          GoRoute(
            path: '/detail',
            pageBuilder: (context, state) => DeskflowTransitions.slideUp(
              state: state,
              child: const Scaffold(body: Text('Detail')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Navigate to detail
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(find.text('Detail'), findsOneWidget);
    });

    testWidgets('fade renders child with transition', (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, _) {
              return ElevatedButton(
                onPressed: () => GoRouter.of(context).go('/modal'),
                child: const Text('Open'),
              );
            },
          ),
          GoRoute(
            path: '/modal',
            pageBuilder: (context, state) => DeskflowTransitions.fade(
              state: state,
              child: const Scaffold(body: Text('Modal')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Modal'), findsOneWidget);
    });

    testWidgets('slideRight renders child with transition', (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, _) {
              return ElevatedButton(
                onPressed: () => GoRouter.of(context).go('/settings'),
                child: const Text('Settings'),
              );
            },
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => DeskflowTransitions.slideRight(
              state: state,
              child: const Scaffold(body: Text('Settings Page')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings Page'), findsOneWidget);
    });
  });
}
