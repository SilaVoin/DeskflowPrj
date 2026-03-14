import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deskflow/core/errors/deskflow_exception.dart';
import 'package:deskflow/features/admin/data/admin_repository.dart';
import 'package:deskflow/features/org/data/org_repository.dart';
import 'package:deskflow/features/org/domain/org_invite_result.dart';
import 'package:deskflow/features/org/domain/org_member.dart';
import 'package:deskflow/features/admin/domain/org_invite.dart';
import '../../../helpers/supabase_fakes.dart';

void main() {
  late MockSupabaseClient mockClient;
  late AdminRepository adminRepository;
  late OrgRepository orgRepository;

  setUp(() {
    mockClient = MockSupabaseClient();
    adminRepository = AdminRepository(mockClient);
    orgRepository = OrgRepository(mockClient);
  });

  group('inviteMemberByEmail', () {
    test('returns typed pending invite payload from RPC', () async {
      when(
        () => mockClient.rpc(
          'invite_member_by_email_v2',
          params: {
            'p_org_id': 'org-1',
            'p_email': 'teammate@example.com',
            'p_role': 'admin',
          },
        ),
      ).thenAnswer(
        (_) => FakeFilterBuilder<dynamic>({
          'id': 'invite-1',
          'organization_id': 'org-1',
          'email': 'teammate@example.com',
          'role': 'admin',
          'invite_code': 'ABC12345',
          'invite_token': 'token-1',
          'status': 'pending',
          'expires_at': '2026-03-25T10:00:00.000Z',
          'last_sent_at': '2026-03-11T10:00:00.000Z',
        }),
      );

      final invite = await adminRepository.inviteMemberByEmail(
        orgId: 'org-1',
        email: 'teammate@example.com',
        role: OrgRole.admin,
      );

      expect(invite, isA<OrgInvite>());
      expect(invite.id, 'invite-1');
      expect(invite.organizationId, 'org-1');
      expect(invite.email, 'teammate@example.com');
      expect(invite.role, OrgRole.admin);
      expect(invite.inviteCode, 'ABC12345');
      expect(invite.inviteToken, 'token-1');
      expect(invite.status, 'pending');
    });

    test('maps pending invite RPC errors to DeskflowException', () async {
      when(
        () => mockClient.rpc(
          'invite_member_by_email_v2',
          params: {
            'p_org_id': 'org-1',
            'p_email': 'owner@example.com',
            'p_role': 'owner',
          },
        ),
      ).thenThrow(
        const PostgrestException(message: 'NOT_ALLOWED_ROLE'),
      );

      await expectLater(
        () => adminRepository.inviteMemberByEmail(
          orgId: 'org-1',
          email: 'owner@example.com',
          role: OrgRole.owner,
        ),
        throwsA(
          isA<DeskflowException>().having(
            (error) => error.code,
            'code',
            'NOT_ALLOWED_ROLE',
          ),
        ),
      );
    });

    test('maps pgcrypto/search_path invite RPC errors to infrastructure exception', () async {
      when(
        () => mockClient.rpc(
          'invite_member_by_email_v2',
          params: {
            'p_org_id': 'org-1',
            'p_email': 'ops@example.com',
            'p_role': 'member',
          },
        ),
      ).thenThrow(
        const PostgrestException(
          message: 'function gen_random_bytes(integer) does not exist',
        ),
      );

      await expectLater(
        () => adminRepository.inviteMemberByEmail(
          orgId: 'org-1',
          email: 'ops@example.com',
          role: OrgRole.member,
        ),
        throwsA(
          isA<DeskflowException>()
              .having((error) => error.code, 'code', 'INVITE_RPC_MISCONFIGURED'),
        ),
      );
    });
  });

  group('acceptInviteByToken', () {
    test('returns organization payload from token acceptance RPC', () async {
      when(
        () => mockClient.rpc(
          'accept_org_invite_by_token',
          params: {'p_invite_token': 'token-1'},
        ),
      ).thenAnswer(
        (_) => FakeFilterBuilder<dynamic>({
          'id': 'org-1',
          'name': 'Deskflow',
          'slug': 'deskflow',
          'logo_url': null,
          'invite_code': 'JOIN1234',
          'created_at': '2026-03-01T10:00:00.000Z',
        }),
      );

      final organization = await orgRepository.acceptInviteByToken(
        inviteToken: 'token-1',
      );

      expect(organization.id, 'org-1');
      expect(organization.name, 'Deskflow');
      expect(organization.inviteCode, 'JOIN1234');
    });
  });

  group('acceptInviteByCode', () {
    test('returns organization payload from code acceptance RPC', () async {
      when(
        () => mockClient.rpc(
          'accept_org_invite_by_code',
          params: {'p_invite_code': 'JOIN1234'},
        ),
      ).thenAnswer(
        (_) => FakeFilterBuilder<dynamic>({
          'id': 'org-1',
          'name': 'Deskflow',
          'slug': null,
          'logo_url': null,
          'invite_code': 'JOIN1234',
          'created_at': '2026-03-01T10:00:00.000Z',
        }),
      );

      final organization = await orgRepository.acceptInviteByCode(
        inviteCode: 'JOIN1234',
      );

      expect(organization.id, 'org-1');
      expect(organization.inviteCode, 'JOIN1234');
    });
  });

  group('claimPendingInvites', () {
    test('returns accepted organizations from claim RPC', () async {
      when(
        () => mockClient.rpc('claim_pending_org_invites'),
      ).thenAnswer(
        (_) => FakeFilterBuilder<dynamic>([
          {
            'id': 'org-1',
            'name': 'Deskflow',
            'slug': null,
            'logo_url': null,
            'invite_code': 'JOIN1234',
            'created_at': '2026-03-01T10:00:00.000Z',
          },
        ]),
      );

      final result = await orgRepository.claimPendingInvites();

      expect(result, isA<OrgInviteClaimResult>());
      expect(result.organizations, hasLength(1));
      expect(result.organizations.single.name, 'Deskflow');
    });
  });
}
