import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/error_state_widget.dart';
import 'package:deskflow/core/widgets/floating_island_nav.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/glass_floating_action_button.dart';
import 'package:deskflow/core/widgets/skeleton_loader.dart';
import 'package:deskflow/core/widgets/status_pill_badge.dart';
import 'package:deskflow/features/admin/data/admin_repository.dart';
import 'package:deskflow/features/admin/domain/admin_providers.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/org/domain/org_member.dart';

class UserManagementScreen extends HookConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(orgMembersProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      appBar: AppBar(
        title: const Text('Участники'),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: FloatingIslandNav.totalHeight(context) + 16,
        ),
        child: GlassFloatingActionButton(
          icon: Icons.person_add_rounded,
          onPressed: () => context.push('/admin/users/invite'),
        ),
      ),
      body: membersAsync.when(
        skipLoadingOnRefresh: false,
        data: (members) {
          if (members.isEmpty) {
            return const Center(
              child: Text('Нет участников', style: DeskflowTypography.body),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(DeskflowSpacing.lg),
            itemCount: members.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: DeskflowSpacing.sm),
            itemBuilder: (_, index) {
              final member = members[index];
              final isCurrentUser = member.userId == currentUser?.id;

              return _MemberCard(
                member: member,
                isCurrentUser: isCurrentUser,
                onChangeRole: () => _showRoleDialog(
                  context,
                  ref,
                  member,
                  members,
                ),
                onRemove: () => _showRemoveDialog(
                  context,
                  ref,
                  member,
                  members,
                ),
              );
            },
          );
        },
        loading: () => const _MembersLoadingSkeleton(),
        error: (error, _) => ErrorStateWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(orgMembersProvider),
        ),
      ),
    );
  }

  void _showRoleDialog(
    BuildContext context,
    WidgetRef ref,
    MemberWithProfile member,
    List<MemberWithProfile> allMembers,
  ) {
    final ownerCount =
        allMembers.where((m) => m.role == OrgRole.owner).length;
    if (member.role == OrgRole.owner && ownerCount <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нельзя сменить роль единственного владельца'),
        ),
      );
      return;
    }

    final availableRoles =
        OrgRole.values.where((r) => r != member.role).toList();

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Сменить роль: ${member.fullName ?? "участника"}'),
        children: availableRoles.map((newRole) {
          return SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Смена роли...'),
                        ],
                      ),
                      duration: Duration(seconds: 10),
                    ),
                  );
              }
              try {
                await ref.read(adminRepositoryProvider).changeRole(
                      memberId: member.id,
                      newRole: newRole,
                    );
                ref.invalidate(orgMembersProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          'Роль изменена на "${newRole.label}"',
                        ),
                      ),
                    );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                }
              }
            },
            child: Text(newRole.label),
          );
        }).toList(),
      ),
    );
  }

  void _showRemoveDialog(
    BuildContext context,
    WidgetRef ref,
    MemberWithProfile member,
    List<MemberWithProfile> allMembers,
  ) {
    final ownerCount =
        allMembers.where((m) => m.role == OrgRole.owner).length;
    if (member.role == OrgRole.owner && ownerCount <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нельзя удалить единственного владельца'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить участника'),
        content: Text(
          'Удалить ${member.fullName ?? 'участника'} из организации?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(adminRepositoryProvider).removeMember(
                      member.id,
                    );
                ref.invalidate(orgMembersProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: DeskflowColors.destructiveSolid,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final MemberWithProfile member;
  final bool isCurrentUser;
  final VoidCallback onChangeRole;
  final VoidCallback onRemove;

  const _MemberCard({
    required this.member,
    required this.isCurrentUser,
    required this.onChangeRole,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final roleColor = switch (member.role) {
      OrgRole.owner => DeskflowColors.successSolid,
      OrgRole.admin => DeskflowColors.warningSolid,
      OrgRole.member => DeskflowColors.primarySolid,
    };

    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: DeskflowColors.glassSurface,
              shape: BoxShape.circle,
              border: Border.all(
                color: DeskflowColors.glassBorder,
                width: 0.5,
              ),
            ),
            child: Center(
              child: Text(
                member.initials,
                style: DeskflowTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: DeskflowSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.fullName ?? 'Без имени',
                        style: DeskflowTypography.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser)
                      Text(
                        ' (вы)',
                        style: DeskflowTypography.caption.copyWith(
                          color: DeskflowColors.textTertiary,
                        ),
                      ),
                  ],
                ),
                if (member.email != null)
                  Text(
                    member.email!,
                    style: DeskflowTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          const SizedBox(width: DeskflowSpacing.sm),

          StatusPillBadge(label: member.role.label, color: roleColor),

          if (!isCurrentUser)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: DeskflowColors.textSecondary,
                size: 20,
              ),
              color: DeskflowColors.glassSurface,
              onSelected: (value) {
                if (value == 'role') onChangeRole();
                if (value == 'remove') onRemove();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'role',
                  child: Text('Сменить роль'),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: Text(
                    'Удалить',
                    style: TextStyle(
                      color: DeskflowColors.destructiveSolid,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MembersLoadingSkeleton extends StatelessWidget {
  const _MembersLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: ListView.separated(
        padding: const EdgeInsets.all(DeskflowSpacing.lg),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: DeskflowSpacing.sm),
        itemBuilder: (_, _) => SkeletonLoader.box(height: 72),
      ),
    );
  }
}
