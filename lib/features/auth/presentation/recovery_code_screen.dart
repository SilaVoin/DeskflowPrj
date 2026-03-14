import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/constants/app_constants.dart';
import 'package:deskflow/core/errors/deskflow_exception.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/pill_button.dart';
import 'package:deskflow/features/auth/domain/auth_notifier.dart';

final _log = AppLogger.getLogger('RecoveryCodeScreen');

class RecoveryCodeScreen extends ConsumerStatefulWidget {
  final String email;

  const RecoveryCodeScreen({super.key, required this.email});

  @override
  ConsumerState<RecoveryCodeScreen> createState() => _RecoveryCodeScreenState();
}

class _RecoveryCodeScreenState extends ConsumerState<RecoveryCodeScreen> {
  static const _codeLength = 8;

  final List<TextEditingController> _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_codeLength, (_) => FocusNode());

  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  String? _newPassword;
  bool _copied = false;

  String get _code => _controllers.map((c) => c.text).join();
  bool get _isCodeComplete => _code.length == _codeLength;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = AppConstants.emailResendCooldown);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldownSeconds = 0);
      } else {
        if (mounted) setState(() => _cooldownSeconds--);
      }
    });
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});

    if (_isCodeComplete) {
      _handleVerify();
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      setState(() {});
    }
  }

  void _handlePaste(String pastedText) {
    final digits = pastedText.replaceAll(RegExp(r'[^0-9]'), '');
    for (int i = 0; i < _codeLength && i < digits.length; i++) {
      _controllers[i].text = digits[i];
    }
    if (digits.length >= _codeLength) {
      _focusNodes[_codeLength - 1].requestFocus();
      setState(() {});
      _handleVerify();
    } else if (digits.isNotEmpty) {
      final nextIndex = digits.length.clamp(0, _codeLength - 1);
      _focusNodes[nextIndex].requestFocus();
      setState(() {});
    }
  }

  String _generatePassword() {
    const chars =
        'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<void> _handleVerify() async {
    if (!_isCodeComplete) return;

    _log.d('[FIX] Verifying recovery code for ${widget.email}');

    final verified =
        await ref.read(authNotifierProvider.notifier).verifyRecoveryOtp(
              email: widget.email,
              token: _code,
            );

    if (!verified || !mounted) return;

    _log.i('[FIX] Recovery OTP verified — generating new password');

    final password = _generatePassword();
    final updated =
        await ref.read(authNotifierProvider.notifier).updatePassword(password);

    if (updated && mounted) {
      _log.i('[FIX] New password set successfully — showing to user');
      setState(() => _newPassword = password);
    }
  }

  Future<void> _handleResend() async {
    if (widget.email.isEmpty) return;

    _log.d('[FIX] Resending recovery email to ${widget.email}');
    final success = await ref
        .read(authNotifierProvider.notifier)
        .resetPassword(widget.email);

    if (success && mounted) {
      _startCooldown();
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Код отправлен повторно'),
          backgroundColor: DeskflowColors.successSolid,
        ),
      );
    }
  }

  Future<void> _copyPassword() async {
    if (_newPassword == null) return;
    await Clipboard.setData(ClipboardData(text: _newPassword!));
    if (mounted) {
      setState(() => _copied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пароль скопирован'),
          backgroundColor: DeskflowColors.successSolid,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final canResend = _cooldownSeconds == 0 && !isLoading;

    ref.listen<AsyncValue<void>>(authNotifierProvider, (_, next) {
      if (next.hasError) {
        final error = next.error;
        final message = error is DeskflowException
            ? error.message
            : 'Неверный код. Попробуйте снова.';
        _log.w('[FIX] Error during recovery: $message');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: DeskflowColors.destructiveSolid,
          ),
        );
      }
    });

    final maskedEmail = _maskEmail(widget.email);

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      appBar: _newPassword == null
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              ),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DeskflowSpacing.xl),
          child: _newPassword != null
              ? _buildSuccessState()
              : _buildCodeEntryState(isLoading, canResend, maskedEmail),
        ),
      ),
    );
  }

  Widget _buildCodeEntryState(
      bool isLoading, bool canResend, String maskedEmail) {
    return Column(
      children: [
        const SizedBox(height: DeskflowSpacing.xl),

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
          child: const Icon(
            Icons.lock_reset_rounded,
            size: 36,
            color: DeskflowColors.primarySolid,
          ),
        ),
        const SizedBox(height: DeskflowSpacing.xl),
        const Text('Введите код', style: DeskflowTypography.h2),
        const SizedBox(height: DeskflowSpacing.sm),
        Text(
          'Мы отправили 8-значный код на\n$maskedEmail',
          style: DeskflowTypography.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DeskflowSpacing.xxl),

        GlassCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_codeLength, (i) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: i == 0 ? 0 : 6,
                        right: i == _codeLength - 1 ? 0 : 6,
                      ),
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (event) => _onKeyEvent(i, event),
                        child: TextFormField(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          enabled: !isLoading,
                          style: DeskflowTypography.h2.copyWith(
                            fontSize: 22,
                            letterSpacing: 0,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: DeskflowColors.glassSurface,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(DeskflowRadius.md),
                              borderSide: const BorderSide(
                                color: DeskflowColors.glassBorder,
                                width: 0.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(DeskflowRadius.md),
                              borderSide: const BorderSide(
                                color: DeskflowColors.glassBorder,
                                width: 0.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(DeskflowRadius.md),
                              borderSide: const BorderSide(
                                color: DeskflowColors.primarySolid,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            if (value.length > 1) {
                              _handlePaste(value);
                            } else {
                              _onDigitChanged(i, value);
                            }
                          },
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: DeskflowSpacing.xl),

              PillButton(
                label: 'Подтвердить',
                expanded: true,
                isLoading: isLoading,
                onPressed:
                    _isCodeComplete && !isLoading ? _handleVerify : null,
              ),
            ],
          ),
        ),

        const SizedBox(height: DeskflowSpacing.xl),

        TextButton(
          onPressed: canResend ? _handleResend : null,
          child: Text(
            canResend
                ? 'Отправить код повторно'
                : 'Повторить через $_cooldownSeconds сек.',
            style: DeskflowTypography.bodySmall.copyWith(
              color: canResend
                  ? DeskflowColors.primarySolid
                  : DeskflowColors.textTertiary,
            ),
          ),
        ),
        const SizedBox(height: DeskflowSpacing.sm),
        TextButton(
          onPressed: () => context.go('/auth/login'),
          child: Text(
            'Назад к входу',
            style: DeskflowTypography.bodySmall.copyWith(
              color: DeskflowColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Column(
      children: [
        const SizedBox(height: DeskflowSpacing.xxl),

        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: DeskflowColors.success,
            shape: BoxShape.circle,
            border: Border.all(
              color: DeskflowColors.glassBorder,
              width: 0.5,
            ),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 40,
            color: DeskflowColors.successSolid,
          ),
        ),
        const SizedBox(height: DeskflowSpacing.xl),
        const Text('Пароль обновлён', style: DeskflowTypography.h2),
        const SizedBox(height: DeskflowSpacing.sm),
        const Text(
          'Ваш новый пароль:',
          style: DeskflowTypography.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DeskflowSpacing.lg),

        GlassCard(
          child: Column(
            children: [
              SelectableText(
                _newPassword!,
                style: DeskflowTypography.h2.copyWith(
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                  fontSize: 24,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DeskflowSpacing.lg),

              PillButton.secondary(
                label: _copied ? 'Скопировано ✓' : 'Скопировать пароль',
                icon: _copied
                    ? Icons.check_rounded
                    : Icons.copy_rounded,
                expanded: true,
                onPressed: _copyPassword,
              ),
            ],
          ),
        ),

        const SizedBox(height: DeskflowSpacing.md),
        const Text(
          'Сохраните этот пароль — он показывается только один раз',
          style: DeskflowTypography.caption,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: DeskflowSpacing.xxl),
        PillButton(
          label: 'Войти с новым паролем',
          expanded: true,
          onPressed: () => context.go('/auth/login'),
        ),
      ],
    );
  }

  String _maskEmail(String email) {
    if (email.isEmpty || !email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 3) return '${name[0]}***@$domain';
    return '${name.substring(0, 3)}***@$domain';
  }
}
