import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deskflow/core/errors/supabase_error_handler.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/profile/domain/notification_settings.dart';

final _log = AppLogger.getLogger('ProfileRepository');

/// Handles profile-related database operations.
class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  // ──────────────────── Notification Settings ────────────────────

  /// Fetch notification settings for user+org.
  /// Returns null if no row exists yet (user hasn't customized).
  Future<NotificationSettings?> getNotificationSettings({
    required String userId,
    required String orgId,
  }) async {
    _log.d('getNotificationSettings: userId=$userId, orgId=$orgId');
    return supabaseGuard(() async {
      final data = await _client
          .from('user_preferences')
          .select()
          .eq('user_id', userId)
          .eq('organization_id', orgId)
          .maybeSingle();

      if (data == null) {
        _log.d('getNotificationSettings: no row found, returning null');
        return null;
      }

      _log.d('getNotificationSettings: loaded settings id=${data['id']}');
      return NotificationSettings.fromJson(data);
    });
  }

  /// Upsert notification settings (insert or update).
  Future<NotificationSettings> saveNotificationSettings(
    NotificationSettings settings,
  ) async {
    _log.d(
      'saveNotificationSettings: userId=${settings.userId}, '
      'orgId=${settings.organizationId}, '
      'newOrders=${settings.notifyNewOrders}, '
      'statusChanges=${settings.notifyStatusChanges}, '
      'chatMessages=${settings.notifyChatMessages}, '
      'sound=${settings.notifySound}',
    );
    return supabaseGuard(() async {
      final data = await _client
          .from('user_preferences')
          .upsert(
            settings.toJson(),
            onConflict: 'user_id,organization_id',
          )
          .select()
          .single();

      _log.i('saveNotificationSettings: saved id=${data['id']}');
      return NotificationSettings.fromJson(data);
    });
  }

  // ──────────────────── Profile Info ─────────────────────────────

  /// Get profile data for the current user.
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    _log.d('getProfile: userId=$userId');
    return supabaseGuard(() async {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      _log.d('getProfile: ${data != null ? 'found' : 'not found'}');
      return data;
    });
  }

  /// Update profile fields for the current user.
  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? avatarUrl,
  }) async {
    _log.d('updateProfile: userId=$userId, fullName=$fullName');
    return supabaseGuard(() async {
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      if (updates.isEmpty) {
        _log.d('updateProfile: no fields to update');
        return;
      }

      await _client.from('profiles').update(updates).eq('id', userId);
      _log.i('updateProfile: updated successfully');
    });
  }

  // ──────────────────── Avatar Upload ────────────────────────────

  /// Upload a user avatar to Supabase Storage 'avatars' bucket.
  ///
  /// Returns the public URL of the uploaded image.
  /// Path format: `{userId}/avatar_{timestamp}.{ext}`
  ///
  /// Uses upsert to replace existing avatar at the same path slot.
  /// Follows the same pattern as `OrgRepository.uploadOrgAvatar`.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    _log.d('uploadAvatar: userId=$userId, fileExt=$fileExt, bytes=${bytes.length}');
    return supabaseGuard(() async {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // [FIX] Normalize extension: both 'jpg' and 'jpeg' use file ext 'jpg'
      final normalizedExt = fileExt == 'jpeg' ? 'jpg' : fileExt;
      final path = '$userId/avatar_$timestamp.$normalizedExt';
      _log.d('[FIX] uploadAvatar: uploading to path=$path');

      // [FIX] Map file extension to correct MIME type
      // 'jpg' must map to 'image/jpeg' (not 'image/jpg' which is invalid)
      final mimeMap = {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'webp': 'image/webp',
      };
      final contentType = mimeMap[fileExt] ?? 'image/jpeg';
      _log.d('[FIX] uploadAvatar: contentType=$contentType (from ext=$fileExt)');

      await _client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );

      final publicUrl = _client.storage.from('avatars').getPublicUrl(path);
      _log.d('uploadAvatar: publicUrl=$publicUrl');
      return publicUrl;
    });
  }
}
