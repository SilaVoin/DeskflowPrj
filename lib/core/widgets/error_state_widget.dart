import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

/// Full-screen error state with retry.
///
/// ```dart
/// ErrorStateWidget(
///   message: 'Ошибка загрузки данных',
///   onRetry: () => ref.invalidate(ordersProvider),
/// )
/// ```
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

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
                color: DeskflowColors.destructive.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: DeskflowColors.destructiveSolid,
              ),
            ),
            const SizedBox(height: DeskflowSpacing.lg),
            Text(
              message,
              style: DeskflowTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: DeskflowSpacing.xl),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: DeskflowColors.primarySolid,
                ),
                label: Text(
                  'Повторить',
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
