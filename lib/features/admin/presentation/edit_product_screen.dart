import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/core/widgets/error_state_widget.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/glass_text_field.dart';
import 'package:deskflow/core/widgets/pill_button.dart';
import 'package:deskflow/core/widgets/skeleton_loader.dart';
import 'package:deskflow/features/products/domain/product.dart';
import 'package:deskflow/features/products/domain/product_providers.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

final _log = AppLogger.getLogger('EditProductScreen');

/// Admin screen for creating or editing a product.
///
/// Routes:
/// - `/admin/catalog/create` — create mode (productId == null)
/// - `/admin/catalog/:id` — edit mode
class EditProductScreen extends HookConsumerWidget {
  final String? productId;

  const EditProductScreen({super.key, this.productId});

  bool get isEditing => productId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isEditing) {
      final productAsync = ref.watch(productDetailProvider(productId!));
      return productAsync.when(
        data: (product) => _ProductForm(product: product),
        loading: () => Scaffold(
          backgroundColor: DeskflowColors.background,
          appBar: AppBar(title: const Text('Загрузка...')),
          body: SkeletonLoader(
            child: ListView(
              padding: const EdgeInsets.all(DeskflowSpacing.lg),
              children: [
                SkeletonLoader.box(height: 200),
                const SizedBox(height: DeskflowSpacing.lg),
                SkeletonLoader.box(height: 300),
              ],
            ),
          ),
        ),
        error: (error, _) => Scaffold(
          backgroundColor: DeskflowColors.background,
          appBar: AppBar(title: const Text('Ошибка')),
          body: ErrorStateWidget(
            message: error.toString(),
            onRetry: () =>
                ref.invalidate(productDetailProvider(productId!)),
          ),
        ),
      );
    }

    return const _ProductForm();
  }
}

/// Product create/edit form.
class _ProductForm extends HookConsumerWidget {
  final Product? product;

  const _ProductForm({this.product});

  bool get isEditing => product != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController =
        useTextEditingController(text: product?.name ?? '');
    final skuController =
        useTextEditingController(text: product?.sku ?? '');
    final priceController = useTextEditingController(
        text: product != null ? product!.price.toStringAsFixed(2) : '');
    final descController =
        useTextEditingController(text: product?.description ?? '');
    final isActive = useState(product?.isActive ?? true);
    final isLoading = useState(false);
    final formKey = useMemoized(() => GlobalKey<FormState>());

    // Image picker state
    final pickedImageBytes = useState<Uint8List?>(null);
    final pickedImageExt = useState<String>('jpg');
    final imageUrl = useState<String?>(product?.imageUrl);
    final isUploadingImage = useState(false);

    Future<void> pickImage() async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      pickedImageBytes.value = bytes;
      pickedImageExt.value = (ext == 'png' || ext == 'webp') ? ext : 'jpeg';
    }

    /// Upload picked image and return the public URL.
    Future<String?> uploadImage(String productId) async {
      if (pickedImageBytes.value == null) return imageUrl.value;
      isUploadingImage.value = true;
      try {
        final orgId = ref.read(currentOrgIdProvider);
        if (orgId == null) return imageUrl.value;
        final url = await ref.read(productRepositoryProvider).uploadProductImage(
              orgId: orgId,
              productId: productId,
              bytes: pickedImageBytes.value!,
              fileExt: pickedImageExt.value,
            );
        imageUrl.value = url;
        return url;
      } catch (e) {
        _log.e('uploadImage failed: $e');
        return imageUrl.value;
      } finally {
        isUploadingImage.value = false;
      }
    }

    Future<void> save() async {
      if (!formKey.currentState!.validate()) return;

      final orgId = ref.read(currentOrgIdProvider);
      if (orgId == null) return;

      isLoading.value = true;
      try {
        final repo = ref.read(productRepositoryProvider);
        final price =
            double.tryParse(priceController.text.trim()) ?? 0.0;

        if (isEditing) {
          // Upload image if picked
          final uploadedUrl = await uploadImage(product!.id);

          await repo.updateProduct(
            productId: product!.id,
            name: nameController.text.trim(),
            price: price,
            sku: skuController.text.trim().isEmpty
                ? null
                : skuController.text.trim(),
            description: descController.text.trim().isEmpty
                ? null
                : descController.text.trim(),
            imageUrl: uploadedUrl,
            isActive: isActive.value,
          );
          ref.invalidate(productDetailProvider(product!.id));
        } else {
          final created = await repo.createProduct(
            orgId: orgId,
            name: nameController.text.trim(),
            price: price,
            sku: skuController.text.trim().isEmpty
                ? null
                : skuController.text.trim(),
            description: descController.text.trim().isEmpty
                ? null
                : descController.text.trim(),
          );

          // Upload image for newly created product
          if (pickedImageBytes.value != null) {
            final uploadedUrl = await uploadImage(created.id);
            if (uploadedUrl != null) {
              await repo.updateProduct(
                productId: created.id,
                name: created.name,
                price: created.price,
                imageUrl: uploadedUrl,
              );
            }
          }
        }

        ref.invalidate(productsListProvider());

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditing ? 'Товар обновлён' : 'Товар создан'),
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> delete() async {
      if (product == null) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: DeskflowColors.modalSurface,
          title: const Text('Удалить товар'),
          content: Text('Удалить «${product!.name}»?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: DeskflowColors.destructiveSolid,
              ),
              child: const Text('Удалить'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      if (!context.mounted) return;

      try {
        // Delete not implemented in repo - deactivate instead
        await ref
            .read(productRepositoryProvider)
            .updateProduct(
              productId: product!.id,
              name: product!.name,
              price: product!.price,
              isActive: false,
            );
        ref.invalidate(productsListProvider());
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Товар деактивирован')),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    }

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Редактировать товар' : 'Новый товар'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DeskflowSpacing.lg),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo section
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Фото', style: DeskflowTypography.caption),
                    const SizedBox(height: DeskflowSpacing.md),
                    GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: DeskflowColors.glassSurface,
                          borderRadius:
                              BorderRadius.circular(DeskflowRadius.md),
                          border: Border.all(
                            color: DeskflowColors.glassBorder,
                            width: 0.5,
                          ),
                        ),
                        child: pickedImageBytes.value != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(
                                    DeskflowRadius.md),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(
                                      pickedImageBytes.value!,
                                      fit: BoxFit.cover,
                                    ),
                                    Positioned(
                                      bottom: DeskflowSpacing.sm,
                                      right: DeskflowSpacing.sm,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: DeskflowSpacing.sm,
                                          vertical: DeskflowSpacing.xs,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(
                                              DeskflowRadius.sm),
                                        ),
                                        child: const Text(
                                          'Изменить',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : imageUrl.value != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                        DeskflowRadius.md),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          imageUrl.value!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          errorBuilder: (_, _, _) =>
                                              const _PhotoPlaceholder(),
                                        ),
                                        Positioned(
                                          bottom: DeskflowSpacing.sm,
                                          right: DeskflowSpacing.sm,
                                          child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: DeskflowSpacing.sm,
                                              vertical: DeskflowSpacing.xs,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      DeskflowRadius.sm),
                                            ),
                                            child: const Text(
                                              'Изменить',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : const _PhotoPlaceholder(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: DeskflowSpacing.lg),

              // Main info
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Основное', style: DeskflowTypography.caption),
                    const SizedBox(height: DeskflowSpacing.md),
                    GlassTextField(
                      label: 'Название',
                      hint: 'Название товара',
                      controller: nameController,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Введите название';
                        }
                        if (v.trim().length > 200) {
                          return 'Макс. 200 символов';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: DeskflowSpacing.md),
                    GlassTextField(
                      label: 'Артикул (SKU)',
                      hint: 'ABC-123',
                      controller: skuController,
                    ),
                    const SizedBox(height: DeskflowSpacing.md),
                    GlassTextField(
                      label: 'Цена',
                      hint: '0.00',
                      controller: priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Введите цену';
                        }
                        final price = double.tryParse(v.trim());
                        if (price == null || price < 0) {
                          return 'Некорректная цена';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: DeskflowSpacing.lg),

              // Description
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Описание', style: DeskflowTypography.caption),
                    const SizedBox(height: DeskflowSpacing.md),
                    GlassTextField(
                      label: 'Описание товара',
                      hint: 'Подробное описание...',
                      controller: descController,
                      maxLines: 5,
                      minLines: 3,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: DeskflowSpacing.lg),

              // Active toggle
              GlassCard(
                child: SwitchListTile(
                  title: const Text(
                    'Активный',
                    style: DeskflowTypography.body,
                  ),
                  subtitle: Text(
                    'Неактивные товары скрыты из каталога',
                    style: DeskflowTypography.caption,
                  ),
                  value: isActive.value,
                  onChanged: (v) => isActive.value = v,
                  activeThumbColor: DeskflowColors.successSolid,
                  contentPadding: EdgeInsets.zero,
                ),
              ),

              const SizedBox(height: DeskflowSpacing.xxl),

              // Save button
              PillButton(
                label: 'Сохранить',
                onPressed: save,
                isLoading: isLoading.value,
              ),

              if (isEditing) ...[
                const SizedBox(height: DeskflowSpacing.md),
                TextButton(
                  onPressed: delete,
                  style: TextButton.styleFrom(
                    foregroundColor: DeskflowColors.destructiveSolid,
                  ),
                  child: const Text('Удалить товар'),
                ),
              ],

              const SizedBox(height: DeskflowSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder for product photo upload area.
class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo_rounded,
            color: DeskflowColors.textTertiary,
            size: 40,
          ),
          SizedBox(height: DeskflowSpacing.sm),
          Text(
            'Добавить фото',
            style: DeskflowTypography.caption,
          ),
        ],
      ),
    );
  }
}
