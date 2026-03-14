class OrderItem {
  final String id;
  final String orderId;
  final String? productId;
  final String productName;
  final double unitPrice;
  final int quantity;

  const OrderItem({
    required this.id,
    required this.orderId,
    this.productId,
    required this.productName,
    required this.unitPrice,
    this.quantity = 1,
  });

  double get subtotal => unitPrice * quantity;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String,
      unitPrice: (json['unit_price'] as num).toDouble(),
      quantity: json['quantity'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      if (productId != null) 'product_id': productId,
      'product_name': productName,
      'unit_price': unitPrice,
      'quantity': quantity,
    };
  }
}
