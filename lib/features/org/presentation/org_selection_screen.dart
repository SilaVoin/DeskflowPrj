import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/pill_button.dart';
import 'package:deskflow/core/widgets/skeleton_loader.dart';
import 'package:deskflow/core/widgets/status_pill_badge.dart';
import 'package:deskflow/core/widgets/empty_state_widget.dart';
import 'package:deskflow/core/widgets/error_state_widget.dart';
import 'package:deskflow/features/org/domain/org_member.dart';
import 'package:deskflow/features/org/domain/org_notifier.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';
import 'package:deskflow/features/org/domain/organization.dart';

/// Organization selection screen — shown when user belongs to multiple orgs.
class OrgSelectionScreen extends ConsumerWidget {
  const OrgSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(userOrganizationsProvider);

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DeskflowSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: DeskflowSpacing.xxl),
              const Text(
                'Выберите организацию',
                style: DeskflowTypography.h1,
              ),
              const SizedBox(height: DeskflowSpacing.xl),

              // Org list from Supabase
              Expanded(
                child: orgsAsync.when(
                  data: (orgs) {
                    if (orgs.isEmpty) {
                      return const EmptyStateWidget(
                        icon: Icons.business_rounded,
                        title: 'Нет организаций',
                        description:
                            'Создайте новую организацию или присоединитесь по приглашению',
                      );
                    }
                    return ListView.separated(
                      itemCount: orgs.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: DeskflowSpacing.sm),
                      itemBuilder: (context, index) {
                        return _OrgCard(
                          org: orgs[index],
                          onTap: () {
                            ref
                                .read(orgNotifierProvider.notifier)
                                .selectOrganization(orgs[index]);
                            context.go('/orders');
                          },
                        );
                      },
                    );
                  },
                  loading: () => ListView.builder(
                    itemCount: 3,
                    itemBuilder: (_, _) => Padding(
                      padding: const EdgeInsets.only(
                          bottom: DeskflowSpacing.sm),
                      child: SkeletonLoader.box(
                        width: double.infinity,
                        height: 80,
                        borderRadius: DeskflowRadius.lg,
                      ),
                    ),
                  ),
                  error: (error, _) => ErrorStateWidget(
                    message: error.toString(),
                    onRetry: () =>
                        ref.invalidate(userOrganizationsProvider),
                  ),
                ),
              ),

              // Bottom actions
              PillButton(
                label: 'Создать организацию',
                icon: Icons.add_rounded,
                expanded: true,
                onPressed: () => context.push('/org/create'),
              ),
              const SizedBox(height: DeskflowSpacing.md),
              PillButton.secondary(
                label: 'Присоединиться по приглашению',
                icon: Icons.link_rounded,
                expanded: true,
                onPressed: () => context.push('/org/join'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrgCard extends StatelessWidget {
  const _OrgCard({required this.org, required this.onTap});
  final Organization org;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = org.name.isNotEmpty ? org.name[0].toUpperCase() : '?';
    final role = org.userRole != null
        ? OrgRole.fromString(org.userRole!)
        : OrgRole.member;
    final roleColor = switch (role) {
      OrgRole.owner => DeskflowColors.successSolid,
      OrgRole.admin => DeskflowColors.warningSolid,
      OrgRole.member => DeskflowColors.primarySolid,
    };

    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: DeskflowColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(initial, style: DeskflowTypography.h3),
            ),
          ),
          const SizedBox(width: DeskflowSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(org.name, style: DeskflowTypography.h3),
                const SizedBox(height: DeskflowSpacing.xs),
                StatusPillBadge(
                  label: role.label,
                  color: roleColor,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: DeskflowColors.textTertiary,
          ),
        ],
      ),
    );
  }
}
