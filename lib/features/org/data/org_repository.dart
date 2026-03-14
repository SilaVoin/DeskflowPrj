import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deskflow/core/errors/deskflow_exception.dart';
import 'package:deskflow/core/errors/supabase_error_handler.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/org/domain/org_member.dart';
import 'package:deskflow/features/org/domain/org_invite_result.dart';
import 'package:deskflow/features/org/domain/organization.dart';

final _log = AppLogger.getLogger('OrgRepository');

class OrgRepository {
  final SupabaseClient _client;

  OrgRepository(this._client);

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

  Future<Organization> acceptInviteByToken({
    required String inviteToken,
  }) async {
    _log.d('acceptInviteByToken');
    return supabaseGuard(() async {
      try {
        final response = await _client.rpc(
          'accept_org_invite_by_token',
          params: {'p_invite_token': inviteToken},
        );
        return Organization.fromJson(response as Map<String, dynamic>);
      } on PostgrestException catch (e) {
        throw _mapInviteAcceptError(e);
      }
    });
  }

  Future<Organization> acceptInviteByCode({
    required String inviteCode,
  }) async {
    _log.d('acceptInviteByCode');
    return supabaseGuard(() async {
      try {
        final response = await _client.rpc(
          'accept_org_invite_by_code',
          params: {'p_invite_code': inviteCode.trim()},
        );
        return Organization.fromJson(response as Map<String, dynamic>);
      } on PostgrestException catch (e) {
        throw _mapInviteAcceptError(e);
      }
    });
  }

  Future<OrgInviteClaimResult> claimPendingInvites() async {
    _log.d('claimPendingInvites');
    return supabaseGuard(() async {
      try {
        final response = await _client.rpc('claim_pending_org_invites');
        final organizations = switch (response) {
          List<dynamic> rows =>
            rows
                .cast<Map<String, dynamic>>()
                .map(Organization.fromJson)
                .toList(),
          {'organizations': final List<dynamic> rows} =>
            rows
                .cast<Map<String, dynamic>>()
                .map(Organization.fromJson)
                .toList(),
          _ => const <Organization>[],
        };
        return OrgInviteClaimResult(organizations: organizations);
      } on PostgrestException catch (e) {
        throw _mapInviteAcceptError(e);
      }
    });
  }

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

  Future<void> updateLogoUrl(String orgId, String logoUrl) async {
    _log.d('updateLogoUrl: orgId=$orgId');
    return supabaseGuard(() async {
      await _client
          .from('organizations')
          .update({'logo_url': logoUrl})
          .eq('id', orgId);
    });
  }

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

  DeskflowException _mapInviteAcceptError(PostgrestException error) {
    final msg = error.message;

    if (msg.contains('INVALID_INVITE_TOKEN') ||
        msg.contains('INVALID_INVITE_CODE') ||
        msg.contains('INVITE_NOT_FOUND')) {
      return const DeskflowException(
        'Приглашение не найдено',
        code: 'INVITE_NOT_FOUND',
      );
    }
    if (msg.contains('INVITE_EXPIRED')) {
      return const DeskflowException(
        'Срок действия приглашения истёк',
        code: 'INVITE_EXPIRED',
      );
    }
    if (msg.contains('INVITE_REVOKED')) {
      return const DeskflowException(
        'Приглашение отозвано',
        code: 'INVITE_REVOKED',
      );
    }
    if (msg.contains('EMAIL_MISMATCH')) {
      return const DeskflowException(
        'Войдите под тем email, на который отправлено приглашение',
        code: 'EMAIL_MISMATCH',
      );
    }
    if (msg.contains('INVITE_ALREADY_ACCEPTED') ||
        msg.contains('ALREADY_MEMBER')) {
      return const DeskflowException(
        'Вы уже состоите в этой организации',
        code: 'ALREADY_MEMBER',
      );
    }

    return DeskflowException(msg, code: error.code);
  }


  Future<String> uploadOrgAvatar({
    required String orgId,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    _log.d('uploadOrgAvatar: orgId=$orgId');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final normalizedExt = fileExt == 'jpeg' ? 'jpg' : fileExt;
    final path = '$orgId/avatar_$timestamp.$normalizedExt';

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
