/// Org member role enum.
enum OrgRole {
  owner,
  admin,
  member;

  factory OrgRole.fromString(String value) {
    return switch (value) {
      'owner' => OrgRole.owner,
      'admin' => OrgRole.admin,
      _ => OrgRole.member,
    };
  }

  String toJson() => name;

  /// User-facing label in Russian.
  String get label => switch (this) {
        OrgRole.owner => 'Владелец',
        OrgRole.admin => 'Администратор',
        OrgRole.member => 'Участник',
      };
}

/// Organization membership domain model.
class OrgMember {
  final String id;
  final String organizationId;
  final String userId;
  final OrgRole role;
  final DateTime joinedAt;

  const OrgMember({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  factory OrgMember.fromJson(Map<String, dynamic> json) {
    return OrgMember(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      userId: json['user_id'] as String,
      role: OrgRole.fromString(json['role'] as String),
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}
