/// Audit event domain model.
class AuditEvent {
  final String id;
  final String organizationId;
  final String entityType;
  final String entityId;
  final String action;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;
  final String userId;
  final DateTime createdAt;

  /// Joined user name (from profiles).
  final String? userName;

  const AuditEvent({
    required this.id,
    required this.organizationId,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.oldValue,
    this.newValue,
    required this.userId,
    required this.createdAt,
    this.userName,
  });

  factory AuditEvent.fromJson(Map<String, dynamic> json) {
    String? userName;
    if (json['profiles'] != null) {
      userName = (json['profiles'] as Map<String, dynamic>)['full_name'] as String?;
    }

    return AuditEvent(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      action: json['action'] as String,
      oldValue: json['old_value'] as Map<String, dynamic>?,
      newValue: json['new_value'] as Map<String, dynamic>?,
      userId: json['user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      userName: userName,
    );
  }

  /// Human-readable action description in Russian.
  String get actionLabel => switch (action) {
        'order_created' => 'Заказ создан',
        'status_changed' => 'Статус изменён',
        'item_added' => 'Товар добавлен',
        'item_removed' => 'Товар удалён',
        'note_updated' => 'Заметка обновлена',
        'order_updated' => 'Заказ обновлён',
        _ => action,
      };
}
