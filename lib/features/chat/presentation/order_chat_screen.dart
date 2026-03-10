import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/core/widgets/error_state_widget.dart';
import 'package:deskflow/core/widgets/skeleton_loader.dart';
import 'package:deskflow/core/widgets/status_pill_badge.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/chat/domain/chat_message.dart';
import 'package:deskflow/features/chat/domain/chat_notifier.dart';
import 'package:deskflow/features/orders/domain/order_providers.dart';

final _log = AppLogger.getLogger('OrderChatScreen');

/// Realtime chat screen for a specific order.
class OrderChatScreen extends HookConsumerWidget {
  const OrderChatScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _log.d('build: orderId=$orderId');

    final chatAsync = ref.watch(chatNotifierProvider(orderId));
    final orderAsync = ref.watch(orderDetailProvider(orderId));
    final currentUserId = ref.watch(currentUserProvider)?.id;

    final scrollController = useScrollController();
    final textController = useTextEditingController();
    final focusNode = useFocusNode();
    final isComposing = useState(false);
    final selectedFiles = useState<List<XFile>>([]);
    final typingUser = useState<String?>(null);
    final isLoadingOlder = useState(false);

    // Wire up typing indicator callback
    useEffect(() {
      final notifier = ref.read(chatNotifierProvider(orderId).notifier);
      notifier.setOnTypingChanged((name) {
        typingUser.value = name;
      });
      return null;
    }, [orderId]);

    // Scroll-to-top listener for pagination
    useEffect(() {
      void onScroll() {
        if (scrollController.position.pixels <=
                scrollController.position.minScrollExtent + 50 &&
            !isLoadingOlder.value) {
          final notifier = ref.read(chatNotifierProvider(orderId).notifier);
          if (notifier.hasMore && !notifier.isLoadingOlder) {
            isLoadingOlder.value = true;
            notifier.loadOlderMessages().then((_) {
              isLoadingOlder.value = false;
            });
          }
        }
      }

      scrollController.addListener(onScroll);
      return () => scrollController.removeListener(onScroll);
    }, [scrollController]);

    // Auto-scroll to bottom when new messages arrive
    ref.listen(chatNotifierProvider(orderId), (prev, next) {
      final prevLen = prev?.valueOrNull?.length ?? 0;
      final nextLen = next.valueOrNull?.length ?? 0;
      if (nextLen > prevLen) {
        _scrollToBottom(scrollController);
      }
    });

    return Scaffold(
      backgroundColor: DeskflowColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        // [FIX] Use Flexible + overflow protection to prevent RenderFlex overflow
        // when status badge + title are wider than available AppBar space.
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Чат заказа',
                style: DeskflowTypography.h3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (orderAsync.hasValue) ...[
              const SizedBox(width: DeskflowSpacing.sm),
              Text(
                orderAsync.value!.formattedNumber,
                style: DeskflowTypography.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          if (orderAsync.hasValue && orderAsync.value!.status != null)
            Padding(
              padding: const EdgeInsets.only(right: DeskflowSpacing.md),
              // ConstrainedBox limits badge width so it never squeezes title.
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: StatusPillBadge(
                  label: orderAsync.value!.status!.name,
                  color: orderAsync.value!.status!.materialColor,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Messages list ──
          Expanded(
            child: chatAsync.when(
              loading: () => const _ChatLoadingSkeleton(),
              error: (error, _) => ErrorStateWidget(
                message: error.toString(),
                onRetry: () =>
                    ref.invalidate(chatNotifierProvider(orderId)),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return const _EmptyChatState();
                }
                // Schedule scroll to bottom on first load
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom(scrollController, animate: false);
                });

                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DeskflowSpacing.md,
                    vertical: DeskflowSpacing.sm,
                  ),
                  itemCount: messages.length + 1, // +1 for load-older header
                  itemBuilder: (context, index) {
                    // First item: loading indicator or "load older" hint
                    if (index == 0) {
                      if (isLoadingOlder.value) {
                        return const Padding(
                          padding: EdgeInsets.all(DeskflowSpacing.md),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: DeskflowColors.textTertiary,
                              ),
                            ),
                          ),
                        );
                      }
                      // Empty space — pagination triggers via scroll listener
                      return const SizedBox(height: DeskflowSpacing.sm);
                    }

                    final msgIndex = index - 1;
                    final message = messages[msgIndex];
                    final isMe = message.senderId == currentUserId;

                    // Show date separator if needed
                    final showDate = msgIndex == 0 ||
                        !_isSameDay(
                          messages[msgIndex - 1].createdAt,
                          message.createdAt,
                        );

                    // Show sender name if different from previous
                    final showSender = !isMe &&
                        !message.isSystem &&
                        (msgIndex == 0 ||
                            messages[msgIndex - 1].senderId !=
                                message.senderId ||
                            messages[msgIndex - 1].isSystem);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDate)
                          _DateSeparator(date: message.createdAt),
                        if (message.isSystem)
                          _SystemMessage(message: message)
                        else
                          _ChatBubble(
                            message: message,
                            isMe: isMe,
                            showSender: showSender,
                            orderId: orderId,
                            onRetry: message.status == MessageStatus.error
                                ? () => ref
                                    .read(
                                        chatNotifierProvider(orderId).notifier)
                                    .retryMessage(message.id)
                                : null,
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ── Selected files preview ──
          if (selectedFiles.value.isNotEmpty)
            _SelectedFilesBar(
              files: selectedFiles.value,
              onRemove: (index) {
                final updated = List<XFile>.from(selectedFiles.value);
                updated.removeAt(index);
                selectedFiles.value = updated;
              },
            ),

          // ── Typing indicator ──
          if (typingUser.value != null)
            _TypingIndicator(userName: typingUser.value!),

          // ── Input bar ──
          _ChatInputBar(
            controller: textController,
            focusNode: focusNode,
            isComposing: isComposing.value,
            hasAttachments: selectedFiles.value.isNotEmpty,
            onTextChanged: (text) {
              isComposing.value = text.trim().isNotEmpty;
              // Send typing indicator (debounced)
              ref
                  .read(chatNotifierProvider(orderId).notifier)
                  .notifyTyping();
            },
            onSend: () {
              final text = textController.text.trim();
              if (text.isEmpty && selectedFiles.value.isEmpty) return;

              if (selectedFiles.value.isNotEmpty) {
                ref
                    .read(chatNotifierProvider(orderId).notifier)
                    .sendMessageWithAttachments(
                      text: text.isEmpty ? null : text,
                      files: selectedFiles.value,
                    );
                selectedFiles.value = [];
              } else {
                ref
                    .read(chatNotifierProvider(orderId).notifier)
                    .sendMessage(text);
              }

              textController.clear();
              isComposing.value = false;
              _scrollToBottom(scrollController);
            },
            onAttach: () => _showAttachmentOptions(
              context,
              selectedFiles,
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom(
    ScrollController controller, {
    bool animate = true,
  }) {
    if (!controller.hasClients) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!controller.hasClients) return;
      if (animate) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        controller.jumpTo(controller.position.maxScrollExtent);
      }
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showAttachmentOptions(
    BuildContext context,
    ValueNotifier<List<XFile>> selectedFiles,
  ) {
    showModalBottomSheet(
      context: context,
      // [FIX] Use opaque surface so attachment options don’t blend with chat.
      backgroundColor: DeskflowColors.modalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DeskflowRadius.xl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DeskflowSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: DeskflowColors.primarySolid),
                title: const Text('Камера'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final image = await ImagePicker()
                      .pickImage(source: ImageSource.camera);
                  if (image != null) {
                    selectedFiles.value = [
                      ...selectedFiles.value,
                      image
                    ];
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: DeskflowColors.primarySolid),
                title: const Text('Галерея'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final images =
                      await ImagePicker().pickMultiImage();
                  if (images.isNotEmpty) {
                    selectedFiles.value = [
                      ...selectedFiles.value,
                      ...images,
                    ];
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file_rounded,
                    color: DeskflowColors.primarySolid),
                title: const Text('Файл'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await FilePicker.platform.pickFiles(
                    allowMultiple: true,
                    withData: true,
                  );
                  if (result != null && result.files.isNotEmpty) {
                    selectedFiles.value = [
                      ...selectedFiles.value,
                      ...result.files.map((f) => f.xFile),
                    ];
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Chat bubble
// ═══════════════════════════════════════════════════════════════════

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.isMe,
    required this.showSender,
    required this.orderId,
    this.onRetry,
  });

  final ChatMessage message;
  final bool isMe;
  final bool showSender;
  final String orderId;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DeskflowSpacing.xs),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for other users
          if (!isMe) ...[
            if (showSender)
              _Avatar(initials: message.senderInitials)
            else
              const SizedBox(width: 32),
            const SizedBox(width: DeskflowSpacing.sm),
          ],

          // Bubble
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Sender name
                if (showSender && message.senderName != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: DeskflowSpacing.sm,
                      bottom: DeskflowSpacing.xs,
                    ),
                    child: Text(
                      message.senderName!,
                      style: DeskflowTypography.caption.copyWith(
                        color: DeskflowColors.primarySolid,
                      ),
                    ),
                  ),

                // Message container
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? DeskflowColors.primary
                        : DeskflowColors.glassSurface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(DeskflowRadius.lg),
                      topRight: const Radius.circular(DeskflowRadius.lg),
                      bottomLeft: isMe
                          ? const Radius.circular(DeskflowRadius.lg)
                          : const Radius.circular(DeskflowRadius.sm),
                      bottomRight: isMe
                          ? const Radius.circular(DeskflowRadius.sm)
                          : const Radius.circular(DeskflowRadius.lg),
                    ),
                    border: Border.all(
                      color: DeskflowColors.glassBorder,
                      width: 0.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DeskflowSpacing.md,
                    vertical: DeskflowSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Attachments
                      if (message.attachments.isNotEmpty) ...[
                        ...message.attachments.map(
                          (att) => _AttachmentWidget(
                            attachment: att,
                            orderId: orderId,
                          ),
                        ),
                        if (message.text != null)
                          const SizedBox(height: DeskflowSpacing.xs),
                      ],

                      // Text
                      if (message.text != null)
                        Text(
                          message.text!,
                          style: DeskflowTypography.body,
                        ),

                      // Time & status
                      const SizedBox(height: DeskflowSpacing.xs),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(message.createdAt),
                            style: DeskflowTypography.caption.copyWith(
                              fontSize: 10,
                              color: isMe
                                  ? DeskflowColors.textSecondary
                                  : DeskflowColors.textTertiary,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            _StatusIcon(status: message.status),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Retry button for failed messages
          if (message.status == MessageStatus.error && onRetry != null) ...[
            const SizedBox(width: DeskflowSpacing.xs),
            GestureDetector(
              onTap: onRetry,
              child: const Icon(
                Icons.error_outline_rounded,
                color: DeskflowColors.destructiveSolid,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════════════
// Message status icon
// ═══════════════════════════════════════════════════════════════════

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      MessageStatus.sending => const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: DeskflowColors.textTertiary,
          ),
        ),
      MessageStatus.sent => const Icon(
          Icons.done_all_rounded,
          size: 14,
          color: DeskflowColors.textSecondary,
        ),
      MessageStatus.error => const Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: DeskflowColors.destructiveSolid,
        ),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════
// Avatar
// ═══════════════════════════════════════════════════════════════════

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: DeskflowColors.glassSurface,
        border: Border.all(
          color: DeskflowColors.glassBorder,
          width: 0.5,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: DeskflowTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: DeskflowColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Attachment widget (inline in bubble)
// ═══════════════════════════════════════════════════════════════════

class _AttachmentWidget extends StatelessWidget {
  const _AttachmentWidget({
    required this.attachment,
    required this.orderId,
  });

  final Attachment attachment;
  final String orderId;

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage) {
      return GestureDetector(
        onTap: () => context.push(
          '/orders/$orderId/chat/attachment',
          extra: attachment,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DeskflowRadius.sm),
          child: Image.network(
            attachment.url,
            width: 200,
            height: 150,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 200,
                height: 150,
                color: DeskflowColors.glassSurface,
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: DeskflowColors.primarySolid,
                  ),
                ),
              );
            },
            errorBuilder: (_, error, stackTrace) => Container(
              width: 200,
              height: 150,
              color: DeskflowColors.glassSurface,
              child: const Icon(
                Icons.broken_image_rounded,
                color: DeskflowColors.textTertiary,
              ),
            ),
          ),
        ),
      );
    }

    // Non-image file
    return GestureDetector(
      onTap: () => context.push(
        '/orders/$orderId/chat/attachment',
        extra: attachment,
      ),
      child: Container(
        padding: const EdgeInsets.all(DeskflowSpacing.sm),
        decoration: BoxDecoration(
          color: DeskflowColors.glassSurface,
          borderRadius: BorderRadius.circular(DeskflowRadius.sm),
          border: Border.all(
            color: DeskflowColors.glassBorder,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_rounded,
                size: 20, color: DeskflowColors.primarySolid),
            const SizedBox(width: DeskflowSpacing.sm),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.fileName,
                    style: DeskflowTypography.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    attachment.formattedSize,
                    style: DeskflowTypography.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// System message (centered, small text)
// ═══════════════════════════════════════════════════════════════════

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DeskflowSpacing.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DeskflowSpacing.md,
            vertical: DeskflowSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: DeskflowColors.glassSurface,
            borderRadius: BorderRadius.circular(DeskflowRadius.pill),
          ),
          child: Text(
            message.text ?? message.systemAction ?? '',
            style: DeskflowTypography.caption,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Date separator
// ═══════════════════════════════════════════════════════════════════

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DeskflowSpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DeskflowSpacing.md,
            vertical: DeskflowSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: DeskflowColors.glassSurface,
            borderRadius: BorderRadius.circular(DeskflowRadius.pill),
          ),
          child: Text(
            _formatDateLabel(date),
            style: DeskflowTypography.caption,
          ),
        ),
      ),
    );
  }

  String _formatDateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Вчера';

    final months = [
      '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    return '${dt.day} ${months[dt.month]}${dt.year != now.year ? ' ${dt.year}' : ''}';
  }
}

// ═══════════════════════════════════════════════════════════════════
// Input bar
// ═══════════════════════════════════════════════════════════════════

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.isComposing,
    required this.hasAttachments,
    required this.onTextChanged,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isComposing;
  final bool hasAttachments;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final canSend = isComposing || hasAttachments;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        DeskflowSpacing.sm,
        DeskflowSpacing.sm,
        DeskflowSpacing.sm,
        DeskflowSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: DeskflowColors.glassSurface,
        border: Border(
          top: BorderSide(
            color: DeskflowColors.glassBorder,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attachment button
            IconButton(
              onPressed: onAttach,
              icon: const Icon(Icons.attach_file_rounded),
              color: DeskflowColors.textSecondary,
              iconSize: 24,
            ),

            // Text field
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onTextChanged,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: DeskflowTypography.body,
                  decoration: InputDecoration(
                    hintText: 'Сообщение...',
                    hintStyle: DeskflowTypography.bodySmall,
                    filled: true,
                    fillColor: DeskflowColors.glassSurface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: DeskflowSpacing.md,
                      vertical: DeskflowSpacing.sm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(DeskflowRadius.xl),
                      borderSide: const BorderSide(
                        color: DeskflowColors.glassBorder,
                        width: 0.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(DeskflowRadius.xl),
                      borderSide: const BorderSide(
                        color: DeskflowColors.glassBorder,
                        width: 0.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(DeskflowRadius.xl),
                      borderSide: const BorderSide(
                        color: DeskflowColors.primarySolid,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: DeskflowSpacing.xs),

            // Send button
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: canSend
                    ? DeskflowColors.primarySolid
                    : DeskflowColors.glassSurface,
              ),
              child: IconButton(
                onPressed: canSend ? onSend : null,
                icon: const Icon(Icons.arrow_upward_rounded),
                color: canSend
                    ? Colors.white
                    : DeskflowColors.textDisabled,
                iconSize: 20,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Selected files bar (before sending)
// ═══════════════════════════════════════════════════════════════════

class _SelectedFilesBar extends StatelessWidget {
  const _SelectedFilesBar({
    required this.files,
    required this.onRemove,
  });

  final List<XFile> files;
  final void Function(int index) onRemove;

  /// [FIX] Check if file is an image by extension.
  static bool _isImageFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    return {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}.contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(
        horizontal: DeskflowSpacing.sm,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: DeskflowColors.glassBorder,
            width: 0.5,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: files.length,
        itemBuilder: (context, index) {
          final file = files[index];
          final isImage = _isImageFile(file.name);
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: DeskflowSpacing.xs),
            child: Stack(
              children: [
                Container(
                  constraints: isImage
                      ? const BoxConstraints.tightFor(
                          width: 60,
                          height: 60,
                        )
                      : const BoxConstraints(
                          minWidth: 60,
                          maxWidth: 140,
                          minHeight: 48,
                          maxHeight: 48,
                        ),
                  margin: const EdgeInsets.only(
                    top: DeskflowSpacing.sm,
                    right: DeskflowSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: DeskflowColors.glassSurface,
                    borderRadius:
                        BorderRadius.circular(DeskflowRadius.sm),
                    border: Border.all(
                      color: DeskflowColors.glassBorder,
                      width: 0.5,
                    ),
                  ),
                  // [FIX] Show image thumbnail for images, filename chip for files
                  child: isImage
                      ? ClipRRect(
                          borderRadius:
                              BorderRadius.circular(DeskflowRadius.sm),
                          child: FutureBuilder<Uint8List>(
                            future: file.readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Image.memory(
                                  snapshot.data!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Center(
                                    child: Text(
                                      file.name.split('.').last.toUpperCase(),
                                      style: DeskflowTypography.caption,
                                    ),
                                  ),
                                );
                              }
                              return const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: DeskflowColors.primarySolid,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.insert_drive_file_rounded,
                                size: 24,
                                color: DeskflowColors.primarySolid,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  file.name.length > 10
                                      ? '${file.name.substring(0, 10)}...'
                                      : file.name,
                                  style: DeskflowTypography.caption.copyWith(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => onRemove(index),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: DeskflowColors.destructiveSolid,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Empty & loading states
// ═══════════════════════════════════════════════════════════════════

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DeskflowSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: DeskflowColors.textTertiary,
            ),
            const SizedBox(height: DeskflowSpacing.lg),
            Text(
              'Начните обсуждение заказа',
              style: DeskflowTypography.body.copyWith(
                color: DeskflowColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DeskflowSpacing.sm),
            Text(
              'Все сообщения привязаны к этому заказу',
              style: DeskflowTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatLoadingSkeleton extends StatelessWidget {
  const _ChatLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DeskflowSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: DeskflowSpacing.xl),
          // Simulate message skeletons
          Align(
            alignment: Alignment.centerLeft,
            child: SkeletonLoader.box(
              height: 60,
              width: MediaQuery.of(context).size.width * 0.6,
            ),
          ),
          const SizedBox(height: DeskflowSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: SkeletonLoader.box(
              height: 40,
              width: MediaQuery.of(context).size.width * 0.5,
            ),
          ),
          const SizedBox(height: DeskflowSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: SkeletonLoader.box(
              height: 80,
              width: MediaQuery.of(context).size.width * 0.7,
            ),
          ),
          const SizedBox(height: DeskflowSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: SkeletonLoader.box(
              height: 50,
              width: MediaQuery.of(context).size.width * 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated typing indicator — "X печатает..."
class _TypingIndicator extends StatefulWidget {
  final String userName;

  const _TypingIndicator({required this.userName});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DeskflowSpacing.lg,
        vertical: DeskflowSpacing.xs,
      ),
      alignment: Alignment.centerLeft,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          // Cycle through 1–3 dots
          final dotCount = (_animation.value * 3).floor() % 3 + 1;
          final dots = '.' * dotCount;
          return Text(
            '${widget.userName} печатает$dots',
            style: DeskflowTypography.caption.copyWith(
              color: DeskflowColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          );
        },
      ),
    );
  }
}
