import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.leading,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  final Widget? leading;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bgColor = selected
        ? (color ?? DeskflowColors.primary.withValues(alpha: 0.3))
        : DeskflowColors.shellGlassSurface;
    final textColor = selected
        ? DeskflowColors.textPrimary
        : DeskflowColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: DeskflowSpacing.md,
          vertical: DeskflowSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(DeskflowRadius.pill),
          border: Border.all(
            color: selected
                ? (color ?? DeskflowColors.primarySolid).withValues(alpha: 0.4)
                : DeskflowColors.glassBorderStrong.withValues(alpha: 0.68),
            width: 0.75,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: DeskflowSpacing.xs),
            ],
            Text(
              label,
              style: DeskflowTypography.bodySmall.copyWith(color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}
