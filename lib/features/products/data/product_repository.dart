import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deskflow/core/errors/supabase_error_handler.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/products/domain/product.dart';

final _log = AppLogger.getLogger('ProductRepository');

class ProductRepository {
  final SupabaseClient _client;

  ProductRepository(this._client);


  Future<List<Product>> getProducts({
    required String orgId,
    String? search,
    bool? activeOnly,
    int limit = 50,
    int offset = 0,
  }) async {
    _log.d('getProducts: orgId=$orgId, search=$search');
    return supabaseGuard(() async {
      var query = _client
          .from('products')
          .select()
          .eq('organization_id', orgId);

      if (activeOnly == true) {
        query = query.eq('is_active', true);
      }

      if (search != null && search.isNotEmpty) {
        query = query.or(
          'name.ilike.%$search%,sku.ilike.%$search%',
        );
      }

      final data = await query
          .order('name')
          .range(offset, offset + limit - 1);

      return (data as List)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }


  Future<Product> getProduct(String productId) async {
    _log.d('getProduct: productId=$productId');
    return supabaseGuard(() async {
      final data = await _client
          .from('products')
          .select()
          .eq('id', productId)
          .single();

      return Product.fromJson(data);
    });
  }


  Future<Product> createProduct({
    required String orgId,
    required String name,
    required double price,
    String? sku,
    String? description,
    String? imageUrl,
  }) async {
    _log.d('createProduct: orgId=$orgId, name=$name');
    return supabaseGuard(() async {
      final data = await _client
          .from('products')
          .insert({
            'organization_id': orgId,
            'name': name,
            'price': price,
            if (sku != null && sku.isNotEmpty) 'sku': sku,
            if (description != null && description.isNotEmpty)
              'description': description,
            if (imageUrl != null && imageUrl.isNotEmpty)
              'image_url': imageUrl,
            'is_active': true,
          })
          .select()
          .single();

      return Product.fromJson(data);
    });
  }

  Future<Product> updateProduct({
    required String productId,
    required String name,
    required double price,
    String? sku,
    String? description,
    String? imageUrl,
    bool isActive = true,
  }) async {
    _log.d('updateProduct: productId=$productId');
    return supabaseGuard(() async {
      final data = await _client
          .from('products')
          .update({
            'name': name,
            'price': price,
            'sku': sku,
            'description': description,
            'image_url': imageUrl,
            'is_active': isActive,
          })
          .eq('id', productId)
          .select()
          .single();

      return Product.fromJson(data);
    });
  }

  Future<void> toggleActive(String productId, bool isActive) async {
    _log.d('toggleActive: productId=$productId, isActive=$isActive');
    return supabaseGuard(() async {
      await _client
          .from('products')
          .update({'is_active': isActive})
          .eq('id', productId);
    });
  }


  Future<String> uploadProductImage({
    required String orgId,
    required String productId,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    _log.d('uploadProductImage: productId=$productId');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final normalizedExt = fileExt == 'jpeg' ? 'jpg' : fileExt;
    final path = '$orgId/${productId}_$timestamp.$normalizedExt';

    const mimeMap = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
    };
    final contentType = mimeMap[fileExt] ?? 'image/jpeg';
    _log.d('[FIX] uploadProductImage: contentType=$contentType');

    await _client.storage.from('product-images').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    final publicUrl =
        _client.storage.from('product-images').getPublicUrl(path);
    _log.d('uploadProductImage: publicUrl=$publicUrl');
    return publicUrl;
  }
}
