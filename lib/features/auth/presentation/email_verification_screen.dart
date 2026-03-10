import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/constants/app_constants.dart';
import 'package:deskflow/core/errors/deskflow_exception.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/pill_button.dart';
import 'package:deskflow/features/auth/domain/auth_notifier.dart';

/// Email verification screen — user enters 6-digit OTP code.
class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  static const _codeLength = 8;

  final List<TextEditingController> _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_codeLength, (_) => FocusNode());

  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

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
      // Move to next field
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {}); // Rebuild for button state

    // Auto-submit when all digits entered
    if (_isCodeComplete) {
      _handleVerify();
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      // Move to previous field on backspace when current is empty
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

  Future<void> _handleVerify() async {
    if (!_isCodeComplete) return;

    final success = await ref.read(authNotifierProvider.notifier).verifyEmail(
          email: widget.email,
          token: _code,
        );

    if (success && mounted) {
      context.go('/org/select');
    }
  }

  Future<void> _handleResend() async {
    if (widget.email.isEmpty) return;

    final success = await ref
        .read(authNotifierProvider.notifier)
        .resendVerification(widget.email);

    if (success && mounted) {
      _startCooldown();
      // Clear existing code
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final canResend = _cooldownSeconds == 0 && !isLoading;

    // Listen for errors
    ref.listen<AsyncValue<void>>(authNotifierProvider, (_, next) {
      if (next.hasError) {
        final error = next.error;
        final message = error is DeskflowException
            ? error.message
            : 'Неверный код. Попробуйте снова.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: DeskflowColors.destructiveSolid,
          ),
        );
      }
    });

    // Mask email: sol***@gmail.com
    final maskedEmail = _maskEmail(widget.email);

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/auth/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DeskflowSpacing.xl),
          child: Column(
            children: [
              const SizedBox(height: DeskflowSpacing.xl),

              // Lock icon
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
                  Icons.mark_email_unread_rounded,
                  size: 36,
                  color: DeskflowColors.primarySolid,
                ),
              ),
              const SizedBox(height: DeskflowSpacing.xl),
              const Text('Подтвердите email', style: DeskflowTypography.h2),
              const SizedBox(height: DeskflowSpacing.sm),
              Text(
                'Мы отправили 8-значный код на\n$maskedEmail',
                style: DeskflowTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DeskflowSpacing.xxl),

              // PIN code input
              GlassCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_codeLength, (i) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: i == 0 ? 0 : 4,
                              right: i == _codeLength - 1 ? 0 : 4,
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
                                  fontSize: 20,
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
                                    borderRadius: BorderRadius.circular(
                                        DeskflowRadius.md),
                                    borderSide: const BorderSide(
                                      color: DeskflowColors.glassBorder,
                                      width: 0.5,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        DeskflowRadius.md),
                                    borderSide: const BorderSide(
                                      color: DeskflowColors.glassBorder,
                                      width: 0.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        DeskflowRadius.md),
                                    borderSide: const BorderSide(
                                      color: DeskflowColors.primarySolid,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value.length > 1) {
                                    // Handle paste into single field
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

              // Resend button
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
          ),
        ),
      ),
    );
  }

  /// Masks email: soloveuiv@gmail.com → sol***@gmail.com
  String _maskEmail(String email) {
    if (email.isEmpty || !email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 3) return '${name[0]}***@$domain';
    return '${name.substring(0, 3)}***@$domain';
  }
}
