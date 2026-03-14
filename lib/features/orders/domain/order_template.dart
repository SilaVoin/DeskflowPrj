import 'package:deskflow/features/orders/domain/order_composition.dart';

class OrderTemplate {
  final String id;
  final String organizationId;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final OrderComposition composition;

  const OrderTemplate({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.composition,
  });

  factory OrderTemplate.fromJson(Map<String, dynamic> json) {
    return OrderTemplate(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      composition: OrderComposition(
        items: (json['items'] as List<dynamic>? ?? const [])
            .map(
              (item) => OrderCompositionItem.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'items': composition.items.map((item) => item.toJson()).toList(),
    };
  }
}
