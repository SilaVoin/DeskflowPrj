import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Router redirect logic', () {

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

      if (!isLoggedIn && !isPublicRoute) {
        return '/auth/login';
      }

      if (isLoggedIn && location == '/') {
        if (hasOrg) {
          return '/orders';
        }
        return null; // SplashScreen handles
      }

      if (isLoggedIn && isPublicRoute) {
        if (!hasOrg) {
          return '/org/select';
        }
        return '/orders';
      }

      if (isLoggedIn && !isPublicRoute && !isOrgRoute && !hasOrg) {
        return '/org/select';
      }

      return null; // No redirect
    }

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

    test('redirects from splash to orders when authenticated with org', () {
      final result = simulateRedirect(
        location: '/',
        isLoggedIn: true,
        hasOrg: true,
      );
      expect(result, '/orders');
    });

    test('stays on splash when authenticated but no org', () {
      final result = simulateRedirect(
        location: '/',
        isLoggedIn: true,
        hasOrg: false,
      );
      expect(result, isNull);
    });

    test('redirects to org select when on auth page without org', () {
      final result = simulateRedirect(
        location: '/auth/login',
        isLoggedIn: true,
        hasOrg: false,
      );
      expect(result, '/org/select');
    });

    test('redirects to orders when on auth page with org', () {
      final result = simulateRedirect(
        location: '/auth/login',
        isLoggedIn: true,
        hasOrg: true,
      );
      expect(result, '/orders');
    });

    test('redirects to org select when accessing main routes without org', () {
      final result = simulateRedirect(
        location: '/orders',
        isLoggedIn: true,
        hasOrg: false,
      );
      expect(result, '/org/select');
    });

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
