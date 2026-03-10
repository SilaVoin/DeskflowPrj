import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

/// A translucent glass-morphism card with blur, specular highlight,
/// and continuous curvature (squircle) corners.
///
/// Implements the Liquid Glass design system from the Deskflow spec.
///
/// ```dart
/// GlassCard(
///   child: Text('Hello'),
///   onTap: () => print('tapped'),
/// )
/// ```
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.borderColor,
    this.blurSigma = 24,
    this.elevated = false,
  });

  /// Card content.
  final Widget child;

  /// Tap callback. When non-null the card shows an InkWell ripple.
  final VoidCallback? onTap;

  /// Long-press callback.
  final VoidCallback? onLongPress;

  /// Inner padding. Defaults to `EdgeInsets.all(16)`.
  final EdgeInsetsGeometry? padding;

  /// Outer margin.
  final EdgeInsetsGeometry? margin;

  /// Corner radius. Defaults to [DeskflowRadius.lg].
  final double? borderRadius;

  /// Override surface color.
  final Color? color;

  /// Override border color.
  final Color? borderColor;

  /// Blur sigma for the backdrop filter. Defaults to 24.
  final double blurSigma;

  /// Use elevated surface (modals, sheets).
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? DeskflowRadius.lg;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    final surfaceColor = color ??
        (elevated
            ? DeskflowColors.glassSurfaceElevated
            : DeskflowColors.glassSurface);

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurSigma,
            sigmaY: blurSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: borderColor ?? DeskflowColors.glassBorder,
                width: 0.5,
              ),
              // Specular highlight — top edge gradient.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  DeskflowColors.glassHighlight.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4],
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                customBorder: shape,
                splashColor: DeskflowColors.primary.withValues(alpha: 0.1),
                highlightColor: Colors.transparent,
                child: Padding(
                  padding:
                      padding ?? const EdgeInsets.all(DeskflowSpacing.lg),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
