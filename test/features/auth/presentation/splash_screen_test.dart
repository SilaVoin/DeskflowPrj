import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deskflow/core/providers/supabase_provider.dart';
import 'package:deskflow/features/auth/presentation/splash_screen.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _TestCurrentOrgId extends CurrentOrgId {
  _TestCurrentOrgId(this._value);

  final String? _value;

  @override
  String? build() => _value;
}

Widget _buildSplashSubject({
  required SupabaseClient client,
  Uri? uri,
  bool isWeb = true,
  Duration initialDelay = Duration.zero,
  Duration gracePeriod = const Duration(seconds: 1),
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) =>
            const Scaffold(body: Text('login-screen')),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) =>
            const Scaffold(body: Text('orders-screen')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      supabaseClientProvider.overrideWithValue(client),
      currentOrgIdProvider.overrideWith(() => _TestCurrentOrgId('org-1')),
      splashBaseUriProvider.overrideWithValue(uri ?? Uri.parse('http://localhost/')),
      splashIsWebProvider.overrideWithValue(isWeb),
      splashInitialDelayProvider.overrideWithValue(initialDelay),
      splashWebAuthGracePeriodProvider.overrideWithValue(gracePeriod),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  late _MockSupabaseClient client;
  late _MockGoTrueClient auth;

  setUp(() {
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();

    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(null);
  });
  group('hasPendingWebAuthCallback', () {
    test('returns true for Supabase auth fragments on web', () {
      final uri = Uri.parse(
        'http://127.0.0.1:7358/#access_token=token&refresh_token=refresh'
        '&token_type=bearer&type=signup',
      );

      expect(
        hasPendingWebAuthCallback(uri, isWeb: true),
        isTrue,
      );
    });

    test('returns false for the same uri outside web', () {
      final uri = Uri.parse(
        'http://127.0.0.1:7358/#access_token=token&refresh_token=refresh',
      );

      expect(
        hasPendingWebAuthCallback(uri, isWeb: false),
        isFalse,
      );
    });
  });

  group('decideSplashAuthDecision', () {
    test('waits for callback when user is signed out with pending web auth', () {
      expect(
        decideSplashAuthDecision(
          isLoggedIn: false,
          hasPendingCallback: true,
        ),
        SplashAuthDecision.waitForWebAuthCallback,
      );
    });

    test('goes to login when user is signed out without pending callback', () {
      expect(
        decideSplashAuthDecision(
          isLoggedIn: false,
          hasPendingCallback: false,
        ),
        SplashAuthDecision.goToLogin,
      );
    });

    test('continues authenticated flow when user is already signed in', () {
      expect(
        decideSplashAuthDecision(
          isLoggedIn: true,
          hasPendingCallback: true,
        ),
        SplashAuthDecision.continueAuthenticatedFlow,
      );
    });
  });

  group('SplashScreen', () {
    testWidgets(
      'waits on splash while pending web auth callback is still unresolved',
      (tester) async {
        await tester.pumpWidget(
          _buildSplashSubject(
            client: client,
            uri: Uri.parse(
              'http://127.0.0.1:7359/#access_token=token&refresh_token=refresh',
            ),
            gracePeriod: const Duration(milliseconds: 300),
          ),
        );

        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Deskflow'), findsOneWidget);
        expect(find.text('login-screen'), findsNothing);

        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'redirects to login immediately when there is no pending callback',
      (tester) async {
        await tester.pumpWidget(
          _buildSplashSubject(
            client: client,
            uri: Uri.parse('http://127.0.0.1:7359/'),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('login-screen'), findsOneWidget);
      },
    );

    testWidgets(
      'redirects to login after grace period when callback never resolves',
      (tester) async {
        await tester.pumpWidget(
          _buildSplashSubject(
            client: client,
            uri: Uri.parse(
              'http://127.0.0.1:7359/#access_token=token&refresh_token=refresh',
            ),
            gracePeriod: const Duration(milliseconds: 300),
          ),
        );

        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('login-screen'), findsOneWidget);
      },
    );

    testWidgets(
      'stays off login when session appears during callback grace period',
      (tester) async {
        var readCount = 0;
        const user = User(
          id: 'user-1',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-03-11T00:00:00.000',
          email: 'user@test.com',
        );
        when(() => auth.currentUser).thenAnswer((_) {
              readCount += 1;
              if (readCount >= 3) return user;
              return null;
            });

        await tester.pumpWidget(
          _buildSplashSubject(
            client: client,
            uri: Uri.parse(
              'http://127.0.0.1:7359/#access_token=token&refresh_token=refresh',
            ),
            gracePeriod: const Duration(milliseconds: 500),
          ),
        );

        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(find.text('login-screen'), findsNothing);
        expect(find.text('orders-screen'), findsOneWidget);
      },
    );
  });
}
