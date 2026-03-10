import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:deskflow/core/providers/supabase_provider.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/org/data/org_repository.dart';
import 'package:deskflow/features/org/domain/org_member.dart';
import 'package:deskflow/features/org/domain/organization.dart';

part 'org_providers.g.dart';

final _log = AppLogger.getLogger('OrgProviders');

/// Org repository — keepAlive singleton.
@Riverpod(keepAlive: true)
OrgRepository orgRepository(Ref ref) {
  return OrgRepository(ref.watch(supabaseClientProvider));
}

/// List of organizations for the current user.
@riverpod
Future<List<Organization>> userOrganizations(Ref ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(orgRepositoryProvider).getUserOrganizations(user.id);
}

/// Currently selected organization ID.
///
/// Persisted across app lifecycle via keepAlive + SharedPreferences.
/// Set when user picks an org on OrgSelectionScreen.
/// [FIX] Auto-restores last selected org from SharedPreferences on app
/// startup / deep link navigation to prevent org context loss.
@Riverpod(keepAlive: true)
class CurrentOrgId extends _$CurrentOrgId {
  static const _prefsKey = 'last_selected_org_id';

  @override
  String? build() {
    // [FIX] Try to restore last org from SharedPreferences synchronously
    _restoreFromPrefs();
    return null;
  }

  /// [FIX] Async restore — called during build; updates state when ready.
  Future<void> _restoreFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrgId = prefs.getString(_prefsKey);
      if (savedOrgId != null && state == null) {
        _log.d('[FIX] CurrentOrgId: restored org=$savedOrgId from SharedPreferences');
        state = savedOrgId;
      }
    } catch (e) {
      _log.d('[FIX] CurrentOrgId: could not restore org (non-critical): $e');
    }
  }

  void select(String orgId) {
    state = orgId;
    _persistToPrefs(orgId);
  }

  void clear() {
    state = null;
    _clearPrefs();
  }

  /// [FIX] Persist selected org to SharedPreferences.
  Future<void> _persistToPrefs(String orgId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, orgId);
      _log.d('[FIX] CurrentOrgId: persisted org=$orgId');
    } catch (e) {
      _log.d('[FIX] CurrentOrgId: could not persist org (non-critical): $e');
    }
  }

  /// [FIX] Clear persisted org from SharedPreferences.
  Future<void> _clearPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      _log.d('[FIX] CurrentOrgId: cleared persisted org');
    } catch (e) {
      _log.d('[FIX] CurrentOrgId: could not clear org (non-critical): $e');
    }
  }
}

/// Current user's role in the selected organization.
@riverpod
Future<OrgRole> currentUserRole(Ref ref) async {
  final user = ref.watch(currentUserProvider);
  final orgId = ref.watch(currentOrgIdProvider);
  if (user == null || orgId == null) {
    return OrgRole.member; // Default fallback
  }
  return ref.watch(orgRepositoryProvider).getRole(user.id, orgId);
}

/// Whether current user is owner of the selected org.
@riverpod
bool isOwner(Ref ref) {
  final role = ref.watch(currentUserRoleProvider).valueOrNull;
  return role == OrgRole.owner;
}

/// Whether current user is owner or admin of the selected org.
@riverpod
bool isOwnerOrAdmin(Ref ref) {
  final role = ref.watch(currentUserRoleProvider).valueOrNull;
  return role == OrgRole.owner || role == OrgRole.admin;
}
