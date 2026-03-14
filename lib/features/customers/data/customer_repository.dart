import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deskflow/core/errors/supabase_error_handler.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/orders/domain/order.dart';

final _log = AppLogger.getLogger('CustomerRepository');

class CustomerRepository {
  final SupabaseClient _client;

  CustomerRepository(this._client);


  Future<List<Customer>> getCustomers({
    required String orgId,
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    _log.d('getCustomers: orgId=$orgId, search=$search, '
        'limit=$limit, offset=$offset');
    return supabaseGuard(() async {
      var query = _client
          .from('customers')
          .select('*, orders(count)')
          .eq('organization_id', orgId);

      if (search != null && search.isNotEmpty) {
        query = query.or(
          'name.ilike.%$search%,phone.ilike.%$search%,email.ilike.%$search%',
        );
      }

      final data = await query
          .order('name')
          .range(offset, offset + limit - 1);

      return (data as List).map((e) {
        final json = Map<String, dynamic>.from(e as Map<String, dynamic>);
        final ordersAgg = json.remove('orders') as List?;
        final count = ordersAgg?.isNotEmpty == true
            ? (ordersAgg!.first['count'] as num?)?.toInt() ?? 0
            : 0;
        json['order_count'] = count;
        return Customer.fromJson(json);
      }).toList();
    });
  }


  Future<Customer> getCustomer(String customerId) async {
    _log.d('getCustomer: customerId=$customerId');
    return supabaseGuard(() async {
      final data = await _client
          .from('customers')
          .select()
          .eq('id', customerId)
          .single();

      final stats = await _client
          .from('orders')
          .select('id, total_amount')
          .eq('customer_id', customerId);

      final orderCount = (stats as List).length;
      final totalSpent = (stats).fold<double>(
        0,
        (sum, o) => sum + ((o['total_amount'] as num?)?.toDouble() ?? 0),
      );

      final json = Map<String, dynamic>.from(data);
      json['order_count'] = orderCount;
      json['total_spent'] = totalSpent;

      return Customer.fromJson(json);
    });
  }


  Future<List<Order>> getCustomerOrders(String customerId) async {
    _log.d('getCustomerOrders: customerId=$customerId');
    return supabaseGuard(() async {
      final data = await _client
          .from('orders')
          .select('*, order_statuses(*), customers(name)')
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      return (data as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }


  Future<Customer> createCustomer({
    required String orgId,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    _log.d('createCustomer: orgId=$orgId, name=$name');
    return supabaseGuard(() async {
      final data = await _client
          .from('customers')
          .insert({
            'organization_id': orgId,
            'name': name,
            if (phone != null && phone.isNotEmpty) 'phone': phone,
            if (email != null && email.isNotEmpty) 'email': email,
            if (address != null && address.isNotEmpty) 'address': address,
            if (notes != null && notes.isNotEmpty) 'notes': notes,
          })
          .select()
          .single();

      return Customer.fromJson(data);
    });
  }

  Future<Customer> updateCustomer({
    required String customerId,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    _log.d('updateCustomer: customerId=$customerId');
    return supabaseGuard(() async {
      final data = await _client
          .from('customers')
          .update({
            'name': name,
            'phone': phone,
            'email': email,
            'address': address,
            'notes': notes,
          })
          .eq('id', customerId)
          .select()
          .single();

      return Customer.fromJson(data);
    });
  }

  Future<void> deleteCustomer(String customerId) async {
    _log.d('deleteCustomer: customerId=$customerId');
    return supabaseGuard(() async {
      await _client.from('customers').delete().eq('id', customerId);
    });
  }
}
