import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:deskflow/core/errors/deskflow_exception.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/currency_formatter.dart';
import 'package:deskflow/core/widgets/error_state_widget.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/glass_chip.dart';
import 'package:deskflow/core/widgets/glass_text_field.dart';
import 'package:deskflow/core/widgets/pill_button.dart';
import 'package:deskflow/core/widgets/skeleton_loader.dart';
import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/orders/domain/order_composition.dart';
import 'package:deskflow/features/orders/domain/order_notifier.dart';
import 'package:deskflow/features/orders/domain/order_providers.dart';
import 'package:deskflow/features/orders/domain/order_template.dart';
import 'package:deskflow/features/products/domain/product.dart';

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
    final notesController = useTextEditingController(text: order.notes ?? '');
    final deliveryCostController = useTextEditingController(
      text: order.deliveryCost.toStringAsFixed(2),
    );
    final selectedCustomer = useState<Customer?>(
      order.customerId == null
          ? null
          : Customer(
              id: order.customerId!,
              organizationId: order.organizationId,
              name: order.customerName ?? 'Клиент',
              createdAt: order.createdAt,
            ),
    );
    final orderState = ref.watch(orderNotifierProvider);
    final isLoading = orderState.isLoading;
    final templatesAsync = ref.watch(orderTemplatesProvider);
    final recentCustomersAsync = ref.watch(recentOrderCustomersProvider);
    final recentProductsAsync = ref.watch(recentOrderProductsProvider);

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
            customerId: selectedCustomer.value?.id,
            deliveryCost: deliveryCost,
            notes: notes,
          );

      if (success && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Заказ обновлён')));
        context.pop();
      }
    }

    bool hasUnsavedChanges() {
      final currentDeliveryCost =
          double.tryParse(deliveryCostController.text.trim()) ?? 0;
      final currentNotes = notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim();

      return selectedCustomer.value?.id != order.customerId ||
          currentDeliveryCost != order.deliveryCost ||
          currentNotes != order.notes;
    }

    Future<bool> confirmLeaveForNewOrder() async {
      if (!hasUnsavedChanges()) {
        return true;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: DeskflowColors.glassSurfaceElevated,
          title: const Text('Перейти к новому заказу?'),
          content: const Text(
            'Несохранённые изменения в текущем заказе будут потеряны.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Остаться'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Перейти'),
            ),
          ],
        ),
      );

      return confirmed == true;
    }

    Future<void> saveAsTemplate() async {
      final controller = TextEditingController();
      final savedName = await showDialog<String>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.68),
        builder: (dialogContext) => AlertDialog(
          backgroundColor: DeskflowColors.modalSurface,
          surfaceTintColor: Colors.transparent,
          title: const Text('Новый шаблон'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Название шаблона'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Сохранить шаблон'),
            ),
          ],
        ),
      );

      if (savedName == null || savedName.isEmpty) return;

      final template = await ref
          .read(orderNotifierProvider.notifier)
          .saveOrderTemplate(
            name: savedName,
            composition: OrderComposition.fromOrderItems(order.items),
          );

      if (!context.mounted || template == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Шаблон "${template.name}" сохранён')),
      );
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
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Заказ ${order.formattedNumber}',
                      style: DeskflowTypography.h3,
                    ),
                    if (selectedCustomer.value != null) ...[
                      const SizedBox(height: DeskflowSpacing.xs),
                      Text(
                        'Клиент: ${selectedCustomer.value!.name}',
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

              GlassCard(
                elevated: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Быстрые источники',
                          style: DeskflowTypography.h3,
                        ),
                        TextButton(
                          onPressed: order.items.isEmpty
                              ? null
                              : saveAsTemplate,
                          child: const Text('Сохранить как шаблон'),
                        ),
                      ],
                    ),
                    const SizedBox(height: DeskflowSpacing.md),
                    _EditQuickSourceGroup<OrderTemplate>(
                      title: 'Шаблоны',
                      itemsAsync: templatesAsync,
                      labelBuilder: (template) => template.name,
                      onTap: (template) async {
                        if (!await confirmLeaveForNewOrder()) {
                          return;
                        }
                        if (!context.mounted) {
                          return;
                        }
                        context.push(
                          '/orders/create',
                          extra: template.composition,
                        );
                      },
                    ),
                    const SizedBox(height: DeskflowSpacing.md),
                    _EditQuickSourceGroup<Customer>(
                      title: 'Последние клиенты',
                      itemsAsync: recentCustomersAsync,
                      labelBuilder: (customer) => customer.name,
                      onTap: (customer) => selectedCustomer.value = customer,
                    ),
                    const SizedBox(height: DeskflowSpacing.md),
                    _EditQuickSourceGroup<Product>(
                      title: 'Последние товары',
                      itemsAsync: recentProductsAsync,
                      labelBuilder: (product) => product.name,
                      onTap: (product) async {
                        if (!await confirmLeaveForNewOrder()) {
                          return;
                        }
                        if (!context.mounted) {
                          return;
                        }
                        context.push(
                          '/orders/create',
                          extra: OrderComposition(
                            items: [
                              OrderCompositionItem(
                                productId: product.id,
                                productName: product.name,
                                unitPrice: product.price,
                                quantity: 1,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: DeskflowSpacing.lg),

              const Text('Стоимость доставки', style: DeskflowTypography.h3),
              const SizedBox(height: DeskflowSpacing.sm),
              GlassCard(
                child: GlassTextField(
                  label: 'Доставка',
                  hint: '0.00',
                  controller: deliveryCostController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),

              const SizedBox(height: DeskflowSpacing.lg),

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

              if (order.items.isNotEmpty) ...[
                const Text('Товары', style: DeskflowTypography.h3),
                const SizedBox(height: DeskflowSpacing.sm),
                GlassCard(
                  child: Column(
                    children: [
                      ...order.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: DeskflowSpacing.sm,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                CurrencyFormatter.formatCompact(
                                  item.unitPrice * item.quantity,
                                ),
                                style: DeskflowTypography.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(color: DeskflowColors.glassBorder),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Итого товары',
                            style: DeskflowTypography.body,
                          ),
                          Text(
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

class _EditQuickSourceGroup<T> extends StatelessWidget {
  const _EditQuickSourceGroup({
    required this.title,
    required this.itemsAsync,
    required this.labelBuilder,
    required this.onTap,
  });

  final String title;
  final AsyncValue<List<T>> itemsAsync;
  final String Function(T item) labelBuilder;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: DeskflowTypography.bodySmall.copyWith(
            color: DeskflowColors.textSecondary,
          ),
        ),
        const SizedBox(height: DeskflowSpacing.sm),
        itemsAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return Text(
                'Пока пусто',
                style: DeskflowTypography.bodySmall.copyWith(
                  color: DeskflowColors.textTertiary,
                ),
              );
            }

            return Wrap(
              spacing: DeskflowSpacing.sm,
              runSpacing: DeskflowSpacing.sm,
              children: items
                  .map(
                    (item) => GlassChip(
                      label: labelBuilder(item),
                      onTap: () => onTap(item),
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (error, stackTrace) => Text(
            'Не удалось загрузить',
            style: DeskflowTypography.bodySmall.copyWith(
              color: DeskflowColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}
