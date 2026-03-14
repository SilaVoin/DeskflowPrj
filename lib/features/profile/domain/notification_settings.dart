class NotificationSettings {
  final String? id;
  final String userId;
  final String organizationId;
  final bool notifyNewOrders;
  final bool notifyStatusChanges;
  final bool notifyChatMessages;
  final bool notifySound;

  const NotificationSettings({
    this.id,
    required this.userId,
    required this.organizationId,
    this.notifyNewOrders = true,
    this.notifyStatusChanges = true,
    this.notifyChatMessages = true,
    this.notifySound = true,
  });

  factory NotificationSettings.defaults({
    required String userId,
    required String organizationId,
  }) {
    return NotificationSettings(
      userId: userId,
      organizationId: organizationId,
    );
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      organizationId: json['organization_id'] as String,
      notifyNewOrders: json['notify_new_orders'] as bool? ?? true,
      notifyStatusChanges: json['notify_status_changes'] as bool? ?? true,
      notifyChatMessages: json['notify_chat_messages'] as bool? ?? true,
      notifySound: json['notify_sound'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'organization_id': organizationId,
      'notify_new_orders': notifyNewOrders,
      'notify_status_changes': notifyStatusChanges,
      'notify_chat_messages': notifyChatMessages,
      'notify_sound': notifySound,
    };
  }

  NotificationSettings copyWith({
    bool? notifyNewOrders,
    bool? notifyStatusChanges,
    bool? notifyChatMessages,
    bool? notifySound,
  }) {
    return NotificationSettings(
      id: id,
      userId: userId,
      organizationId: organizationId,
      notifyNewOrders: notifyNewOrders ?? this.notifyNewOrders,
      notifyStatusChanges: notifyStatusChanges ?? this.notifyStatusChanges,
      notifyChatMessages: notifyChatMessages ?? this.notifyChatMessages,
      notifySound: notifySound ?? this.notifySound,
    );
  }
}
