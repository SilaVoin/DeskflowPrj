import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deskflow/core/config/app_config.dart';
import 'package:deskflow/core/router/app_router.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/profile/domain/account_history_providers.dart';
import 'package:timeago/timeago.dart' as timeago;

final _log = AppLogger.getLogger('Main');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // [FIX] Use path-based URLs instead of hash (#) for deep link compatibility
  if (kIsWeb) usePathUrlStrategy();

  _log.i('Deskflow starting...');

  // Set Russian locale for timeago (relative time formatting)
  timeago.setLocaleMessages('ru', timeago.RuMessages());
  timeago.setDefaultLocale('ru');

  // [FIX] Load config from assets/env.json (runtime) with dart-define fallback
  final config = await AppConfig.load();
  AppConfig.instance = config;

  // Initialize Supabase with validated config
  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
  );

  _log.i('[FIX] Supabase initialized successfully');

  // Force dark status bar for AMOLED theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: DeskflowColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: DeskflowApp(),
    ),
  );
}

/// Root application widget.
///
/// Uses [ProviderScope] for Riverpod and [GoRouter] for navigation.
/// ConsumerWidget so the router can react to auth state changes.
class DeskflowApp extends ConsumerWidget {
  const DeskflowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _log.d('Building DeskflowApp');
    final router = ref.watch(appRouterProvider);

    // [FIX] Initialize auth token refresh watcher — automatically updates
    // stored refresh tokens when Supabase SDK rotates them in the background.
    ref.watch(authTokenRefreshWatcherProvider);

    return MaterialApp.router(
      title: 'Deskflow',
      debugShowCheckedModeBanner: false,
      theme: buildDeskflowTheme(),
      routerConfig: router,
    );
  }
}
