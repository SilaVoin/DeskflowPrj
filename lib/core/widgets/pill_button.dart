import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

/// Pill-shaped (capsule / stadium) button with Liquid Glass styling.
///
/// Variants:
/// - **primary** — blue glass fill (default)
/// - **secondary** — neutral glass fill
/// - **destructive** — red glass fill
///
/// ```dart
/// PillButton(
///   label: 'Сохранить',
///   onPressed: () {},
/// )
///
/// PillButton.secondary(
///   label: 'Отмена',
///   onPressed: () {},
/// )
/// ```
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.color,
    this.textColor,
    this.expanded = false,
    this.height = 48,
  });

  /// Primary (blue) variant — default constructor.
  factory PillButton.primary({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    bool expanded = false,
  }) {
    return PillButton(
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      color: DeskflowColors.primary,
      expanded: expanded,
    );
  }

  /// Secondary (neutral glass) variant.
  factory PillButton.secondary({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    bool expanded = false,
  }) {
    return PillButton(
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      color: DeskflowColors.glassSurface,
      expanded: expanded,
    );
  }

  /// Destructive (red) variant.
  factory PillButton.destructive({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    bool expanded = false,
  }) {
    return PillButton(
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      color: DeskflowColors.destructive,
      expanded: expanded,
    );
  }

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? color;
  final Color? textColor;
  final bool expanded;
  final double height;

  bool get _isDisabled => onPressed == null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? DeskflowColors.primary;
    final effectiveBg =
        _isDisabled ? bgColor.withValues(alpha: 0.3) : bgColor;
    final effectiveTextColor = _isDisabled
        ? DeskflowColors.textDisabled
        : (textColor ?? DeskflowColors.textPrimary);

    final buttonChild = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: effectiveTextColor,
            ),
          ),
          const SizedBox(width: DeskflowSpacing.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: effectiveTextColor),
          const SizedBox(width: DeskflowSpacing.sm),
        ],
        Text(
          label,
          style: DeskflowTypography.button.copyWith(color: effectiveTextColor),
        ),
      ],
    );

    return SizedBox(
      height: height,
      width: expanded ? double.infinity : null,
      child: MaterialButton(
        onPressed: isLoading ? null : onPressed,
        color: effectiveBg,
        disabledColor: effectiveBg,
        elevation: 0,
        highlightElevation: 0,
        shape: const StadiumBorder(
          side: BorderSide(
            color: DeskflowColors.glassBorder,
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: DeskflowSpacing.xl,
          vertical: DeskflowSpacing.md,
        ),
        child: buttonChild,
      ),
    );
  }
}
