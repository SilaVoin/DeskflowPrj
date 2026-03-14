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
import 'package:deskflow/features/orders/domain/order_providers.dart';
import 'package:deskflow/features/orders/domain/order_status.dart';
import 'package:deskflow/features/products/domain/product.dart';
import 'package:deskflow/features/search/domain/search_history_entry.dart';
import 'package:deskflow/features/search/domain/search_providers.dart';

class UniversalSearchScreen extends HookConsumerWidget {
  const UniversalSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final debounceTimer = useRef<Timer?>(null);
    final isProgrammaticChange = useRef(false);
    final controls = ref.watch(searchControlsProvider);
    final controlsNotifier = ref.read(searchControlsProvider.notifier);

    void setControllerText(String value) {
      isProgrammaticChange.value = true;
      searchController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
      Future<void>.microtask(() {
        isProgrammaticChange.value = false;
      });
    }

    void syncQuery(String value) {
      final normalized = normalizeSearchQuery(value);
      setControllerText(normalized);
      controlsNotifier.setQuery(normalized);
    }

    void onSearchChanged(String value) {
      if (isProgrammaticChange.value) {
        return;
      }

      debounceTimer.value?.cancel();
      debounceTimer.value = Timer(const Duration(milliseconds: 300), () {
        controlsNotifier.setQuery(value);
      });
    }

    Future<void> onSearchSubmitted(String value) async {
      debounceTimer.value?.cancel();
      syncQuery(value);
      await controlsNotifier.saveExecutedQuery(value);
    }

    useEffect(() {
      return () => debounceTimer.value?.cancel();
    }, const []);

    useEffect(() {
      if (searchController.text == controls.query) {
        return null;
      }

      setControllerText(controls.query);
      return null;
    }, [controls.query]);

    final isBrowseMode = !controls.hasRunnableQuery;
    final browseAsync = isBrowseMode ? ref.watch(browseCategoryProvider) : null;
    final searchAsync =
        controls.hasRunnableQuery ? ref.watch(universalSearchProvider) : null;
    final historyAsync = ref.watch(searchHistoryProvider);
    final pipelineAsync = controls.showsOrderStatusFilters
        ? ref.watch(pipelineProvider)
        : const AsyncValue<List<OrderStatus>>.data(<OrderStatus>[]);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
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
                onSubmitted: onSearchSubmitted,
                onClear: controlsNotifier.clearQuery,
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _PinnedHeaderDelegate(
                      child: _SearchFilterBar(
                        selectedFilter: controls.entityFilter,
                        pipelineAsync: pipelineAsync,
                        selectedStatusId: controls.orderStatusId,
                        onSelectFilter: controlsNotifier.switchEntityFilter,
                        onSelectStatus: controlsNotifier.setOrderStatus,
                      ),
                    ),
                  ),
                  if (isBrowseMode) ...[
                    _buildBrowseSliver(
                      browseAsync: browseAsync!,
                      filter: controls.entityFilter,
                    ),
                    _buildHistorySliver(
                      historyAsync: historyAsync,
                      expanded: controls.isHistoryExpanded,
                      onToggleExpanded: controlsNotifier.toggleHistoryExpanded,
                      onRunHistory: (entry) async {
                        syncQuery(entry.query);
                        await controlsNotifier.saveExecutedQuery(entry.query);
                      },
                      onInsertHistory: (entry) => syncQuery(entry.query),
                    ),
                  ] else
                    _buildSearchSliver(
                      searchAsync: searchAsync!,
                      filter: controls.entityFilter,
                      query: controls.query,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowseSliver({
    required AsyncValue<SearchResults> browseAsync,
    required SearchFilter filter,
  }) {
    return browseAsync.when(
      data: (results) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DeskflowSpacing.lg,
            DeskflowSpacing.md,
            DeskflowSpacing.lg,
            DeskflowSpacing.lg,
          ),
          child: results.isEmpty
              ? _BrowseEmptyHint(filter: filter)
              : Container(
                  key: const Key('search-browse-content'),
                  child: _SearchResultsContent(
                    results: results,
                    filter: filter,
                    query: '',
                    browseMode: true,
                  ),
                ),
        ),
      ),
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(DeskflowSpacing.lg),
          child: _LoadingContent(),
        ),
      ),
      error: (error, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(DeskflowSpacing.lg),
          child: _ErrorMessage(message: 'Ошибка загрузки: $error'),
        ),
      ),
    );
  }

  Widget _buildHistorySliver({
    required AsyncValue<List<SearchHistoryEntry>> historyAsync,
    required bool expanded,
    required VoidCallback onToggleExpanded,
    required Future<void> Function(SearchHistoryEntry entry) onRunHistory,
    required void Function(SearchHistoryEntry entry) onInsertHistory,
  }) {
    return historyAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox(height: 120));
        }

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DeskflowSpacing.lg,
              0,
              DeskflowSpacing.lg,
              120,
            ),
            child: _SearchHistoryBlock(
              key: const Key('search-history-block'),
              entries: entries,
              expanded: expanded,
              onToggleExpanded: onToggleExpanded,
              onRunHistory: onRunHistory,
              onInsertHistory: onInsertHistory,
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: DeskflowSpacing.lg),
          child: _LoadingContent(lines: 3),
        ),
      ),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  Widget _buildSearchSliver({
    required AsyncValue<SearchResults> searchAsync,
    required SearchFilter filter,
    required String query,
  }) {
    return searchAsync.when(
      data: (results) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DeskflowSpacing.lg,
            DeskflowSpacing.md,
            DeskflowSpacing.lg,
            120,
          ),
          child: _SearchResultsContent(
            results: results,
            filter: filter,
            query: query,
            browseMode: false,
          ),
        ),
      ),
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(DeskflowSpacing.lg),
          child: _LoadingContent(),
        ),
      ),
      error: (error, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(DeskflowSpacing.lg),
          child: _ErrorMessage(message: 'Ошибка поиска: $error'),
        ),
      ),
    );
  }
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 66;

  @override
  double get maxExtent => 66;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: DeskflowSpacing.sm),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: _SearchFilterSurface(child: child),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_PinnedHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _SearchFilterSurface extends StatelessWidget {
  const _SearchFilterSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('search-filter-surface'),
      padding: const EdgeInsets.only(bottom: 2),
      child: child,
    );
  }
}

class _SearchFilterBar extends StatelessWidget {
  const _SearchFilterBar({
    required this.selectedFilter,
    required this.pipelineAsync,
    required this.selectedStatusId,
    required this.onSelectFilter,
    required this.onSelectStatus,
  });

  final SearchFilter selectedFilter;
  final AsyncValue<List<OrderStatus>> pipelineAsync;
  final String? selectedStatusId;
  final ValueChanged<SearchFilter> onSelectFilter;
  final ValueChanged<String?> onSelectStatus;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('search-filter-row'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: DeskflowSpacing.lg),
      child: Row(
        children: [
          _buildEntityChip(
            key: const Key('search-filter-all'),
            filter: SearchFilter.all,
            label: 'Все',
          ),
          const SizedBox(width: DeskflowSpacing.sm),
          _buildEntityChip(
            key: const Key('search-filter-orders'),
            filter: SearchFilter.orders,
            label: 'Заказы',
          ),
          const SizedBox(width: DeskflowSpacing.sm),
          _buildEntityChip(
            key: const Key('search-filter-customers'),
            filter: SearchFilter.customers,
            label: 'Клиенты',
          ),
          const SizedBox(width: DeskflowSpacing.sm),
          _buildEntityChip(
            key: const Key('search-filter-products'),
            filter: SearchFilter.products,
            label: 'Товары',
          ),
          if (selectedFilter == SearchFilter.orders)
            ...pipelineAsync.when(
              data: (statuses) => [
                for (final status in statuses) ...[
                  const SizedBox(width: DeskflowSpacing.sm),
                  GlassChip(
                    label: status.name,
                    selected: selectedStatusId == status.id,
                    onTap: () => onSelectStatus(
                      selectedStatusId == status.id ? null : status.id,
                    ),
                  ),
                ],
              ],
              loading: () => const [],
              error: (_, _) => const [],
            ),
        ],
      ),
    );
  }

  Widget _buildEntityChip({
    required Key key,
    required SearchFilter filter,
    required String label,
  }) {
    return GlassChip(
      key: key,
      label: label,
      selected: selectedFilter == filter,
      onTap: () => onSelectFilter(filter),
    );
  }
}

class _SearchHistoryBlock extends StatelessWidget {
  const _SearchHistoryBlock({
    super.key,
    required this.entries,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onRunHistory,
    required this.onInsertHistory,
  });

  final List<SearchHistoryEntry> entries;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final Future<void> Function(SearchHistoryEntry entry) onRunHistory;
  final void Function(SearchHistoryEntry entry) onInsertHistory;

  @override
  Widget build(BuildContext context) {
    final visibleEntries = expanded ? entries : entries.take(4).toList();
    final hasMore = entries.length > 4;

    return GlassCard(
      color: DeskflowColors.shellGlassSurface,
      borderColor: DeskflowColors.glassBorderStrong.withValues(alpha: 0.62),
      padding: const EdgeInsets.all(DeskflowSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('История поиска', style: DeskflowTypography.h3),
              const Spacer(),
              if (hasMore)
                GestureDetector(
                  onTap: onToggleExpanded,
                  child: Text(
                    expanded ? 'Свернуть' : 'Ещё',
                    style: DeskflowTypography.bodySmall.copyWith(
                      color: DeskflowColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: DeskflowSpacing.md),
          for (var index = 0; index < visibleEntries.length; index++) ...[
            _SearchHistoryRow(
              entry: visibleEntries[index],
              onRun: () => onRunHistory(visibleEntries[index]),
              onInsert: () => onInsertHistory(visibleEntries[index]),
            ),
            if (index < visibleEntries.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: DeskflowSpacing.xs),
                child: Divider(color: DeskflowColors.glassBorder, height: 1),
              ),
          ],
        ],
      ),
    );
  }
}

class _SearchHistoryRow extends StatelessWidget {
  const _SearchHistoryRow({
    required this.entry,
    required this.onRun,
    required this.onInsert,
  });

  final SearchHistoryEntry entry;
  final VoidCallback onRun;
  final VoidCallback onInsert;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            key: Key('search-history-run-${entry.id}'),
            onTap: onRun,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DeskflowSpacing.sm),
              child: Text(
                entry.query,
                style: DeskflowTypography.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        IconButton(
          key: Key('search-history-insert-${entry.id}'),
          onPressed: onInsert,
          icon: const Icon(
            Icons.arrow_outward_rounded,
            size: 18,
            color: DeskflowColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

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
          const Icon(
            Icons.inbox_rounded,
            size: 48,
            color: DeskflowColors.textTertiary,
          ),
          const SizedBox(height: DeskflowSpacing.lg),
          Text('Нет $label', style: DeskflowTypography.bodySmall),
        ],
      ),
    );
  }
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent({this.lines = 5});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < lines; index++) ...[
          SkeletonLoader(child: SkeletonLoader.box(height: 64)),
          if (index < lines - 1) const SizedBox(height: DeskflowSpacing.sm),
        ],
      ],
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: DeskflowTypography.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SearchResultsContent extends StatelessWidget {
  const _SearchResultsContent({
    required this.results,
    required this.filter,
    required this.query,
    required this.browseMode,
  });

  final SearchResults results;
  final SearchFilter filter;
  final String query;
  final bool browseMode;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty && !browseMode) {
      return const _UniversalNoResults();
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
      return const _UniversalNoResults();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showOrders) ...[
          _SectionHeader(title: 'Заказы', count: results.orders.length),
          const SizedBox(height: DeskflowSpacing.sm),
          for (final item in results.orders.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: DeskflowSpacing.sm),
              child: _OrderResultCard(order: item),
            ),
          const SizedBox(height: DeskflowSpacing.lg),
        ],
        if (showCustomers) ...[
          _SectionHeader(title: 'Клиенты', count: results.customers.length),
          const SizedBox(height: DeskflowSpacing.sm),
          for (final item in results.customers.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: DeskflowSpacing.sm),
              child: _CustomerResultCard(customer: item),
            ),
          const SizedBox(height: DeskflowSpacing.lg),
        ],
        if (showProducts) ...[
          _SectionHeader(title: 'Товары', count: results.products.length),
          const SizedBox(height: DeskflowSpacing.sm),
          for (final item in results.products.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: DeskflowSpacing.sm),
              child: _ProductResultCard(product: item),
            ),
        ],
      ],
    );
  }
}

class _UniversalNoResults extends StatelessWidget {
  const _UniversalNoResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 48,
            color: DeskflowColors.textTertiary,
          ),
          const SizedBox(height: DeskflowSpacing.lg),
          Text('Ничего не найдено', style: DeskflowTypography.h3),
          const SizedBox(height: DeskflowSpacing.xs),
          Text(
            'Попробуйте изменить запрос или очистить фильтры',
            style: DeskflowTypography.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

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
          key: Key('search-section-count-$title'),
          padding: const EdgeInsets.symmetric(
            horizontal: DeskflowSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: DeskflowColors.modalSurface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(DeskflowRadius.pill),
            border: Border.all(
              color: DeskflowColors.glassBorderStrong.withValues(alpha: 0.62),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            '$count',
            style: DeskflowTypography.caption.copyWith(
              color: DeskflowColors.textPrimary.withValues(alpha: 0.94),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderResultCard extends StatelessWidget {
  const _OrderResultCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => context.push('/orders/${order.id}'),
      color: DeskflowColors.shellGlassSurface,
      borderColor: DeskflowColors.glassBorderStrong.withValues(alpha: 0.7),
      padding: const EdgeInsets.all(DeskflowSpacing.md),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color:
                  order.status?.materialColor.withValues(alpha: 0.2) ??
                  DeskflowColors.shellGlassSurfaceFocused,
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
                    _TrailingMetricBadge(
                      key: Key('search-order-amount-pill-${order.id}'),
                      label: CurrencyFormatter.formatCompact(order.totalAmount),
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

class _CustomerResultCard extends StatelessWidget {
  const _CustomerResultCard({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => context.push('/customers/${customer.id}'),
      color: DeskflowColors.shellGlassSurface,
      borderColor: DeskflowColors.glassBorderStrong.withValues(alpha: 0.7),
      padding: const EdgeInsets.all(DeskflowSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: DeskflowColors.shellGlassSurfaceFocused,
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
          _TrailingMetricBadge(
            key: Key('search-customer-count-pill-${customer.id}'),
            label: '${customer.orderCount} заказов',
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

class _ProductResultCard extends StatelessWidget {
  const _ProductResultCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => context.push('/products/${product.id}'),
      color: DeskflowColors.shellGlassSurface,
      borderColor: DeskflowColors.glassBorderStrong.withValues(alpha: 0.7),
      padding: const EdgeInsets.all(DeskflowSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: DeskflowColors.shellGlassSurfaceFocused,
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
          _TrailingMetricBadge(
            key: Key('search-product-price-pill-${product.id}'),
            label: product.formattedPrice,
          ),
          const SizedBox(width: DeskflowSpacing.sm),
          if (!product.isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: DeskflowColors.shellGlassSurfaceFocused,
                borderRadius: BorderRadius.circular(DeskflowRadius.pill),
                border: Border.all(
                  color: DeskflowColors.glassBorderStrong.withValues(alpha: 0.55),
                ),
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

class _TrailingMetricBadge extends StatelessWidget {
  const _TrailingMetricBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DeskflowSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: DeskflowColors.modalSurface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(DeskflowRadius.pill),
        border: Border.all(
          color: DeskflowColors.glassBorderStrong.withValues(alpha: 0.58),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        label,
        style: DeskflowTypography.caption.copyWith(
          color: DeskflowColors.textPrimary.withValues(alpha: 0.96),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
