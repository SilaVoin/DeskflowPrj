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

  if (kIsWeb) usePathUrlStrategy();

  _log.i('Deskflow starting...');

  timeago.setLocaleMessages('ru', timeago.RuMessages());
  timeago.setDefaultLocale('ru');

  final config = await AppConfig.load();
  AppConfig.instance = config;

  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
  );

  _log.i('[FIX] Supabase initialized successfully');

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

class DeskflowApp extends ConsumerWidget {
  const DeskflowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _log.d('Building DeskflowApp');
    final router = ref.watch(appRouterProvider);

    ref.watch(authTokenRefreshWatcherProvider);

    return MaterialApp.router(
      title: 'Deskflow',
      debugShowCheckedModeBanner: false,
      theme: buildDeskflowTheme(),
      routerConfig: router,
    );
  }
}
