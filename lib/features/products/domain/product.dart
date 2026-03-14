import 'package:deskflow/core/utils/currency_formatter.dart';

class Product {
  final String id;
  final String organizationId;
  final String name;
  final double price;
  final String? sku;
  final String? description;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;

  const Product({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.price,
    this.sku,
    this.description,
    this.imageUrl,
    this.isActive = true,
    required this.createdAt,
  });

  String get formattedPrice => CurrencyFormatter.formatCompact(price);

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      sku: json['sku'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'organization_id': organizationId,
      'name': name,
      'price': price,
      if (sku != null) 'sku': sku,
      if (description != null) 'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
      'is_active': isActive,
    };
  }

  Product copyWith({
    String? name,
    double? price,
    String? sku,
    String? description,
    String? imageUrl,
    bool? isActive,
  }) {
    return Product(
      id: id,
      organizationId: organizationId,
      name: name ?? this.name,
      price: price ?? this.price,
      sku: sku ?? this.sku,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}
