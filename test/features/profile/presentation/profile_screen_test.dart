import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/org/domain/org_member.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';
import 'package:deskflow/features/org/domain/organization.dart';
import 'package:deskflow/features/profile/presentation/profile_screen.dart';

/// Helper to build a testable ProfileScreen with provider overrides.
Widget _buildTestApp({
  User? user,
  bool isOwner = false,
  OrgRole role = OrgRole.member,
  List<Organization> organizations = const [],
  String? orgId,
}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(user),
      isOwnerProvider.overrideWithValue(isOwner),
      isOwnerOrAdminProvider
          .overrideWithValue(role == OrgRole.owner || role == OrgRole.admin),
      currentUserRoleProvider.overrideWith((_) async => role),
      currentOrgIdProvider.overrideWith(() {
        return _TestCurrentOrgId(orgId);
      }),
      userOrganizationsProvider.overrideWith((_) async => organizations),
    ],
    child: const MaterialApp(
      home: Scaffold(body: ProfileScreen()),
    ),
  );
}

class _TestCurrentOrgId extends CurrentOrgId {
  _TestCurrentOrgId(this._initial);
  final String? _initial;

  @override
  String? build() => _initial;
}

User _makeUser({
  String id = 'user-1',
  String? email,
  String? fullName,
}) {
  return User(
    id: id,
    appMetadata: const {},
    userMetadata: fullName != null ? {'full_name': fullName} : const {},
    aud: 'authenticated',
    createdAt: DateTime(2025, 1, 1).toIso8601String(),
    email: email,
  );
}

void main() {
  group('ProfileScreen', () {
    testWidgets('shows user email', (tester) async {
      final user = _makeUser(email: 'test@example.com');
      await tester.pumpWidget(_buildTestApp(user: user));
      await tester.pumpAndSettle();

      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('shows full name and initials', (tester) async {
      final user = _makeUser(
        email: 'a@b.com',
        fullName: 'Иван Петров',
      );
      await tester.pumpWidget(_buildTestApp(user: user));
      await tester.pumpAndSettle();

      expect(find.text('Иван Петров'), findsOneWidget);
      expect(find.text('ИП'), findsOneWidget);
    });

    testWidgets('shows "Владелец" badge when owner', (tester) async {
      final user = _makeUser(email: 'owner@org.com');
      await tester.pumpWidget(
        _buildTestApp(user: user, isOwner: true, role: OrgRole.owner),
      );
      await tester.pumpAndSettle();

      expect(find.text('Владелец'), findsOneWidget);
    });

    testWidgets('shows "Участник" badge when member', (tester) async {
      final user = _makeUser(email: 'member@org.com');
      await tester.pumpWidget(
        _buildTestApp(user: user, isOwner: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('Участник'), findsOneWidget);
    });

    testWidgets('shows admin section for owner', (tester) async {
      final user = _makeUser(email: 'admin@org.com');
      await tester.pumpWidget(
        _buildTestApp(user: user, isOwner: true, role: OrgRole.owner),
      );
      await tester.pumpAndSettle();

      expect(find.text('Админ-панель'), findsOneWidget);
      expect(find.text('Управление пользователями'), findsOneWidget);
      expect(find.text('Настройка статусов'), findsOneWidget);
      expect(find.text('Управление каталогом'), findsOneWidget);
    });

    testWidgets('hides admin section for member', (tester) async {
      final user = _makeUser(email: 'member@org.com');
      await tester.pumpWidget(
        _buildTestApp(user: user, isOwner: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('Админ-панель'), findsNothing);
      expect(find.text('Управление пользователями'), findsNothing);
    });

    testWidgets('shows org settings for owner only', (tester) async {
      final user = _makeUser(email: 'owner@org.com');
      await tester.pumpWidget(
        _buildTestApp(user: user, isOwner: true, role: OrgRole.owner),
      );
      await tester.pumpAndSettle();

      expect(find.text('Настройки организации'), findsOneWidget);
    });

    testWidgets('hides org settings for member', (tester) async {
      final user = _makeUser(email: 'member@org.com');
      await tester.pumpWidget(
        _buildTestApp(user: user, isOwner: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('Настройки организации'), findsNothing);
    });

    testWidgets('shows organization name', (tester) async {
      final user = _makeUser(email: 'user@org.com');
      final orgs = [
        Organization(
          id: 'org-1',
          name: 'Тестовая компания',
          createdAt: DateTime(2025, 1, 1),
        ),
      ];
      await tester.pumpWidget(
        _buildTestApp(user: user, organizations: orgs, orgId: 'org-1'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Тестовая компания'), findsOneWidget);
    });

    testWidgets('shows logout button', (tester) async {
      final user = _makeUser(email: 'user@org.com');
      await tester.pumpWidget(_buildTestApp(user: user));
      await tester.pumpAndSettle();

      expect(find.text('Выйти'), findsOneWidget);
    });

    testWidgets('shows settings section', (tester) async {
      final user = _makeUser(email: 'user@org.com');
      await tester.pumpWidget(_buildTestApp(user: user));
      await tester.pumpAndSettle();

      expect(find.text('Настройки'), findsOneWidget);
      expect(find.text('Уведомления'), findsOneWidget);
      expect(find.text('О приложении'), findsOneWidget);
    });

    testWidgets('email initial when no full name', (tester) async {
      final user = _makeUser(email: 'zara@test.com');
      await tester.pumpWidget(_buildTestApp(user: user));
      await tester.pumpAndSettle();

      expect(find.text('Z'), findsOneWidget);
    });
  });
}
