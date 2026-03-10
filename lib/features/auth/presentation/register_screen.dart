import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:deskflow/core/errors/deskflow_exception.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/glass_text_field.dart';
import 'package:deskflow/core/widgets/pill_button.dart';
import 'package:deskflow/features/auth/domain/auth_notifier.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/profile/domain/account_history_providers.dart';
import 'package:deskflow/features/profile/domain/profile_providers.dart';

final _log = AppLogger.getLogger('RegisterScreen');

/// Registration screen — create new account.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  Uint8List? _avatarBytes;
  String _avatarExt = 'jpeg';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final ext = picked.path.split('.').last.toLowerCase();
    setState(() {
      _avatarBytes = bytes;
      _avatarExt = (ext == 'png' || ext == 'webp') ? ext : 'jpeg';
    });
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пароли не совпадают'),
          backgroundColor: DeskflowColors.destructiveSolid,
        ),
      );
      return;
    }

    final success = await ref.read(authNotifierProvider.notifier).register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (success && mounted) {
      // Attempt avatar upload if photo was picked
      if (_avatarBytes != null) {
        try {
          final repo = ref.read(profileRepositoryProvider);
          final userId = ref.read(currentUserProvider)?.id;
          if (userId != null) {
            final avatarUrl = await repo.uploadAvatar(
              userId: userId,
              bytes: _avatarBytes!,
              fileExt: _avatarExt,
            );
            await repo.updateProfile(userId: userId, avatarUrl: avatarUrl);
            _log.i('Avatar uploaded during registration');
          }
        } catch (e) {
          _log.e('Avatar upload after registration failed: $e');
        }
      }

      // Reset addingAccount flag if was set
      ref.read(addingAccountProvider.notifier).state = false;

      final email = Uri.encodeComponent(_emailController.text.trim());
      _log.i('[FIX] Registration successful — navigating to email verification '
          '(email=$email)');
      if (mounted) context.go('/auth/verify-email?email=$email');
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            final wasAddingAccount = ref.read(addingAccountProvider);
            ref.read(addingAccountProvider.notifier).state = false;
            if (wasAddingAccount) {
              context.go('/profile');
            } else {
              context.go('/auth/login');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DeskflowSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Avatar picker
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Container(
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
                    child: _avatarBytes != null
                        ? ClipOval(
                            child: Image.memory(
                              _avatarBytes!,
                              fit: BoxFit.cover,
                              width: 80,
                              height: 80,
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt_rounded,
                                size: 24,
                                color: DeskflowColors.textTertiary,
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: DeskflowSpacing.sm),
                Text(
                  'Добавить фото (необязательно)',
                  style: DeskflowTypography.caption,
                ),
                const SizedBox(height: DeskflowSpacing.lg),
                const Text('Создать аккаунт', style: DeskflowTypography.h2),
                const SizedBox(height: DeskflowSpacing.xxl),

                GlassCard(
                  child: Column(
                    children: [
                      GlassTextField(
                        label: 'Имя',
                        hint: 'Ваше имя',
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Введите имя';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: DeskflowSpacing.lg),
                      GlassTextField(
                        label: 'Email',
                        hint: 'example@mail.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || !value.contains('@')) {
                            return 'Введите корректный email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: DeskflowSpacing.lg),
                      GlassTextField(
                        label: 'Пароль',
                        hint: 'Минимум 8 символов',
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.length < 8) {
                            return 'Минимум 8 символов';
                          }
                          return null;
                        },
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
                      const SizedBox(height: DeskflowSpacing.lg),
                      GlassTextField(
                        label: 'Подтвердите пароль',
                        hint: '••••••••',
                        controller: _confirmPasswordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Пароли не совпадают';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: DeskflowSpacing.xl),
                      PillButton(
                        label: 'Создать аккаунт',
                        expanded: true,
                        isLoading: isLoading,
                        onPressed: isLoading ? null : _handleRegister,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: DeskflowSpacing.xl),
                TextButton(
                  onPressed: () {
                    final wasAdding = ref.read(addingAccountProvider);
                    ref.read(addingAccountProvider.notifier).state = false;
                    if (wasAdding) {
                      context.go('/profile');
                    } else {
                      context.go('/auth/login');
                    }
                  },
                  child: Text(
                    ref.watch(addingAccountProvider)
                        ? 'Назад в профиль'
                        : 'Уже есть аккаунт? Войти',
                    style: DeskflowTypography.bodySmall.copyWith(
                      color: DeskflowColors.primarySolid,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
