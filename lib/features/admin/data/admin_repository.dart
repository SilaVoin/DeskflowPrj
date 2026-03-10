import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deskflow/core/errors/deskflow_exception.dart';
import 'package:deskflow/core/errors/supabase_error_handler.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/org/domain/org_member.dart';
import 'package:deskflow/features/orders/domain/order_status.dart';

final _log = AppLogger.getLogger('AdminRepository');

/// Handles admin-panel database operations:
/// - Organization member management (invite, role change, remove)
/// - Pipeline (order statuses) CRUD
class AdminRepository {
  final SupabaseClient _client;

  AdminRepository(this._client);

  // ──────────────────────── Members ─────────────────────────────────

  /// Get all members with their profile info (full_name, email).
  Future<List<MemberWithProfile>> getMembers(String orgId) async {
    _log.d('getMembers: orgId=$orgId');
    return supabaseGuard(() async {
      final data = await _client
          .from('organization_members')
          .select(
              '*, profiles!organization_members_user_id_fkey(full_name, email)')
          .eq('organization_id', orgId)
          .order('joined_at');

      return (data as List)
          .map((e) => MemberWithProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// Change a member's role.
  Future<void> changeRole({
    required String memberId,
    required OrgRole newRole,
  }) async {
    _log.d('changeRole: memberId=$memberId, newRole=$newRole');
    return supabaseGuard(() async {
      await _client
          .from('organization_members')
          .update({'role': newRole.toJson()})
          .eq('id', memberId);
    });
  }

  /// Remove a member from the organization.
  Future<void> removeMember(String memberId) async {
    _log.d('removeMember: memberId=$memberId');
    return supabaseGuard(() async {
      await _client
          .from('organization_members')
          .delete()
          .eq('id', memberId);
    });
  }

  /// Invite a new member by email.
  ///
  /// Uses a SECURITY DEFINER RPC function to bypass RLS on profiles table,
  /// since admin cannot SELECT other users' profiles (RLS: auth.uid() = id).
  Future<void> inviteMember({
    required String orgId,
    required String email,
    required OrgRole role,
  }) async {
    _log.d('inviteMember: orgId=$orgId, email=$email, role=$role');
    return supabaseGuard(() async {
      try {
        await _client.rpc(
          'invite_member_by_email',
          params: {
            'p_org_id': orgId,
            'p_email': email,
            'p_role': role.toJson(),
          },
        );
      } on PostgrestException catch (e) {
        // [FIX] Map RPC exceptions to DeskflowException (not plain Exception)
        // so supabaseGuard passes them through instead of wrapping as UNKNOWN_ERROR
        final msg = e.message;
        _log.w('[FIX] inviteMember RPC error: $msg');
        if (msg.contains('USER_NOT_FOUND')) {
          throw DeskflowException(
              'Пользователь с email $email не найден. '
              'Он должен сперва зарегистрироваться.',
              code: 'USER_NOT_FOUND');
        } else if (msg.contains('ALREADY_MEMBER')) {
          throw const DeskflowException(
              'Этот пользователь уже является участником',
              code: 'ALREADY_MEMBER');
        } else if (msg.contains('NOT_OWNER')) {
          throw const DeskflowException(
              'Только владелец может приглашать участников',
              code: 'NOT_OWNER');
        } else {
          rethrow;
        }
      }
    });
  }

  /// Count owners in an organization.
  Future<int> countOwners(String orgId) async {
    return supabaseGuard(() async {
      final response = await _client
          .from('organization_members')
          .select()
          .eq('organization_id', orgId)
          .eq('role', 'owner')
          .count(CountOption.exact);
      return response.count;
    });
  }

  // ──────────────────────── Pipeline ────────────────────────────────

  /// Create a new order status.
  Future<OrderStatus> createStatus({
    required String orgId,
    required String name,
    required String color,
    required int sortOrder,
    bool isDefault = false,
    bool isFinal = false,
  }) async {
    _log.d('createStatus: orgId=$orgId, name=$name');
    return supabaseGuard(() async {
      // If setting as default, unset any existing default
      if (isDefault) {
        await _client
            .from('order_statuses')
            .update({'is_default': false})
            .eq('organization_id', orgId)
            .eq('is_default', true);
      }

      final data = await _client
          .from('order_statuses')
          .insert({
            'organization_id': orgId,
            'name': name,
            'color': color,
            'sort_order': sortOrder,
            'is_default': isDefault,
            'is_final': isFinal,
          })
          .select()
          .single();

      return OrderStatus.fromJson(data);
    });
  }

  /// Update an existing order status.
  Future<OrderStatus> updateStatus({
    required String statusId,
    required String orgId,
    required String name,
    required String color,
    bool isDefault = false,
    bool isFinal = false,
  }) async {
    _log.d('updateStatus: statusId=$statusId, name=$name');
    return supabaseGuard(() async {
      if (isDefault) {
        await _client
            .from('order_statuses')
            .update({'is_default': false})
            .eq('organization_id', orgId)
            .eq('is_default', true);
      }

      final data = await _client
          .from('order_statuses')
          .update({
            'name': name,
            'color': color,
            'is_default': isDefault,
            'is_final': isFinal,
          })
          .eq('id', statusId)
          .select()
          .single();

      return OrderStatus.fromJson(data);
    });
  }

  /// Delete an order status.
  Future<void> deleteStatus(String statusId) async {
    _log.d('deleteStatus: statusId=$statusId');
    return supabaseGuard(() async {
      await _client.from('order_statuses').delete().eq('id', statusId);
    });
  }

  /// Reorder statuses by updating sort_order.
  Future<void> reorderStatuses(List<String> statusIds) async {
    _log.d('reorderStatuses: count=${statusIds.length}');
    return supabaseGuard(() async {
      for (int i = 0; i < statusIds.length; i++) {
        await _client
            .from('order_statuses')
            .update({'sort_order': i})
            .eq('id', statusIds[i]);
      }
    });
  }

  /// Count orders using a specific status.
  Future<int> countOrdersWithStatus(String statusId) async {
    return supabaseGuard(() async {
      final response = await _client
          .from('orders')
          .select()
          .eq('status_id', statusId)
          .count(CountOption.exact);
      return response.count;
    });
  }

  // ──────────────────────── Organization ────────────────────────────

  /// Update organization name.
  Future<void> updateOrganization({
    required String orgId,
    required String name,
  }) async {
    _log.d('updateOrganization: orgId=$orgId, name=$name');
    return supabaseGuard(() async {
      await _client
          .from('organizations')
          .update({'name': name})
          .eq('id', orgId);
    });
  }

  /// Delete organization.
  Future<void> deleteOrganization(String orgId) async {
    _log.d('deleteOrganization: orgId=$orgId');
    return supabaseGuard(() async {
      await _client.from('organizations').delete().eq('id', orgId);
    });
  }
}

/// OrgMember enriched with profile info.
class MemberWithProfile {
  final String id;
  final String organizationId;
  final String userId;
  final OrgRole role;
  final DateTime joinedAt;
  final String? fullName;
  final String? email;

  const MemberWithProfile({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.fullName,
    this.email,
  });

  /// Initials from full name.
  String get initials {
    if (fullName == null || fullName!.isEmpty) return '?';
    final parts = fullName!.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  factory MemberWithProfile.fromJson(Map<String, dynamic> json) {
    String? fullName;
    String? email;
    if (json['profiles'] != null) {
      final profile = json['profiles'] as Map<String, dynamic>;
      fullName = profile['full_name'] as String?;
      email = profile['email'] as String?;
    }

    return MemberWithProfile(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      userId: json['user_id'] as String,
      role: OrgRole.fromString(json['role'] as String),
      joinedAt: DateTime.parse(json['joined_at'] as String),
      fullName: fullName,
      email: email,
    );
  }
}
