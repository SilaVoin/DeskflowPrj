import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deskflow/core/errors/deskflow_exception.dart';
import 'package:deskflow/core/errors/supabase_error_handler.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/admin/domain/org_invite.dart';
import 'package:deskflow/features/org/domain/org_member.dart';
import 'package:deskflow/features/orders/domain/order_status.dart';

final _log = AppLogger.getLogger('AdminRepository');

class AdminRepository {
  final SupabaseClient _client;

  AdminRepository(this._client);


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

  Future<void> removeMember(String memberId) async {
    _log.d('removeMember: memberId=$memberId');
    return supabaseGuard(() async {
      await _client
          .from('organization_members')
          .delete()
          .eq('id', memberId);
    });
  }

  Future<OrgInvite> inviteMemberByEmail({
    required String orgId,
    required String email,
    required OrgRole role,
  }) async {
    _log.d('inviteMemberByEmail: orgId=$orgId, email=$email, role=$role');
    return supabaseGuard(() async {
      try {
        final response = await _client.rpc(
          'invite_member_by_email_v2',
          params: {
            'p_org_id': orgId,
            'p_email': email.trim(),
            'p_role': role.toJson(),
          },
        );

        return OrgInvite.fromJson(response as Map<String, dynamic>);
      } on PostgrestException catch (e) {
        throw _mapInviteError(e, email: email);
      }
    });
  }

  Future<void> inviteMember({
    required String orgId,
    required String email,
    required OrgRole role,
  }) async {
    await inviteMemberByEmail(orgId: orgId, email: email, role: role);
  }

  DeskflowException _mapInviteError(
    PostgrestException error, {
    required String email,
  }) {
    final msg = error.message;
    _log.w('invite RPC error: $msg');

    if (msg.contains('ALREADY_MEMBER')) {
      return const DeskflowException(
        'Этот пользователь уже является участником',
        code: 'ALREADY_MEMBER',
      );
    }
    if (msg.contains('NOT_ALLOWED_ROLE')) {
      return const DeskflowException(
        'Администратор не может приглашать владельца',
        code: 'NOT_ALLOWED_ROLE',
      );
    }
    if (msg.contains('NOT_ALLOWED')) {
      return const DeskflowException(
        'Только владелец или администратор может приглашать участников',
        code: 'NOT_ALLOWED',
      );
    }
    if (msg.contains('INVALID_ROLE')) {
      return const DeskflowException(
        'Выбрана некорректная роль',
        code: 'INVALID_ROLE',
      );
    }
    if (msg.contains('INVALID_EMAIL')) {
      return DeskflowException(
        'Некорректный email: $email',
        code: 'INVALID_EMAIL',
      );
    }
    if (msg.contains('gen_random_bytes')) {
      return const DeskflowException(
        'Сервис приглашений временно недоступен. Обновите миграции базы данных.',
        code: 'INVITE_RPC_MISCONFIGURED',
      );
    }

    return DeskflowException(msg, code: error.code);
  }

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

  Future<void> deleteStatus(String statusId) async {
    _log.d('deleteStatus: statusId=$statusId');
    return supabaseGuard(() async {
      await _client.from('order_statuses').delete().eq('id', statusId);
    });
  }

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

  Future<void> deleteOrganization(String orgId) async {
    _log.d('deleteOrganization: orgId=$orgId');
    return supabaseGuard(() async {
      await _client.from('organizations').delete().eq('id', orgId);
    });
  }
}

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
