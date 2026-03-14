import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deskflow/core/errors/supabase_error_handler.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/orders/domain/audit_event.dart';
import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/orders/domain/order_composition.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/orders/domain/order_item.dart';
import 'package:deskflow/features/orders/domain/order_status.dart';
import 'package:deskflow/features/orders/domain/order_template.dart';
import 'package:deskflow/features/orders/domain/orders_list_controls.dart';
import 'package:deskflow/features/products/domain/product.dart';

final _log = AppLogger.getLogger('OrderRepository');

class OrderRepository {
  final SupabaseClient _client;

  OrderRepository(this._client);


  Future<List<OrderStatus>> getPipeline(String orgId) async {
    _log.d('getPipeline: orgId=$orgId');
    return supabaseGuard(() async {
      final data = await _client
          .from('order_statuses')
          .select()
          .eq('organization_id', orgId)
          .order('sort_order', ascending: true);

      return (data as List)
          .map((e) => OrderStatus.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

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


  Future<List<Order>> getOrders({
    required String orgId,
    String? statusId,
    OrdersPeriodPreset periodPreset = OrdersPeriodPreset.all,
    DateTime? selectedDate,
    OrderDateRange? selectedDateRange,
    OrderAmountRange? amountRange,
    int limit = 20,
    int offset = 0,
  }) async {
    _log.d(
      'getOrders: orgId=$orgId, statusId=$statusId, '
      'periodPreset=$periodPreset, selectedDate=$selectedDate, '
      'selectedDateRange=$selectedDateRange, '
      'amountRange=$amountRange, '
      'limit=$limit, offset=$offset',
    );
    return supabaseGuard(() async {
      dynamic query = _client
          .from('orders')
          .select('*, order_statuses(*), customers(name)')
          .eq('organization_id', orgId);

      if (statusId != null) {
        query = query.eq('status_id', statusId);
      }

      final dateRange = _resolveDateRange(
        selectedDate: selectedDate,
        selectedDateRange: selectedDateRange,
        periodPreset: periodPreset,
      );

      if (dateRange != null) {
        query = query
            .gte('created_at', dateRange.start.toUtc().toIso8601String())
            .lt('created_at', dateRange.end.toUtc().toIso8601String());
      }

      if (amountRange != null) {
        query = query
            .gte('total_amount', amountRange.min)
            .lte('total_amount', amountRange.max);
      }

      query = query.order('created_at', ascending: false);

      final data = await query.range(offset, offset + limit - 1);

      return (data as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  ({DateTime start, DateTime end})? _resolveDateRange({
    required DateTime? selectedDate,
    required OrderDateRange? selectedDateRange,
    required OrdersPeriodPreset periodPreset,
  }) {
    if (selectedDateRange != null) {
      final normalized = selectedDateRange.normalized();
      return (
        start: normalized.start,
        end: normalized.end.add(const Duration(days: 1)),
      );
    }

    if (selectedDate != null) {
      final dayStart = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
      return (
        start: dayStart,
        end: dayStart.add(const Duration(days: 1)),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (periodPreset) {
      case OrdersPeriodPreset.all:
        return null;
      case OrdersPeriodPreset.today:
        return (start: today, end: today.add(const Duration(days: 1)));
      case OrdersPeriodPreset.last7Days:
        return (
          start: today.subtract(const Duration(days: 6)),
          end: today.add(const Duration(days: 1)),
        );
      case OrdersPeriodPreset.last30Days:
        return (
          start: today.subtract(const Duration(days: 29)),
          end: today.add(const Duration(days: 1)),
        );
    }
  }

  Future<List<Order>> searchOrders({
    required String orgId,
    required String query,
    String? statusId,
  }) async {
    _log.d(
      '[FIX] searchOrders: orgId=$orgId, query="$query", statusId=$statusId',
    );
    return supabaseGuard(() async {
      final normalizedQuery = query.trim();
      if (normalizedQuery.isEmpty) return [];

      final numberStr = normalizedQuery
          .replaceAll('#', '')
          .replaceAll(RegExp(r'^0+'), '');
      final orderNumber = int.tryParse(numberStr);

      final customerData = await _client
          .from('customers')
          .select('id')
          .eq('organization_id', orgId)
          .ilike('name', '%$normalizedQuery%');
      final customerIds = (customerData as List)
          .map((e) => e['id'] as String)
          .toList();

      _log.d(
        '[FIX] searchOrders: orderNumber=$orderNumber, '
        'matchingCustomers=${customerIds.length}',
      );

      final orParts = <String>['notes.ilike.%$normalizedQuery%'];

      if (orderNumber != null) {
        orParts.add('order_number.eq.$orderNumber');
      }

      if (customerIds.isNotEmpty) {
        orParts.add('customer_id.in.(${customerIds.join(",")})');
      }

      final orFilter = orParts.join(',');

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

  Future<Order> getOrder(String orderId) async {
    _log.d('getOrder: orderId=$orderId');
    return supabaseGuard(() async {
      final data = await _client
          .from('orders')
          .select(
            '*, order_statuses(*), customers(name, phone, email), order_items(*)',
          )
          .eq('id', orderId)
          .single();

      return Order.fromJson(data);
    });
  }

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
      double total = 0;
      for (final item in items) {
        total +=
            (item['unit_price'] as num).toDouble() * (item['quantity'] as int);
      }
      _log.d(
        '[FIX] createOrder: items total=$total, deliveryCost=$deliveryCost (stored separately)',
      );

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

      if (items.isNotEmpty) {
        final itemRows = items
            .map(
              (item) => {
                'order_id': order.id,
                'product_id': item['product_id'],
                'product_name': item['product_name'],
                'unit_price': item['unit_price'],
                'quantity': item['quantity'],
              },
            )
            .toList();
        await _client.from('order_items').insert(itemRows);
      }

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
        oldValue: oldStatusName != null ? {'status': oldStatusName} : null,
        newValue: newStatusName != null ? {'status': newStatusName} : null,
      );

      return Order.fromJson(data);
    });
  }

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


  Future<List<OrderTemplate>> getOrderTemplates({required String orgId}) async {
    _log.d('getOrderTemplates: orgId=$orgId');
    return supabaseGuard(() async {
      final data = await _client
          .from('order_templates')
          .select()
          .eq('organization_id', orgId)
          .order('updated_at', ascending: false);

      return (data as List)
          .map((row) => OrderTemplate.fromJson(row as Map<String, dynamic>))
          .toList();
    });
  }

  Future<OrderTemplate> saveOrderTemplate({
    required String orgId,
    required String name,
    required OrderComposition composition,
    String? templateId,
  }) async {
    _log.d(
      'saveOrderTemplate: orgId=$orgId, templateId=$templateId, name=$name',
    );
    return supabaseGuard(() async {
      final data = await _client
          .from('order_templates')
          .upsert({
            if (templateId != null) 'id': templateId,
            'organization_id': orgId,
            'name': name,
            'items': composition.items.map((item) => item.toJson()).toList(),
          }, onConflict: 'id')
          .select()
          .single();

      return OrderTemplate.fromJson(data);
    });
  }

  Future<void> deleteOrderTemplate(String templateId) async {
    _log.d('deleteOrderTemplate: templateId=$templateId');
    return supabaseGuard(() async {
      await _client.from('order_templates').delete().eq('id', templateId);
    });
  }

  Future<OrderComposition> getDuplicateOrderComposition(String orderId) async {
    _log.d('getDuplicateOrderComposition: orderId=$orderId');
    final order = await getOrder(orderId);
    return OrderComposition.fromOrderItems(order.items);
  }

  Future<List<Customer>> getRecentCustomers({
    required String orgId,
    int limit = 6,
  }) async {
    _log.d('getRecentCustomers: orgId=$orgId, limit=$limit');
    return supabaseGuard(() async {
      final data = await _client
          .from('orders')
          .select('customer_id, customers(*)')
          .eq('organization_id', orgId)
          .not('customer_id', 'is', null)
          .order('created_at', ascending: false)
          .limit(limit * 3);

      final uniqueCustomers = <String, Customer>{};
      for (final row in data as List) {
        final json = row as Map<String, dynamic>;
        final customerId = json['customer_id'] as String?;
        final customerJson = json['customers'] as Map<String, dynamic>?;
        if (customerId == null || customerJson == null) continue;
        uniqueCustomers.putIfAbsent(
          customerId,
          () => Customer.fromJson(customerJson),
        );
        if (uniqueCustomers.length >= limit) break;
      }

      return uniqueCustomers.values.toList();
    });
  }

  Future<List<Product>> getRecentProducts({
    required String orgId,
    int limit = 6,
  }) async {
    _log.d('getRecentProducts: orgId=$orgId, limit=$limit');
    return supabaseGuard(() async {
      final data = await _client
          .from('orders')
          .select('order_items(product_id, products(*))')
          .eq('organization_id', orgId)
          .order('created_at', ascending: false)
          .limit(limit * 3);

      final uniqueProducts = <String, Product>{};
      for (final row in data as List) {
        final items = (row as Map<String, dynamic>)['order_items'] as List?;
        if (items == null) continue;
        for (final item in items) {
          final itemJson = item as Map<String, dynamic>;
          final productId = itemJson['product_id'] as String?;
          final productJson = itemJson['products'] as Map<String, dynamic>?;
          if (productId == null || productJson == null) continue;
          uniqueProducts.putIfAbsent(
            productId,
            () => Product.fromJson(productJson),
          );
          if (uniqueProducts.length >= limit) {
            return uniqueProducts.values.toList();
          }
        }
      }

      return uniqueProducts.values.toList();
    });
  }


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

      await _recalculateTotal(orderId);

      return OrderItem.fromJson(data);
    });
  }

  Future<void> removeItem(String itemId, String orderId) async {
    _log.d('removeItem: itemId=$itemId');
    return supabaseGuard(() async {
      await _client.from('order_items').delete().eq('id', itemId);
      await _recalculateTotal(orderId);
    });
  }

  Future<void> _recalculateTotal(String orderId) async {
    final items = await _client
        .from('order_items')
        .select('unit_price, quantity')
        .eq('order_id', orderId);

    double total = 0;
    for (final item in items as List) {
      total +=
          (item['unit_price'] as num).toDouble() * (item['quantity'] as int);
    }

    _log.d(
      '[FIX] _recalculateTotal: items total=$total (delivery not included)',
    );

    await _client
        .from('orders')
        .update({'total_amount': total})
        .eq('id', orderId);
  }


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
