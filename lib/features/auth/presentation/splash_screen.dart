import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

/// Splash screen — checks auth session, auto-redirects.
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
    // Small delay for splash feel
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final isLoggedIn = ref.read(isAuthenticatedProvider);

    if (!isLoggedIn) {
      context.go('/auth/login');
      return;
    }

    // Check if user has an org selected
    final hasOrg = ref.read(currentOrgIdProvider) != null;

    if (hasOrg) {
      context.go('/orders');
    } else {
      // Try to auto-select if user has exactly one org
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DeskflowColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glass logo
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
