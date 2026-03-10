import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/currency_formatter.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/glass_chip.dart';
import 'package:deskflow/core/widgets/pill_search_bar.dart';
import 'package:deskflow/core/widgets/skeleton_loader.dart';
import 'package:deskflow/core/widgets/status_pill_badge.dart';
import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/products/domain/product.dart';
import 'package:deskflow/features/search/domain/search_providers.dart';

/// Universal search screen — Tab 2.
///
/// Searches across orders, customers, and products with debounce
/// and category filter chips.
class UniversalSearchScreen extends HookConsumerWidget {
  const UniversalSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final query = useState('');
    final filter = useState(SearchFilter.all);
    final debounceTimer = useRef<Timer?>(null);

    void onSearchChanged(String value) {
      debounceTimer.value?.cancel();
      debounceTimer.value = Timer(const Duration(milliseconds: 300), () {
        query.value = value.trim();
      });
    }

    // Clean up timer on dispose
    useEffect(() {
      return () => debounceTimer.value?.cancel();
    }, []);

    final hasQuery = query.value.length >= 2;
    final searchAsync =
        hasQuery ? ref.watch(universalSearchProvider(query.value)) : null;

    // Browse mode: when no search query, show items for the selected tab.
    final isBrowseMode = !hasQuery;
    final browseAsync = isBrowseMode
        ? ref.watch(browseCategoryProvider(filter.value))
        : null;

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Search bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DeskflowSpacing.lg,
                DeskflowSpacing.lg,
                DeskflowSpacing.lg,
                DeskflowSpacing.sm,
              ),
              child: PillSearchBar(
                hintText: 'Поиск заказов, клиентов, товаров...',
                autofocus: true,
                controller: searchController,
                onChanged: onSearchChanged,
              ),
            ),

            // ── Filter chips ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DeskflowSpacing.lg,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in SearchFilter.values) ...[
                      if (f != SearchFilter.values.first)
                        const SizedBox(width: DeskflowSpacing.sm),
                      GlassChip(
                        label: _filterLabel(f),
                        selected: filter.value == f,
                        onTap: () => filter.value = f,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: DeskflowSpacing.md),

            // ── Content ──
            Expanded(
              child: hasQuery
                  ? searchAsync!.when(
                      data: (results) => _SearchResultsList(
                        results: results,
                        filter: filter.value,
                        query: query.value,
                      ),
                      loading: () => _LoadingSkeleton(),
                      error: (e, _) => Center(
                        child: Text(
                          'Ошибка поиска: $e',
                          style: DeskflowTypography.bodySmall,
                        ),
                      ),
                    )
                  : browseAsync!.when(
                      data: (results) => results.isEmpty
                          ? _BrowseEmptyHint(filter: filter.value)
                          : _SearchResultsList(
                              results: results,
                              filter: filter.value,
                              query: '',
                            ),
                      loading: () => _LoadingSkeleton(),
                      error: (e, _) => Center(
                        child: Text(
                          'Ошибка загрузки: $e',
                          style: DeskflowTypography.bodySmall,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _filterLabel(SearchFilter f) {
    return switch (f) {
      SearchFilter.all => 'Всё',
      SearchFilter.orders => 'Заказы',
      SearchFilter.customers => 'Клиенты',
      SearchFilter.products => 'Товары',
    };
  }
}

// ─────────────────────── Browse empty hint ──────────────────────

class _BrowseEmptyHint extends StatelessWidget {
  const _BrowseEmptyHint({required this.filter});

  final SearchFilter filter;

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      SearchFilter.orders => 'заказов',
      SearchFilter.customers => 'клиентов',
      SearchFilter.products => 'товаров',
      SearchFilter.all => 'данных',
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 48,
            color: DeskflowColors.textTertiary,
          ),
          const SizedBox(height: DeskflowSpacing.lg),
          Text(
            'Нет $label',
            style: DeskflowTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Loading skeleton ──────────────────────

class _LoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: DeskflowSpacing.lg),
      children: [
        SkeletonLoader(child: SkeletonLoader.box(height: 20, width: 80)),
        const SizedBox(height: DeskflowSpacing.sm),
        for (int i = 0; i < 3; i++) ...[
          SkeletonLoader(child: SkeletonLoader.box(height: 72)),
          const SizedBox(height: DeskflowSpacing.sm),
        ],
        const SizedBox(height: DeskflowSpacing.lg),
        SkeletonLoader(child: SkeletonLoader.box(height: 20, width: 100)),
        const SizedBox(height: DeskflowSpacing.sm),
        for (int i = 0; i < 2; i++) ...[
          SkeletonLoader(child: SkeletonLoader.box(height: 60)),
          const SizedBox(height: DeskflowSpacing.sm),
        ],
      ],
    );
  }
}

// ─────────────────────── Results list ──────────────────────

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.results,
    required this.filter,
    required this.query,
  });

  final SearchResults results;
  final SearchFilter filter;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      // In browse mode (no query), the parent handles the empty state,
      // so this only shows for search results.
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: DeskflowColors.textTertiary,
            ),
            const SizedBox(height: DeskflowSpacing.lg),
            Text(
              query.isEmpty
                  ? 'Нет данных'
                  : 'Ничего не найдено по запросу «$query»',
              style: DeskflowTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final showOrders =
        (filter == SearchFilter.all || filter == SearchFilter.orders) &&
            results.orders.isNotEmpty;
    final showCustomers =
        (filter == SearchFilter.all || filter == SearchFilter.customers) &&
            results.customers.isNotEmpty;
    final showProducts =
        (filter == SearchFilter.all || filter == SearchFilter.products) &&
            results.products.isNotEmpty;

    if (!showOrders && !showCustomers && !showProducts) {
      return Center(
        child: Text(
          'Нет результатов в выбранной категории',
          style: DeskflowTypography.bodySmall,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: DeskflowSpacing.lg),
      children: [
        // ── Orders section ──
        if (showOrders) ...[
          _SectionHeader(
            title: 'Заказы',
            count: results.orders.length,
          ),
          const SizedBox(height: DeskflowSpacing.sm),
          for (final order in results.orders.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: DeskflowSpacing.sm),
              child: _OrderResultCard(order: order),
            ),
          if (results.orders.length > 5)
            _ShowAllButton(
              label: 'Показать все ${results.orders.length} заказов',
              onTap: () {
                // Could navigate to orders list with filter
              },
            ),
          const SizedBox(height: DeskflowSpacing.lg),
        ],

        // ── Customers section ──
        if (showCustomers) ...[
          _SectionHeader(
            title: 'Клиенты',
            count: results.customers.length,
          ),
          const SizedBox(height: DeskflowSpacing.sm),
          for (final customer in results.customers.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: DeskflowSpacing.sm),
              child: _CustomerResultCard(customer: customer),
            ),
          const SizedBox(height: DeskflowSpacing.lg),
        ],

        // ── Products section ──
        if (showProducts) ...[
          _SectionHeader(
            title: 'Товары',
            count: results.products.length,
          ),
          const SizedBox(height: DeskflowSpacing.sm),
          for (final product in results.products.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: DeskflowSpacing.sm),
              child: _ProductResultCard(product: product),
            ),
          const SizedBox(height: DeskflowSpacing.lg),
        ],

        // Bottom padding for nav bar
        const SizedBox(height: 100),
      ],
    );
  }
}

// ─────────────────────── Section header ──────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: DeskflowTypography.h3),
        const SizedBox(width: DeskflowSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DeskflowSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: DeskflowColors.glassSurface,
            borderRadius: BorderRadius.circular(DeskflowRadius.pill),
          ),
          child: Text(
            '$count',
            style: DeskflowTypography.caption,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────── Show all button ──────────────────────

class _ShowAllButton extends StatelessWidget {
  const _ShowAllButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DeskflowSpacing.sm),
        child: Text(
          label,
          style: DeskflowTypography.bodySmall.copyWith(
            color: DeskflowColors.primary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ─────────────────────── Order result card ──────────────────────

class _OrderResultCard extends StatelessWidget {
  const _OrderResultCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => context.push('/orders/${order.id}'),
      child: Row(
        children: [
          // Order number
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: order.status?.materialColor.withValues(alpha: 0.2) ??
                  DeskflowColors.glassSurface,
              borderRadius: BorderRadius.circular(DeskflowRadius.sm),
            ),
            child: Center(
              child: Text(
                order.formattedNumber,
                style: DeskflowTypography.caption.copyWith(
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
                Text(
                  order.customerName ?? 'Без клиента',
                  style: DeskflowTypography.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (order.status != null)
                      StatusPillBadge(
                        label: order.status!.name,
                        color: order.status!.materialColor,
                      ),
                    const Spacer(),
                    Text(
                      CurrencyFormatter.formatCompact(order.totalAmount),
                      style: DeskflowTypography.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: DeskflowSpacing.sm),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: DeskflowColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Customer result card ──────────────────────

class _CustomerResultCard extends StatelessWidget {
  const _CustomerResultCard({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => context.push('/customers/${customer.id}'),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: DeskflowColors.glassSurface,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                customer.initials,
                style: DeskflowTypography.caption.copyWith(
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
                Text(
                  customer.name,
                  style: DeskflowTypography.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (customer.phone != null || customer.email != null)
                  Text(
                    customer.phone ?? customer.email ?? '',
                    style: DeskflowTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: DeskflowSpacing.sm),
          Text(
            '${customer.orderCount} заказов',
            style: DeskflowTypography.caption,
          ),
          const SizedBox(width: DeskflowSpacing.sm),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: DeskflowColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Product result card ──────────────────────

class _ProductResultCard extends StatelessWidget {
  const _ProductResultCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => context.push('/products/${product.id}'),
      child: Row(
        children: [
          // Image placeholder
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: DeskflowColors.glassSurface,
              borderRadius: BorderRadius.circular(DeskflowRadius.sm),
            ),
            child: product.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(DeskflowRadius.sm),
                    child: Image.network(
                      product.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.inventory_2_outlined,
                        size: 20,
                        color: DeskflowColors.textTertiary,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.inventory_2_outlined,
                    size: 20,
                    color: DeskflowColors.textTertiary,
                  ),
          ),
          const SizedBox(width: DeskflowSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: DeskflowTypography.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (product.sku != null)
                  Text(
                    'SKU: ${product.sku}',
                    style: DeskflowTypography.caption,
                  ),
              ],
            ),
          ),
          const SizedBox(width: DeskflowSpacing.sm),
          Text(
            product.formattedPrice,
            style: DeskflowTypography.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: DeskflowSpacing.sm),
          if (!product.isActive)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: DeskflowColors.glassSurface,
                borderRadius: BorderRadius.circular(DeskflowRadius.pill),
              ),
              child: Text(
                'Скрыт',
                style: DeskflowTypography.caption.copyWith(
                  color: DeskflowColors.textTertiary,
                  fontSize: 10,
                ),
              ),
            ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: DeskflowColors.textTertiary,
          ),
        ],
      ),
    );
  }
}
