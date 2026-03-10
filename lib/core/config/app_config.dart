import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:deskflow/core/utils/app_logger.dart';

final _log = AppLogger.getLogger('AppConfig');

/// Runtime configuration loaded from env.json asset.
///
/// Falls back to compile-time `String.fromEnvironment` if asset loading fails.
/// This avoids issues where `--dart-define-from-file` values are lost
/// during the Flutter → Gradle → Dart compiler build chain.
class AppConfig {
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String? googleWebClientId;
  final String? googleIosClientId;

  /// The loaded config instance. Available after [load] completes.
  static late final AppConfig instance;

  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.googleWebClientId,
    this.googleIosClientId,
  });

  /// Load config: first try env.json asset, then fall back to dart-define.
  static Future<AppConfig> load() async {
    _log.i('[FIX] Loading app config...');

    // 1. Try loading from asset file (most reliable)
    try {
      final jsonStr = await rootBundle.loadString('assets/env.json');
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      final url = map['SUPABASE_URL'] as String? ?? '';
      final key = map['SUPABASE_ANON_KEY'] as String? ?? '';

      if (url.isNotEmpty && key.isNotEmpty) {
        _log.i('[FIX] Config loaded from assets/env.json');
        _log.i('[FIX] SUPABASE_URL: ${url.substring(0, url.length.clamp(0, 30))}...');
        return AppConfig(
          supabaseUrl: url,
          supabaseAnonKey: key,
          googleWebClientId: _nonEmpty(map['GOOGLE_WEB_CLIENT_ID'] as String?),
          googleIosClientId: _nonEmpty(map['GOOGLE_IOS_CLIENT_ID'] as String?),
        );
      }
      _log.w('[FIX] assets/env.json exists but values are empty');
    } catch (e) {
      _log.w('[FIX] Could not load assets/env.json: $e');
    }

    // 2. Fall back to compile-time dart-define
    const dartDefineUrl = String.fromEnvironment('SUPABASE_URL');
    const dartDefineKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    _log.i('[FIX] Trying dart-define fallback: '
        'URL present=${dartDefineUrl.isNotEmpty}, '
        'KEY present=${dartDefineKey.isNotEmpty}');

    if (dartDefineUrl.isNotEmpty && dartDefineKey.isNotEmpty) {
      _log.i('[FIX] Config loaded from dart-define');
      const dartDefineGoogleWeb =
          String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
      const dartDefineGoogleIos =
          String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
      return AppConfig(
        supabaseUrl: dartDefineUrl,
        supabaseAnonKey: dartDefineKey,
        googleWebClientId: _nonEmpty(dartDefineGoogleWeb),
        googleIosClientId: _nonEmpty(dartDefineGoogleIos),
      );
    }

    // 3. Nothing worked
    _log.e('[FIX] CRITICAL: No Supabase config found! '
        'Add assets/env.json or build with --dart-define-from-file=env.json');
    throw StateError(
      'Supabase config not found. '
      'Create assets/env.json with SUPABASE_URL and SUPABASE_ANON_KEY, '
      'or build with --dart-define-from-file=env.json',
    );
  }

  /// Returns null for empty/placeholder strings.
  static String? _nonEmpty(String? value) {
    if (value == null || value.isEmpty || value.startsWith('YOUR_')) {
      return null;
    }
    return value;
  }
}
