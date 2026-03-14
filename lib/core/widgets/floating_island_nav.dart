import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_motion.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';

class FloatingIslandNav extends StatelessWidget {
  const FloatingIslandNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.notificationBadgeCount = 0,
  });

  final int currentIndex;

  final ValueChanged<int> onTap;

  final int notificationBadgeCount;

  static const double navHeight = 64;

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
    final motion = DeskflowMotionTheme.of(context);
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalInset = screenWidth < 380
        ? DeskflowSpacing.lg
        : DeskflowSpacing.xl;

    return Padding(
      padding: EdgeInsets.only(
        left: horizontalInset,
        right: horizontalInset,
        bottom: bottomPadding + DeskflowSpacing.sm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DeskflowRadius.nav),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: DeskflowColors.shellGlassSurfaceFocused,
              borderRadius: BorderRadius.circular(DeskflowRadius.nav),
              border: Border.all(
                color: DeskflowColors.glassBorderStrong.withValues(alpha: 0.72),
                width: 0.9,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  DeskflowColors.glassHighlight.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_tabs.length, (index) {
                final tab = _tabs[index];
                final isActive = index == currentIndex;

                return Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final showLabel = isActive &&
                          constraints.maxWidth >= 88 &&
                          screenWidth >= 360;

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(index),
                        child: Center(
                          child: AnimatedContainer(
                            duration: motion.durationFor(
                              DeskflowMotion.regularDuration,
                            ),
                            curve: motion.emphasizedCurve,
                            constraints: BoxConstraints(
                              maxWidth:
                                  constraints.maxWidth - DeskflowSpacing.xs,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 9,
                            ),
                            decoration: isActive
                                ? BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        DeskflowColors.glassHighlight
                                            .withValues(alpha: 0.08),
                                        Color.lerp(
                                              DeskflowColors.shellGlassSurfaceFocused,
                                              DeskflowColors.primarySolid,
                                              0.06,
                                            ) ??
                                            DeskflowColors.shellGlassSurfaceFocused,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      DeskflowRadius.pill,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.12),
                                        blurRadius: 12,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  )
                                : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
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
                                    backgroundColor:
                                        DeskflowColors.destructiveSolid,
                                    child: Icon(
                                      tab.icon,
                                      size: isActive ? 22 : 21,
                                      color: isActive
                                          ? DeskflowColors.textPrimary
                                          : DeskflowColors.textSecondary,
                                    ),
                                  )
                                else
                                  Icon(
                                    tab.icon,
                                    size: isActive ? 22 : 21,
                                    color: isActive
                                        ? DeskflowColors.textPrimary
                                        : DeskflowColors.textSecondary,
                                  ),
                                if (showLabel)
                                  Flexible(
                                    child: AnimatedSize(
                                      duration: motion.durationFor(
                                        DeskflowMotion.microDuration,
                                      ),
                                      curve: motion.standardCurve,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: DeskflowSpacing.sm,
                                        ),
                                        child: Text(
                                          tab.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          softWrap: false,
                                          style: DeskflowTypography.bodySmall
                                              .copyWith(
                                            color:
                                                DeskflowColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
