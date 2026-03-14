import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/errors/deskflow_exception.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/features/orders/domain/order_notifier.dart';
import 'package:deskflow/features/orders/domain/order_providers.dart';
import 'package:deskflow/features/orders/domain/order_status.dart';

class StatusChangeSheet extends ConsumerWidget {
  const StatusChangeSheet({
    super.key,
    required this.orderId,
    required this.currentStatusId,
  });

  final String orderId;
  final String currentStatusId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pipelineAsync = ref.watch(pipelineProvider);

    ref.listen<AsyncValue<void>>(orderNotifierProvider, (_, next) {
      if (next.hasValue && !next.isLoading) {
        Navigator.pop(context);
      }
      if (next.hasError) {
        final error = next.error;
        final message = error is DeskflowException
            ? error.message
            : 'Не удалось сменить статус';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: DeskflowColors.destructiveSolid,
          ),
        );
      }
    });

    return Container(
      decoration: const BoxDecoration(
        color: DeskflowColors.modalSurface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DeskflowRadius.xl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DeskflowSpacing.lg,
            DeskflowSpacing.md,
            DeskflowSpacing.lg,
            DeskflowSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(
                      bottom: DeskflowSpacing.lg),
                  decoration: BoxDecoration(
                    color: DeskflowColors.textTertiary,
                    borderRadius:
                        BorderRadius.circular(DeskflowRadius.pill),
                  ),
                ),
              ),

              const Text('Сменить статус',
                  style: DeskflowTypography.h2),
              const SizedBox(height: DeskflowSpacing.lg),

              pipelineAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: DeskflowColors.primarySolid,
                  ),
                ),
                error: (e, _) => Text('Ошибка: $e',
                    style: DeskflowTypography.bodySmall),
                data: (pipeline) => _PipelineView(
                  pipeline: pipeline,
                  currentStatusId: currentStatusId,
                  orderId: orderId,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PipelineView extends ConsumerWidget {
  const _PipelineView({
    required this.pipeline,
    required this.currentStatusId,
    required this.orderId,
  });

  final List<OrderStatus> pipeline;
  final String currentStatusId;
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifierState = ref.watch(orderNotifierProvider);
    final isLoading = notifierState.isLoading;

    final currentIndex =
        pipeline.indexWhere((s) => s.id == currentStatusId);

    return Column(
      children: List.generate(pipeline.length, (i) {
        final status = pipeline[i];
        final isCurrent = status.id == currentStatusId;
        final isPast = i < currentIndex;
        final isNext = i == currentIndex + 1;

        return Padding(
          padding:
              const EdgeInsets.only(bottom: DeskflowSpacing.sm),
          child: GlassCard(
            onTap: isCurrent || isPast || isLoading
                ? null
                : () => _changeStatus(ref, status),
            borderColor: isCurrent
                ? status.materialColor.withValues(alpha: 0.6)
                : isNext
                    ? DeskflowColors.primarySolid
                        .withValues(alpha: 0.3)
                    : null,
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPast || isCurrent
                        ? status.materialColor
                        : status.materialColor.withValues(alpha: 0.3),
                    border: isCurrent
                        ? Border.all(
                            color: Colors.white,
                            width: 2,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: DeskflowSpacing.md),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.name,
                        style: DeskflowTypography.body.copyWith(
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: isPast
                              ? DeskflowColors.textTertiary
                              : null,
                        ),
                      ),
                      if (isCurrent)
                        Text('Текущий статус',
                            style: DeskflowTypography.caption),
                      if (isNext)
                        Text('Следующий',
                            style: DeskflowTypography.caption
                                .copyWith(
                                    color: DeskflowColors
                                        .primarySolid)),
                    ],
                  ),
                ),

                if (isPast)
                  const Icon(Icons.check_circle_rounded,
                      size: 20,
                      color: DeskflowColors.successSolid),
                if (isCurrent)
                  const Icon(Icons.radio_button_checked_rounded,
                      size: 20,
                      color: DeskflowColors.primarySolid),
                if (!isCurrent && !isPast)
                  Icon(Icons.circle_outlined,
                      size: 20,
                      color:
                          DeskflowColors.textTertiary),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _changeStatus(WidgetRef ref, OrderStatus newStatus) async {
    final currentStatus = pipeline.firstWhere(
      (s) => s.id == currentStatusId,
      orElse: () => pipeline.first,
    );

    await ref.read(orderNotifierProvider.notifier).changeStatus(
          orderId: orderId,
          newStatusId: newStatus.id,
          oldStatusName: currentStatus.name,
          newStatusName: newStatus.name,
        );
  }
}
