import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:deskflow/core/providers/supabase_provider.dart';
import 'package:deskflow/features/admin/data/admin_repository.dart';
import 'package:deskflow/features/orders/domain/order_status.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

part 'admin_providers.g.dart';

/// Admin repository singleton.
@Riverpod(keepAlive: true)
AdminRepository adminRepository(Ref ref) {
  return AdminRepository(ref.watch(supabaseClientProvider));
}

/// Organization members with profiles.
@riverpod
Future<List<MemberWithProfile>> orgMembers(Ref ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return [];
  return ref.watch(adminRepositoryProvider).getMembers(orgId);
}

/// Pipeline statuses for management (already exists in order_providers,
/// but admin may want fresh reload).
@riverpod
Future<List<OrderStatus>> adminPipeline(Ref ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return [];

  // Reuse OrderRepository's getPipeline via the Supabase client
  // [FIX] ascending: true required — postgrest-dart defaults to descending.
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
