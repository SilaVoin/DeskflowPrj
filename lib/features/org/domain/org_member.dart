enum OrgRole {
  owner,
  admin,
  member;

  static OrgRole fromString(String value) {
    return switch (value) {
      'owner' => OrgRole.owner,
      'admin' => OrgRole.admin,
      'member' => OrgRole.member,
      _ => OrgRole.member,
    };
  }

  String toJson() => name;

  String get label => switch (this) {
        OrgRole.owner => '\u0412\u043b\u0430\u0434\u0435\u043b\u0435\u0446',
        OrgRole.admin => '\u0410\u0434\u043c\u0438\u043d\u0438\u0441\u0442\u0440\u0430\u0442\u043e\u0440',
        OrgRole.member => '\u0423\u0447\u0430\u0441\u0442\u043d\u0438\u043a',
      };
}

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
      role: OrgRole.fromString(json['role'] as String? ?? 'member'),
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}
