import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/notifications/domain/notification_model.dart';

final _log = AppLogger.getLogger('NotificationRepository');

class NotificationRepository {
  final SupabaseClient _client;

  NotificationRepository(this._client);

  Future<List<AppNotification>> getNotifications({
    required String orgId,
    int limit = 50,
  }) async {
    _log.d('[FIX] getNotifications: orgId=$orgId, limit=$limit');
    final response = await _client
        .from('notifications')
        .select()
        .eq('org_id', orgId)
        .order('created_at', ascending: false)
        .limit(limit);

    final list = (response as List)
        .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
        .toList();
    _log.i('[FIX] getNotifications: fetched ${list.length} notifications');
    return list;
  }

  Future<int> getUnreadCount({required String orgId}) async {
    _log.d('[FIX] getUnreadCount: orgId=$orgId');
    final response = await _client
        .from('notifications')
        .select()
        .eq('org_id', orgId)
        .eq('is_read', false);

    final count = (response as List).length;
    _log.d('[FIX] getUnreadCount: $count unread');
    return count;
  }

  Future<void> markAsRead(String notificationId) async {
    _log.d('[FIX] markAsRead: id=$notificationId');
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead({required String orgId}) async {
    _log.d('[FIX] markAllAsRead: orgId=$orgId');
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('org_id', orgId)
        .eq('is_read', false);
  }

  Future<void> deleteNotification(String notificationId) async {
    _log.d('[FIX] deleteNotification: id=$notificationId');
    await _client.from('notifications').delete().eq('id', notificationId);
  }

  RealtimeChannel subscribeToNotifications({
    required String userId,
    required void Function(AppNotification notification) onInsert,
  }) {
    _log.d('[FIX] subscribeToNotifications: userId=$userId');
    final channel = _client.channel('notifications:$userId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _log.d('[FIX] realtime notification received: ${payload.newRecord}');
            try {
              final notification = AppNotification.fromJson(payload.newRecord);
              onInsert(notification);
            } catch (e, st) {
              _log.e('[FIX] failed to parse realtime notification',
                  error: e, stackTrace: st);
            }
          },
        )
        .subscribe();

    return channel;
  }
}
