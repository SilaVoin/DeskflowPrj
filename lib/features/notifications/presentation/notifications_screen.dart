import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/empty_state_widget.dart';
import 'package:deskflow/core/widgets/error_state_widget.dart';
import 'package:deskflow/features/notifications/domain/notification_model.dart';
import 'package:deskflow/features/notifications/domain/notification_providers.dart';

final _log = AppLogger.getLogger('NotificationsScreen');

/// In-app notifications list screen.
///
/// Shows all notifications for the current user/org with:
/// - Tap to navigate to the related order
/// - Mark as read / mark all as read
/// - Pull-to-refresh
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsListProvider);

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          // Mark all as read button
          notificationsAsync.whenOrNull(
                data: (list) {
                  final hasUnread = list.any((n) => !n.isRead);
                  if (!hasUnread) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.done_all_rounded),
                    tooltip: 'Прочитать все',
                    onPressed: () {
                      _log.d('[FIX] markAllAsRead tapped');
                      ref
                          .read(notificationsListProvider.notifier)
                          .markAllAsRead();
                    },
                  );
                },
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorStateWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(notificationsListProvider),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.notifications_none_rounded,
              title: 'Нет уведомлений',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsListProvider);
              ref.invalidate(unreadNotificationCountProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(DeskflowSpacing.lg),
              itemCount: notifications.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: DeskflowSpacing.sm),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationCard(
                  notification: notification,
                  onTap: () {
                    _log.d('[FIX] notification tapped: id=${notification.id}, '
                        'type=${notification.type}, orderId=${notification.orderId}');

                    // Mark as read
                    if (!notification.isRead) {
                      ref
                          .read(notificationsListProvider.notifier)
                          .markAsRead(notification.id);
                    }

                    // Navigate to order if available
                    if (notification.orderId != null) {
                      context.push('/orders/${notification.orderId}');
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Single notification card.
class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon based on type
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(DeskflowRadius.md),
            ),
            child: Icon(
              _iconData,
              color: _iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: DeskflowSpacing.md),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: DeskflowTypography.body.copyWith(
                    fontWeight:
                        notification.isRead ? FontWeight.normal : FontWeight.w600,
                    color: DeskflowColors.textPrimary,
                  ),
                ),
                if (notification.body != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    notification.body!,
                    style: DeskflowTypography.caption.copyWith(
                      color: DeskflowColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  timeago.format(notification.createdAt, locale: 'ru'),
                  style: DeskflowTypography.caption.copyWith(
                    color: DeskflowColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Unread indicator
          if (!notification.isRead)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: const BoxDecoration(
                color: DeskflowColors.primarySolid,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  IconData get _iconData {
    switch (notification.type) {
      case NotificationType.newOrder:
        return Icons.add_shopping_cart_rounded;
      case NotificationType.statusChange:
        return Icons.swap_horiz_rounded;
      case NotificationType.chatMessage:
        return Icons.chat_bubble_rounded;
    }
  }

  Color get _iconColor {
    switch (notification.type) {
      case NotificationType.newOrder:
        return const Color(0xFF3B82F6); // blue
      case NotificationType.statusChange:
        return const Color(0xFFF59E0B); // amber
      case NotificationType.chatMessage:
        return const Color(0xFF22C55E); // green
    }
  }
}
