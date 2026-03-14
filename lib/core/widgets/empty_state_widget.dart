import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DeskflowSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: DeskflowColors.glassSurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: DeskflowColors.glassBorder,
                  width: 0.5,
                ),
              ),
              child: Icon(
                icon,
                size: 32,
                color: DeskflowColors.textTertiary,
              ),
            ),
            const SizedBox(height: DeskflowSpacing.lg),
            Text(
              title,
              style: DeskflowTypography.h3,
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: DeskflowSpacing.sm),
              Text(
                description!,
                style: DeskflowTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: DeskflowSpacing.xl),
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: DeskflowTypography.button.copyWith(
                    color: DeskflowColors.primarySolid,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
