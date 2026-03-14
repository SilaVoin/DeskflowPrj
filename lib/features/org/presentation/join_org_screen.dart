import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/errors/deskflow_exception.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/glass_text_field.dart';
import 'package:deskflow/core/widgets/pill_button.dart';
import 'package:deskflow/features/org/domain/org_notifier.dart';

class JoinOrgScreen extends ConsumerStatefulWidget {
  final String? initialCode;

  const JoinOrgScreen({super.key, this.initialCode});

  @override
  ConsumerState<JoinOrgScreen> createState() => _JoinOrgScreenState();
}

class _JoinOrgScreenState extends ConsumerState<JoinOrgScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode ?? '');
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleJoin());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(orgNotifierProvider.notifier)
        .joinByInviteCode(_codeController.text.trim());

    if (success && mounted) {
      context.go('/orders');
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgState = ref.watch(orgNotifierProvider);
    final isLoading = orgState.isLoading;

    ref.listen<AsyncValue<void>>(orgNotifierProvider, (_, next) {
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
          onPressed: () => context.pop(),
        ),
        title: const Text('Присоединиться'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DeskflowSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Присоединиться к организации',
                  style: DeskflowTypography.h2,
                ),
                const SizedBox(height: DeskflowSpacing.sm),
                const Text(
                  'Попросите администратора организации отправить вам приглашение',
                  style: DeskflowTypography.bodySmall,
                ),
                const SizedBox(height: DeskflowSpacing.xxl),
                GlassCard(
                  child: Column(
                    children: [
                      GlassTextField(
                        label: 'Код приглашения',
                        hint: 'Введите код',
                        controller: _codeController,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Введите код приглашения';
                          }
                          if (value.trim().length < 6) {
                            return 'Код должен быть не менее 6 символов';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: DeskflowSpacing.xl),
                      PillButton(
                        label: 'Присоединиться',
                        expanded: true,
                        isLoading: isLoading,
                        onPressed: isLoading ? null : _handleJoin,
                      ),
                    ],
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
