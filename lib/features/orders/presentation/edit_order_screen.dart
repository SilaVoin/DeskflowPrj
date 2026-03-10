import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:deskflow/core/errors/deskflow_exception.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/currency_formatter.dart';
import 'package:deskflow/core/widgets/error_state_widget.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/glass_text_field.dart';
import 'package:deskflow/core/widgets/pill_button.dart';
import 'package:deskflow/core/widgets/skeleton_loader.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/orders/domain/order_notifier.dart';
import 'package:deskflow/features/orders/domain/order_providers.dart';

/// Edit order screen — allows editing delivery cost, notes, and customer.
class EditOrderScreen extends HookConsumerWidget {
  final String orderId;

  const EditOrderScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return orderAsync.when(
      data: (order) => _EditOrderForm(order: order),
      loading: () => Scaffold(
        backgroundColor: DeskflowColors.background,
        appBar: AppBar(title: const Text('Загрузка...')),
        body: SkeletonLoader(
          child: ListView(
            padding: const EdgeInsets.all(DeskflowSpacing.lg),
            children: [
              SkeletonLoader.box(height: 120),
              const SizedBox(height: DeskflowSpacing.lg),
              SkeletonLoader.box(height: 200),
            ],
          ),
        ),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: DeskflowColors.background,
        appBar: AppBar(title: const Text('Ошибка')),
        body: ErrorStateWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
        ),
      ),
    );
  }
}

class _EditOrderForm extends HookConsumerWidget {
  final Order order;

  const _EditOrderForm({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesController =
        useTextEditingController(text: order.notes ?? '');
    final deliveryCostController = useTextEditingController(
      text: order.deliveryCost.toStringAsFixed(2),
    );
    final orderState = ref.watch(orderNotifierProvider);
    final isLoading = orderState.isLoading;

    ref.listen<AsyncValue<void>>(orderNotifierProvider, (_, next) {
      if (next.hasError) {
        final error = next.error;
        final message = error is DeskflowException
            ? error.message
            : 'Произошла ошибка';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: DeskflowColors.destructiveSolid,
          ),
        );
      }
    });

    Future<void> save() async {
      final deliveryCost =
          double.tryParse(deliveryCostController.text.trim()) ?? 0;
      final notes = notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim();

      final success = await ref
          .read(orderNotifierProvider.notifier)
          .updateOrder(
            orderId: order.id,
            deliveryCost: deliveryCost,
            notes: notes,
          );

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заказ обновлён')),
        );
        context.pop();
      }
    }

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('Редактировать ${order.formattedNumber}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: DeskflowSpacing.md),
            child: PillButton(
              label: 'Сохранить',
              isLoading: isLoading,
              onPressed: isLoading ? null : save,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DeskflowSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order number info
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Заказ ${order.formattedNumber}',
                      style: DeskflowTypography.h3,
                    ),
                    if (order.customerName != null) ...[
                      const SizedBox(height: DeskflowSpacing.xs),
                      Text(
                        'Клиент: ${order.customerName}',
                        style: DeskflowTypography.bodySmall,
                      ),
                    ],
                    if (order.status != null) ...[
                      const SizedBox(height: DeskflowSpacing.xs),
                      Text(
                        'Статус: ${order.status!.name}',
                        style: DeskflowTypography.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: DeskflowSpacing.lg),

              // Delivery cost
              const Text('Стоимость доставки',
                  style: DeskflowTypography.h3),
              const SizedBox(height: DeskflowSpacing.sm),
              GlassCard(
                child: GlassTextField(
                  label: 'Доставка',
                  hint: '0.00',
                  controller: deliveryCostController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                ),
              ),

              const SizedBox(height: DeskflowSpacing.lg),

              // Notes
              const Text('Заметки', style: DeskflowTypography.h3),
              const SizedBox(height: DeskflowSpacing.sm),
              GlassCard(
                child: GlassTextField(
                  label: 'Заметки к заказу',
                  hint: 'Комментарий...',
                  controller: notesController,
                  maxLines: 5,
                  minLines: 3,
                ),
              ),

              const SizedBox(height: DeskflowSpacing.lg),

              // Items summary (read-only)
              if (order.items.isNotEmpty) ...[
                const Text('Товары', style: DeskflowTypography.h3),
                const SizedBox(height: DeskflowSpacing.sm),
                GlassCard(
                  child: Column(
                    children: [
                      ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.only(
                                bottom: DeskflowSpacing.sm),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.productName} ×${item.quantity}',
                                    style: DeskflowTypography.body,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.formatCompact(item.unitPrice * item.quantity),
                                  style: DeskflowTypography.body
                                      .copyWith(
                                          fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          )),
                      const Divider(
                        color: DeskflowColors.glassBorder,
                      ),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Итого товары',
                              style: DeskflowTypography.body),
                          Text(
                            // Items subtotal (items only, excluding delivery)
                            CurrencyFormatter.formatCompact(order.itemsTotal),
                            style: DeskflowTypography.body.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: DeskflowSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
