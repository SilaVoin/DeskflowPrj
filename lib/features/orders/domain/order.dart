import 'package:deskflow/features/orders/domain/order_item.dart';
import 'package:deskflow/features/orders/domain/order_status.dart';

class Order {
  final String id;
  final String organizationId;
  final String? customerId;
  final String statusId;
  final int orderNumber;
  final double totalAmount;
  final double deliveryCost;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  final OrderStatus? status;
  final String? customerName;
  final List<OrderItem> items;

  const Order({
    required this.id,
    required this.organizationId,
    this.customerId,
    required this.statusId,
    required this.orderNumber,
    required this.totalAmount,
    this.deliveryCost = 0,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.status,
    this.customerName,
    this.items = const [],
  });

  double get itemsTotal => totalAmount;

  double get grandTotal => totalAmount + deliveryCost;

  String get formattedNumber => '#${orderNumber.toString().padLeft(3, '0')}';

  factory Order.fromJson(Map<String, dynamic> json) {
    OrderStatus? status;
    if (json['order_statuses'] != null) {
      status = OrderStatus.fromJson(
          json['order_statuses'] as Map<String, dynamic>);
    }

    String? customerName;
    if (json['customers'] != null) {
      customerName =
          (json['customers'] as Map<String, dynamic>)['name'] as String?;
    }

    List<OrderItem> items = [];
    if (json['order_items'] != null) {
      items = (json['order_items'] as List)
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Order(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      customerId: json['customer_id'] as String?,
      statusId: json['status_id'] as String,
      orderNumber: json['order_number'] as int? ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      deliveryCost: (json['delivery_cost'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      status: status,
      customerName: customerName,
      items: items,
    );
  }
}
