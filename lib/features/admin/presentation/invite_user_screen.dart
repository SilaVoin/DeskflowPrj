import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:deskflow/core/errors/deskflow_exception.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/glass_text_field.dart';
import 'package:deskflow/core/widgets/pill_button.dart';
import 'package:deskflow/features/admin/domain/admin_providers.dart';
import 'package:deskflow/features/org/domain/org_member.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

final _log = AppLogger.getLogger('InviteUserScreen');

/// Screen for inviting a new user to the organization.
class InviteUserScreen extends HookConsumerWidget {
  const InviteUserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    final selectedRole = useState(OrgRole.member);
    final isLoading = useState(false);
    final formKey = useMemoized(() => GlobalKey<FormState>());

    Future<void> invite() async {
      if (!formKey.currentState!.validate()) return;

      final orgId = ref.read(currentOrgIdProvider);
      if (orgId == null) return;

      isLoading.value = true;
      try {
        await ref.read(adminRepositoryProvider).inviteMember(
              orgId: orgId,
              email: emailController.text.trim(),
              role: selectedRole.value,
            );
        ref.invalidate(orgMembersProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Участник добавлен')),
          );
          context.pop();
        }
      } catch (e) {
        _log.w('[FIX] inviteMember error: $e');
        if (context.mounted) {
          // [FIX] Show DeskflowException.message, not toString()
          final message = e is DeskflowException
              ? e.message
              : 'Произошла ошибка';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    // Get invite code for copy
    final orgsAsync = ref.watch(userOrganizationsProvider);
    final orgId = ref.watch(currentOrgIdProvider);

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      appBar: AppBar(
        title: const Text('Пригласить участника'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DeskflowSpacing.lg),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Email field
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('По email', style: DeskflowTypography.caption),
                    const SizedBox(height: DeskflowSpacing.md),
                    GlassTextField(
                      label: 'Email',
                      hint: 'user@example.com',
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Введите email';
                        }
                        if (!v.contains('@')) {
                          return 'Некорректный email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: DeskflowSpacing.lg),

                    // Role picker
                    Text('Роль', style: DeskflowTypography.caption),
                    const SizedBox(height: DeskflowSpacing.sm),
                    Row(
                      children: OrgRole.values.map((role) {
                        final selected = selectedRole.value == role;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: role != OrgRole.values.last
                                  ? DeskflowSpacing.sm
                                  : 0,
                            ),
                            child: GestureDetector(
                              onTap: () => selectedRole.value = role,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: DeskflowSpacing.md,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? DeskflowColors.primarySolid
                                          .withValues(alpha: 0.2)
                                      : DeskflowColors.glassSurface,
                                  borderRadius: BorderRadius.circular(
                                    DeskflowRadius.md,
                                  ),
                                  border: Border.all(
                                    color: selected
                                        ? DeskflowColors.primarySolid
                                        : DeskflowColors.glassBorder,
                                    width: selected ? 1.5 : 0.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    role.label,
                                    style: DeskflowTypography.body.copyWith(
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: selected
                                          ? DeskflowColors.primarySolid
                                          : DeskflowColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: DeskflowSpacing.xl),
                    PillButton(
                      label: 'Отправить приглашение',
                      onPressed: invite,
                      isLoading: isLoading.value,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: DeskflowSpacing.xl),

              // Invite code section
              orgsAsync.when(
                data: (orgs) {
                  final currentOrg = orgs
                      .where((o) => o.id == orgId)
                      .firstOrNull;
                  if (currentOrg?.inviteCode == null) {
                    return const SizedBox.shrink();
                  }

                  // [FIX] Build invite link with code query param
                  // Works for web (hash routing) and as deep link
                  const webHost = 'https://deskflow.app';
                  final joinLink =
                      '$webHost/org/join?code=${currentOrg!.inviteCode}';

                  final inviteMessage =
                      'Присоединяйтесь к организации '
                      '«${currentOrg.name}» в Deskflow!\n\n'
                      'Перейдите по ссылке:\n$joinLink\n\n'
                      'Или введите код приглашения вручную: '
                      '${currentOrg.inviteCode}';

                  return GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Или по коду приглашения',
                          style: DeskflowTypography.caption,
                        ),
                        const SizedBox(height: DeskflowSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: DeskflowSpacing.md,
                                  vertical: DeskflowSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: DeskflowColors.glassSurface,
                                  borderRadius: BorderRadius.circular(
                                    DeskflowRadius.md,
                                  ),
                                ),
                                child: Text(
                                  currentOrg.inviteCode!,
                                  style: DeskflowTypography.body.copyWith(
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: DeskflowSpacing.sm),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded),
                              tooltip: 'Копировать код',
                              onPressed: () {
                                _log.d('[FIX] Copying invite code for '
                                    'org=${currentOrg.name}');
                                Clipboard.setData(ClipboardData(
                                  text: currentOrg.inviteCode!,
                                ));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Код скопирован'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: DeskflowSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: PillButton(
                            label: 'Поделиться приглашением',
                            icon: Icons.share_rounded,
                            onPressed: () async {
                              _log.d('[FIX] Sharing invite link for '
                                  'org=${currentOrg.name}, '
                                  'code=${currentOrg.inviteCode}');
                              try {
                                final result = await Share.share(
                                  inviteMessage,
                                  subject: 'Приглашение в '
                                      '${currentOrg.name}',
                                );
                                _log.d('[FIX] Share result: '
                                    'status=${result.status}');
                              } catch (e) {
                                _log.e('[FIX] Share failed', error: e);
                                // Fallback: copy to clipboard
                                await Clipboard.setData(
                                  ClipboardData(text: inviteMessage),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Приглашение скопировано '
                                        'в буфер обмена',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
