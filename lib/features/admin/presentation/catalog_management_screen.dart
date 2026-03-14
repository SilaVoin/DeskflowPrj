import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/core/widgets/error_state_widget.dart';
import 'package:deskflow/core/widgets/floating_island_nav.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/glass_floating_action_button.dart';
import 'package:deskflow/core/widgets/pill_search_bar.dart';
import 'package:deskflow/core/widgets/skeleton_loader.dart';
import 'package:deskflow/features/products/domain/product.dart';
import 'package:deskflow/features/products/domain/product_providers.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

final _log = AppLogger.getLogger('CatalogManagementScreen');

class CatalogManagementScreen extends HookConsumerWidget {
  const CatalogManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = useState('');
    final productsAsync = ref.watch(productsListProvider(
      search: searchQuery.value.isEmpty ? null : searchQuery.value,
    ));

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      appBar: AppBar(
        title: const Text('Управление каталогом'),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: FloatingIslandNav.totalHeight(context) + 16,
        ),
        child: GlassFloatingActionButton(
          icon: Icons.add_rounded,
          onPressed: () => context.push('/admin/catalog/create'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DeskflowSpacing.lg,
              DeskflowSpacing.sm,
              DeskflowSpacing.lg,
              DeskflowSpacing.sm,
            ),
            child: PillSearchBar(
              hintText: 'Поиск товаров...',
              onChanged: (v) => searchQuery.value = v,
            ),
          ),

          Expanded(
            child: productsAsync.when(
              data: (paginated) {
                final products = paginated.items;
                if (products.isEmpty) {
                  return Center(
                    child: Text(
                      searchQuery.value.isEmpty
                          ? 'Каталог пуст. Добавьте первый товар.'
                          : 'Ничего не найдено',
                      style: DeskflowTypography.body,
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(DeskflowSpacing.lg),
                  itemCount: products.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: DeskflowSpacing.sm),
                  itemBuilder: (_, index) {
                    final product = products[index];
                    return _CatalogProductCard(
                      product: product,
                      onTap: () => context.push('/admin/catalog/${product.id}'),
                      onToggleActive: () =>
                          _toggleActive(ref, product),
                    );
                  },
                );
              },
              loading: () => const _CatalogLoadingSkeleton(),
              error: (error, _) => ErrorStateWidget(
                message: error.toString(),
                onRetry: () => ref.invalidate(
                  productsListProvider(
                    search: searchQuery.value.isEmpty
                        ? null
                        : searchQuery.value,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(WidgetRef ref, Product product) async {
    try {
      final orgId = ref.read(currentOrgIdProvider);
      if (orgId == null) return;

      await ref.read(productRepositoryProvider).toggleActive(
        product.id,
        !product.isActive,
      );
      ref.invalidate(productsListProvider());
    } catch (e) {
      _log.e('toggleActive failed: $e');
    }
  }
}

class _CatalogProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onToggleActive;

  const _CatalogProductCard({
    required this.product,
    required this.onTap,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: DeskflowColors.glassSurface,
              borderRadius: BorderRadius.circular(DeskflowRadius.sm),
              border: Border.all(
                color: DeskflowColors.glassBorder,
                width: 0.5,
              ),
            ),
            child: product.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(DeskflowRadius.sm),
                    child: Image.network(
                      product.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.image_rounded,
                        color: DeskflowColors.textTertiary,
                        size: 24,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.inventory_2_rounded,
                    color: DeskflowColors.textTertiary,
                    size: 24,
                  ),
          ),
          const SizedBox(width: DeskflowSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: DeskflowTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (product.sku != null) ...[
                      Text(
                        product.sku!,
                        style: DeskflowTypography.caption.copyWith(
                          color: DeskflowColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: DeskflowSpacing.sm),
                    ],
                    Text(
                      product.formattedPrice,
                      style: DeskflowTypography.bodySmall.copyWith(
                        color: DeskflowColors.primarySolid,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Switch(
            value: product.isActive,
            onChanged: (_) => onToggleActive(),
            activeThumbColor: DeskflowColors.successSolid,
          ),
        ],
      ),
    );
  }
}

class _CatalogLoadingSkeleton extends StatelessWidget {
  const _CatalogLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: ListView.separated(
        padding: const EdgeInsets.all(DeskflowSpacing.lg),
        itemCount: 8,
        separatorBuilder: (_, _) => const SizedBox(height: DeskflowSpacing.sm),
        itemBuilder: (_, _) => SkeletonLoader.box(height: 72),
      ),
    );
  }
}
