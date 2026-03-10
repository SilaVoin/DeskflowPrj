import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:deskflow/core/models/paginated_list.dart';
import 'package:deskflow/core/providers/supabase_provider.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/orders/data/order_repository.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/orders/domain/order_status.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

part 'order_providers.g.dart';

/// Order repository singleton.
@Riverpod(keepAlive: true)
OrderRepository orderRepository(Ref ref) {
  return OrderRepository(ref.watch(supabaseClientProvider));
}

/// Order status pipeline for current organization.
@riverpod
Future<List<OrderStatus>> pipeline(Ref ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return [];
  return ref.watch(orderRepositoryProvider).getPipeline(orgId);
}

/// Orders list for current org — paginated, supports status filter.
@riverpod
class OrdersList extends _$OrdersList {
  static const _pageSize = 20;

  @override
  Future<PaginatedList<Order>> build({String? statusId}) async {
    final orgId = ref.watch(currentOrgIdProvider);
    if (orgId == null) return const PaginatedList(items: [], hasMore: false);
    // Watch currentUser to rebuild on auth changes
    ref.watch(currentUserProvider);
    final items = await ref.watch(orderRepositoryProvider).getOrders(
          orgId: orgId,
          statusId: statusId,
          limit: _pageSize,
          offset: 0,
        );
    return PaginatedList(
      items: items,
      hasMore: items.length >= _pageSize,
    );
  }

  /// Load next page and append to current items.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final orgId = ref.read(currentOrgIdProvider);
      if (orgId == null) return;

      final newItems = await ref.read(orderRepositoryProvider).getOrders(
            orgId: orgId,
            statusId: statusId,
            limit: _pageSize,
            offset: current.items.length,
          );

      state = AsyncData(PaginatedList(
        items: [...current.items, ...newItems],
        hasMore: newItems.length >= _pageSize,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

/// Server-side order search — searches by order number, customer name, notes.
@riverpod
Future<List<Order>> ordersSearch(
  Ref ref,
  String query,
  String? statusId,
) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return [];
  return ref.watch(orderRepositoryProvider).searchOrders(
    orgId: orgId,
    query: query,
    statusId: statusId,
  );
}

/// Single order detail with full joins.
@riverpod
Future<Order> orderDetail(Ref ref, String orderId) async {
  return ref.watch(orderRepositoryProvider).getOrder(orderId);
}
