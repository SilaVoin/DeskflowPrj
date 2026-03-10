import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:deskflow/core/providers/supabase_provider.dart';
import 'package:deskflow/core/router/deskflow_transitions.dart';
import 'package:deskflow/core/router/go_router_refresh_stream.dart';
import 'package:deskflow/core/router/main_shell_screen.dart';
import 'package:deskflow/features/admin/presentation/catalog_management_screen.dart';
import 'package:deskflow/features/admin/presentation/edit_product_screen.dart';
import 'package:deskflow/features/admin/presentation/invite_user_screen.dart';
import 'package:deskflow/features/admin/presentation/pipeline_config_screen.dart';
import 'package:deskflow/features/admin/presentation/user_management_screen.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/profile/domain/account_history_providers.dart';
import 'package:deskflow/features/auth/presentation/email_verification_screen.dart';
import 'package:deskflow/features/auth/presentation/forgot_password_screen.dart';
import 'package:deskflow/features/auth/presentation/login_screen.dart';
import 'package:deskflow/features/auth/presentation/recovery_code_screen.dart';
import 'package:deskflow/features/auth/presentation/register_screen.dart';
import 'package:deskflow/features/auth/presentation/splash_screen.dart';
import 'package:deskflow/features/orders/presentation/create_order_screen.dart';
import 'package:deskflow/features/orders/presentation/edit_order_screen.dart';
import 'package:deskflow/features/orders/presentation/order_detail_screen.dart';
import 'package:deskflow/features/orders/presentation/orders_list_screen.dart';
import 'package:deskflow/features/chat/domain/chat_message.dart';
import 'package:deskflow/features/chat/presentation/order_chat_screen.dart';
import 'package:deskflow/features/chat/presentation/attachment_preview_screen.dart';
import 'package:deskflow/features/customers/presentation/customers_list_screen.dart';
import 'package:deskflow/features/customers/presentation/customer_detail_screen.dart';
import 'package:deskflow/features/customers/presentation/customer_form_screen.dart';
import 'package:deskflow/features/products/presentation/products_list_screen.dart';
import 'package:deskflow/features/products/presentation/product_detail_screen.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';
import 'package:deskflow/features/org/presentation/create_org_screen.dart';
import 'package:deskflow/features/org/presentation/join_org_screen.dart';
import 'package:deskflow/features/org/presentation/org_selection_screen.dart';
import 'package:deskflow/features/profile/presentation/notification_settings_screen.dart';
import 'package:deskflow/features/notifications/presentation/notifications_screen.dart';
import 'package:deskflow/features/profile/presentation/org_settings_screen.dart';
import 'package:deskflow/features/profile/presentation/profile_screen.dart';
import 'package:deskflow/features/search/presentation/universal_search_screen.dart';
import 'package:deskflow/core/utils/app_logger.dart';

part 'app_router.g.dart';

final _log = AppLogger.getLogger('AppRouter');

/// Global navigation key for root navigator.
final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Auth-aware routes that don't require authentication.
const _publicRoutes = [
  '/',
  '/auth/login',
  '/auth/register',
  '/auth/forgot-password',
  '/auth/verify-email',
  '/auth/recovery-code',
];

/// GoRouter provider — reactive to auth state changes.
///
/// Uses [ref.listen] instead of [ref.watch] for auth/org providers to avoid
/// rebuilding the entire GoRouter (which resets navigation stack). Instead,
/// auth and org changes trigger redirect re-evaluation via [GoRouterRefreshStream].
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final supabaseClient = ref.watch(supabaseClientProvider);

  final refreshStream = GoRouterRefreshStream(
    supabaseClient.auth.onAuthStateChange,
  );
  ref.onDispose(refreshStream.dispose);

  // Trigger redirect re-evaluation (NOT provider rebuild) on state changes
  ref.listen(currentOrgIdProvider, (_, _) => refreshStream.notify());
  ref.listen(isAuthenticatedProvider, (_, _) => refreshStream.notify());
  ref.listen(isSwitchingAccountProvider, (_, _) => refreshStream.notify());

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: refreshStream,
    redirect: (context, state) {
      // [FIX] Suppress redirects during account switch to prevent
      // navigation to login between signOut and restoreSession.
      final isSwitching = ref.read(isSwitchingAccountProvider);
      if (isSwitching) {
        _log.d('redirect: suppressed (account switch in progress)');
        return null;
      }

      final location = state.matchedLocation;
      final isPublicRoute = _publicRoutes.contains(location);
      final isOrgRoute = location.startsWith('/org');

      // [FIX] Read current values at redirect time (not captured at build time)
      final isLoggedIn = supabaseClient.auth.currentUser != null;
      final hasOrg = ref.read(currentOrgIdProvider) != null;

      _log.d('redirect: location=$location, isLoggedIn=$isLoggedIn, '
          'hasOrg=$hasOrg');

      // Not logged in → force to login (unless already on public route)
      if (!isLoggedIn && !isPublicRoute) {
        _log.d('redirect → /auth/login (not authenticated)');
        return '/auth/login';
      }

      // Logged in + on splash → redirect based on org state
      if (isLoggedIn && location == '/') {
        if (hasOrg) {
          _log.d('redirect → /orders (splash, has org)');
          return '/orders';
        }
        // Let SplashScreen handle org loading and auto-select
        return null;
      }

      // Logged in but on auth pages → redirect to org check
      if (isLoggedIn && isPublicRoute) {
        // [FIX] Always allow verify-email and recovery-code for logged-in users
        // (Supabase creates a session on signUp before email is verified)
        if (location == '/auth/verify-email' || location == '/auth/recovery-code') {
          _log.d('redirect: allowing $location (post-auth verification)');
          return null;
        }
        // Allow auth routes when user is adding/switching account from Profile
        final isAddingAccount = ref.read(addingAccountProvider);
        if (isAddingAccount && (location == '/auth/register' || location == '/auth/login')) {
          _log.d('redirect: allowing $location (adding account)');
          return null;
        }
        if (!hasOrg) {
          _log.d('redirect → /org/select (no org selected)');
          return '/org/select';
        }
        _log.d('redirect → /orders (authenticated, has org)');
        return '/orders';
      }

      // Logged in, past org selection, trying to access main routes
      if (isLoggedIn && !isPublicRoute && !isOrgRoute && !hasOrg) {
        _log.d('redirect → /org/select (no org selected)');
        return '/org/select';
      }

      return null; // No redirect needed
    },
    routes: [
    // ── Splash ────────────────────────────────────────────
    GoRoute(
      path: '/',
      builder: (context, state) {
        _log.d('Navigating to SplashScreen');
        return const SplashScreen();
      },
    ),

    // ── Auth Flow (no nav bar) ────────────────────────────
    GoRoute(
      path: '/auth/login',
      builder: (context, state) {
        _log.d('Navigating to LoginScreen');
        return const LoginScreen();
      },
    ),
    GoRoute(
      path: '/auth/register',
      builder: (context, state) {
        _log.d('Navigating to RegisterScreen');
        return const RegisterScreen();
      },
    ),
    GoRoute(
      path: '/auth/forgot-password',
      builder: (context, state) {
        _log.d('Navigating to ForgotPasswordScreen');
        return ForgotPasswordScreen();
      },
    ),
    GoRoute(
      path: '/auth/recovery-code',
      builder: (context, state) {
        final email = state.uri.queryParameters['email'] ?? '';
        _log.d('[FIX] Navigating to RecoveryCodeScreen (email=$email)');
        return RecoveryCodeScreen(email: email);
      },
    ),
    GoRoute(
      path: '/auth/verify-email',
      builder: (context, state) {
        final email = state.uri.queryParameters['email'] ?? '';
        _log.d('Navigating to EmailVerificationScreen (email=$email)');
        return EmailVerificationScreen(email: email);
      },
    ),

    // ── Org Flow (no nav bar) ─────────────────────────────
    GoRoute(
      path: '/org/select',
      builder: (context, state) {
        _log.d('Navigating to OrgSelectionScreen');
        return const OrgSelectionScreen();
      },
    ),
    GoRoute(
      path: '/org/create',
      builder: (context, state) {
        _log.d('Navigating to CreateOrgScreen');
        return CreateOrgScreen();
      },
    ),
    GoRoute(
      path: '/org/join',
      builder: (context, state) {
        final code = state.uri.queryParameters['code'];
        _log.d('Navigating to JoinOrgScreen (code=$code)');
        return JoinOrgScreen(initialCode: code);
      },
    ),

    // ── Main App (with floating island nav) ───────────────
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShellScreen(navigationShell: navigationShell);
      },
      branches: [
        // Tab 1: Orders
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/orders',
              builder: (context, state) {
                _log.d('Navigating to OrdersListScreen');
                return const OrdersListScreen();
              },
              routes: [
                GoRoute(
                  path: 'create',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    _log.d('Navigating to CreateOrderScreen');
                    return DeskflowTransitions.slideUp(
                      state: state,
                      child: const CreateOrderScreen(),
                    );
                  },
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    final orderId = state.pathParameters['id']!;
                    _log.d('Navigating to OrderDetailScreen, id=$orderId');
                    return DeskflowTransitions.slideUp(
                      state: state,
                      child: OrderDetailScreen(orderId: orderId),
                    );
                  },
                  routes: [
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) {
                        final orderId = state.pathParameters['id']!;
                        _log.d('Navigating to EditOrderScreen, id=$orderId');
                        return EditOrderScreen(orderId: orderId);
                      },
                    ),
                    GoRoute(
                      path: 'chat',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) {
                        final orderId = state.pathParameters['id']!;
                        _log.d('Navigating to OrderChatScreen, id=$orderId');
                        return OrderChatScreen(orderId: orderId);
                      },
                      routes: [
                        GoRoute(
                          path: 'attachment',
                          parentNavigatorKey: _rootNavigatorKey,
                          builder: (context, state) {
                            final attachment = state.extra as Attachment;
                            _log.d('Navigating to AttachmentPreviewScreen');
                            return AttachmentPreviewScreen(
                                attachment: attachment);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Tab 2: Search
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) {
                _log.d('Navigating to UniversalSearchScreen');
                return const UniversalSearchScreen();
              },
            ),
          ],
        ),

        // Tab 3: Customers
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/customers',
              builder: (context, state) {
                _log.d('Navigating to CustomersListScreen');
                return const CustomersListScreen();
              },
              routes: [
                GoRoute(
                  path: 'create',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    _log.d('Navigating to CreateCustomerScreen');
                    return DeskflowTransitions.slideUp(
                      state: state,
                      child: const CustomerFormScreen(),
                    );
                  },
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    final customerId = state.pathParameters['id']!;
                    _log.d('Navigating to CustomerDetailScreen, id=$customerId');
                    return DeskflowTransitions.slideUp(
                      state: state,
                      child: CustomerDetailScreen(customerId: customerId),
                    );
                  },
                  routes: [
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) {
                        final customerId = state.pathParameters['id']!;
                        _log.d('Navigating to EditCustomerScreen, id=$customerId');
                        return CustomerFormScreen(customerId: customerId);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Tab 4: Profile
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) {
                _log.d('Navigating to ProfileScreen');
                return const ProfileScreen();
              },
              routes: [
                GoRoute(
                  path: 'org-settings',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    _log.d('Navigating to OrgSettingsScreen');
                    return DeskflowTransitions.slideRight(
                      state: state,
                      child: const OrgSettingsScreen(),
                    );
                  },
                ),
                GoRoute(
                  path: 'notifications',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    _log.d('Navigating to NotificationSettingsScreen');
                    return DeskflowTransitions.slideRight(
                      state: state,
                      child: const NotificationSettingsScreen(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ── Admin Routes ──────────────────────────────────────
    GoRoute(
      path: '/notifications',
      pageBuilder: (context, state) {
        _log.d('Navigating to NotificationsScreen');
        return DeskflowTransitions.slideRight(
          state: state,
          child: const NotificationsScreen(),
        );
      },
    ),
    GoRoute(
      path: '/admin/users',
      pageBuilder: (context, state) {
        _log.d('Navigating to UserManagementScreen');
        return DeskflowTransitions.slideRight(
          state: state,
          child: const UserManagementScreen(),
        );
      },
      routes: [
        GoRoute(
          path: 'invite',
          builder: (context, state) {
            _log.d('Navigating to InviteUserScreen');
            return const InviteUserScreen();
          },
        ),
      ],
    ),
    GoRoute(
      path: '/admin/pipeline',
      pageBuilder: (context, state) {
        _log.d('Navigating to PipelineConfigScreen');
        return DeskflowTransitions.slideRight(
          state: state,
          child: const PipelineConfigScreen(),
        );
      },
    ),
    GoRoute(
      path: '/admin/catalog',
      builder: (context, state) {
        _log.d('Navigating to CatalogManagementScreen');
        return const CatalogManagementScreen();
      },
      routes: [
        GoRoute(
          path: 'create',
          builder: (context, state) {
            _log.d('Navigating to EditProductScreen (create)');
            return const EditProductScreen();
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) {
            final productId = state.pathParameters['id']!;
            _log.d('Navigating to EditProductScreen, id=$productId');
            return EditProductScreen(productId: productId);
          },
        ),
      ],
    ),

    // ── Shared Entity Routes ──────────────────────────────
    GoRoute(
      path: '/products',
      builder: (context, state) {
        _log.d('Navigating to ProductsListScreen');
        return const ProductsListScreen();
      },
      routes: [
        GoRoute(
          path: ':id',
          pageBuilder: (context, state) {
            final productId = state.pathParameters['id']!;
            _log.d('Navigating to ProductDetailScreen, id=$productId');
            return DeskflowTransitions.slideUp(
              state: state,
              child: ProductDetailScreen(productId: productId),
            );
          },
        ),
      ],
    ),
  ],
  );
}
