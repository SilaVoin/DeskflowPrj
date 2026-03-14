import 'package:deskflow/features/orders/domain/order_item.dart';

class OrderCompositionItem {
  final String? productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final String? note;

  const OrderCompositionItem({
    this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    this.note,
  });

  factory OrderCompositionItem.fromJson(Map<String, dynamic> json) {
    return OrderCompositionItem(
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String,
      unitPrice: (json['unit_price'] as num).toDouble(),
      quantity: json['quantity'] as int? ?? 1,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'unit_price': unitPrice,
      'quantity': quantity,
      if (note != null) 'note': note,
    };
  }
}

class OrderComposition {
  final List<OrderCompositionItem> items;

  const OrderComposition({
    this.items = const [],
  });

  factory OrderComposition.fromOrderItems(List<OrderItem> items) {
    return OrderComposition(
      items: items
          .map(
            (item) => OrderCompositionItem(
              productId: item.productId,
              productName: item.productName,
              unitPrice: item.unitPrice,
              quantity: item.quantity,
            ),
          )
          .toList(),
    );
  }

  factory OrderComposition.fromJson(Map<String, dynamic> json) {
    return OrderComposition(
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((item) => OrderCompositionItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}
