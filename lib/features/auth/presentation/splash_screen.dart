import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/constants/app_constants.dart';
import 'package:deskflow/core/providers/supabase_provider.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

enum SplashAuthDecision {
  waitForWebAuthCallback,
  goToLogin,
  continueAuthenticatedFlow,
}

@visibleForTesting
final splashBaseUriProvider = Provider<Uri>((ref) => Uri.base);

@visibleForTesting
final splashIsWebProvider = Provider<bool>((ref) => kIsWeb);

@visibleForTesting
final splashInitialDelayProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 2),
);

@visibleForTesting
final splashWebAuthGracePeriodProvider = Provider<Duration>(
  (ref) => const Duration(seconds: AppConstants.splashTimeout),
);

@visibleForTesting
bool hasPendingWebAuthCallback(Uri uri, {required bool isWeb}) {
  if (!isWeb) return false;

  final fragment = uri.fragment;
  return fragment.contains('access_token=') ||
      fragment.contains('refresh_token=') ||
      fragment.contains('error=') ||
      fragment.contains('error_code=');
}

@visibleForTesting
SplashAuthDecision decideSplashAuthDecision({
  required bool isLoggedIn,
  required bool hasPendingCallback,
}) {
  if (isLoggedIn) {
    return SplashAuthDecision.continueAuthenticatedFlow;
  }

  if (hasPendingCallback) {
    return SplashAuthDecision.waitForWebAuthCallback;
  }

  return SplashAuthDecision.goToLogin;
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(ref.read(splashInitialDelayProvider));
    if (!mounted) return;

    final initialDecision = decideSplashAuthDecision(
      isLoggedIn: ref.read(supabaseClientProvider).auth.currentUser != null,
      hasPendingCallback: hasPendingWebAuthCallback(
        ref.read(splashBaseUriProvider),
        isWeb: ref.read(splashIsWebProvider),
      ),
    );

    if (initialDecision == SplashAuthDecision.waitForWebAuthCallback) {
      final restored = await _waitForWebAuthCallback();
      if (!mounted) return;
      if (!restored) {
        context.go('/auth/login');
        return;
      }
    } else if (initialDecision == SplashAuthDecision.goToLogin) {
      context.go('/auth/login');
      return;
    }

    final isLoggedIn = ref.read(isAuthenticatedProvider);

    if (!isLoggedIn) {
      context.go('/auth/login');
      return;
    }

    final hasOrg = ref.read(currentOrgIdProvider) != null;

    if (hasOrg) {
      context.go('/orders');
    } else {
      final orgs = await ref.read(userOrganizationsProvider.future);

      if (!mounted) return;

      if (orgs.length == 1) {
        ref.read(currentOrgIdProvider.notifier).select(orgs.first.id);
        context.go('/orders');
      } else {
        context.go('/org/select');
      }
    }
  }

  Future<bool> _waitForWebAuthCallback() async {
    final client = ref.read(supabaseClientProvider);
    final deadline = DateTime.now().add(
      ref.read(splashWebAuthGracePeriodProvider),
    );

    while (DateTime.now().isBefore(deadline)) {
      if (client.auth.currentUser != null) {
        return true;
      }

      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return false;
    }

    return client.auth.currentUser != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DeskflowColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: DeskflowColors.glassSurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: DeskflowColors.glassBorder,
                  width: 0.5,
                ),
              ),
              child: const Icon(
                Icons.business_center_rounded,
                size: 40,
                color: DeskflowColors.primarySolid,
              ),
            ),
            const SizedBox(height: DeskflowSpacing.lg),
            Text(
              'Deskflow',
              style: DeskflowTypography.h1.copyWith(
                color: DeskflowColors.primarySolid,
              ),
            ),
            const SizedBox(height: DeskflowSpacing.xl),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DeskflowColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
