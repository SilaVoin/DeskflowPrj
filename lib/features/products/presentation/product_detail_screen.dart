import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/glass_card.dart';

import 'package:deskflow/core/widgets/error_state_widget.dart';
import 'package:deskflow/core/widgets/skeleton_loader.dart';
import 'package:deskflow/features/products/domain/product.dart';
import 'package:deskflow/features/products/domain/product_providers.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productDetailProvider(productId));

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      appBar: AppBar(
        title: const Text('Товар'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => context.push('/admin/catalog/$productId'),
          ),
        ],
      ),
      body: productAsync.when(
        data: (product) => _ProductContent(product: product),
        loading: () => const _ProductDetailSkeleton(),
        error: (error, _) => ErrorStateWidget(
          message: error.toString(),
          onRetry: () =>
              ref.invalidate(productDetailProvider(productId)),
        ),
      ),
    );
  }
}

class _ProductContent extends StatelessWidget {
  final Product product;

  const _ProductContent({required this.product});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(DeskflowSpacing.lg),
      children: [
        _ProductHero(product: product),
        const SizedBox(height: DeskflowSpacing.lg),

        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(DeskflowSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: DeskflowTypography.h2),
                const SizedBox(height: DeskflowSpacing.md),

                Text(
                  product.formattedPrice,
                  style: DeskflowTypography.h1.copyWith(
                    color: DeskflowColors.primarySolid,
                  ),
                ),
                const SizedBox(height: DeskflowSpacing.lg),

                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: product.isActive
                            ? DeskflowColors.successSolid
                            : DeskflowColors.destructiveSolid,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: DeskflowSpacing.sm),
                    Text(
                      product.isActive ? 'Активен' : 'Неактивен',
                      style: DeskflowTypography.bodySmall.copyWith(
                        color: product.isActive
                            ? DeskflowColors.successSolid
                            : DeskflowColors.destructiveSolid,
                      ),
                    ),
                  ],
                ),

                if (product.sku != null) ...[
                  const SizedBox(height: DeskflowSpacing.lg),
                  const Divider(),
                  const SizedBox(height: DeskflowSpacing.md),
                  _DetailRow(label: 'SKU', value: product.sku!),
                ],
              ],
            ),
          ),
        ),

        if (product.description != null &&
            product.description!.isNotEmpty) ...[
          const SizedBox(height: DeskflowSpacing.lg),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(DeskflowSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Описание', style: DeskflowTypography.h3),
                  const SizedBox(height: DeskflowSpacing.sm),
                  Text(
                    product.description!,
                    style: DeskflowTypography.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: DeskflowSpacing.xxxl * 2),
      ],
    );
  }
}

class _ProductHero extends StatelessWidget {
  final Product product;

  const _ProductHero({required this.product});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DeskflowRadius.lg),
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: DeskflowColors.glassSurface,
          border: Border.all(color: DeskflowColors.glassBorder),
          borderRadius: BorderRadius.circular(DeskflowRadius.lg),
        ),
        child: product.imageUrl != null
            ? Image.network(
                product.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _PlaceholderIcon(),
              )
            : const _PlaceholderIcon(),
      ),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  const _PlaceholderIcon();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.shopping_bag_rounded,
        size: 64,
        color: DeskflowColors.textTertiary,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: DeskflowTypography.bodySmall),
        Text(
          value,
          style: DeskflowTypography.body.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ProductDetailSkeleton extends StatelessWidget {
  const _ProductDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: ListView(
        padding: const EdgeInsets.all(DeskflowSpacing.lg),
        children: [
          SkeletonLoader.box(height: 200),
          const SizedBox(height: DeskflowSpacing.lg),
          SkeletonLoader.box(height: 180),
          const SizedBox(height: DeskflowSpacing.lg),
          SkeletonLoader.box(height: 120),
        ],
      ),
    );
  }
}
