import 'package:deskflow/features/org/domain/org_member.dart';

class OrgInvite {
  final String id;
  final String organizationId;
  final String email;
  final OrgRole role;
  final String inviteCode;
  final String inviteToken;
  final String status;
  final DateTime expiresAt;
  final DateTime lastSentAt;

  const OrgInvite({
    required this.id,
    required this.organizationId,
    required this.email,
    required this.role,
    required this.inviteCode,
    required this.inviteToken,
    required this.status,
    required this.expiresAt,
    required this.lastSentAt,
  });

  factory OrgInvite.fromJson(Map<String, dynamic> json) {
    return OrgInvite(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      email: json['email'] as String,
      role: OrgRole.fromString(json['role'] as String),
      inviteCode: json['invite_code'] as String,
      inviteToken: json['invite_token'] as String,
      status: json['status'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      lastSentAt: DateTime.parse(json['last_sent_at'] as String),
    );
  }
}
