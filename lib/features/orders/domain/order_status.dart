import 'package:flutter/material.dart';

class OrderStatus {
  final String id;
  final String organizationId;
  final String name;
  final String color;
  final int sortOrder;
  final bool isDefault;
  final bool isFinal;

  const OrderStatus({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.color,
    required this.sortOrder,
    required this.isDefault,
    required this.isFinal,
  });

  factory OrderStatus.fromJson(Map<String, dynamic> json) {
    return OrderStatus(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      name: json['name'] as String,
      color: json['color'] as String? ?? '#6B7280',
      sortOrder: json['sort_order'] as int? ?? 0,
      isDefault: json['is_default'] as bool? ?? false,
      isFinal: json['is_final'] as bool? ?? false,
    );
  }

  Color get materialColor {
    final hex = color.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
