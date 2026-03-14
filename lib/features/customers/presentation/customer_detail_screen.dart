import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/currency_formatter.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/status_pill_badge.dart';
import 'package:deskflow/core/widgets/error_state_widget.dart';
import 'package:deskflow/core/widgets/skeleton_loader.dart';
import 'package:deskflow/core/widgets/empty_state_widget.dart';
import 'package:deskflow/features/customers/domain/customer_providers.dart';
import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/orders/domain/order.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerDetailProvider(customerId));
    final ordersAsync = ref.watch(customerOrdersProvider(customerId));

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      appBar: AppBar(
        title: const Text('Клиент'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => context.push('/customers/$customerId/edit'),
          ),
        ],
      ),
      body: customerAsync.when(
        data: (customer) => _CustomerContent(
          customer: customer,
          ordersAsync: ordersAsync,
          onRefresh: () {
            ref.invalidate(customerDetailProvider(customerId));
            ref.invalidate(customerOrdersProvider(customerId));
          },
        ),
        loading: () => const _CustomerDetailSkeleton(),
        error: (error, _) => ErrorStateWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(customerDetailProvider(customerId)),
        ),
      ),
    );
  }
}

class _CustomerContent extends StatelessWidget {
  final Customer customer;
  final AsyncValue<List<Order>> ordersAsync;
  final VoidCallback onRefresh;

  const _CustomerContent({
    required this.customer,
    required this.ordersAsync,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: DeskflowColors.primarySolid,
      backgroundColor: DeskflowColors.modalSurface,
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(DeskflowSpacing.lg),
        children: [
          _CustomerHeader(customer: customer),
          const SizedBox(height: DeskflowSpacing.lg),

          _ContactSection(customer: customer),
          const SizedBox(height: DeskflowSpacing.lg),

          _StatsSection(customer: customer),
          const SizedBox(height: DeskflowSpacing.lg),

          if (customer.notes != null && customer.notes!.isNotEmpty) ...[
            _NotesSection(notes: customer.notes!),
            const SizedBox(height: DeskflowSpacing.lg),
          ],

          _OrdersSection(ordersAsync: ordersAsync),
          const SizedBox(height: DeskflowSpacing.xxxl * 2),
        ],
      ),
    );
  }
}

class _CustomerHeader extends StatelessWidget {
  final Customer customer;

  const _CustomerHeader({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: DeskflowColors.primary,
            borderRadius: BorderRadius.circular(DeskflowRadius.xl),
          ),
          alignment: Alignment.center,
          child: Text(
            customer.initials,
            style: DeskflowTypography.h1.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: DeskflowSpacing.md),
        Text(
          customer.name,
          style: DeskflowTypography.h2,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DeskflowSpacing.md),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (customer.phone != null) ...[
              _QuickActionButton(
                icon: Icons.phone_rounded,
                label: 'Позвонить',
                onTap: () => _launchUrl('tel:${customer.phone}'),
              ),
              const SizedBox(width: DeskflowSpacing.lg),
            ],
            if (customer.email != null) ...[
              _QuickActionButton(
                icon: Icons.email_rounded,
                label: 'Написать',
                onTap: () => _launchUrl('mailto:${customer.email}'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: DeskflowColors.glassSurface,
              borderRadius: BorderRadius.circular(DeskflowRadius.md),
              border: Border.all(color: DeskflowColors.glassBorder),
            ),
            child: Icon(icon, color: DeskflowColors.primarySolid, size: 22),
          ),
          const SizedBox(height: DeskflowSpacing.xs),
          Text(label, style: DeskflowTypography.caption),
        ],
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  final Customer customer;

  const _ContactSection({required this.customer});

  @override
  Widget build(BuildContext context) {
    final hasContact = customer.phone != null ||
        customer.email != null ||
        customer.address != null;

    if (!hasContact) return const SizedBox.shrink();

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(DeskflowSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Контакты', style: DeskflowTypography.h3),
            const SizedBox(height: DeskflowSpacing.md),
            if (customer.phone != null)
              _ContactRow(
                icon: Icons.phone_rounded,
                value: customer.phone!,
              ),
            if (customer.email != null) ...[
              const SizedBox(height: DeskflowSpacing.sm),
              _ContactRow(
                icon: Icons.email_rounded,
                value: customer.email!,
              ),
            ],
            if (customer.address != null) ...[
              const SizedBox(height: DeskflowSpacing.sm),
              _ContactRow(
                icon: Icons.location_on_rounded,
                value: customer.address!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _ContactRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: DeskflowColors.textTertiary),
        const SizedBox(width: DeskflowSpacing.md),
        Expanded(
          child: Text(value, style: DeskflowTypography.bodySmall),
        ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  final Customer customer;

  const _StatsSection({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(DeskflowSpacing.lg),
              child: Column(
                children: [
                  Text(
                    '${customer.orderCount}',
                    style: DeskflowTypography.h2,
                  ),
                  const SizedBox(height: DeskflowSpacing.xs),
                  Text('Заказов', style: DeskflowTypography.caption),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: DeskflowSpacing.sm),
        Expanded(
          child: GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(DeskflowSpacing.lg),
              child: Column(
                children: [
                  Text(
                    CurrencyFormatter.formatCompact(customer.totalSpent),
                    style: DeskflowTypography.h2,
                  ),
                  const SizedBox(height: DeskflowSpacing.xs),
                  Text('Общая сумма', style: DeskflowTypography.caption),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotesSection extends StatelessWidget {
  final String notes;

  const _NotesSection({required this.notes});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(DeskflowSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Заметки', style: DeskflowTypography.h3),
            const SizedBox(height: DeskflowSpacing.sm),
            Text(notes, style: DeskflowTypography.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _OrdersSection extends StatelessWidget {
  final AsyncValue<List<Order>> ordersAsync;

  const _OrdersSection({required this.ordersAsync});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Заказы', style: DeskflowTypography.h3),
        const SizedBox(height: DeskflowSpacing.md),
        ordersAsync.when(
          data: (orders) {
            if (orders.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.receipt_long_rounded,
                title: 'Нет заказов',
                description: 'У этого клиента пока нет заказов',
              );
            }

            return Column(
              children: orders.map((order) {
                return Padding(
                  padding:
                      const EdgeInsets.only(bottom: DeskflowSpacing.sm),
                  child: GlassCard(
                    onTap: () =>
                        context.push('/orders/${order.id}'),
                    child: Padding(
                      padding:
                          const EdgeInsets.all(DeskflowSpacing.lg),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Заказ #${order.orderNumber}',
                                  style: DeskflowTypography.body,
                                ),
                                const SizedBox(
                                    height: DeskflowSpacing.xs),
                                Text(
                                  _formatDate(order.createdAt),
                                  style: DeskflowTypography.caption,
                                ),
                              ],
                            ),
                          ),
                          if (order.status != null)
                            StatusPillBadge(
                              label: order.status!.name,
                              color: order.status!.materialColor,
                            ),
                          const SizedBox(width: DeskflowSpacing.sm),
                          Text(
                            CurrencyFormatter.formatCompact(order.totalAmount),
                            style: DeskflowTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => SkeletonLoader(
            child: SkeletonLoader.box(height: 72),
          ),
          error: (error, _) => Text(
            'Ошибка загрузки заказов',
            style: DeskflowTypography.bodySmall.copyWith(
              color: DeskflowColors.destructiveSolid,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}

class _CustomerDetailSkeleton extends StatelessWidget {
  const _CustomerDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: ListView(
        padding: const EdgeInsets.all(DeskflowSpacing.lg),
        children: [
          Center(child: SkeletonLoader.box(width: 72, height: 72, borderRadius: 20)),
          const SizedBox(height: DeskflowSpacing.md),
          Center(child: SkeletonLoader.box(width: 200, height: 24, borderRadius: 8)),
          const SizedBox(height: DeskflowSpacing.xl),
          SkeletonLoader.box(height: 120),
          const SizedBox(height: DeskflowSpacing.lg),
          Row(
            children: [
              Expanded(child: SkeletonLoader.box(height: 80)),
              const SizedBox(width: DeskflowSpacing.sm),
              Expanded(child: SkeletonLoader.box(height: 80)),
            ],
          ),
          const SizedBox(height: DeskflowSpacing.lg),
          SkeletonLoader.box(height: 200),
        ],
      ),
    );
  }
}
