import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:deskflow/core/errors/deskflow_exception.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/orders/domain/order_providers.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

part 'order_notifier.g.dart';

final _log = AppLogger.getLogger('OrderNotifier');

/// Manages order mutations (create, update status, edit).
@riverpod
class OrderNotifier extends _$OrderNotifier {
  @override
  FutureOr<void> build() {}

  /// Create a new order.
  Future<Order?> createOrder({
    String? customerId,
    double deliveryCost = 0,
    String? notes,
    List<Map<String, dynamic>> items = const [],
  }) async {
    final orgId = ref.read(currentOrgIdProvider);
    final userId = ref.read(currentUserProvider)?.id;
    if (orgId == null || userId == null) return null;

    state = const AsyncLoading();

    Order? created;
    state = await AsyncValue.guard(() async {
      // Get default status
      final defaultStatus =
          await ref.read(orderRepositoryProvider).getDefaultStatus(orgId);

      created = await ref.read(orderRepositoryProvider).createOrder(
            orgId: orgId,
            userId: userId,
            statusId: defaultStatus.id,
            customerId: customerId,
            deliveryCost: deliveryCost,
            notes: notes,
            items: items,
          );

      _log.d('Order created: ${created!.formattedNumber}');

      // Invalidate orders list
      ref.invalidate(ordersListProvider);
    });

    return created;
  }

  /// Change order status.
  Future<bool> changeStatus({
    required String orderId,
    required String newStatusId,
    String? oldStatusName,
    String? newStatusName,
  }) async {
    final orgId = ref.read(currentOrgIdProvider);
    final userId = ref.read(currentUserProvider)?.id;
    if (orgId == null || userId == null) return false;

    // Validate role-based access
    final role = await ref.read(currentUserRoleProvider.future);
    final pipeline = await ref.read(pipelineProvider.future);

    final order =
        await ref.read(orderRepositoryProvider).getOrder(orderId);
    final currentStatus =
        pipeline.firstWhere((s) => s.id == order.statusId);
    final newStatus =
        pipeline.firstWhere((s) => s.id == newStatusId);

    if (currentStatus.isFinal) {
      throw DeskflowException.orderAlreadyFinal;
    }

    if (role.name != 'owner') {
      // Members can only advance forward or cancel (final).
      // Pipeline is sorted descending by sort_order, so advancing
      // means moving to a status with a LOWER sort_order value.
      if (!newStatus.isFinal &&
          newStatus.sortOrder >= currentStatus.sortOrder) {
        throw DeskflowException(
            'Нельзя вернуть заказ на предыдущий статус');
      }
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(orderRepositoryProvider).updateStatus(
            orderId: orderId,
            statusId: newStatusId,
            userId: userId,
            orgId: orgId,
            oldStatusName: oldStatusName,
            newStatusName: newStatusName,
          );

      // Invalidate caches
      ref.invalidate(ordersListProvider);
      ref.invalidate(orderDetailProvider(orderId));
    });

    return !state.hasError;
  }

  /// Update order details.
  Future<bool> updateOrder({
    required String orderId,
    String? customerId,
    double? deliveryCost,
    String? notes,
  }) async {
    final orgId = ref.read(currentOrgIdProvider);
    final userId = ref.read(currentUserProvider)?.id;
    if (orgId == null || userId == null) return false;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(orderRepositoryProvider).updateOrder(
            orderId: orderId,
            userId: userId,
            orgId: orgId,
            customerId: customerId,
            deliveryCost: deliveryCost,
            notes: notes,
          );

      ref.invalidate(ordersListProvider);
      ref.invalidate(orderDetailProvider(orderId));
    });

    return !state.hasError;
  }
}
