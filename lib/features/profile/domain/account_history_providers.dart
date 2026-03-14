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

final pendingLoginEmailProvider = StateProvider<String?>((ref) => null);

final addingAccountProvider = StateProvider<bool>((ref) => false);

final isSwitchingAccountProvider = StateProvider<bool>((ref) => false);

@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(Ref ref) async {
  _log.d('sharedPreferences: initializing');
  final prefs = await SharedPreferences.getInstance();
  _log.i('sharedPreferences: initialized successfully');
  return prefs;
}

@Riverpod(keepAlive: true)
AccountHistoryService accountHistoryService(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  if (prefs == null) {
    _log.d('accountHistoryService: SharedPreferences not ready yet');
    throw StateError('SharedPreferences not yet initialized');
  }
  _log.i('accountHistoryService: created with SharedPreferences');
  return AccountHistoryService(prefs);
}

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

  Future<void> addEmail(String email) async {
    _log.d('RecentEmailsNotifier.addEmail: email=$email');
    try {
      final prefs = await SharedPreferences.getInstance();
      final service = AccountHistoryService(prefs);
      await service.addEmail(email);
      state = service.getRecentEmails();
      _log.i('RecentEmailsNotifier.addEmail: state updated, count=${state.length}');
    } catch (e, st) {
      _log.e('RecentEmailsNotifier.addEmail: failed', error: e, stackTrace: st);
    }
  }

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
