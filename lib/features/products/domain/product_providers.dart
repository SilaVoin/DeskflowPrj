import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:deskflow/core/models/paginated_list.dart';
import 'package:deskflow/core/providers/supabase_provider.dart';
import 'package:deskflow/features/products/data/product_repository.dart';
import 'package:deskflow/features/products/domain/product.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

part 'product_providers.g.dart';

@Riverpod(keepAlive: true)
ProductRepository productRepository(Ref ref) {
  return ProductRepository(ref.watch(supabaseClientProvider));
}

@riverpod
class ProductsList extends _$ProductsList {
  static const _pageSize = 20;

  @override
  Future<PaginatedList<Product>> build({String? search}) async {
    final orgId = ref.watch(currentOrgIdProvider);
    if (orgId == null) return const PaginatedList(items: [], hasMore: false);
    final items = await ref.watch(productRepositoryProvider).getProducts(
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

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final orgId = ref.read(currentOrgIdProvider);
      if (orgId == null) return;

      final newItems = await ref.read(productRepositoryProvider).getProducts(
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

@riverpod
Future<List<Product>> activeProducts(Ref ref, {String? search}) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return [];
  return ref.watch(productRepositoryProvider).getProducts(
        orgId: orgId,
        search: search,
        activeOnly: true,
      );
}

@riverpod
Future<Product> productDetail(Ref ref, String productId) async {
  return ref.watch(productRepositoryProvider).getProduct(productId);
}
