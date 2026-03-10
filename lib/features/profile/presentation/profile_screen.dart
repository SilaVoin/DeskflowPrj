import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/status_pill_badge.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';
import 'package:deskflow/features/profile/domain/account_history_providers.dart';
import 'package:deskflow/features/profile/domain/profile_providers.dart';

final _log = AppLogger.getLogger('ProfileScreen');

/// Profile screen — Tab 3.
///
/// Shows real user info with profile photo, org settings (owner-gated),
/// admin panel access, and logout.
/// Reads profile data from `profiles` table via UserProfileNotifier,
/// auth data from Supabase auth + org providers.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploadingAvatar = false;
  final _imagePicker = ImagePicker();

  Future<void> _showEditNameDialog(String currentName) async {
    _log.d('_showEditNameDialog: currentName=$currentName');
    final controller = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DeskflowColors.modalSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DeskflowRadius.lg),
        ),
        title: const Text('Изменить имя', style: DeskflowTypography.h2),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Имя',
              hintText: 'Введите ваше имя',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Имя не может быть пустым';
              }
              if (value.trim().length > 200) {
                return 'Имя слишком длинное (макс. 200 символов)';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (newName == null || newName == currentName) {
      _log.d('_showEditNameDialog: cancelled or unchanged');
      return;
    }

    _log.d('_showEditNameDialog: saving new name=$newName');
    try {
      await ref
          .read(userProfileNotifierProvider.notifier)
          .updateDisplayName(newName);
      _log.i('_showEditNameDialog: name updated successfully');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Имя обновлено')),
        );
      }
    } catch (e, st) {
      _log.e('_showEditNameDialog: failed', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.toString()}')),
        );
      }
    }
  }

  /// Navigate to login/register for adding another account.
  ///
  /// IMPORTANT: Does NOT call signOut() — because signOut(scope: local)
  /// revokes the current refresh token on the Supabase server, making
  /// it impossible to switch back to this account later.
  /// Instead, sets [addingAccountProvider] flag so the router allows
  /// auth routes while still logged in. The new signInWithPassword()
  /// call will replace the current session atomically.
  Future<void> _signOutAndNavigate(String route) async {
    _log.d('_signOutAndNavigate: route=$route');
    try {
      // Save current session's refresh token AND email to recent list
      // (it stays valid on the server because we don't call signOut)
      final currentSession = ref.read(authRepositoryProvider).currentSession;
      final currentEmail = ref.read(authRepositoryProvider).currentUser?.email;
      if (currentEmail != null) {
        _log.d('[FIX] _signOutAndNavigate: saving email + token for $currentEmail');
        // Ensure current email is in recent list so it appears in account switcher
        await ref.read(recentEmailsNotifierProvider.notifier).addEmail(currentEmail);
        if (currentSession?.refreshToken != null) {
          await ref.read(recentEmailsNotifierProvider.notifier).saveRefreshToken(
                currentEmail,
                currentSession!.refreshToken!,
              );
        }
      }

      // Set flag so router allows auth routes while logged in
      ref.read(addingAccountProvider.notifier).state = true;
      ref.read(currentOrgIdProvider.notifier).clear();

      _log.i('_signOutAndNavigate: navigating to $route (no sign-out)');
      if (mounted) {
        context.go(route);
      }
    } catch (e, st) {
      _log.e('_signOutAndNavigate: failed', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка выхода: ${e.toString()}')),
        );
      }
    }
  }

  /// Genuine sign out — revokes the session and navigates to login.
  /// Used by the "Выйти" button (not for account switching).
  Future<void> _realSignOut() async {
    _log.d('_realSignOut: performing genuine sign out');
    try {
      ref.read(currentOrgIdProvider.notifier).clear();
      await ref.read(authRepositoryProvider).signOut();
      _log.i('_realSignOut: signed out, navigating to /auth/login');
      if (mounted) {
        context.go('/auth/login');
      }
    } catch (e, st) {
      _log.e('_realSignOut: failed', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка выхода: ${e.toString()}')),
        );
      }
    }
  }

  void _confirmSignOut({
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DeskflowColors.modalSurface,
        title: Text(title, style: DeskflowTypography.h3),
        content: Text(message, style: DeskflowTypography.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Назад',
              style: DeskflowTypography.body.copyWith(
                color: DeskflowColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm();
            },
            child: Text(
              'Продолжить',
              style: DeskflowTypography.body.copyWith(
                color: DeskflowColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAccountSwitcher() {
    final recentEmails = ref.read(recentEmailsNotifierProvider);
    _log.d('_showAccountSwitcher: recentEmails=$recentEmails');

    // Filter out the current user's email — no point switching to yourself
    final currentEmail = ref.read(authRepositoryProvider).currentUser?.email?.toLowerCase();
    final otherEmails = recentEmails
        .where((e) => e.toLowerCase() != currentEmail)
        .toList();

    if (otherEmails.isEmpty) {
      // [FIX] Don't sign out immediately — show bottom sheet with "Add account" option
      _log.d('[FIX] _showAccountSwitcher: no other emails, showing add-account sheet');
      showModalBottomSheet(
        context: context,
        backgroundColor: DeskflowColors.modalSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DeskflowRadius.lg),
          ),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DeskflowSpacing.lg,
                vertical: DeskflowSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Сменить аккаунт', style: DeskflowTypography.h3),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: DeskflowColors.textSecondary,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: DeskflowSpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: DeskflowSpacing.md),
                    child: Text(
                      'Нет других аккаунтов',
                      style: DeskflowTypography.bodySmall.copyWith(
                        color: DeskflowColors.textTertiary,
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: DeskflowColors.glassSurface,
                      child: Icon(
                        Icons.add_rounded,
                        color: DeskflowColors.primary,
                      ),
                    ),
                    title: Text('Добавить аккаунт', style: DeskflowTypography.body),
                    onTap: () {
                      _log.i('[FIX] _showAccountSwitcher: add account chosen');
                      Navigator.of(ctx).pop();
                      _signOutAndNavigate('/auth/login');
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: DeskflowColors.modalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DeskflowRadius.lg),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DeskflowSpacing.lg,
              vertical: DeskflowSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Сменить аккаунт', style: DeskflowTypography.h3),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: DeskflowColors.textSecondary,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: DeskflowSpacing.md),
                ...otherEmails.map(
                  (email) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: DeskflowColors.glassSurface,
                      child: Text(
                        email[0].toUpperCase(),
                        style: DeskflowTypography.body.copyWith(
                          color: DeskflowColors.primary,
                        ),
                      ),
                    ),
                    title: Text(email, style: DeskflowTypography.body),
                    onTap: () {
                      _log.i('_showAccountSwitcher: selected email=$email');
                      Navigator.of(ctx).pop();
                      _switchToAccount(email);
                    },
                  ),
                ),
                const SizedBox(height: DeskflowSpacing.md),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: DeskflowColors.glassSurface,
                    child: Icon(
                      Icons.add_rounded,
                      color: DeskflowColors.primary,
                    ),
                  ),
                  title: Text('Другой аккаунт', style: DeskflowTypography.body),
                  onTap: () {
                    _log.i('_showAccountSwitcher: other account chosen');
                    Navigator.of(ctx).pop();
                    _signOutAndNavigate('/auth/login');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// [FIX] Try to restore another account's session via stored refresh token.
  /// Falls back to login page if the token is missing or expired.
  ///
  /// Captures all provider dependencies BEFORE signOut to avoid using
  /// a disposed WidgetRef after the GoRouter redirect removes this widget.
  /// Uses [isSwitchingAccountProvider] to suppress router redirects
  /// during the signOut→restoreSession gap.
  /// Switch to another account using its stored refresh token.
  ///
  /// IMPORTANT: Does NOT call signOut() — because signOut(scope: local)
  /// revokes the current refresh token on the Supabase server.
  /// Instead, calls setSession(targetRT) directly, which atomically
  /// replaces the current session without revoking any tokens.
  Future<void> _switchToAccount(String email) async {
    _log.d('[FIX] _switchToAccount: email=$email');

    // 1. Check for stored refresh token
    final refreshToken = ref
        .read(recentEmailsNotifierProvider.notifier)
        .getRefreshToken(email);

    if (refreshToken == null) {
      _log.d('[FIX] _switchToAccount: no stored token, falling back to login');
      ref.read(pendingLoginEmailProvider.notifier).state = email;
      _signOutAndNavigate('/auth/login');
      return;
    }

    // Capture dependencies BEFORE any state changes
    final authRepo = ref.read(authRepositoryProvider);
    final emailsNotifier = ref.read(recentEmailsNotifierProvider.notifier);

    // Suppress router redirects during the switch
    ref.read(isSwitchingAccountProvider.notifier).state = true;
    _log.d('[FIX] _switchToAccount: switching flag ON');

    try {
      // 2. Save current session's refresh token (NO signOut = token stays valid)
      final currentSession = authRepo.currentSession;
      final currentEmail = authRepo.currentUser?.email;
      if (currentSession?.refreshToken != null && currentEmail != null) {
        _log.d('[FIX] _switchToAccount: saving current session for $currentEmail');
        await emailsNotifier.saveRefreshToken(
          currentEmail,
          currentSession!.refreshToken!,
        );
      }

      // 3. Clear org state for the new user
      ref.read(currentOrgIdProvider.notifier).clear();

      // 4. Restore target session directly — NO signOut needed!
      // setSession replaces the current session atomically.
      // The old session's refresh token is NOT revoked on the server.
      _log.d('[FIX] _switchToAccount: restoring target session (no signOut)');
      final response = await authRepo.restoreSession(refreshToken);
      final newRefreshToken = response.session?.refreshToken;
      _log.i('[FIX] _switchToAccount: session restored for $email');

      // Save the rotated refresh token
      if (newRefreshToken != null) {
        await emailsNotifier.saveRefreshToken(email, newRefreshToken);
      }

      // Clear switching flag BEFORE navigation so redirect can work
      ref.read(isSwitchingAccountProvider.notifier).state = false;
      _log.d('[FIX] _switchToAccount: switching flag OFF, navigating to splash');

      // Navigate to splash for full flow: splash → org-select → orders
      if (mounted) {
        context.go('/');
      }
      return;
    } catch (e, st) {
      _log.e('[FIX] _switchToAccount: restore failed, trying refreshSession fallback',
          error: e, stackTrace: st);

      // [FIX] Retry: if setSession failed (token revoked/rotated),
      // try refreshSession as fallback before giving up.
      try {
        final retryResponse = await authRepo.refreshCurrentSession();
        final retryToken = retryResponse.session?.refreshToken;
        final retryEmail = retryResponse.session?.user.email;
        if (retryToken != null && retryEmail != null) {
          _log.i('[FIX] _switchToAccount: refreshSession succeeded for $retryEmail');
          await emailsNotifier.saveRefreshToken(retryEmail, retryToken);
          ref.read(isSwitchingAccountProvider.notifier).state = false;
          if (mounted) context.go('/');
          return;
        }
      } catch (retryError) {
        _log.e('[FIX] _switchToAccount: refreshSession also failed',
            error: retryError);
      }

      // Both attempts failed — fall back to login
      try {
        ref.read(pendingLoginEmailProvider.notifier).state = email;
        ref.read(isSwitchingAccountProvider.notifier).state = false;
        ref.read(currentOrgIdProvider.notifier).clear();
        await authRepo.signOut();
      } catch (_) {}
    } finally {
      try {
        if (ref.read(isSwitchingAccountProvider)) {
          ref.read(isSwitchingAccountProvider.notifier).state = false;
          _log.d('[FIX] _switchToAccount: switching flag OFF (finally)');
        }
      } catch (_) {}
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    _log.d('_pickAndUploadAvatar: opening gallery');
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (picked == null) {
        _log.d('_pickAndUploadAvatar: user cancelled');
        return;
      }

      _log.d('_pickAndUploadAvatar: picked file=${picked.name}, path=${picked.path}');

      // Determine file extension
      final ext = picked.name.split('.').last.toLowerCase();
      final allowedExts = ['jpg', 'jpeg', 'png', 'webp'];
      final fileExt = allowedExts.contains(ext) ? ext : 'jpg';
      _log.d('_pickAndUploadAvatar: fileExt=$fileExt');

      setState(() => _isUploadingAvatar = true);

      final bytes = await picked.readAsBytes();
      _log.d('_pickAndUploadAvatar: read ${bytes.length} bytes, uploading...');

      await ref.read(userProfileNotifierProvider.notifier).updateAvatar(
            bytes,
            fileExt,
          );

      _log.i('_pickAndUploadAvatar: upload complete');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фото профиля обновлено')),
        );
      }
    } catch (e, st) {
      _log.e('_pickAndUploadAvatar: failed', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final orgs = ref.watch(userOrganizationsProvider);
    final orgId = ref.watch(currentOrgIdProvider);
    final isOwner = ref.watch(isOwnerProvider);
    final isOwnerOrAdmin = ref.watch(isOwnerOrAdminProvider);
    final currentRole = ref.watch(currentUserRoleProvider).valueOrNull;

    // ── Profile data from profiles table ──
    final profileAsync = ref.watch(userProfileNotifierProvider);
    final profileData = profileAsync.valueOrNull;

    // Use profile name from DB; fall back to auth metadata
    final email = user?.email ?? '';
    final meta = user?.userMetadata;
    final metaName =
        (meta?['full_name'] as String?) ?? (meta?['name'] as String?) ?? '';
    final displayName = (profileData?.fullName?.isNotEmpty == true)
        ? profileData!.fullName!
        : metaName;
    final avatarUrl = profileData?.avatarUrl;
    final initials = _buildInitials(displayName, email);

    _log.d('build: displayName=$displayName, avatarUrl=${avatarUrl != null ? 'present' : 'null'}');

    // Find current org name
    final currentOrg = orgs.valueOrNull
        ?.cast<dynamic>()
        .where((o) => o.id == orgId)
        .firstOrNull;
    final orgName = currentOrg?.name ?? 'Организация';

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            DeskflowSpacing.lg,
            DeskflowSpacing.xl,
            DeskflowSpacing.lg,
            104 + MediaQuery.of(context).padding.bottom, // nav bar + system insets
          ),
          child: Column(
            children: [
              // ── Avatar + Info ──
              GestureDetector(
                onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: DeskflowColors.glassSurface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: DeskflowColors.glassBorder,
                          width: 0.5,
                        ),
                      ),
                      child: ClipOval(
                        child: _isUploadingAvatar
                            ? const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: DeskflowColors.primary,
                                  ),
                                ),
                              )
                            : avatarUrl != null && avatarUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: avatarUrl,
                                    fit: BoxFit.cover,
                                    width: 80,
                                    height: 80,
                                    placeholder: (_, _) => Center(
                                      child: Text(
                                        initials,
                                        style: DeskflowTypography.h2,
                                      ),
                                    ),
                                    errorWidget: (_, _, _) => Center(
                                      child: Text(
                                        initials,
                                        style: DeskflowTypography.h2,
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      initials,
                                      style: DeskflowTypography.h2,
                                    ),
                                  ),
                      ),
                    ),
                    // Camera badge
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: DeskflowColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: DeskflowColors.background,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DeskflowSpacing.md),
              // ── Display name from profiles table (tappable to edit) ──
              GestureDetector(
                onTap: () => _showEditNameDialog(displayName),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        displayName.isNotEmpty ? displayName : 'Добавить имя',
                        style: displayName.isNotEmpty
                            ? DeskflowTypography.h2
                            : DeskflowTypography.h2.copyWith(
                                color: DeskflowColors.textTertiary,
                              ),
                      ),
                    ),
                    const SizedBox(width: DeskflowSpacing.xs),
                    Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: DeskflowColors.textTertiary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DeskflowSpacing.xs),
              Text(
                email,
                style: DeskflowTypography.bodySmall,
              ),
              const SizedBox(height: DeskflowSpacing.sm),
              StatusPillBadge(
                label: currentRole?.label ?? 'Участник',
                color: isOwner
                    ? DeskflowColors.successSolid
                    : isOwnerOrAdmin
                        ? DeskflowColors.warningSolid
                        : DeskflowColors.primary,
              ),

              const SizedBox(height: DeskflowSpacing.xxl),

              // ── Organization section ──
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Организация',
                      style: DeskflowTypography.caption,
                    ),
                    const SizedBox(height: DeskflowSpacing.sm),
                    Text(
                      orgName,
                      style: DeskflowTypography.h3,
                    ),
                    const SizedBox(height: DeskflowSpacing.lg),
                    _SettingsItem(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Сменить организацию',
                      onTap: () => context.push('/org/select'),
                    ),
                    if (isOwnerOrAdmin)
                      _SettingsItem(
                        icon: Icons.settings_rounded,
                        label: 'Настройки организации',
                        onTap: () => context.push('/profile/org-settings'),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: DeskflowSpacing.lg),

              // ── Admin section (Owner or Admin) ──
              if (isOwnerOrAdmin) ...[
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Админ-панель',
                        style: DeskflowTypography.caption,
                      ),
                      const SizedBox(height: DeskflowSpacing.sm),
                      _SettingsItem(
                        icon: Icons.people_rounded,
                        label: 'Управление пользователями',
                        onTap: () => context.push('/admin/users'),
                      ),
                      _SettingsItem(
                        icon: Icons.linear_scale_rounded,
                        label: 'Настройка статусов',
                        onTap: () => context.push('/admin/pipeline'),
                      ),
                      _SettingsItem(
                        icon: Icons.inventory_2_rounded,
                        label: 'Управление каталогом',
                        onTap: () => context.push('/admin/catalog'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DeskflowSpacing.lg),
              ],

              // ── Settings section ──
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Настройки',
                      style: DeskflowTypography.caption,
                    ),
                    const SizedBox(height: DeskflowSpacing.sm),
                    _SettingsItem(
                      icon: Icons.notifications_rounded,
                      label: 'Уведомления',
                      onTap: () => context.push('/profile/notifications'),
                    ),
                    _SettingsItem(
                      icon: Icons.info_outline_rounded,
                      label: 'О приложении',
                      onTap: () => _showAboutDialog(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: DeskflowSpacing.lg),

              // ── Account section ──
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Аккаунт',
                      style: DeskflowTypography.caption,
                    ),
                    const SizedBox(height: DeskflowSpacing.sm),
                    _SettingsItem(
                      icon: Icons.person_add_rounded,
                      label: 'Добавить аккаунт',
                      onTap: () {
                        _log.i('[FIX] Add account pressed — sign out and navigate to login');
                        _signOutAndNavigate('/auth/login');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Сменить аккаунт',
                      onTap: () {
                        _log.i('Switch account pressed — showing account picker');
                        _showAccountSwitcher();
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.logout_rounded,
                      label: 'Выйти',
                      onTap: () => _confirmSignOut(
                        title: 'Выйти из аккаунта',
                        message: 'Вы уверены, что хотите выйти?',
                        onConfirm: () {
                          _log.i('Logout confirmed — signing out');
                          _realSignOut();
                        },
                      ),
                      isDestructive: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildInitials(String fullName, String email) {
    if (fullName.isNotEmpty) {
      final parts = fullName.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return fullName[0].toUpperCase();
    }
    if (email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return '?';
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DeskflowColors.modalSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DeskflowRadius.lg),
        ),
        title: const Text('Deskflow', style: DeskflowTypography.h2),
        content: Text(
          'CRM для управления заказами, клиентами и каталогом товаров.\n\n'
          'Версия 1.0.0',
          style: DeskflowTypography.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? DeskflowColors.destructiveSolid
        : DeskflowColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DeskflowRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DeskflowSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: DeskflowSpacing.md),
            Expanded(
              child: Text(
                label,
                style: isDestructive
                    ? DeskflowTypography.body.copyWith(
                        color: DeskflowColors.destructiveSolid,
                      )
                    : DeskflowTypography.body,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: DeskflowColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
