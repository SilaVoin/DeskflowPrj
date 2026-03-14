import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

class GlassFloatingActionButton extends StatelessWidget {
  const GlassFloatingActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.heroTag,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Object? heroTag;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: DeskflowColors.shellGlassSurfaceFocused,
            border: Border.all(
              color: DeskflowColors.glassBorderStrong.withValues(alpha: 0.72),
              width: 0.9,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                DeskflowColors.glassHighlight.withValues(alpha: 0.08),
                DeskflowColors.shellGlassSurfaceFocused,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: FloatingActionButton(
            heroTag: heroTag,
            tooltip: tooltip,
            backgroundColor: Colors.transparent,
            foregroundColor: DeskflowColors.textPrimary,
            elevation: 0,
            focusElevation: 0,
            hoverElevation: 0,
            highlightElevation: 0,
            disabledElevation: 0,
            onPressed: onPressed,
            shape: const CircleBorder(),
            child: Icon(icon),
          ),
        ),
      ),
    );
  }
}
