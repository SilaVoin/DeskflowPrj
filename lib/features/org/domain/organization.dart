/// Organization domain model.
class Organization {
  final String id;
  final String name;
  final String? slug;
  final String? logoUrl;
  final String? inviteCode;
  final DateTime createdAt;

  /// Role of the current user in this org (set when fetching user's orgs).
  final String? userRole;

  const Organization({
    required this.id,
    required this.name,
    this.slug,
    this.logoUrl,
    this.inviteCode,
    required this.createdAt,
    this.userRole,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String?,
      logoUrl: json['logo_url'] as String?,
      inviteCode: json['invite_code'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      userRole: json['user_role'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (logoUrl != null) 'logo_url': logoUrl,
    };
  }
}
