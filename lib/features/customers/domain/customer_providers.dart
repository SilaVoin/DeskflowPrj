import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:deskflow/core/models/paginated_list.dart';
import 'package:deskflow/core/providers/supabase_provider.dart';
import 'package:deskflow/features/customers/data/customer_repository.dart';
import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

part 'customer_providers.g.dart';

/// Customer repository singleton.
@Riverpod(keepAlive: true)
CustomerRepository customerRepository(Ref ref) {
  return CustomerRepository(ref.watch(supabaseClientProvider));
}

/// All customers for current org — paginated, supports search.
@riverpod
class CustomersList extends _$CustomersList {
  static const _pageSize = 20;

  @override
  Future<PaginatedList<Customer>> build({String? search}) async {
    final orgId = ref.watch(currentOrgIdProvider);
    if (orgId == null) return const PaginatedList(items: [], hasMore: false);
    final items = await ref.watch(customerRepositoryProvider).getCustomers(
          orgId: orgId,
          search: search,
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

      final newItems = await ref.read(customerRepositoryProvider).getCustomers(
            orgId: orgId,
            search: search,
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

/// Single customer detail with stats.
@riverpod
Future<Customer> customerDetail(Ref ref, String customerId) async {
  return ref.watch(customerRepositoryProvider).getCustomer(customerId);
}

/// Orders for a specific customer.
@riverpod
Future<List<Order>> customerOrders(Ref ref, String customerId) async {
  return ref.watch(customerRepositoryProvider).getCustomerOrders(customerId);
}
