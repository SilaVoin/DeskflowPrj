enum NotificationType {
  newOrder,
  statusChange,
  chatMessage;

  static NotificationType fromString(String value) {
    return switch (value) {
      'new_order' => NotificationType.newOrder,
      'status_change' => NotificationType.statusChange,
      'chat_message' => NotificationType.chatMessage,
      _ => NotificationType.newOrder,
    };
  }
}

class AppNotification {
  final String id;
  final String orgId;
  final String userId;
  final String? orderId;
  final NotificationType type;
  final String title;
  final String? body;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.orgId,
    required this.userId,
    this.orderId,
    required this.type,
    required this.title,
    this.body,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      userId: json['user_id'] as String,
      orderId: json['order_id'] as String?,
      type: NotificationType.fromString(json['type'] as String? ?? ''),
      title: json['title'] as String,
      body: json['body'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      orgId: orgId,
      userId: userId,
      orderId: orderId,
      type: type,
      title: title,
      body: body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
