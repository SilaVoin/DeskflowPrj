import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Router redirect logic', () {
    // These tests verify the redirect rules in isolation:
    //
    // Rule 1: Not logged in + non-public route → /auth/login
    // Rule 2: Logged in + splash (/) + has org → /orders
    // Rule 3: Logged in + public route + no org → /org/select
    // Rule 4: Logged in + public route + has org → /orders
    // Rule 5: Logged in + main route + no org → /org/select
    // Rule 6: No redirect when conditions matched

    String? simulateRedirect({
      required String location,
      required bool isLoggedIn,
      required bool hasOrg,
    }) {
      const publicRoutes = [
        '/',
        '/auth/login',
        '/auth/register',
        '/auth/forgot-password',
        '/auth/verify-email',
        '/auth/recovery-code',
      ];

      final isPublicRoute = publicRoutes.contains(location);
      final isOrgRoute = location.startsWith('/org');

      // Not logged in → force to login (unless already on public route)
      if (!isLoggedIn && !isPublicRoute) {
        return '/auth/login';
      }

      // Logged in + on splash → redirect based on org state
      if (isLoggedIn && location == '/') {
        if (hasOrg) {
          return '/orders';
        }
        return null; // SplashScreen handles
      }

      // Logged in but on auth pages → redirect to org check
      if (isLoggedIn && isPublicRoute) {
        if (!hasOrg) {
          return '/org/select';
        }
        return '/orders';
      }

      // Logged in, past org selection, trying to access main routes
      if (isLoggedIn && !isPublicRoute && !isOrgRoute && !hasOrg) {
        return '/org/select';
      }

      return null; // No redirect
    }

    // Rule 1: Not logged in → /auth/login
    test('redirects to login when not authenticated on protected route', () {
      final result = simulateRedirect(
        location: '/orders',
        isLoggedIn: false,
        hasOrg: false,
      );
      expect(result, '/auth/login');
    });

    test('allows public routes when not authenticated', () {
      final result = simulateRedirect(
        location: '/auth/login',
        isLoggedIn: false,
        hasOrg: false,
      );
      expect(result, isNull);
    });

    test('allows register route when not authenticated', () {
      final result = simulateRedirect(
        location: '/auth/register',
        isLoggedIn: false,
        hasOrg: false,
      );
      expect(result, isNull);
    });

    // Rule 2: Logged in + splash + has org → /orders
    test('redirects from splash to orders when authenticated with org', () {
      final result = simulateRedirect(
        location: '/',
        isLoggedIn: true,
        hasOrg: true,
      );
      expect(result, '/orders');
    });

    // Logged in + splash + no org → null (SplashScreen handles)
    test('stays on splash when authenticated but no org', () {
      final result = simulateRedirect(
        location: '/',
        isLoggedIn: true,
        hasOrg: false,
      );
      expect(result, isNull);
    });

    // Rule 3: Logged in + public route + no org → /org/select
    test('redirects to org select when on auth page without org', () {
      final result = simulateRedirect(
        location: '/auth/login',
        isLoggedIn: true,
        hasOrg: false,
      );
      expect(result, '/org/select');
    });

    // Rule 4: Logged in + public route + has org → /orders
    test('redirects to orders when on auth page with org', () {
      final result = simulateRedirect(
        location: '/auth/login',
        isLoggedIn: true,
        hasOrg: true,
      );
      expect(result, '/orders');
    });

    // Rule 5: Logged in + main route + no org → /org/select
    test('redirects to org select when accessing main routes without org', () {
      final result = simulateRedirect(
        location: '/orders',
        isLoggedIn: true,
        hasOrg: false,
      );
      expect(result, '/org/select');
    });

    // Rule 6: No redirect on valid state
    test('no redirect for authenticated user with org on orders', () {
      final result = simulateRedirect(
        location: '/orders',
        isLoggedIn: true,
        hasOrg: true,
      );
      expect(result, isNull);
    });

    test('no redirect for authenticated user on org selection', () {
      final result = simulateRedirect(
        location: '/org/select',
        isLoggedIn: true,
        hasOrg: false,
      );
      expect(result, isNull);
    });

    test('no redirect for authenticated user with org on profile', () {
      final result = simulateRedirect(
        location: '/profile',
        isLoggedIn: true,
        hasOrg: true,
      );
      expect(result, isNull);
    });

    test('redirects admin route to login when not authenticated', () {
      final result = simulateRedirect(
        location: '/admin/users',
        isLoggedIn: false,
        hasOrg: false,
      );
      expect(result, '/auth/login');
    });

    test('no redirect for authenticated owner on admin route', () {
      final result = simulateRedirect(
        location: '/admin/users',
        isLoggedIn: true,
        hasOrg: true,
      );
      expect(result, isNull);
    });
  });
}
