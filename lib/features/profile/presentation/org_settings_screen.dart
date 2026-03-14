import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/glass_text_field.dart';
import 'package:deskflow/core/widgets/pill_button.dart';
import 'package:deskflow/core/utils/pluralize_ru.dart';
import 'package:deskflow/features/admin/domain/admin_providers.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

class OrgSettingsScreen extends HookConsumerWidget {
  const OrgSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(userOrganizationsProvider);
    final orgId = ref.watch(currentOrgIdProvider);
    final nameController = useTextEditingController();
    final isLoading = useState(false);
    final initialized = useState(false);

    orgsAsync.whenData((orgs) {
      if (!initialized.value) {
        final org = orgs.where((o) => o.id == orgId).firstOrNull;
        if (org != null) {
          nameController.text = org.name;
          initialized.value = true;
        }
      }
    });

    Future<void> saveName() async {
      if (orgId == null) return;
      final name = nameController.text.trim();
      if (name.isEmpty) return;

      isLoading.value = true;
      try {
        await ref.read(adminRepositoryProvider).updateOrganization(
              orgId: orgId,
              name: name,
            );
        ref.invalidate(userOrganizationsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Название обновлено')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    void showDeleteConfirmation() {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Удалить организацию'),
          content: const Text(
            'Вы уверены? Это действие нельзя отменить. '
            'Все данные организации будут удалены.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx2) => AlertDialog(
                    title: const Text('Точно удалить?'),
                    content: const Text(
                      'Введите УДАЛИТЬ для подтверждения.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx2, false),
                        child: const Text('Отмена'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx2, true),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              DeskflowColors.destructiveSolid,
                        ),
                        child: const Text('Удалить навсегда'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;

                try {
                  await ref
                      .read(adminRepositoryProvider)
                      .deleteOrganization(orgId!);
                  ref.read(currentOrgIdProvider.notifier).clear();
                  ref.invalidate(userOrganizationsProvider);
                  if (context.mounted) {
                    context.go('/org/select');
                  }
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

    final membersAsync = ref.watch(orgMembersProvider);

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      appBar: AppBar(
        title: const Text('Настройки организации'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DeskflowSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Основное', style: DeskflowTypography.caption),
                  const SizedBox(height: DeskflowSpacing.md),
                  GlassTextField(
                    label: 'Название организации',
                    hint: 'Моя компания',
                    controller: nameController,
                  ),
                  const SizedBox(height: DeskflowSpacing.lg),
                  PillButton(
                    label: 'Сохранить',
                    onPressed: saveName,
                    isLoading: isLoading.value,
                  ),
                ],
              ),
            ),

            const SizedBox(height: DeskflowSpacing.lg),

            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Участники', style: DeskflowTypography.caption),
                  const SizedBox(height: DeskflowSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      membersAsync.when(
                        data: (members) => Text(
                          pluralizeRu(members.length, 'участник', 'участника', 'участников'),
                          style: DeskflowTypography.body,
                        ),
                        loading: () => const Text(
                          'Загрузка...',
                          style: DeskflowTypography.body,
                        ),
                        error: (_, _) => const Text(
                          'Ошибка',
                          style: DeskflowTypography.body,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.people_rounded, size: 18),
                        label: const Text('Управление'),
                        onPressed: () => context.push('/admin/users'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: DeskflowSpacing.xxl),

            Container(
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(DeskflowRadius.lg),
                border: Border.all(
                  color: DeskflowColors.destructiveSolid
                      .withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Опасная зона',
                      style: DeskflowTypography.caption.copyWith(
                        color: DeskflowColors.destructiveSolid,
                      ),
                    ),
                    const SizedBox(height: DeskflowSpacing.md),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: const Text('Удалить организацию'),
                      onPressed: showDeleteConfirmation,
                      style: TextButton.styleFrom(
                        foregroundColor:
                            DeskflowColors.destructiveSolid,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
