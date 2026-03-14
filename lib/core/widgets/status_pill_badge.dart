import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

class StatusPillBadge extends StatelessWidget {
  const StatusPillBadge({
    super.key,
    required this.label,
    this.color,
  });

  final String label;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? DeskflowColors.primarySolid;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DeskflowSpacing.sm + 2,
        vertical: DeskflowSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(DeskflowRadius.pill),
        border: Border.all(
          color: tint.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: DeskflowTypography.badge.copyWith(color: tint),
      ),
    );
  }
}
