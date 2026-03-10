import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

/// Generic placeholder screen for features not yet implemented.
///
/// Shows the screen title and a "Coming soon" message.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.icon = Icons.construction_rounded,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DeskflowColors.background,
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: DeskflowColors.textTertiary),
            const SizedBox(height: DeskflowSpacing.lg),
            Text(title, style: DeskflowTypography.h2),
            const SizedBox(height: DeskflowSpacing.sm),
            const Text(
              'Скоро будет реализовано',
              style: DeskflowTypography.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
