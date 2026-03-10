import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deskflow/core/errors/supabase_error_handler.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/org/domain/org_member.dart';
import 'package:deskflow/features/org/domain/organization.dart';

final _log = AppLogger.getLogger('OrgRepository');

/// Handles all organization-related database operations.
class OrgRepository {
  final SupabaseClient _client;

  OrgRepository(this._client);

  /// Fetch organizations where the current user is a member.
  Future<List<Organization>> getUserOrganizations(String userId) async {
    _log.d('getUserOrganizations: userId=$userId');
    return supabaseGuard(() async {
      final data = await _client
          .from('organization_members')
          .select('organization_id, role, organizations(*)')
          .eq('user_id', userId);

      return (data as List).map((row) {
        final orgJson = row['organizations'] as Map<String, dynamic>;
        orgJson['user_role'] = row['role'] as String?;
        return Organization.fromJson(orgJson);
      }).toList();
    });
  }

  /// Get org member record for a specific user in an organization.
  Future<OrgMember?> getMembership(String userId, String orgId) async {
    _log.d('getMembership: userId=$userId, orgId=$orgId');
    return supabaseGuard(() async {
      final data = await _client
          .from('organization_members')
          .select()
          .eq('user_id', userId)
          .eq('organization_id', orgId)
          .maybeSingle();

      if (data == null) return null;
      return OrgMember.fromJson(data);
    });
  }

  /// Get all members of an organization.
  Future<List<OrgMember>> getOrgMembers(String orgId) async {
    _log.d('getOrgMembers: orgId=$orgId');
    return supabaseGuard(() async {
      final data = await _client
          .from('organization_members')
          .select()
          .eq('organization_id', orgId)
          .order('joined_at');

      return (data as List).map((row) => OrgMember.fromJson(row)).toList();
    });
  }

  /// Create a new organization and add creator as owner.
  /// Uses an RPC function to bypass RLS chicken-and-egg issue.
  Future<Organization> createOrganization({
    required String name,
    required String userId,
    String? logoUrl,
  }) async {
    _log.d('createOrganization: name=$name');
    return supabaseGuard(() async {
      final response = await _client.rpc('create_organization', params: {
        'p_name': name,
        'p_logo_url': logoUrl,
      });

      final orgData = response as Map<String, dynamic>;
      return Organization.fromJson(orgData);
    });
  }

  /// Join an organization via invite code.
  ///
  /// Uses a SECURITY DEFINER RPC function to bypass RLS on organizations table,
  /// since non-members cannot SELECT org rows (required to look up by invite_code).
  Future<Organization> joinByInviteCode({
    required String inviteCode,
    required String userId,
  }) async {
    _log.d('joinByInviteCode: code=$inviteCode');
    return supabaseGuard(() async {
      final response = await _client.rpc(
        'join_org_by_invite_code',
        params: {'p_invite_code': inviteCode},
      );

      final orgData = response as Map<String, dynamic>;
      return Organization.fromJson(orgData);
    });
  }

  /// Get user's role in an organization.
  Future<OrgRole> getRole(String userId, String orgId) async {
    _log.d('getRole: userId=$userId, orgId=$orgId');
    return supabaseGuard(() async {
      final data = await _client
          .from('organization_members')
          .select('role')
          .eq('user_id', userId)
          .eq('organization_id', orgId)
          .single();

      return OrgRole.fromString(data['role'] as String);
    });
  }

  /// Update organization's logo URL.
  Future<void> updateLogoUrl(String orgId, String logoUrl) async {
    _log.d('updateLogoUrl: orgId=$orgId');
    return supabaseGuard(() async {
      await _client
          .from('organizations')
          .update({'logo_url': logoUrl})
          .eq('id', orgId);
    });
  }

  /// Get member count for an organization.
  Future<int> getMemberCount(String orgId) async {
    return supabaseGuard(() async {
      final response = await _client
          .from('organization_members')
          .select()
          .eq('organization_id', orgId)
          .count(CountOption.exact);

      return response.count;
    });
  }

  // ──────────────────────────── Storage ──────────────────────────────

  /// Upload an organization avatar to Supabase Storage.
  ///
  /// Returns the public URL of the uploaded image.
  /// Path format: `{orgId}/avatar_{timestamp}.{ext}`
  Future<String> uploadOrgAvatar({
    required String orgId,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    _log.d('uploadOrgAvatar: orgId=$orgId');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // [FIX] Normalize ext for file path
    final normalizedExt = fileExt == 'jpeg' ? 'jpg' : fileExt;
    final path = '$orgId/avatar_$timestamp.$normalizedExt';

    // [FIX] Map to correct MIME type ('jpg' -> 'image/jpeg', not 'image/jpg')
    const mimeMap = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
    };
    final contentType = mimeMap[fileExt] ?? 'image/jpeg';
    _log.d('[FIX] uploadOrgAvatar: contentType=$contentType');

    await _client.storage.from('org-avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    final publicUrl =
        _client.storage.from('org-avatars').getPublicUrl(path);
    _log.d('uploadOrgAvatar: publicUrl=$publicUrl');
    return publicUrl;
  }
}
