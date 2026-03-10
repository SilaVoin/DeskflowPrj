import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deskflow/core/errors/supabase_error_handler.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/orders/domain/audit_event.dart';
import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/orders/domain/order_item.dart';
import 'package:deskflow/features/orders/domain/order_status.dart';

final _log = AppLogger.getLogger('OrderRepository');

/// Handles all order-related database operations.
class OrderRepository {
  final SupabaseClient _client;

  OrderRepository(this._client);

  // ──────────────────────────── Pipeline ─────────────────────────────

  /// Fetch order status pipeline for an organization (sorted).
  Future<List<OrderStatus>> getPipeline(String orgId) async {
    _log.d('getPipeline: orgId=$orgId');
    return supabaseGuard(() async {
      final data = await _client
          .from('order_statuses')
          .select()
          .eq('organization_id', orgId)
          // [FIX] ascending: true required — postgrest-dart defaults to descending.
          .order('sort_order', ascending: true);

      return (data as List)
          .map((e) => OrderStatus.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// Get default status for new orders.
  Future<OrderStatus> getDefaultStatus(String orgId) async {
    _log.d('getDefaultStatus: orgId=$orgId');
    return supabaseGuard(() async {
      final data = await _client
          .from('order_statuses')
          .select()
          .eq('organization_id', orgId)
          .eq('is_default', true)
          .single();

      return OrderStatus.fromJson(data);
    });
  }

  // ──────────────────────────── Orders ───────────────────────────────

  /// Fetch orders for org with joined status + customer name.
  Future<List<Order>> getOrders({
    required String orgId,
    String? statusId,
    int limit = 20,
    int offset = 0,
  }) async {
    _log.d('getOrders: orgId=$orgId, statusId=$statusId, '
        'limit=$limit, offset=$offset');
    return supabaseGuard(() async {
      var query = _client
          .from('orders')
          .select('*, order_statuses(*), customers(name)')
          .eq('organization_id', orgId);

      if (statusId != null) {
        query = query.eq('status_id', statusId);
      }

      final data = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (data as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// Search orders by number, customer name, or notes (server-side).
  Future<List<Order>> searchOrders({
    required String orgId,
    required String query,
    String? statusId,
  }) async {
    _log.d('[FIX] searchOrders: orgId=$orgId, query="$query", statusId=$statusId');
    return supabaseGuard(() async {
      // Normalize query: trim whitespace
      final normalizedQuery = query.trim();
      if (normalizedQuery.isEmpty) return [];

      // Try to parse as order number — strip "#" prefix and leading zeros
      final numberStr = normalizedQuery
          .replaceAll('#', '')
          .replaceAll(RegExp(r'^0+'), '');
      final orderNumber = int.tryParse(numberStr);

      // Step 1: Find customer IDs matching the query
      final customerData = await _client
          .from('customers')
          .select('id')
          .eq('organization_id', orgId)
          .ilike('name', '%$normalizedQuery%');
      final customerIds = (customerData as List)
          .map((e) => e['id'] as String)
          .toList();

      _log.d('[FIX] searchOrders: orderNumber=$orderNumber, '
          'matchingCustomers=${customerIds.length}');

      // Step 2: Build OR filter parts
      final orParts = <String>['notes.ilike.%$normalizedQuery%'];

      if (orderNumber != null) {
        orParts.add('order_number.eq.$orderNumber');
      }

      if (customerIds.isNotEmpty) {
        orParts.add('customer_id.in.(${customerIds.join(",")})');
      }

      final orFilter = orParts.join(',');

      // Step 3: Query orders with combined filter
      var queryBuilder = _client
          .from('orders')
          .select('*, order_statuses(*), customers(name)')
          .eq('organization_id', orgId);

      if (statusId != null) {
        queryBuilder = queryBuilder.eq('status_id', statusId);
      }

      final data = await queryBuilder
          .or(orFilter)
          .order('created_at', ascending: false)
          .limit(50);

      final results = (data as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();

      _log.d('[FIX] searchOrders: found ${results.length} orders');
      return results;
    });
  }

  /// Fetch single order with full details.
  Future<Order> getOrder(String orderId) async {
    _log.d('getOrder: orderId=$orderId');
    return supabaseGuard(() async {
      final data = await _client
          .from('orders')
          .select(
              '*, order_statuses(*), customers(name, phone, email), order_items(*)')
          .eq('id', orderId)
          .single();

      return Order.fromJson(data);
    });
  }

  /// Create a new order.
  Future<Order> createOrder({
    required String orgId,
    required String userId,
    required String statusId,
    String? customerId,
    double deliveryCost = 0,
    String? notes,
    List<Map<String, dynamic>> items = const [],
  }) async {
    _log.d('createOrder: orgId=$orgId');
    return supabaseGuard(() async {
      // 1. Calculate total from items (items-only subtotal, delivery stored separately)
      double total = 0;
      for (final item in items) {
        total +=
            (item['unit_price'] as num).toDouble() * (item['quantity'] as int);
      }
      _log.d('[FIX] createOrder: items total=$total, deliveryCost=$deliveryCost (stored separately)');

      // 2. Insert order
      final orderData = await _client
          .from('orders')
          .insert({
            'organization_id': orgId,
            'customer_id': customerId,
            'status_id': statusId,
            'total_amount': total,
            'delivery_cost': deliveryCost,
            'notes': notes,
            'created_by': userId,
          })
          .select('*, order_statuses(*), customers(name)')
          .single();

      final order = Order.fromJson(orderData);

      // 3. Insert items
      if (items.isNotEmpty) {
        final itemRows = items
            .map((item) => {
                  'order_id': order.id,
                  'product_id': item['product_id'],
                  'product_name': item['product_name'],
                  'unit_price': item['unit_price'],
                  'quantity': item['quantity'],
                })
            .toList();
        await _client.from('order_items').insert(itemRows);
      }

      // 4. Audit event
      await _insertAudit(
        orgId: orgId,
        entityType: 'order',
        entityId: order.id,
        action: 'order_created',
        userId: userId,
        newValue: {'order_number': order.orderNumber},
      );

      return order;
    });
  }

  /// Update order status.
  Future<Order> updateStatus({
    required String orderId,
    required String statusId,
    required String userId,
    required String orgId,
    String? oldStatusName,
    String? newStatusName,
  }) async {
    _log.d('updateStatus: orderId=$orderId, statusId=$statusId');
    return supabaseGuard(() async {
      final data = await _client
          .from('orders')
          .update({'status_id': statusId})
          .eq('id', orderId)
          .select('*, order_statuses(*), customers(name)')
          .single();

      await _insertAudit(
        orgId: orgId,
        entityType: 'order',
        entityId: orderId,
        action: 'status_changed',
        userId: userId,
        oldValue:
            oldStatusName != null ? {'status': oldStatusName} : null,
        newValue:
            newStatusName != null ? {'status': newStatusName} : null,
      );

      return Order.fromJson(data);
    });
  }

  /// Update order details (notes, delivery cost, customer).
  Future<Order> updateOrder({
    required String orderId,
    required String userId,
    required String orgId,
    String? customerId,
    double? deliveryCost,
    String? notes,
  }) async {
    _log.d('updateOrder: orderId=$orderId');
    return supabaseGuard(() async {
      final updates = <String, dynamic>{};
      if (customerId != null) updates['customer_id'] = customerId;
      if (deliveryCost != null) updates['delivery_cost'] = deliveryCost;
      if (notes != null) updates['notes'] = notes;

      final data = await _client
          .from('orders')
          .update(updates)
          .eq('id', orderId)
          .select('*, order_statuses(*), customers(name), order_items(*)')
          .single();

      await _insertAudit(
        orgId: orgId,
        entityType: 'order',
        entityId: orderId,
        action: 'order_updated',
        userId: userId,
      );

      return Order.fromJson(data);
    });
  }

  // ──────────────────────────── Order Items ──────────────────────────

  /// Add item to order.
  Future<OrderItem> addItem({
    required String orderId,
    required String productId,
    required String productName,
    required double unitPrice,
    int quantity = 1,
  }) async {
    _log.d('addItem: orderId=$orderId, product=$productName');
    return supabaseGuard(() async {
      final data = await _client
          .from('order_items')
          .insert({
            'order_id': orderId,
            'product_id': productId,
            'product_name': productName,
            'unit_price': unitPrice,
            'quantity': quantity,
          })
          .select()
          .single();

      // Recalculate total
      await _recalculateTotal(orderId);

      return OrderItem.fromJson(data);
    });
  }

  /// Remove item from order.
  Future<void> removeItem(String itemId, String orderId) async {
    _log.d('removeItem: itemId=$itemId');
    return supabaseGuard(() async {
      await _client.from('order_items').delete().eq('id', itemId);
      await _recalculateTotal(orderId);
    });
  }

  /// Recalculate order total from items + delivery.
  Future<void> _recalculateTotal(String orderId) async {
    final items = await _client
        .from('order_items')
        .select('unit_price, quantity')
        .eq('order_id', orderId);

    double total = 0;
    for (final item in items as List) {
      total += (item['unit_price'] as num).toDouble() *
          (item['quantity'] as int);
    }

    // [FIX] total_amount stores items-only subtotal; delivery_cost is separate
    _log.d('[FIX] _recalculateTotal: items total=$total (delivery not included)');

    await _client
        .from('orders')
        .update({'total_amount': total})
        .eq('id', orderId);
  }

  // ──────────────────────────── Customers ────────────────────────────

  /// Search customers by name.
  Future<List<Customer>> searchCustomers({
    required String orgId,
    required String query,
  }) async {
    _log.d('searchCustomers: orgId=$orgId, query=$query');
    return supabaseGuard(() async {
      final data = await _client
          .from('customers')
          .select()
          .eq('organization_id', orgId)
          .ilike('name', '%$query%')
          .order('name')
          .limit(20);

      return (data as List)
          .map((e) => Customer.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// Create a new customer.
  Future<Customer> createCustomer({
    required String orgId,
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    _log.d('createCustomer: orgId=$orgId, name=$name');
    return supabaseGuard(() async {
      final data = await _client
          .from('customers')
          .insert({
            'organization_id': orgId,
            'name': name,
            if (phone != null) 'phone': phone,
            if (email != null) 'email': email,
            if (address != null) 'address': address,
          })
          .select()
          .single();

      return Customer.fromJson(data);
    });
  }

  // ──────────────────────────── Audit ────────────────────────────────

  /// Get audit events for an order.
  Future<List<AuditEvent>> getOrderAuditLog(String orderId) async {
    _log.d('getOrderAuditLog: orderId=$orderId');
    return supabaseGuard(() async {
      final data = await _client
          .from('audit_events')
          .select('*, profiles!audit_events_user_id_fkey(full_name)')
          .eq('entity_type', 'order')
          .eq('entity_id', orderId)
          .order('created_at', ascending: false);

      return (data as List)
          .map((e) => AuditEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// Insert audit event.
  Future<void> _insertAudit({
    required String orgId,
    required String entityType,
    required String entityId,
    required String action,
    required String userId,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
  }) async {
    await _client.from('audit_events').insert({
      'organization_id': orgId,
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'user_id': userId,
      if (oldValue != null) 'old_value': oldValue,
      if (newValue != null) 'new_value': newValue,
    });
  }
}
