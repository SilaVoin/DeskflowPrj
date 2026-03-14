import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deskflow/core/providers/supabase_provider.dart';
import 'package:deskflow/features/auth/data/auth_repository.dart';

part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
}

@Riverpod(keepAlive: true)
Stream<AuthState> authStateChanges(Ref ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
}

@Riverpod(keepAlive: true)
User? currentUser(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  ref.watch(authStateChangesProvider);
  return client.auth.currentUser;
}

@riverpod
bool isAuthenticated(Ref ref) {
  return ref.watch(currentUserProvider) != null;
}


