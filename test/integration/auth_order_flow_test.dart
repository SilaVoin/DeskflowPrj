import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:deskflow/features/auth/domain/auth_notifier.dart';
import 'package:deskflow/features/auth/presentation/login_screen.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/orders/domain/order_notifier.dart';
import 'package:deskflow/features/orders/domain/order_status.dart';
import 'package:deskflow/features/orders/presentation/create_order_screen.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';


const _testUserId = 'user-int-1';
const _testOrgId = 'org-int-1';

User _fakeUser() => const User(
      id: _testUserId,
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00.000',
    );

Order _fakeOrder() => Order(
      id: 'ord-new',
      organizationId: _testOrgId,
      statusId: 'st-1',
      orderNumber: 1,
      totalAmount: 1500,
      createdBy: _testUserId,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      status: const OrderStatus(
        id: 'st-1',
        organizationId: _testOrgId,
        name: 'Новый',
        color: '#3B82F6',
        sortOrder: 0,
        isDefault: true,
        isFinal: false,
      ),
    );


class FakeAuthNotifier extends AuthNotifier {
  bool signInCalled = false;
  String? lastEmail;
  String? lastPassword;

  @override
  FutureOr<void> build() {}

  @override
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    signInCalled = true;
    lastEmail = email;
    lastPassword = password;
    state = const AsyncData(null);
    return true;
  }

  @override
  Future<bool> signInWithGoogle() async => true;

  @override
  Future<bool> signInWithApple() async => true;
}

class FakeCurrentOrgId extends CurrentOrgId {
  @override
  String? build() => _testOrgId;
}

class FakeOrderNotifier extends OrderNotifier {
  Order? createdOrder;
  int createOrderCallCount = 0;

  @override
  FutureOr<void> build() {}

  @override
  Future<Order?> createOrder({
    String? customerId,
    double deliveryCost = 0,
    String? notes,
    List<Map<String, dynamic>> items = const [],
  }) async {
    createOrderCallCount++;
    createdOrder = _fakeOrder();
    state = const AsyncData(null);
    return createdOrder;
  }
}


Widget _buildLoginScreen({FakeAuthNotifier? authNotifier}) {
  final notifier = authNotifier ?? FakeAuthNotifier();
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, _) => const Scaffold()),
      GoRoute(
        path: '/auth/register',
        builder: (_, _) => const Scaffold(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (_, _) => const Scaffold(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => notifier),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Widget _buildCreateOrderScreen({FakeOrderNotifier? orderNotifier}) {
  final notifier = orderNotifier ?? FakeOrderNotifier();
  final router = GoRouter(
    initialLocation: '/create',
    routes: [
      GoRoute(
        path: '/create',
        builder: (_, _) => const CreateOrderScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (_, _) => const Scaffold(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => _fakeUser()),
      currentOrgIdProvider.overrideWith(FakeCurrentOrgId.new),
      orderNotifierProvider.overrideWith(() => notifier),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}


void main() {
  group('Auth flow', () {
    testWidgets('renders login form with email and password fields',
        (tester) async {
      await tester.pumpWidget(_buildLoginScreen());
      await tester.pumpAndSettle();

      expect(find.text('Войти в аккаунт'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Войти'), findsOneWidget);
    });

    testWidgets('shows OAuth buttons', (tester) async {
      await tester.pumpWidget(_buildLoginScreen());
      await tester.pumpAndSettle();

      expect(find.text('Войти через Google'), findsOneWidget);
      expect(find.text('Войти через Apple'), findsOneWidget);
    });

    testWidgets('can enter email and password', (tester) async {
      await tester.pumpWidget(_buildLoginScreen());
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'test@example.com');
      await tester.enterText(fields.at(1), 'password123');
      await tester.pumpAndSettle();

      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('password123'), findsOneWidget);
    });

    testWidgets('submits credentials to AuthNotifier', (tester) async {
      final fakeNotifier = FakeAuthNotifier();
      await tester.pumpWidget(_buildLoginScreen(authNotifier: fakeNotifier));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'user@test.com');
      await tester.enterText(fields.at(1), 'mysecret');

      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.signInCalled, isTrue);
      expect(fakeNotifier.lastEmail, 'user@test.com');
      expect(fakeNotifier.lastPassword, 'mysecret');
    });

    testWidgets('shows registration link', (tester) async {
      await tester.pumpWidget(_buildLoginScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Зарегистрироваться'), findsOneWidget);
    });

    testWidgets('password visibility toggle works', (tester) async {
      await tester.pumpWidget(_buildLoginScreen());
      await tester.pumpAndSettle();

      final passwordField = find.byType(TextField).last;
      await tester.enterText(passwordField, 'secret');
      await tester.pumpAndSettle();

      final toggleIcon = find.byIcon(Icons.visibility_off_rounded);
      if (toggleIcon.evaluate().isNotEmpty) {
        await tester.tap(toggleIcon);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
      }
    });
  });

  group('Order creation flow', () {
    testWidgets('renders create order form', (tester) async {
      await tester.pumpWidget(_buildCreateOrderScreen());
      await tester.pumpAndSettle();

      expect(find.text('Новый заказ'), findsOneWidget);
      expect(find.text('Сохранить'), findsOneWidget);
    });

    testWidgets('submits order via notifier', (tester) async {
      final fakeNotifier = FakeOrderNotifier();
      await tester.pumpWidget(
        _buildCreateOrderScreen(orderNotifier: fakeNotifier),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.createOrderCallCount, 1);
    });

    testWidgets('shows form sections', (tester) async {
      await tester.pumpWidget(_buildCreateOrderScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Клиент'), findsWidgets);
      expect(find.textContaining('Товары'), findsWidgets);
    });
  });
}
