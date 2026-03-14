import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:deskflow/core/providers/supabase_provider.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';
import 'package:deskflow/features/profile/data/profile_repository.dart';
import 'package:deskflow/features/profile/domain/notification_settings.dart';

part 'profile_providers.g.dart';

final _log = AppLogger.getLogger('ProfileProviders');

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
}

@riverpod
class NotificationSettingsNotifier extends _$NotificationSettingsNotifier {
  @override
  Future<NotificationSettings> build() async {
    final user = ref.watch(currentUserProvider);
    final orgId = ref.watch(currentOrgIdProvider);

    if (user == null || orgId == null) {
      _log.d('NotificationSettingsNotifier: no user or org, returning defaults');
      return NotificationSettings.defaults(
        userId: '',
        organizationId: '',
      );
    }

    _log.d('NotificationSettingsNotifier: loading for user=${user.id}, org=$orgId');
    final repo = ref.watch(profileRepositoryProvider);
    final saved = await repo.getNotificationSettings(
      userId: user.id,
      orgId: orgId,
    );

    if (saved != null) {
      _log.d('NotificationSettingsNotifier: loaded saved settings');
      return saved;
    }

    _log.d('NotificationSettingsNotifier: no saved settings, using defaults');
    return NotificationSettings.defaults(
      userId: user.id,
      organizationId: orgId,
    );
  }

  Future<void> updateSetting({
    bool? notifyNewOrders,
    bool? notifyStatusChanges,
    bool? notifyChatMessages,
    bool? notifySound,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.copyWith(
      notifyNewOrders: notifyNewOrders,
      notifyStatusChanges: notifyStatusChanges,
      notifyChatMessages: notifyChatMessages,
      notifySound: notifySound,
    );

    state = AsyncData(updated);

    _log.d('updateSetting: saving to Supabase');
    try {
      final repo = ref.read(profileRepositoryProvider);
      final saved = await repo.saveNotificationSettings(updated);
      state = AsyncData(saved);
      _log.i('updateSetting: saved successfully');
    } catch (e, st) {
      _log.e('updateSetting: failed, reverting', error: e, stackTrace: st);
      state = AsyncData(current);
    }
  }
}

class UserProfileData {
  final String? fullName;
  final String? avatarUrl;

  const UserProfileData({this.fullName, this.avatarUrl});
}

@riverpod
class UserProfileNotifier extends _$UserProfileNotifier {
  @override
  Future<UserProfileData> build() async {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      _log.d('UserProfileNotifier: no user, returning empty');
      return const UserProfileData();
    }

    _log.d('UserProfileNotifier: loading profile for user=${user.id}');
    final repo = ref.watch(profileRepositoryProvider);
    final data = await repo.getProfile(user.id);

    if (data == null) {
      _log.d('UserProfileNotifier: profile not found, returning empty');
      return const UserProfileData();
    }

    final profile = UserProfileData(
      fullName: data['full_name'] as String?,
      avatarUrl: data['avatar_url'] as String?,
    );
    _log.d(
      'UserProfileNotifier: loaded fullName=${profile.fullName}, '
      'avatarUrl=${profile.avatarUrl != null ? 'present' : 'null'}',
    );
    return profile;
  }

  Future<void> updateAvatar(Uint8List bytes, String fileExt) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _log.w('updateAvatar: no user, aborting');
      return;
    }

    _log.d('updateAvatar: userId=${user.id}, ext=$fileExt, bytes=${bytes.length}');
    final repo = ref.read(profileRepositoryProvider);

    try {
      _log.d('updateAvatar: uploading to Storage...');
      final publicUrl = await repo.uploadAvatar(
        userId: user.id,
        bytes: bytes,
        fileExt: fileExt,
      );
      _log.d('updateAvatar: uploaded, publicUrl=$publicUrl');

      _log.d('updateAvatar: updating profiles table...');
      await repo.updateProfile(userId: user.id, avatarUrl: publicUrl);
      _log.i('updateAvatar: profile updated successfully');

      final current = state.valueOrNull ?? const UserProfileData();
      state = AsyncData(UserProfileData(
        fullName: current.fullName,
        avatarUrl: publicUrl,
      ));
    } catch (e, st) {
      _log.e('updateAvatar: failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> updateDisplayName(String name) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _log.w('updateDisplayName: no user, aborting');
      return;
    }

    _log.d('updateDisplayName: userId=${user.id}, name=$name');
    final repo = ref.read(profileRepositoryProvider);

    try {
      await repo.updateProfile(userId: user.id, fullName: name);
      _log.i('updateDisplayName: updated successfully');

      final current = state.valueOrNull ?? const UserProfileData();
      state = AsyncData(UserProfileData(
        fullName: name,
        avatarUrl: current.avatarUrl,
      ));
    } catch (e, st) {
      _log.e('updateDisplayName: failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}
