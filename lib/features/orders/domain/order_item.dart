/// Order item domain model — snapshot of product at time of order.
class OrderItem {
  final String id;
  final String orderId;
  final String? productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final DateTime createdAt;

  const OrderItem({
    required this.id,
    required this.orderId,
    this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.createdAt,
  });

  /// Subtotal for this line item.
  double get subtotal => unitPrice * quantity;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String,
      unitPrice: (json['unit_price'] as num).toDouble(),
      quantity: json['quantity'] as int? ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
