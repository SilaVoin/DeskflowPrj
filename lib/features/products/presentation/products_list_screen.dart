import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/pill_search_bar.dart';
import 'package:deskflow/core/widgets/empty_state_widget.dart';
import 'package:deskflow/core/widgets/error_state_widget.dart';
import 'package:deskflow/core/widgets/floating_island_nav.dart';
import 'package:deskflow/core/widgets/skeleton_loader.dart';
import 'package:deskflow/features/products/domain/product.dart';
import 'package:deskflow/features/products/domain/product_providers.dart';

/// Products list (catalog) screen.
///
/// Members see read-only catalog. Owners can add/edit products
/// via FAB → admin catalog routes.
class ProductsListScreen extends HookConsumerWidget {
  const ProductsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = useState('');
    final scrollController = useScrollController();
    final productsAsync = ref.watch(
      productsListProvider(
        search: searchQuery.value.isEmpty ? null : searchQuery.value,
      ),
    );

    useEffect(() {
      void onScroll() {
        if (!scrollController.hasClients) return;
        final maxScroll = scrollController.position.maxScrollExtent;
        final currentScroll = scrollController.position.pixels;
        if (currentScroll >= maxScroll - 200) {
          ref
              .read(productsListProvider(
                search: searchQuery.value.isEmpty ? null : searchQuery.value,
              ).notifier)
              .loadMore();
        }
      }

      scrollController.addListener(onScroll);
      return () => scrollController.removeListener(onScroll);
    }, [scrollController, searchQuery.value]);

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      appBar: AppBar(
        title: const Text('Каталог'),
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DeskflowSpacing.lg,
              DeskflowSpacing.sm,
              DeskflowSpacing.lg,
              DeskflowSpacing.sm,
            ),
            child: PillSearchBar(
              hintText: 'Поиск товаров...',
              onChanged: (query) => searchQuery.value = query,
            ),
          ),

          // Products grid
          Expanded(
            child: productsAsync.when(
              data: (paginated) {
                final products = paginated.items;
                if (products.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.shopping_bag_rounded,
                    title: searchQuery.value.isNotEmpty
                        ? 'Ничего не найдено'
                        : 'Каталог пуст',
                    description: searchQuery.value.isNotEmpty
                        ? 'Попробуйте изменить запрос'
                        : 'Товары пока не добавлены',
                  );
                }

                return RefreshIndicator(
                  color: DeskflowColors.primarySolid,
                  backgroundColor: DeskflowColors.modalSurface,
                  onRefresh: () async {
                    ref.invalidate(productsListProvider);
                  },
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      DeskflowSpacing.lg,
                      DeskflowSpacing.sm,
                      DeskflowSpacing.lg,
                      DeskflowSpacing.xxxl * 2,
                    ),
                    itemCount:
                        products.length + (paginated.hasMore ? 1 : 0),
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: DeskflowSpacing.sm),
                    itemBuilder: (context, index) {
                      if (index >= products.length) {
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
                      final product = products[index];
                      return _ProductCard(
                        product: product,
                        onTap: () =>
                            context.push('/products/${product.id}'),
                      );
                    },
                  ),
                );
              },
              loading: () => const _ProductsLoadingSkeleton(),
              error: (error, _) => ErrorStateWidget(
                message: error.toString(),
                onRetry: () => ref.invalidate(productsListProvider),
              ),
            ),
          ),
        ],
      ),
      // FAB for owner to add products (navigates to admin catalog)
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          // [FIX] Dynamic FAB offset — fixes Samsung One UI 7 positioning
          bottom: FloatingIslandNav.totalHeight(context) + 16,
        ),
        child: FloatingActionButton(
          backgroundColor: DeskflowColors.primarySolid,
          onPressed: () => context.push('/admin/catalog/create'),
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

/// Single product card.
class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(DeskflowSpacing.lg),
        child: Row(
          children: [
            // Thumbnail / icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: DeskflowColors.glassSurface,
                borderRadius: BorderRadius.circular(DeskflowRadius.md),
                border: Border.all(color: DeskflowColors.glassBorder),
                image: product.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(product.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: product.imageUrl == null
                  ? const Icon(
                      Icons.shopping_bag_rounded,
                      color: DeskflowColors.textTertiary,
                      size: 22,
                    )
                  : null,
            ),
            const SizedBox(width: DeskflowSpacing.md),

            // Name + SKU
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
                  if (product.sku != null) ...[
                    const SizedBox(height: DeskflowSpacing.xs),
                    Text(
                      'SKU: ${product.sku}',
                      style: DeskflowTypography.caption,
                    ),
                  ],
                ],
              ),
            ),

            // Price
            Text(
              product.formattedPrice,
              style: DeskflowTypography.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            // Inactive indicator
            if (!product.isActive) ...[
              const SizedBox(width: DeskflowSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DeskflowSpacing.sm,
                  vertical: DeskflowSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: DeskflowColors.destructive.withValues(alpha: 0.3),
                  borderRadius:
                      BorderRadius.circular(DeskflowRadius.pill),
                ),
                child: Text(
                  'Неактивен',
                  style: DeskflowTypography.caption.copyWith(
                    color: DeskflowColors.destructiveSolid,
                    fontSize: 10,
                  ),
                ),
              ),
            ],

            const SizedBox(width: DeskflowSpacing.xs),
            const Icon(
              Icons.chevron_right_rounded,
              color: DeskflowColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading skeleton for products list.
class _ProductsLoadingSkeleton extends StatelessWidget {
  const _ProductsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: ListView.separated(
        padding: const EdgeInsets.all(DeskflowSpacing.lg),
        itemCount: 8,
        separatorBuilder: (_, _) => const SizedBox(height: DeskflowSpacing.sm),
        itemBuilder: (_, _) => SkeletonLoader.box(height: 80),
      ),
    );
  }
}
