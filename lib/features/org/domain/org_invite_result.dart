import 'package:deskflow/features/org/domain/organization.dart';

class OrgInviteClaimResult {
  final List<Organization> organizations;

  const OrgInviteClaimResult({
    required this.organizations,
  });

  bool get hasOrganizations => organizations.isNotEmpty;

  Organization? get primaryOrganization =>
      organizations.isEmpty ? null : organizations.first;
}
