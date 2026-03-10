import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';
import 'package:deskflow/features/org/domain/organization.dart';

part 'org_notifier.g.dart';

final _log = AppLogger.getLogger('OrgNotifier');

/// Manages organization create / join actions.
@riverpod
class OrgNotifier extends _$OrgNotifier {
  @override
  FutureOr<void> build() {
    // No initial async work.
  }

  /// Create a new organization and select it.
  ///
  /// Returns the created [Organization] or `null` on error.
  Future<Organization?> createOrganization(String name) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return null;

    Organization? createdOrg;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final org = await ref.read(orgRepositoryProvider).createOrganization(
            name: name,
            userId: user.id,
          );
      createdOrg = org;
      ref.read(currentOrgIdProvider.notifier).select(org.id);
      // Invalidate org list so it re-fetches
      ref.invalidate(userOrganizationsProvider);
      _log.i('Organization created: ${org.name}');
    });
    return state.hasError ? null : createdOrg;
  }

  /// Join an organization by invite code and select it.
  Future<bool> joinByInviteCode(String code) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return false;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final org = await ref.read(orgRepositoryProvider).joinByInviteCode(
            inviteCode: code,
            userId: user.id,
          );
      ref.read(currentOrgIdProvider.notifier).select(org.id);
      ref.invalidate(userOrganizationsProvider);
      _log.i('Joined organization: ${org.name}');
    });
    return !state.hasError;
  }

  /// Select an existing organization from the list.
  void selectOrganization(Organization org) {
    ref.read(currentOrgIdProvider.notifier).select(org.id);
    _log.i('Selected organization: ${org.name}');
  }
}
