import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deskflow/core/providers/supabase_provider.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/profile/data/account_history_service.dart';

part 'account_history_providers.g.dart';

final _log = AppLogger.getLogger('AccountHistoryProviders');

/// Email to pre-fill on LoginScreen after account switch.
/// Set before signOut so it survives the redirect.
final pendingLoginEmailProvider = StateProvider<String?>((ref) => null);

/// Flag: user is adding a new account from Profile.
/// Allows /auth/register to be accessed while still logged in.
final addingAccountProvider = StateProvider<bool>((ref) => false);

/// Flag: account switch in progress — suppresses router redirects
/// to prevent navigation to login between signOut and restoreSession.
final isSwitchingAccountProvider = StateProvider<bool>((ref) => false);

/// SharedPreferences instance — keepAlive singleton.
@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(Ref ref) async {
  _log.d('sharedPreferences: initializing');
  final prefs = await SharedPreferences.getInstance();
  _log.i('sharedPreferences: initialized successfully');
  return prefs;
}

/// AccountHistoryService — keepAlive singleton.
@Riverpod(keepAlive: true)
AccountHistoryService accountHistoryService(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  if (prefs == null) {
    _log.d('accountHistoryService: SharedPreferences not ready yet');
    // Return a service that will work once prefs are available.
    // This is a temporary state — the provider will rebuild when prefs resolve.
    throw StateError('SharedPreferences not yet initialized');
  }
  _log.i('accountHistoryService: created with SharedPreferences');
  return AccountHistoryService(prefs);
}

/// StateNotifier for the list of recent emails — provides reactive updates.
///
/// [FIX] keepAlive: true — prevents provider disposal during navigation
/// (splash → org-select → orders) when switching accounts.
/// Without this, the notifier (and stored emails + tokens) would be lost
/// when the widget tree rebuilds during account switch.
@Riverpod(keepAlive: true)
class RecentEmailsNotifier extends _$RecentEmailsNotifier {
  @override
  List<String> build() {
    try {
      final service = ref.watch(accountHistoryServiceProvider);
      final emails = service.getRecentEmails();
      _log.d('RecentEmailsNotifier.build: loaded ${emails.length} emails');
      return emails;
    } catch (_) {
      _log.d('RecentEmailsNotifier.build: service not ready, returning empty');
      return [];
    }
  }

  /// Add email and refresh state.
  Future<void> addEmail(String email) async {
    _log.d('RecentEmailsNotifier.addEmail: email=$email');
    try {
      // Ensure SharedPreferences is ready before saving
      final prefs = await SharedPreferences.getInstance();
      final service = AccountHistoryService(prefs);
      await service.addEmail(email);
      state = service.getRecentEmails();
      _log.i('RecentEmailsNotifier.addEmail: state updated, count=${state.length}');
    } catch (e, st) {
      _log.e('RecentEmailsNotifier.addEmail: failed', error: e, stackTrace: st);
    }
  }

  /// Remove email and refresh state.
  Future<void> removeEmail(String email) async {
    _log.d('RecentEmailsNotifier.removeEmail: email=$email');
    try {
      final prefs = await SharedPreferences.getInstance();
      final service = AccountHistoryService(prefs);
      await service.removeEmail(email);
      await service.removeRefreshToken(email);
      state = service.getRecentEmails();
      _log.i('RecentEmailsNotifier.removeEmail: state updated, count=${state.length}');
    } catch (e, st) {
      _log.e('RecentEmailsNotifier.removeEmail: failed', error: e, stackTrace: st);
    }
  }

  /// Save a refresh token for a specific email.
  Future<void> saveRefreshToken(String email, String refreshToken) async {
    _log.d('[FIX] saveRefreshToken: email=$email');
    try {
      final prefs = await SharedPreferences.getInstance();
      final service = AccountHistoryService(prefs);
      await service.saveRefreshToken(email, refreshToken);
      _log.i('[FIX] saveRefreshToken: done');
    } catch (e, st) {
      _log.e('[FIX] saveRefreshToken: failed', error: e, stackTrace: st);
    }
  }

  /// Get the stored refresh token for [email], or null.
  String? getRefreshToken(String email) {
    _log.d('[FIX] getRefreshToken: email=$email');
    try {
      final service = ref.read(accountHistoryServiceProvider);
      return service.getRefreshToken(email);
    } catch (e, st) {
      _log.e('[FIX] getRefreshToken: failed', error: e, stackTrace: st);
      return null;
    }
  }
}

/// [FIX] Auth state change listener — keepAlive.
///
/// Subscribes to Supabase auth state changes and automatically updates
/// the stored refresh token when a `tokenRefreshed` event occurs.
/// This prevents stale tokens from being saved when the SDK rotates
/// them in the background.
@Riverpod(keepAlive: true)
Stream<void> authTokenRefreshWatcher(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  final controller = StreamController<void>();

  final subscription = client.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    final session = data.session;

    if (event == AuthChangeEvent.tokenRefreshed && session != null) {
      final email = session.user.email;
      final newToken = session.refreshToken;

      if (email != null && newToken != null) {
        _log.i('[FIX] authTokenRefreshWatcher: token refreshed for $email, updating stored token');
        ref
            .read(recentEmailsNotifierProvider.notifier)
            .saveRefreshToken(email, newToken);
      }
    }

    controller.add(null);
  });

  ref.onDispose(() {
    _log.d('[FIX] authTokenRefreshWatcher: disposing');
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
}
