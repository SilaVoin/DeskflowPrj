import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:deskflow/core/models/paginated_list.dart';
import 'package:deskflow/core/providers/supabase_provider.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/orders/data/order_repository.dart';
import 'package:deskflow/features/orders/domain/order_composition.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/orders/domain/order_status.dart';
import 'package:deskflow/features/orders/domain/order_template.dart';
import 'package:deskflow/features/orders/domain/orders_list_controls.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';
import 'package:deskflow/features/products/domain/product.dart';

part 'order_providers.g.dart';

@Riverpod(keepAlive: true)
OrderRepository orderRepository(Ref ref) {
  return OrderRepository(ref.watch(supabaseClientProvider));
}

@riverpod
Future<List<OrderStatus>> pipeline(Ref ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return [];
  return ref.watch(orderRepositoryProvider).getPipeline(orgId);
}

final ordersListControlsProvider = StateProvider<OrdersListControls>(
  (ref) => const OrdersListControls(),
);

final orderTemplatesProvider = FutureProvider<List<OrderTemplate>>((ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return [];
  return ref.watch(orderRepositoryProvider).getOrderTemplates(orgId: orgId);
});

final duplicateOrderCompositionProvider =
    FutureProvider.family<OrderComposition, String>((ref, orderId) async {
      return ref
          .watch(orderRepositoryProvider)
          .getDuplicateOrderComposition(orderId);
    });

final recentOrderCustomersProvider = FutureProvider<List<Customer>>((
  ref,
) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return [];
  return ref.watch(orderRepositoryProvider).getRecentCustomers(orgId: orgId);
});

final recentOrderProductsProvider = FutureProvider<List<Product>>((ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return [];
  return ref.watch(orderRepositoryProvider).getRecentProducts(orgId: orgId);
});

@riverpod
class OrdersList extends _$OrdersList {
  static const _pageSize = 20;

  @override
  Future<PaginatedList<Order>> build({String? statusId}) async {
    final orgId = ref.watch(currentOrgIdProvider);
    if (orgId == null) return const PaginatedList(items: [], hasMore: false);
    ref.watch(currentUserProvider);
    final controls = ref.watch(ordersListControlsProvider);
    final items = await ref
        .watch(orderRepositoryProvider)
        .getOrders(
          orgId: orgId,
          statusId: statusId,
          periodPreset: controls.periodPreset,
          selectedDate: controls.selectedDate,
          selectedDateRange: controls.selectedDateRange,
          amountRange: controls.amountRange,
          limit: _pageSize,
          offset: 0,
        );
    return PaginatedList(items: items, hasMore: items.length >= _pageSize);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final orgId = ref.read(currentOrgIdProvider);
      if (orgId == null) return;
      final controls = ref.read(ordersListControlsProvider);

      final newItems = await ref
          .read(orderRepositoryProvider)
          .getOrders(
            orgId: orgId,
            statusId: statusId,
            periodPreset: controls.periodPreset,
            selectedDate: controls.selectedDate,
            selectedDateRange: controls.selectedDateRange,
            amountRange: controls.amountRange,
            limit: _pageSize,
            offset: current.items.length,
          );

      state = AsyncData(
        PaginatedList(
          items: [...current.items, ...newItems],
          hasMore: newItems.length >= _pageSize,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

@riverpod
Future<List<Order>> ordersSearch(
  Ref ref,
  String query,
  String? statusId,
) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return [];
  return ref
      .watch(orderRepositoryProvider)
      .searchOrders(orgId: orgId, query: query, statusId: statusId);
}

@riverpod
Future<Order> orderDetail(Ref ref, String orderId) async {
  return ref.watch(orderRepositoryProvider).getOrder(orderId);
}
