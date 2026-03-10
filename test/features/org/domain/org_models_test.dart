import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/features/org/domain/org_member.dart';
import 'package:deskflow/features/org/domain/organization.dart';

void main() {
  group('OrgRole', () {
    test('fromString parses owner', () {
      expect(OrgRole.fromString('owner'), OrgRole.owner);
    });

    test('fromString parses admin', () {
      expect(OrgRole.fromString('admin'), OrgRole.admin);
    });

    test('fromString parses member', () {
      expect(OrgRole.fromString('member'), OrgRole.member);
    });

    test('fromString defaults to member for unknown', () {
      expect(OrgRole.fromString('superadmin'), OrgRole.member);
      expect(OrgRole.fromString(''), OrgRole.member);
    });

    test('toJson returns name string', () {
      expect(OrgRole.owner.toJson(), 'owner');
      expect(OrgRole.admin.toJson(), 'admin');
      expect(OrgRole.member.toJson(), 'member');
    });

    test('label returns Russian text', () {
      expect(OrgRole.owner.label, 'Владелец');
      expect(OrgRole.admin.label, 'Администратор');
      expect(OrgRole.member.label, 'Участник');
    });
  });

  group('OrgMember', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'mem-1',
        'organization_id': 'org-1',
        'user_id': 'user-1',
        'role': 'owner',
        'joined_at': '2025-01-15T10:00:00.000Z',
      };

      final member = OrgMember.fromJson(json);
      expect(member.id, 'mem-1');
      expect(member.organizationId, 'org-1');
      expect(member.userId, 'user-1');
      expect(member.role, OrgRole.owner);
    });
  });

  group('Organization', () {
    final json = {
      'id': 'org-1',
      'name': 'Тестовая организация',
      'slug': 'test-org',
      'logo_url': 'https://example.com/logo.png',
      'invite_code': 'ABC123',
      'created_at': '2025-01-15T10:00:00.000Z',
    };

    test('fromJson parses all fields', () {
      final org = Organization.fromJson(json);

      expect(org.id, 'org-1');
      expect(org.name, 'Тестовая организация');
      expect(org.slug, 'test-org');
      expect(org.logoUrl, 'https://example.com/logo.png');
      expect(org.inviteCode, 'ABC123');
    });

    test('fromJson handles missing optional fields', () {
      final minimalJson = {
        'id': 'org-2',
        'name': 'Базовая',
        'created_at': '2025-01-15T10:00:00.000Z',
      };

      final org = Organization.fromJson(minimalJson);
      expect(org.slug, isNull);
      expect(org.logoUrl, isNull);
      expect(org.inviteCode, isNull);
    });

    test('toJson includes all fields', () {
      final org = Organization.fromJson(json);
      final output = org.toJson();

      expect(output['name'], 'Тестовая организация');
      expect(output.containsKey('id'), false); // id not in toJson
    });
  });
}
