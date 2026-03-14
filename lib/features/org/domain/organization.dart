class Organization {
  final String id;
  final String name;
  final String? slug;
  final String? logoUrl;
  final String? inviteCode;
  final DateTime createdAt;
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
    String? userRole;
    final members = json['organization_members'];
    if (members is List && members.isNotEmpty) {
      userRole = (members.first as Map<String, dynamic>)['role'] as String?;
    } else if (members is Map<String, dynamic>) {
      userRole = members['role'] as String?;
    } else {
      userRole = json['user_role'] as String?;
    }

    return Organization(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String?,
      logoUrl: json['logo_url'] as String?,
      inviteCode: json['invite_code'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      userRole: userRole,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (slug != null) 'slug': slug,
      if (logoUrl != null) 'logo_url': logoUrl,
    };
  }
}
