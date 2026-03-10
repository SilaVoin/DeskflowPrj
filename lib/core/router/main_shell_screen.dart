import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/core/widgets/floating_island_nav.dart';
import 'package:deskflow/features/notifications/domain/notification_providers.dart';

final _log = AppLogger.getLogger('MainShellScreen');

/// Main app shell with floating island bottom navigation.
///
/// Wraps the 4 main tabs (Orders, Search, Customers, Profile) using
/// [StatefulShellRoute.indexedStack] from GoRouter.
///
/// On first display, requests notification permission (Android 13+).
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    // Only request on Android/iOS — web doesn't support this
    if (kIsWeb) return;

    try {
      final status = await Permission.notification.status;
      _log.d('Notification permission status: $status');

      if (status.isDenied) {
        final result = await Permission.notification.request();
        _log.d('Notification permission result: $result');
      }
    } catch (e) {
      _log.e('Failed to request notification permission: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeCount = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      body: widget.navigationShell,
      extendBody: true,
      bottomNavigationBar: FloatingIslandNav(
        currentIndex: widget.navigationShell.currentIndex,
        notificationBadgeCount: badgeCount,
        onTap: (index) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}
