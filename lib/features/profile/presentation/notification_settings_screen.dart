import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/features/profile/domain/profile_providers.dart';

/// Notification preferences screen.
///
/// Persists settings to Supabase `user_preferences` table per user+org.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(notificationSettingsNotifierProvider);

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      appBar: AppBar(
        title: const Text('Уведомления'),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Ошибка загрузки: $e',
            style: DeskflowTypography.body.copyWith(
              color: DeskflowColors.destructiveSolid,
            ),
          ),
        ),
        data: (settings) => SingleChildScrollView(
          padding: const EdgeInsets.all(DeskflowSpacing.lg),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Настройки уведомлений',
                  style: DeskflowTypography.caption,
                ),
                const SizedBox(height: DeskflowSpacing.md),

                _NotificationToggle(
                  title: 'Новые заказы',
                  subtitle: 'Уведомлять о новых заказах',
                  icon: Icons.add_shopping_cart_rounded,
                  value: settings.notifyNewOrders,
                  onChanged: (v) => ref
                      .read(notificationSettingsNotifierProvider.notifier)
                      .updateSetting(notifyNewOrders: v),
                ),
                const Divider(
                  color: DeskflowColors.glassBorder,
                  height: 1,
                ),
                _NotificationToggle(
                  title: 'Изменения статуса',
                  subtitle: 'Уведомлять при смене статуса заказа',
                  icon: Icons.swap_horiz_rounded,
                  value: settings.notifyStatusChanges,
                  onChanged: (v) => ref
                      .read(notificationSettingsNotifierProvider.notifier)
                      .updateSetting(notifyStatusChanges: v),
                ),
                const Divider(
                  color: DeskflowColors.glassBorder,
                  height: 1,
                ),
                _NotificationToggle(
                  title: 'Сообщения в чате',
                  subtitle: 'Уведомлять о новых сообщениях',
                  icon: Icons.chat_rounded,
                  value: settings.notifyChatMessages,
                  onChanged: (v) => ref
                      .read(notificationSettingsNotifierProvider.notifier)
                      .updateSetting(notifyChatMessages: v),
                ),
                const Divider(
                  color: DeskflowColors.glassBorder,
                  height: 1,
                ),
                _NotificationToggle(
                  title: 'Звук уведомлений',
                  subtitle: 'Воспроизводить звук',
                  icon: Icons.volume_up_rounded,
                  value: settings.notifySound,
                  onChanged: (v) => ref
                      .read(notificationSettingsNotifierProvider.notifier)
                      .updateSetting(notifySound: v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationToggle({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: DeskflowColors.textSecondary, size: 22),
      title: Text(title, style: DeskflowTypography.body),
      subtitle: Text(subtitle, style: DeskflowTypography.caption),
      value: value,
      onChanged: onChanged,
      activeThumbColor: DeskflowColors.primarySolid,
      contentPadding: const EdgeInsets.symmetric(
        vertical: DeskflowSpacing.xs,
      ),
    );
  }
}
