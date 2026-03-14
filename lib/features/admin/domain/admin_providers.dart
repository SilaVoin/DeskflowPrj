import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:deskflow/core/providers/supabase_provider.dart';
import 'package:deskflow/features/admin/data/admin_repository.dart';
import 'package:deskflow/features/orders/domain/order_status.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

part 'admin_providers.g.dart';

@Riverpod(keepAlive: true)
AdminRepository adminRepository(Ref ref) {
  return AdminRepository(ref.watch(supabaseClientProvider));
}

@riverpod
Future<List<MemberWithProfile>> orgMembers(Ref ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return [];
  return ref.watch(adminRepositoryProvider).getMembers(orgId);
}

@riverpod
Future<List<OrderStatus>> adminPipeline(Ref ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return [];

  final data = await ref
      .watch(supabaseClientProvider)
      .from('order_statuses')
      .select()
      .eq('organization_id', orgId)
      .order('sort_order', ascending: true);

  return (data as List)
      .map((e) => OrderStatus.fromJson(e as Map<String, dynamic>))
      .toList();
}
