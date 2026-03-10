import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

/// Floating island bottom navigation bar — 4 tabs.
///
/// Renders as a translucent glass capsule hovering above content,
/// with safe-area padding at the bottom.
///
/// Tab structure:
/// - 0: Заказы (Orders)
/// - 1: Поиск (Search)
/// - 2: Клиенты (Customers)
/// - 3: Профиль (Profile)
class FloatingIslandNav extends StatelessWidget {
  const FloatingIslandNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.notificationBadgeCount = 0,
  });

  /// Currently selected tab index (0-3).
  final int currentIndex;

  /// Called when a tab is tapped.
  final ValueChanged<int> onTap;

  /// Unread notification count — shows badge on Orders tab (index 0).
  final int notificationBadgeCount;

  /// Fixed height of the nav island capsule (without bottom padding).
  static const double navHeight = 64;

  /// [FIX] Compute the total height occupied by the floating nav island,
  /// including the system bottom padding and spacing.
  ///
  /// Formula: navHeight(64) + bottomPadding + DeskflowSpacing.sm(8)
  ///
  /// Uses [viewPadding.bottom] instead of [padding.bottom] because
  /// child Scaffolds inside [extendBody: true] parent have padding.bottom
  /// consumed (set to 0). viewPadding is never consumed by Scaffold/SafeArea,
  /// so it always reports the true system inset — critical for Samsung One UI 7
  /// where the gesture bar inset is significantly larger than stock Android.
  ///
  /// Use this in screens that need to position a FAB above the nav island:
  /// ```dart
  /// final fabOffset = FloatingIslandNav.totalHeight(context) + 16; // 16 = gap
  /// ```
  static double totalHeight(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    return navHeight + bottomPadding + DeskflowSpacing.sm;
  }

  static const _tabs = [
    _TabItem(icon: Icons.receipt_long_rounded, label: 'Заказы'),
    _TabItem(icon: Icons.search_rounded, label: 'Поиск'),
    _TabItem(icon: Icons.people_rounded, label: 'Клиенты'),
    _TabItem(icon: Icons.person_rounded, label: 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: DeskflowSpacing.xl,
        right: DeskflowSpacing.xl,
        bottom: bottomPadding + DeskflowSpacing.sm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DeskflowRadius.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: DeskflowColors.glassSurfaceElevated,
              borderRadius: BorderRadius.circular(DeskflowRadius.pill),
              border: Border.all(
                color: DeskflowColors.glassBorder,
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_tabs.length, (index) {
                final tab = _tabs[index];
                final isActive = index == currentIndex;

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Show badge on Orders tab (index 0) when
                          // there are unread notifications.
                          if (index == 0 && notificationBadgeCount > 0)
                            Badge(
                              label: Text(
                                notificationBadgeCount > 99
                                    ? '99+'
                                    : '$notificationBadgeCount',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              backgroundColor: DeskflowColors.destructiveSolid,
                              child: Icon(
                                tab.icon,
                                size: isActive ? 26 : 24,
                                color: isActive
                                    ? DeskflowColors.primarySolid
                                    : DeskflowColors.textTertiary,
                              ),
                            )
                          else
                            Icon(
                              tab.icon,
                              size: isActive ? 26 : 24,
                              color: isActive
                                  ? DeskflowColors.primarySolid
                                  : DeskflowColors.textTertiary,
                            ),
                          if (isActive) ...[
                            const SizedBox(height: 2),
                            Text(
                              tab.label,
                              style: DeskflowTypography.caption.copyWith(
                                color: DeskflowColors.primarySolid,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  const _TabItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
