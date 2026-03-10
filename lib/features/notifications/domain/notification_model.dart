/// Notification model — maps to the `notifications` table in Supabase.
class AppNotification {
  final String id;
  final String orgId;
  final String userId;
  final NotificationType type;
  final String title;
  final String? body;
  final String? orderId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.orgId,
    required this.userId,
    required this.type,
    required this.title,
    this.body,
    this.orderId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      userId: json['user_id'] as String,
      type: NotificationType.fromString(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String?,
      orderId: json['order_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      orgId: orgId,
      userId: userId,
      type: type,
      title: title,
      body: body,
      orderId: orderId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

enum NotificationType {
  newOrder,
  statusChange,
  chatMessage;

  static NotificationType fromString(String value) {
    switch (value) {
      case 'new_order':
        return NotificationType.newOrder;
      case 'status_change':
        return NotificationType.statusChange;
      case 'chat_message':
        return NotificationType.chatMessage;
      default:
        return NotificationType.newOrder;
    }
  }

  String toDbValue() {
    switch (this) {
      case NotificationType.newOrder:
        return 'new_order';
      case NotificationType.statusChange:
        return 'status_change';
      case NotificationType.chatMessage:
        return 'chat_message';
    }
  }
}
