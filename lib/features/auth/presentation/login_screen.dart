import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/errors/deskflow_exception.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/glass_text_field.dart';
import 'package:deskflow/core/widgets/pill_button.dart';
import 'package:deskflow/features/auth/domain/auth_notifier.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/profile/domain/account_history_providers.dart';

final _log = AppLogger.getLogger('LoginScreen');

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final pendingEmail = ref.read(pendingLoginEmailProvider);
    _emailController = TextEditingController(text: pendingEmail ?? '');
    if (pendingEmail != null && pendingEmail.isNotEmpty) {
      _log.i('initState: pre-filled email=$pendingEmail');
      Future(() {
        ref.read(pendingLoginEmailProvider.notifier).state = null;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).clearSnackBars();

    final email = _emailController.text.trim();
    final success = await ref.read(authNotifierProvider.notifier).signIn(
          email: email,
          password: _passwordController.text,
        );

    if (!success || !mounted) return;

      _log.i('_handleLogin: saving email=$email to account history');
      try {
        await ref
            .read(recentEmailsNotifierProvider.notifier)
            .addEmail(email);
      } catch (e) {
        _log.d('_handleLogin: could not save email to history (non-critical): $e');
      }

      try {
        final refreshToken = ref.read(authRepositoryProvider).currentSession?.refreshToken;
        if (refreshToken != null) {
          _log.d('[FIX] _handleLogin: saving refresh token for $email');
          await ref
              .read(recentEmailsNotifierProvider.notifier)
              .saveRefreshToken(email, refreshToken);
        }
      } catch (e) {
        _log.d('[FIX] _handleLogin: could not save refresh token (non-critical): $e');
      }

      ref.read(addingAccountProvider.notifier).state = false;
      if (!mounted) return;
      context.go('/');
  }

  Future<void> _handleGoogleSignIn() async {
    ScaffoldMessenger.of(context).clearSnackBars();
    final success =
        await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    if (!success || !mounted) return;
    await _saveSessionAfterOAuth();
    ref.read(addingAccountProvider.notifier).state = false;
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _handleAppleSignIn() async {
    ScaffoldMessenger.of(context).clearSnackBars();
    final success =
        await ref.read(authNotifierProvider.notifier).signInWithApple();
    if (!success || !mounted) return;
    await _saveSessionAfterOAuth();
    ref.read(addingAccountProvider.notifier).state = false;
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _saveSessionAfterOAuth() async {
    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      final session = ref.read(authRepositoryProvider).currentSession;
      final email = user?.email;
      final refreshToken = session?.refreshToken;
      if (email != null && email.isNotEmpty) {
        _log.d('[FIX] _saveSessionAfterOAuth: saving for $email');
        await ref.read(recentEmailsNotifierProvider.notifier).addEmail(email);
        if (refreshToken != null) {
          await ref.read(recentEmailsNotifierProvider.notifier).saveRefreshToken(email, refreshToken);
        }
      }
    } catch (e) {
      _log.d('[FIX] _saveSessionAfterOAuth: non-critical error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    ref.listen<AsyncValue<void>>(authNotifierProvider, (_, next) {
      if (next.hasError) {
        final error = next.error;
        final message = error is DeskflowException
            ? error.message
            : 'Произошла ошибка';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: DeskflowColors.destructiveSolid,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DeskflowSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: DeskflowColors.glassSurface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: DeskflowColors.glassBorder,
                      width: 0.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.business_center_rounded,
                    size: 32,
                    color: DeskflowColors.primarySolid,
                  ),
                ),
                const SizedBox(height: DeskflowSpacing.lg),
                const Text('Войти в аккаунт', style: DeskflowTypography.h2),
                const SizedBox(height: DeskflowSpacing.xxl),

                GlassCard(
                  child: Column(
                    children: [
                      GlassTextField(
                        label: 'Email',
                        hint: 'example@mail.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: DeskflowSpacing.lg),
                      GlassTextField(
                        label: 'Пароль',
                        hint: '••••••••',
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: DeskflowColors.textTertiary,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(
                                () => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      const SizedBox(height: DeskflowSpacing.xl),
                      PillButton(
                        label: 'Войти',
                        expanded: true,
                        isLoading: isLoading,
                        onPressed: isLoading ? null : _handleLogin,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: DeskflowSpacing.xl),

                Row(
                  children: [
                    const Expanded(
                      child: Divider(color: DeskflowColors.glassBorder),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DeskflowSpacing.lg,
                      ),
                      child: Text(
                        'или',
                        style: DeskflowTypography.caption,
                      ),
                    ),
                    const Expanded(
                      child: Divider(color: DeskflowColors.glassBorder),
                    ),
                  ],
                ),

                const SizedBox(height: DeskflowSpacing.xl),

                PillButton.secondary(
                  label: 'Войти через Google',
                  icon: Icons.g_mobiledata_rounded,
                  expanded: true,
                  onPressed: isLoading ? null : _handleGoogleSignIn,
                ),
                const SizedBox(height: DeskflowSpacing.md),
                PillButton.secondary(
                  label: 'Войти через Apple',
                  icon: Icons.apple_rounded,
                  expanded: true,
                  onPressed: isLoading ? null : _handleAppleSignIn,
                ),

                const SizedBox(height: DeskflowSpacing.xxl),

                TextButton(
                  onPressed: () => context.push('/auth/register'),
                  child: Text(
                    'Нет аккаунта? Зарегистрироваться',
                    style: DeskflowTypography.bodySmall.copyWith(
                      color: DeskflowColors.primarySolid,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/auth/forgot-password'),
                  child: Text(
                    'Забыли пароль?',
                    style: DeskflowTypography.caption.copyWith(
                      color: DeskflowColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}
