import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/models/paginated_list.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/currency_formatter.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/glass_chip.dart';
import 'package:deskflow/core/widgets/pill_search_bar.dart';
import 'package:deskflow/core/widgets/status_pill_badge.dart';
import 'package:deskflow/core/widgets/empty_state_widget.dart';
import 'package:deskflow/core/widgets/error_state_widget.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/core/widgets/floating_island_nav.dart';
import 'package:deskflow/core/widgets/skeleton_loader.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/orders/domain/order_providers.dart';

final _log = AppLogger.getLogger('OrdersListScreen');

/// Orders list screen — Tab 1.
///
/// Shows all orders with search, status filter chips,
/// pull-to-refresh, and infinite scroll.
class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({super.key});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> {
  String? _selectedStatusId;
  String _debouncedQuery = '';
  Timer? _debounceTimer;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _debouncedQuery = '');
    } else {
      _debounceTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) {
          _log.d('[FIX] searchOrders triggered: query="$query"');
          setState(() => _debouncedQuery = query.trim());
        }
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      ref
          .read(ordersListProvider(statusId: _selectedStatusId).notifier)
          .loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pipelineAsync = ref.watch(pipelineProvider);
    final ordersAsync =
        ref.watch(ordersListProvider(statusId: _selectedStatusId));

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DeskflowSpacing.lg,
                DeskflowSpacing.lg,
                DeskflowSpacing.lg,
                DeskflowSpacing.sm,
              ),
              child: PillSearchBar(
                hintText: 'Поиск заказов...',
                onChanged: _onSearchChanged,
              ),
            ),

            // Filter chips — dynamic from pipeline
            SizedBox(
              height: 40,
              child: pipelineAsync.when(
                data: (pipeline) => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DeskflowSpacing.lg,
                  ),
                  children: [
                    GlassChip(
                      label: 'Все',
                      selected: _selectedStatusId == null,
                      onTap: () =>
                          setState(() => _selectedStatusId = null),
                    ),
                    ...pipeline.map((status) => Padding(
                          padding: const EdgeInsets.only(
                              left: DeskflowSpacing.sm),
                          child: GlassChip(
                            label: status.name,
                            selected:
                                _selectedStatusId == status.id,
                            leading: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: status.materialColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            onTap: () => setState(() =>
                                _selectedStatusId = status.id),
                          ),
                        )),
                  ],
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),

            const SizedBox(height: DeskflowSpacing.sm),

            // Orders list — server-side search or paginated list
            Expanded(
              child: _debouncedQuery.isNotEmpty
                  ? _buildSearchResults()
                  : _buildPaginatedList(ordersAsync),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          // [FIX] Dynamic FAB offset — uses FloatingIslandNav.totalHeight()
          // instead of hardcoded 72 + viewPadding.bottom. Fixes Samsung One UI 7
          // where viewPadding.bottom is significantly larger than stock Android.
          bottom: FloatingIslandNav.totalHeight(context) + 16,
        ),
        child: FloatingActionButton(
          onPressed: () => context.push('/orders/create'),
          backgroundColor: DeskflowColors.primarySolid,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
    );
  }

  /// Server-side search results view.
  Widget _buildSearchResults() {
    final searchAsync = ref.watch(
      ordersSearchProvider(_debouncedQuery, _selectedStatusId),
    );

    return searchAsync.when(
      data: (orders) {
        _log.d('[FIX] searchOrders results: ${orders.length} orders '
            'for query="$_debouncedQuery"');

        if (orders.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.search_off_rounded,
            title: 'Ничего не найдено',
            description: 'Попробуйте изменить запрос',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            DeskflowSpacing.lg,
            DeskflowSpacing.sm,
            DeskflowSpacing.lg,
            100,
          ),
          itemCount: orders.length,
          separatorBuilder: (_, _) =>
              const SizedBox(height: DeskflowSpacing.sm),
          itemBuilder: (_, index) => _OrderCard(order: orders[index]),
        );
      },
      loading: () => ListView.builder(
        padding:
            const EdgeInsets.symmetric(horizontal: DeskflowSpacing.lg),
        itemCount: 3,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(bottom: DeskflowSpacing.sm),
          child: SkeletonLoader(
            child: SkeletonLoader.box(height: 72),
          ),
        ),
      ),
      error: (error, _) => ErrorStateWidget(
        message: 'Ошибка поиска заказов',
        onRetry: () => ref.invalidate(
          ordersSearchProvider(_debouncedQuery, _selectedStatusId),
        ),
      ),
    );
  }

  /// Paginated orders list view (default, no search).
  Widget _buildPaginatedList(
      AsyncValue<PaginatedList<Order>> ordersAsync) {
    return ordersAsync.when(
      data: (paginated) {
        final orders = paginated.items;

        if (orders.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.receipt_long_rounded,
            title: _selectedStatusId != null
                ? 'Нет заказов с этим статусом'
                : 'Нет заказов',
            description: _selectedStatusId != null
                ? 'Попробуйте другой фильтр'
                : 'Создайте первый заказ!',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ordersListProvider);
          },
          color: DeskflowColors.primarySolid,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(
              DeskflowSpacing.lg,
              DeskflowSpacing.sm,
              DeskflowSpacing.lg,
              100,
            ),
            itemCount: orders.length + (paginated.hasMore ? 1 : 0),
            separatorBuilder: (_, _) =>
                const SizedBox(height: DeskflowSpacing.sm),
            itemBuilder: (context, index) {
              if (index >= orders.length) {
                return const Padding(
                  padding: EdgeInsets.all(DeskflowSpacing.lg),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DeskflowColors.primarySolid,
                      ),
                    ),
                  ),
                );
              }
              return _OrderCard(order: orders[index]);
            },
          ),
        );
      },
      loading: () => ListView.builder(
        padding:
            const EdgeInsets.symmetric(horizontal: DeskflowSpacing.lg),
        itemCount: 5,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(bottom: DeskflowSpacing.sm),
          child: SkeletonLoader(
            child: SkeletonLoader.box(height: 72),
          ),
        ),
      ),
      error: (error, _) => ErrorStateWidget(
        message: 'Ошибка загрузки заказов',
        onRetry: () => ref.invalidate(ordersListProvider),
      ),
    );
  }
}

/// Individual order card in the list.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => context.push('/orders/${order.id}'),
      padding: const EdgeInsets.all(DeskflowSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      order.formattedNumber,
                      style: DeskflowTypography.h3,
                    ),
                    const SizedBox(width: DeskflowSpacing.sm),
                    Expanded(
                      child: Text(
                        order.customerName ?? 'Без клиента',
                        style: DeskflowTypography.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DeskflowSpacing.xs),
                Text(
                  CurrencyFormatter.formatCompact(order.totalAmount),
                  style: DeskflowTypography.body,
                ),
              ],
            ),
          ),
          if (order.status != null)
            StatusPillBadge(
              label: order.status!.name,
              color: order.status!.materialColor,
            ),
        ],
      ),
    );
  }
}
