import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';
import 'package:deskflow/features/org/domain/organization.dart';
import 'package:deskflow/features/org/domain/pending_org_invite_intent.dart';

part 'org_notifier.g.dart';

final _log = AppLogger.getLogger('OrgNotifier');

@Riverpod(keepAlive: true)
class OrgNotifier extends _$OrgNotifier {
  @override
  FutureOr<void> build() {
  }

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
      ref.invalidate(userOrganizationsProvider);
      _log.i('Organization created: ${org.name}');
    });
    return state.hasError ? null : createdOrg;
  }

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

  Future<Organization?> acceptInviteByToken(String inviteToken) async {
    Organization? acceptedOrg;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final org = await ref.read(orgRepositoryProvider).acceptInviteByToken(
            inviteToken: inviteToken,
          );
      acceptedOrg = org;
      _completeInviteAcceptance(org);
      _log.i('Accepted organization invite by token: ${org.name}');
    });

    return state.hasError ? null : acceptedOrg;
  }

  Future<Organization?> acceptInviteByCode(String inviteCode) async {
    Organization? acceptedOrg;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final org = await ref.read(orgRepositoryProvider).acceptInviteByCode(
            inviteCode: inviteCode,
          );
      acceptedOrg = org;
      _completeInviteAcceptance(org);
      _log.i('Accepted organization invite by code: ${org.name}');
    });

    return state.hasError ? null : acceptedOrg;
  }

  Future<List<Organization>> claimPendingInvites() async {
    List<Organization> acceptedOrganizations = const [];

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref.read(orgRepositoryProvider).claimPendingInvites();
      acceptedOrganizations = result.organizations;

      if (acceptedOrganizations.isNotEmpty) {
        _completeInviteAcceptance(acceptedOrganizations.first);
        _log.i(
          'Claimed ${acceptedOrganizations.length} pending organization invite(s)',
        );
      }
    });

    return state.hasError ? const [] : acceptedOrganizations;
  }

  void selectOrganization(Organization org) {
    ref.read(currentOrgIdProvider.notifier).select(org.id);
    _log.i('Selected organization: ${org.name}');
  }

  void _completeInviteAcceptance(Organization org) {
    ref.read(currentOrgIdProvider.notifier).select(org.id);
    ref.invalidate(userOrganizationsProvider);
    ref.read(pendingOrgInviteIntentProvider.notifier).clear();
  }
}
