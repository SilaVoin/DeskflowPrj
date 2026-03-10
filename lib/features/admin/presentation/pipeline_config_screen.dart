import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/core/widgets/error_state_widget.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/skeleton_loader.dart';
import 'package:deskflow/core/widgets/status_pill_badge.dart';
import 'package:deskflow/features/admin/domain/admin_providers.dart';
import 'package:deskflow/features/admin/presentation/edit_status_sheet.dart';
import 'package:deskflow/features/orders/domain/order_status.dart';

final _log = AppLogger.getLogger('PipelineConfigScreen');

/// Admin screen — configure order status pipeline (drag-and-drop list).
class PipelineConfigScreen extends HookConsumerWidget {
  const PipelineConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pipelineAsync = ref.watch(adminPipelineProvider);

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      appBar: AppBar(
        title: const Text('Настройка статусов'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: DeskflowColors.primarySolid,
        child: const Icon(Icons.add_rounded),
        onPressed: () => _showEditSheet(context, ref, null),
      ),
      body: pipelineAsync.when(
        data: (statuses) {
          if (statuses.isEmpty) {
            return const Center(
              child: Text(
                'Нет статусов. Создайте первый.',
                style: DeskflowTypography.body,
              ),
            );
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(DeskflowSpacing.lg),
            itemCount: statuses.length,
            onReorder: (oldIndex, newIndex) =>
                _onReorder(ref, statuses, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final status = statuses[index];
              return _StatusCard(
                key: ValueKey(status.id),
                status: status,
                onEdit: () => _showEditSheet(context, ref, status),
                onDelete: () =>
                    _showDeleteDialog(context, ref, status),
              );
            },
          );
        },
        loading: () => const _PipelineLoadingSkeleton(),
        error: (error, _) => ErrorStateWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(adminPipelineProvider),
        ),
      ),
    );
  }

  void _showEditSheet(
    BuildContext context,
    WidgetRef ref,
    OrderStatus? status,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditStatusSheet(
        status: status,
        onSaved: () => ref.invalidate(adminPipelineProvider),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    OrderStatus status,
  ) async {
    if (status.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Нельзя удалить статус по умолчанию. Сначала смените его.'),
        ),
      );
      return;
    }

    // Check if orders use this status
    final count = await ref
        .read(adminRepositoryProvider)
        .countOrdersWithStatus(status.id);

    if (!context.mounted) return;

    if (count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Нельзя удалить: $count заказов используют этот статус',
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DeskflowColors.modalSurface,
        title: const Text('Удалить статус'),
        content: Text('Удалить статус «${status.name}»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(adminRepositoryProvider)
                    .deleteStatus(status.id);
                ref.invalidate(adminPipelineProvider);
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

  Future<void> _onReorder(
    WidgetRef ref,
    List<OrderStatus> statuses,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex--;
    final ids = statuses.map((s) => s.id).toList();
    final id = ids.removeAt(oldIndex);
    ids.insert(newIndex, id);

    try {
      await ref.read(adminRepositoryProvider).reorderStatuses(ids);
      ref.invalidate(adminPipelineProvider);
    } catch (e) {
      _log.e('reorder failed: $e');
    }
  }
}

/// Single status card with drag handle.
class _StatusCard extends StatelessWidget {
  final OrderStatus status;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StatusCard({
    super.key,
    required this.status,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DeskflowSpacing.sm),
      child: GlassCard(
        child: Row(
          children: [
            // Drag handle
            const Icon(
              Icons.drag_handle_rounded,
              color: DeskflowColors.textTertiary,
              size: 20,
            ),
            const SizedBox(width: DeskflowSpacing.md),

            // Color dot
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: status.materialColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: DeskflowSpacing.md),

            // Name + badges
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      status.name,
                      style: DeskflowTypography.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (status.isDefault) ...[
                    const SizedBox(width: DeskflowSpacing.sm),
                    const StatusPillBadge(
                      label: 'По умолчанию',
                      color: DeskflowColors.primarySolid,
                    ),
                  ],
                  if (status.isFinal) ...[
                    const SizedBox(width: DeskflowSpacing.sm),
                    const StatusPillBadge(
                      label: 'Финальный',
                      color: DeskflowColors.successSolid,
                    ),
                  ],
                ],
              ),
            ),

            // Menu
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: DeskflowColors.textSecondary,
                size: 20,
              ),
              color: DeskflowColors.glassSurface,
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Редактировать'),
                ),
                PopupMenuItem(
                  value: 'delete',
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
      ),
    );
  }
}

/// Loading skeleton.
class _PipelineLoadingSkeleton extends StatelessWidget {
  const _PipelineLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: ListView.separated(
        padding: const EdgeInsets.all(DeskflowSpacing.lg),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: DeskflowSpacing.sm),
        itemBuilder: (_, _) => SkeletonLoader.box(height: 64),
      ),
    );
  }
}
