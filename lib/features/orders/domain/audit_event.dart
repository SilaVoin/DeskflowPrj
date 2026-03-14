class AuditEvent {
  final String id;
  final String organizationId;
  final String entityType;
  final String entityId;
  final String action;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;
  final String userId;
  final String? userName;
  final DateTime createdAt;

  const AuditEvent({
    required this.id,
    required this.organizationId,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.oldValue,
    this.newValue,
    required this.userId,
    this.userName,
    required this.createdAt,
  });

  String get actionLabel => switch (action) {
        'created' => '\u0421\u043e\u0437\u0434\u0430\u043d',
        'status_changed' => '\u0421\u0442\u0430\u0442\u0443\u0441 \u0438\u0437\u043c\u0435\u043d\u0451\u043d',
        'customer_changed' => '\u041a\u043b\u0438\u0435\u043d\u0442 \u0438\u0437\u043c\u0435\u043d\u0451\u043d',
        'notes_changed' => '\u0417\u0430\u043c\u0435\u0442\u043a\u0438 \u0438\u0437\u043c\u0435\u043d\u0435\u043d\u044b',
        'delivery_cost_changed' => '\u0421\u0442\u043e\u0438\u043c\u043e\u0441\u0442\u044c \u0434\u043e\u0441\u0442\u0430\u0432\u043a\u0438 \u0438\u0437\u043c\u0435\u043d\u0435\u043d\u0430',
        'item_added' => '\u0422\u043e\u0432\u0430\u0440 \u0434\u043e\u0431\u0430\u0432\u043b\u0435\u043d',
        'item_removed' => '\u0422\u043e\u0432\u0430\u0440 \u0443\u0434\u0430\u043b\u0451\u043d',
        _ => action,
      };

  factory AuditEvent.fromJson(Map<String, dynamic> json) {
    String? userName;
    if (json['profiles'] != null) {
      final profile = json['profiles'] as Map<String, dynamic>;
      userName = profile['full_name'] as String?;
    }

    return AuditEvent(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      action: json['action'] as String,
      oldValue: json['old_value'] != null
          ? Map<String, dynamic>.from(json['old_value'] as Map)
          : null,
      newValue: json['new_value'] != null
          ? Map<String, dynamic>.from(json['new_value'] as Map)
          : null,
      userId: json['user_id'] as String,
      userName: userName,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
