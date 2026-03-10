import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:deskflow/core/errors/deskflow_exception.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/glass_text_field.dart';
import 'package:deskflow/core/widgets/pill_button.dart';
import 'package:deskflow/core/widgets/error_state_widget.dart';
import 'package:deskflow/core/widgets/skeleton_loader.dart';
import 'package:deskflow/features/customers/domain/customer_providers.dart';
import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

/// Create or edit customer screen.
///
/// If [customerId] is provided — edit mode, else create mode.
class CustomerFormScreen extends HookConsumerWidget {
  final String? customerId;

  const CustomerFormScreen({super.key, this.customerId});

  bool get isEditing => customerId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For edit mode, fetch existing data
    final customerAsync =
        isEditing ? ref.watch(customerDetailProvider(customerId!)) : null;

    if (isEditing) {
      return Scaffold(
        backgroundColor: DeskflowColors.background,
        appBar: AppBar(
          title: const Text('Редактировать клиента'),
        ),
        body: customerAsync!.when(
          data: (customer) => _CustomerForm(
            customer: customer,
            customerId: customerId,
          ),
          loading: () => const _FormSkeleton(),
          error: (error, _) => ErrorStateWidget(
            message: error.toString(),
            onRetry: () =>
                ref.invalidate(customerDetailProvider(customerId!)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      appBar: AppBar(
        title: const Text('Новый клиент'),
      ),
      body: const _CustomerForm(),
    );
  }
}

class _CustomerForm extends HookConsumerWidget {
  final Customer? customer;
  final String? customerId;

  const _CustomerForm({this.customer, this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final isLoading = useState(false);

    final nameCtrl = useTextEditingController(text: customer?.name ?? '');
    final phoneCtrl = useTextEditingController(text: customer?.phone ?? '');
    final emailCtrl = useTextEditingController(text: customer?.email ?? '');
    final addressCtrl =
        useTextEditingController(text: customer?.address ?? '');
    final notesCtrl = useTextEditingController(text: customer?.notes ?? '');

    Future<void> handleSave() async {
      if (!formKey.currentState!.validate()) return;

      isLoading.value = true;
      try {
        final repo = ref.read(customerRepositoryProvider);

        if (customerId != null) {
          // Edit mode
          await repo.updateCustomer(
            customerId: customerId!,
            name: nameCtrl.text.trim(),
            phone: phoneCtrl.text.trim().isEmpty
                ? null
                : phoneCtrl.text.trim(),
            email: emailCtrl.text.trim().isEmpty
                ? null
                : emailCtrl.text.trim(),
            address: addressCtrl.text.trim().isEmpty
                ? null
                : addressCtrl.text.trim(),
            notes: notesCtrl.text.trim().isEmpty
                ? null
                : notesCtrl.text.trim(),
          );
          ref.invalidate(customerDetailProvider(customerId!));
        } else {
          // Create mode
          final orgId = ref.read(currentOrgIdProvider);
          if (orgId == null) return;

          await repo.createCustomer(
            orgId: orgId,
            name: nameCtrl.text.trim(),
            phone: phoneCtrl.text.trim().isEmpty
                ? null
                : phoneCtrl.text.trim(),
            email: emailCtrl.text.trim().isEmpty
                ? null
                : emailCtrl.text.trim(),
            address: addressCtrl.text.trim().isEmpty
                ? null
                : addressCtrl.text.trim(),
            notes: notesCtrl.text.trim().isEmpty
                ? null
                : notesCtrl.text.trim(),
          );
        }

        // Invalidate list and go back
        ref.invalidate(customersListProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(customerId != null
                  ? 'Клиент обновлён'
                  : 'Клиент создан'),
            ),
          );
          context.pop();
        }
      } on DeskflowException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: DeskflowColors.destructive,
            ),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DeskflowSpacing.lg),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Name (required) ──
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(DeskflowSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Основная информация',
                        style: DeskflowTypography.h3),
                    const SizedBox(height: DeskflowSpacing.lg),
                    GlassTextField(
                      controller: nameCtrl,
                      label: 'Имя *',
                      hint: 'Иван Иванов',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Введите имя клиента';
                        }
                        if (value.trim().length > 200) {
                          return 'Максимум 200 символов';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: DeskflowSpacing.lg),

            // ── Contact ──
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(DeskflowSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Контакты', style: DeskflowTypography.h3),
                    const SizedBox(height: DeskflowSpacing.lg),
                    GlassTextField(
                      controller: phoneCtrl,
                      label: 'Телефон',
                      hint: '+7 (777) 123-45-67',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: DeskflowSpacing.md),
                    GlassTextField(
                      controller: emailCtrl,
                      label: 'Email',
                      hint: 'client@example.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (!value.contains('@') ||
                              !value.contains('.')) {
                            return 'Некорректный email';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: DeskflowSpacing.md),
                    GlassTextField(
                      controller: addressCtrl,
                      label: 'Адрес',
                      hint: 'г. Алматы, ул. Абая 1',
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: DeskflowSpacing.lg),

            // ── Notes ──
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(DeskflowSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Заметки', style: DeskflowTypography.h3),
                    const SizedBox(height: DeskflowSpacing.lg),
                    GlassTextField(
                      controller: notesCtrl,
                      label: 'Заметки о клиенте',
                      hint: 'Любая дополнительная информация...',
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: DeskflowSpacing.xl),

            // ── Save button ──
            PillButton(
              label: customerId != null ? 'Сохранить' : 'Создать клиента',
              onPressed: isLoading.value ? null : handleSave,
              isLoading: isLoading.value,
            ),
            const SizedBox(height: DeskflowSpacing.xxxl * 2),
          ],
        ),
      ),
    );
  }
}

/// Loading skeleton for form.
class _FormSkeleton extends StatelessWidget {
  const _FormSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: ListView(
        padding: const EdgeInsets.all(DeskflowSpacing.lg),
        children: [
          SkeletonLoader.box(height: 160),
          const SizedBox(height: DeskflowSpacing.lg),
          SkeletonLoader.box(height: 240),
          const SizedBox(height: DeskflowSpacing.lg),
          SkeletonLoader.box(height: 160),
        ],
      ),
    );
  }
}
