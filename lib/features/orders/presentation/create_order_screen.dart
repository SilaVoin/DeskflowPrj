import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/errors/deskflow_exception.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/core/utils/currency_formatter.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/glass_text_field.dart';
import 'package:deskflow/core/widgets/pill_button.dart';
import 'package:deskflow/features/customers/domain/customer_providers.dart';
import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/orders/domain/order_notifier.dart';
import 'package:deskflow/features/products/domain/product.dart';
import 'package:deskflow/features/products/domain/product_providers.dart';

final _log = AppLogger.getLogger('CreateOrderScreen');


/// Create new order screen.
class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _notesController = TextEditingController();
  final _deliveryCostController = TextEditingController(text: '0');
  final _customerSearchController = TextEditingController();

  Customer? _selectedCustomer;
  final List<_OrderItemDraft> _items = [];

  @override
  void dispose() {
    _notesController.dispose();
    _deliveryCostController.dispose();
    _customerSearchController.dispose();
    super.dispose();
  }

  double get _itemsTotal =>
      _items.fold(0, (sum, item) => sum + item.unitPrice * item.quantity);

  double get _deliveryCost =>
      double.tryParse(_deliveryCostController.text) ?? 0;

  double get _grandTotal => _itemsTotal + _deliveryCost;

  Future<void> _handleCreate() async {
    final orderNotifier = ref.read(orderNotifierProvider.notifier);

    final order = await orderNotifier.createOrder(
      customerId: _selectedCustomer?.id,
      deliveryCost: _deliveryCost,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      items: _items
          .map((item) => {
                'product_id': item.productId,
                'product_name': item.productName,
                'unit_price': item.unitPrice,
                'quantity': item.quantity,
              })
          .toList(),
    );

    if (order != null && mounted) {
      context.go('/orders/${order.id}');
    }
  }

  // [FIX] Customer picker — shows bottom sheet with search and selection
  void _showCustomerPicker() {
    _log.d('[FIX] _showCustomerPicker: opening customer picker');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerPickerSheet(
        onCustomerSelected: (customer) {
          _log.d('[FIX] _showCustomerPicker: selected customer=${customer.name}');
          setState(() => _selectedCustomer = customer);
        },
      ),
    );
  }

  void _addProductFromCatalog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CatalogPickerSheet(
        ref: ref,
        onProductSelected: (product, quantity) {
          setState(() {
            // Merge with existing item if same product
            final existing = _items.indexWhere(
              (i) => i.productId == product.id,
            );
            if (existing >= 0) {
              _items[existing].quantity += quantity;
            } else {
              _items.add(_OrderItemDraft(
                productId: product.id,
                productName: product.name,
                unitPrice: product.price,
                quantity: quantity,
              ));
            }
          });
        },
        onManualEntry: _addManualItem,
      ),
    );
  }

  void _addManualItem() {
    showDialog(
      context: context,
      builder: (ctx) => _ManualItemDialog(
        onAdd: (name, price, qty) {
          setState(() {
            _items.add(_OrderItemDraft(
              productName: name,
              unitPrice: price,
              quantity: qty,
            ));
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderNotifierProvider);
    final isLoading = orderState.isLoading;

    ref.listen<AsyncValue<void>>(orderNotifierProvider, (_, next) {
      if (next.hasError) {
        final error = next.error;
        final message = error is DeskflowException
            ? error.message
            : 'Произошла ошибка';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: DeskflowColors.destructiveSolid,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Новый заказ'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: DeskflowSpacing.md),
            child: PillButton(
              label: 'Сохранить',
              isLoading: isLoading,
              onPressed: isLoading ? null : _handleCreate,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DeskflowSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Customer section ──
              const Text('Клиент', style: DeskflowTypography.h3),
              const SizedBox(height: DeskflowSpacing.sm),
              GestureDetector(
                onTap: _selectedCustomer == null ? _showCustomerPicker : null,
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedCustomer != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(_selectedCustomer!.name,
                                      style: DeskflowTypography.body),
                                  if (_selectedCustomer!.phone != null)
                                    Text(_selectedCustomer!.phone!,
                                        style:
                                            DeskflowTypography.bodySmall),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  size: 18),
                              onPressed: () => setState(
                                  () => _selectedCustomer = null),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            const Icon(Icons.person_add_rounded,
                                size: 18, color: DeskflowColors.textTertiary),
                            const SizedBox(width: DeskflowSpacing.sm),
                            Text(
                              'Выбрать клиента (необязательно)',
                              style: DeskflowTypography.bodySmall.copyWith(
                                color: DeskflowColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: DeskflowSpacing.xl),

              // ── Items section ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Товары', style: DeskflowTypography.h3),
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Добавить'),
                    onPressed: _addProductFromCatalog,
                  ),
                ],
              ),
              const SizedBox(height: DeskflowSpacing.sm),
              if (_items.isEmpty)
                GlassCard(
                  child: Center(
                    child: Text(
                      'Нет товаров',
                      style: DeskflowTypography.bodySmall,
                    ),
                  ),
                )
              else
                ...List.generate(_items.length, (i) {
                  final item = _items[i];
                  return Padding(
                    padding: const EdgeInsets.only(
                        bottom: DeskflowSpacing.sm),
                    child: GlassCard(
                      padding:
                          const EdgeInsets.all(DeskflowSpacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(item.productName,
                                    style: DeskflowTypography.body),
                                Text(
                                  '${item.quantity} × ${CurrencyFormatter.formatCompact(item.unitPrice)} = ${CurrencyFormatter.formatCompact(item.unitPrice * item.quantity)}',
                                  style:
                                      DeskflowTypography.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 18,
                                color:
                                    DeskflowColors.destructiveSolid),
                            onPressed: () =>
                                setState(() => _items.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: DeskflowSpacing.xl),

              // ── Delivery ──
              const Text('Доставка', style: DeskflowTypography.h3),
              const SizedBox(height: DeskflowSpacing.sm),
              GlassCard(
                child: GlassTextField(
                  label: 'Стоимость доставки (₽)',
                  controller: _deliveryCostController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),

              const SizedBox(height: DeskflowSpacing.xl),

              // ── Notes ──
              const Text('Заметки', style: DeskflowTypography.h3),
              const SizedBox(height: DeskflowSpacing.sm),
              GlassCard(
                child: GlassTextField(
                  label: 'Заметки к заказу',
                  hint: 'Необязательно',
                  controller: _notesController,
                  maxLines: 3,
                ),
              ),

              const SizedBox(height: DeskflowSpacing.xl),

              // ── Total ──
              GlassCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Итого',
                        style: DeskflowTypography.h2),
                    Text(
                      CurrencyFormatter.formatCompact(_grandTotal),
                      style: DeskflowTypography.h2,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: DeskflowSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draft order item (before saving to DB).
class _OrderItemDraft {
  final String? productId;
  final String productName;
  final double unitPrice;
  int quantity;

  _OrderItemDraft({
    this.productId,
    required this.productName,
    required this.unitPrice,
    this.quantity = 1,
  });
}

/// Dialog for manually entering a custom order item.
///
/// Extracted into a [StatefulWidget] so that the three
/// [TextEditingController]s are properly disposed when the dialog closes,
/// avoiding the memory leak that occurs when controllers are created
/// inside a [showDialog] builder function.
class _ManualItemDialog extends StatefulWidget {
  const _ManualItemDialog({required this.onAdd});

  /// Called with (name, price, quantity) when the user confirms.
  final void Function(String name, double price, int qty) onAdd;

  @override
  State<_ManualItemDialog> createState() => _ManualItemDialogState();
}

class _ManualItemDialogState extends State<_ManualItemDialog> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final qty = int.tryParse(_qtyCtrl.text) ?? 1;
    if (name.isNotEmpty && price > 0) {
      widget.onAdd(name, price, qty);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить товар', style: DeskflowTypography.h3),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassTextField(
            label: 'Название',
            controller: _nameCtrl,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: DeskflowSpacing.md),
          GlassTextField(
            label: 'Цена',
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: DeskflowSpacing.md),
          GlassTextField(
            label: 'Количество',
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}

/// Bottom sheet for picking a product from the catalog.
class _CatalogPickerSheet extends HookConsumerWidget {
  const _CatalogPickerSheet({
    required this.ref,
    required this.onProductSelected,
    required this.onManualEntry,
  });

  final WidgetRef ref;
  final void Function(Product product, int quantity) onProductSelected;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = useState('');
    final productsAsync = ref.watch(
      productsListProvider(
        search: searchQuery.value.isEmpty ? null : searchQuery.value,
      ),
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: DeskflowColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DeskflowRadius.xl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        DeskflowSpacing.lg,
        DeskflowSpacing.md,
        DeskflowSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + DeskflowSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DeskflowColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: DeskflowSpacing.md),

          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Добавить товар', style: DeskflowTypography.h2),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onManualEntry();
                },
                child: const Text('Вручную'),
              ),
            ],
          ),
          const SizedBox(height: DeskflowSpacing.md),

          // Search bar
          TextField(
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Поиск в каталоге...',
              hintStyle: const TextStyle(color: DeskflowColors.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: DeskflowColors.textSecondary),
              filled: true,
              fillColor: DeskflowColors.glassSurface,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(DeskflowRadius.pill),
                borderSide: const BorderSide(
                  color: DeskflowColors.glassBorder,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(DeskflowRadius.pill),
                borderSide: const BorderSide(
                  color: DeskflowColors.glassBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(DeskflowRadius.pill),
                borderSide: const BorderSide(
                  color: DeskflowColors.primarySolid,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: DeskflowSpacing.md),
            ),
            style: const TextStyle(color: DeskflowColors.textPrimary),
            onChanged: (v) => searchQuery.value = v,
          ),
          const SizedBox(height: DeskflowSpacing.md),

          // Product list
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(e.toString(),
                    style: const TextStyle(color: DeskflowColors.textSecondary)),
              ),
              data: (paginated) {
                final products = paginated.items;
                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shopping_bag_outlined,
                            size: 48, color: DeskflowColors.textTertiary),
                        const SizedBox(height: DeskflowSpacing.sm),
                        Text(
                          searchQuery.value.isNotEmpty
                              ? 'Ничего не найдено'
                              : 'Каталог пуст',
                          style: const TextStyle(
                              color: DeskflowColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: products.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: DeskflowSpacing.sm),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _CatalogProductTile(
                      product: product,
                      onAdd: (qty) {
                        Navigator.pop(context);
                        onProductSelected(product, qty);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Single product row in the catalog picker.
class _CatalogProductTile extends HookWidget {
  const _CatalogProductTile({
    required this.product,
    required this.onAdd,
  });

  final Product product;
  final void Function(int qty) onAdd;

  @override
  Widget build(BuildContext context) {
    final qty = useState(1);

    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: DeskflowSpacing.md,
        vertical: DeskflowSpacing.sm,
      ),
      child: Row(
        children: [
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: DeskflowTypography.body),
                Text(
                  CurrencyFormatter.formatCompact(product.price),
                  style: DeskflowTypography.bodySmall,
                ),
              ],
            ),
          ),

          // Quantity stepper
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_rounded, size: 18),
                onPressed:
                    qty.value > 1 ? () => qty.value-- : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '${qty.value}',
                  textAlign: TextAlign.center,
                  style: DeskflowTypography.body,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded, size: 18),
                onPressed: () => qty.value++,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: DeskflowSpacing.sm),
              // Add button
              FilledButton(
                onPressed: () => onAdd(qty.value),
                style: FilledButton.styleFrom(
                  backgroundColor: DeskflowColors.primarySolid,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DeskflowSpacing.md,
                    vertical: DeskflowSpacing.xs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Добавить'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// [FIX] Bottom sheet for picking a customer from the organization.
class _CustomerPickerSheet extends HookConsumerWidget {
  const _CustomerPickerSheet({
    required this.onCustomerSelected,
  });

  final void Function(Customer customer) onCustomerSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = useState('');
    final customersAsync = ref.watch(
      customersListProvider(
        search: searchQuery.value.isEmpty ? null : searchQuery.value,
      ),
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: DeskflowColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DeskflowRadius.xl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        DeskflowSpacing.lg,
        DeskflowSpacing.md,
        DeskflowSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + DeskflowSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DeskflowColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: DeskflowSpacing.md),

          // Title
          const Text('Выбрать клиента', style: DeskflowTypography.h2),
          const SizedBox(height: DeskflowSpacing.md),

          // Search bar
          TextField(
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Поиск клиентов...',
              hintStyle: const TextStyle(color: DeskflowColors.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: DeskflowColors.textSecondary),
              filled: true,
              fillColor: DeskflowColors.glassSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DeskflowRadius.md),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: DeskflowSpacing.md,
                vertical: DeskflowSpacing.sm,
              ),
            ),
            style: DeskflowTypography.body,
            onChanged: (value) => searchQuery.value = value,
          ),
          const SizedBox(height: DeskflowSpacing.md),

          // Customer list
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: DeskflowColors.primarySolid,
                ),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Ошибка загрузки: $e',
                  style: DeskflowTypography.bodySmall.copyWith(
                    color: DeskflowColors.destructiveSolid,
                  ),
                ),
              ),
              data: (paginated) {
                final customers = paginated.items;
                if (customers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(DeskflowSpacing.xl),
                      child: Text(
                        searchQuery.value.isEmpty
                            ? 'Нет клиентов'
                            : 'Ничего не найдено',
                        style: DeskflowTypography.bodySmall.copyWith(
                          color: DeskflowColors.textTertiary,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: customers.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    color: DeskflowColors.glassBorder,
                  ),
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: DeskflowColors.glassSurface,
                        child: Text(
                          customer.name.isNotEmpty
                              ? customer.name[0].toUpperCase()
                              : '?',
                          style: DeskflowTypography.body.copyWith(
                            color: DeskflowColors.primary,
                          ),
                        ),
                      ),
                      title: Text(customer.name,
                          style: DeskflowTypography.body),
                      subtitle: customer.phone != null
                          ? Text(customer.phone!,
                              style: DeskflowTypography.bodySmall)
                          : null,
                      onTap: () {
                        _log.d('[FIX] _CustomerPickerSheet: selected ${customer.name}');
                        Navigator.pop(context);
                        onCustomerSelected(customer);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
