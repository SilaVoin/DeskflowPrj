import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deskflow/core/providers/supabase_provider.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/notifications/data/notification_repository.dart';
import 'package:deskflow/features/notifications/domain/notification_model.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

part 'notification_providers.g.dart';

final _log = AppLogger.getLogger('NotificationProviders');

@Riverpod(keepAlive: true)
NotificationRepository notificationRepository(Ref ref) {
  return NotificationRepository(ref.watch(supabaseClientProvider));
}

@riverpod
class UnreadNotificationCount extends _$UnreadNotificationCount {
  RealtimeChannel? _channel;

  @override
  Future<int> build() async {
    final orgId = ref.watch(currentOrgIdProvider);
    final user = ref.watch(currentUserProvider);

    if (orgId == null || user == null) {
      _log.d('[FIX] UnreadNotificationCount: no org/user, returning 0');
      return 0;
    }

    _subscribeToRealtime(user.id);

    ref.onDispose(() {
      _log.d('[FIX] UnreadNotificationCount: disposing realtime channel');
      _channel?.unsubscribe();
      _channel = null;
    });

    final repo = ref.read(notificationRepositoryProvider);
    final count = await repo.getUnreadCount(orgId: orgId);
    _log.i('[FIX] UnreadNotificationCount: $count unread for org=$orgId');
    return count;
  }

  void _subscribeToRealtime(String userId) {
    if (_channel != null) return;

    final repo = ref.read(notificationRepositoryProvider);
    _channel = repo.subscribeToNotifications(
      userId: userId,
      onInsert: (notification) {
        _log.d('[FIX] UnreadNotificationCount: new notification, incrementing');
        final current = state.valueOrNull ?? 0;
        state = AsyncData(current + 1);
      },
    );
  }

  void decrement() {
    final current = state.valueOrNull ?? 0;
    if (current > 0) {
      state = AsyncData(current - 1);
    }
  }

  void reset() {
    state = const AsyncData(0);
  }
}

@riverpod
class NotificationsList extends _$NotificationsList {
  @override
  Future<List<AppNotification>> build() async {
    final orgId = ref.watch(currentOrgIdProvider);
    final user = ref.watch(currentUserProvider);

    if (orgId == null || user == null) {
      _log.d('[FIX] NotificationsList: no org/user, returning empty');
      return [];
    }

    final repo = ref.read(notificationRepositoryProvider);
    final list = await repo.getNotifications(orgId: orgId);
    _log.i('[FIX] NotificationsList: loaded ${list.length} notifications');
    return list;
  }

  Future<void> markAsRead(String notificationId) async {
    _log.d('[FIX] NotificationsList.markAsRead: id=$notificationId');
    final repo = ref.read(notificationRepositoryProvider);

    state = AsyncData(
      (state.valueOrNull ?? []).map((n) {
        if (n.id == notificationId && !n.isRead) {
          ref.read(unreadNotificationCountProvider.notifier).decrement();
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList(),
    );

    await repo.markAsRead(notificationId);
  }

  Future<void> markAllAsRead() async {
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId == null) return;

    _log.d('[FIX] NotificationsList.markAllAsRead: orgId=$orgId');
    final repo = ref.read(notificationRepositoryProvider);

    state = AsyncData(
      (state.valueOrNull ?? []).map((n) => n.copyWith(isRead: true)).toList(),
    );
    ref.read(unreadNotificationCountProvider.notifier).reset();

    await repo.markAllAsRead(orgId: orgId);
  }
}
