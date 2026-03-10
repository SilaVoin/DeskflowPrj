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
import 'package:deskflow/features/org/domain/org_notifier.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

final _log = AppLogger.getLogger('CreateOrgScreen');

/// Create organization screen.
class CreateOrgScreen extends ConsumerStatefulWidget {
  const CreateOrgScreen({super.key});

  @override
  ConsumerState<CreateOrgScreen> createState() => _CreateOrgScreenState();
}

class _CreateOrgScreenState extends ConsumerState<CreateOrgScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  Uint8List? _avatarBytes;
  String _avatarExt = 'jpeg';

  @override
  void dispose() {
    _nameController.dispose();
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

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final org = await ref
        .read(orgNotifierProvider.notifier)
        .createOrganization(_nameController.text.trim());

    if (org != null && _avatarBytes != null) {
      try {
        final repo = ref.read(orgRepositoryProvider);
        final logoUrl = await repo.uploadOrgAvatar(
          orgId: org.id,
          bytes: _avatarBytes!,
          fileExt: _avatarExt,
        );
        await repo.updateLogoUrl(org.id, logoUrl);
      } catch (e) {
        _log.e('Avatar upload failed: $e');
      }
    }

    if (org != null && mounted) {
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
        title: const Text('Создать организацию'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DeskflowSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                GlassCard(
                  child: Column(
                    children: [
                      GlassTextField(
                        label: 'Название организации',
                        hint: 'Введите название',
                        controller: _nameController,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (value == null || value.trim().length < 2) {
                            return 'Минимум 2 символа';
                          }
                          if (value.trim().length > 100) {
                            return 'Максимум 100 символов';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: DeskflowSpacing.lg),
                      // Logo upload
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
                              : const Icon(
                                  Icons.camera_alt_rounded,
                                  color: DeskflowColors.textTertiary,
                                ),
                        ),
                      ),
                      const SizedBox(height: DeskflowSpacing.sm),
                      Text(
                        'Добавить логотип (необязательно)',
                        style: DeskflowTypography.caption,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                PillButton(
                  label: 'Создать',
                  expanded: true,
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _handleCreate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
