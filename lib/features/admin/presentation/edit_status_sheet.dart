import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/glass_text_field.dart';
import 'package:deskflow/core/widgets/pill_button.dart';
import 'package:deskflow/features/admin/domain/admin_providers.dart';
import 'package:deskflow/features/orders/domain/order_status.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

const _statusColors = [
  '#6B7280', // gray
  '#3B82F6', // blue
  '#8B5CF6', // purple
  '#EC4899', // pink
  '#EF4444', // red
  '#F97316', // orange
  '#EAB308', // yellow
  '#22C55E', // green
  '#14B8A6', // teal
  '#06B6D4', // cyan
];

class EditStatusSheet extends HookConsumerWidget {
  final OrderStatus? status;
  final VoidCallback onSaved;

  const EditStatusSheet({
    super.key,
    this.status,
    required this.onSaved,
  });

  bool get isEditing => status != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController =
        useTextEditingController(text: status?.name ?? '');
    final selectedColor = useState(status?.color ?? _statusColors[0]);
    final isDefault = useState(status?.isDefault ?? false);
    final isFinal = useState(status?.isFinal ?? false);
    final isLoading = useState(false);
    final formKey = useMemoized(() => GlobalKey<FormState>());

    Future<void> save() async {
      if (!formKey.currentState!.validate()) return;

      final orgId = ref.read(currentOrgIdProvider);
      if (orgId == null) return;

      isLoading.value = true;
      try {
        final repo = ref.read(adminRepositoryProvider);

        if (isEditing) {
          await repo.updateStatus(
            statusId: status!.id,
            orgId: orgId,
            name: nameController.text.trim(),
            color: selectedColor.value,
            isDefault: isDefault.value,
            isFinal: isFinal.value,
          );
        } else {
          final pipeline =
              await ref.read(adminPipelineProvider.future);
          await repo.createStatus(
            orgId: orgId,
            name: nameController.text.trim(),
            color: selectedColor.value,
            sortOrder: pipeline.length,
            isDefault: isDefault.value,
            isFinal: isFinal.value,
          );
        }

        onSaved();
        if (context.mounted) Navigator.pop(context);
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

    return Container(
      decoration: const BoxDecoration(
        color: DeskflowColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DeskflowRadius.xl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        DeskflowSpacing.lg,
        DeskflowSpacing.md,
        DeskflowSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + DeskflowSpacing.lg,
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DeskflowColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: DeskflowSpacing.lg),

            Text(
              isEditing ? 'Редактировать статус' : 'Новый статус',
              style: DeskflowTypography.h2,
            ),
            const SizedBox(height: DeskflowSpacing.xl),

            GlassTextField(
              label: 'Название',
              hint: 'Например: В работе',
              controller: nameController,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Введите название';
                }
                return null;
              },
            ),
            const SizedBox(height: DeskflowSpacing.xl),

            Text('Цвет', style: DeskflowTypography.caption),
            const SizedBox(height: DeskflowSpacing.sm),
            Wrap(
              spacing: DeskflowSpacing.sm,
              runSpacing: DeskflowSpacing.sm,
              children: _statusColors.map((hex) {
                final color = _hexToColor(hex);
                final selected = selectedColor.value == hex;
                return GestureDetector(
                  onTap: () => selectedColor.value = hex,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(
                              color: Colors.white,
                              width: 2.5,
                            )
                          : null,
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: DeskflowSpacing.xl),

            SwitchListTile(
              title: const Text('По умолчанию',
                  style: DeskflowTypography.body),
              subtitle: Text(
                'Новые заказы получат этот статус',
                style: DeskflowTypography.caption,
              ),
              value: isDefault.value,
              onChanged: (v) {
                isDefault.value = v;
                if (v) isFinal.value = false;
              },
              activeThumbColor: DeskflowColors.primarySolid,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Финальный статус',
                  style: DeskflowTypography.body),
              subtitle: Text(
                'Обозначает завершение заказа',
                style: DeskflowTypography.caption,
              ),
              value: isFinal.value,
              onChanged: (v) {
                isFinal.value = v;
                if (v) isDefault.value = false;
              },
              activeThumbColor: DeskflowColors.successSolid,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: DeskflowSpacing.xl),

            PillButton(
              label: 'Сохранить',
              onPressed: save,
              isLoading: isLoading.value,
            ),
          ],
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
