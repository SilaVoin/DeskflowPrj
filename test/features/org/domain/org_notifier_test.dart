import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/org/data/org_repository.dart';
import 'package:deskflow/features/org/domain/org_invite_result.dart';
import 'package:deskflow/features/org/domain/org_notifier.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';
import 'package:deskflow/features/org/domain/organization.dart';
import 'package:deskflow/features/org/domain/pending_org_invite_intent.dart';

class _MockOrgRepository extends Mock implements OrgRepository {}

class _TestCurrentOrgId extends CurrentOrgId {
  @override
  String? build() => null;
}

User _makeUser() {
  return User(
    id: 'user-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime(2026, 3, 11).toIso8601String(),
    email: 'user@test.com',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockOrgRepository orgRepository;
  late Organization organization;

  setUp(() {
    orgRepository = _MockOrgRepository();
    organization = Organization(
      id: 'org-1',
      name: 'Deskflow',
      inviteCode: 'JOIN1234',
      createdAt: DateTime(2026, 3, 11),
    );
  });

  test(
    'acceptInviteByToken selects organization, invalidates org list and clears pending intent',
    () async {
      var organizationsBuilds = 0;

      when(
        () => orgRepository.acceptInviteByToken(inviteToken: 'token-1'),
      ).thenAnswer((_) async => organization);

      final container = ProviderContainer(
        overrides: [
          orgRepositoryProvider.overrideWith((ref) => orgRepository),
          currentUserProvider.overrideWithValue(_makeUser()),
          currentOrgIdProvider.overrideWith(() => _TestCurrentOrgId()),
          userOrganizationsProvider.overrideWith((ref) async {
            organizationsBuilds++;
            return <Organization>[];
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(userOrganizationsProvider.future);
      expect(organizationsBuilds, 1);

      container
          .read(pendingOrgInviteIntentProvider.notifier)
          .setToken('token-1');

      await container
          .read(orgNotifierProvider.notifier)
          .acceptInviteByToken('token-1');

      expect(container.read(currentOrgIdProvider), 'org-1');
      expect(container.read(pendingOrgInviteIntentProvider), isNull);

      await container.read(userOrganizationsProvider.future);
      expect(organizationsBuilds, 2);
    },
  );

  test(
    'claimPendingInvites completes without a persistent listener during reconcile flow',
    () async {
      final completer = Completer<OrgInviteClaimResult>();

      when(
        () => orgRepository.claimPendingInvites(),
      ).thenAnswer((_) => completer.future);

      final container = ProviderContainer(
        overrides: [
          orgRepositoryProvider.overrideWith((ref) => orgRepository),
          currentUserProvider.overrideWithValue(_makeUser()),
          currentOrgIdProvider.overrideWith(() => _TestCurrentOrgId()),
        ],
      );
      addTearDown(container.dispose);

      final future = container.read(orgNotifierProvider.notifier).claimPendingInvites();

      await Future<void>.delayed(Duration.zero);

      completer.complete(
        OrgInviteClaimResult(organizations: [organization]),
      );

      final claimed = await future;

      expect(claimed, hasLength(1));
      expect(container.read(currentOrgIdProvider), 'org-1');
    },
  );
}
