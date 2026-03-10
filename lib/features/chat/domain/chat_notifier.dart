import 'dart:async';

import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/chat/domain/chat_message.dart';
import 'package:deskflow/features/chat/domain/chat_providers.dart';

part 'chat_notifier.g.dart';

final _log = AppLogger.getLogger('ChatNotifier');
const _uuid = Uuid();

/// Manages chat state for a specific order — handles realtime, sending, etc.
@riverpod
class ChatNotifier extends _$ChatNotifier {
  RealtimeChannel? _channel;
  Timer? _typingTimer;
  Timer? _typingDisplayTimer;
  String? _typingUserName;
  void Function(String?)? _onTypingChanged;

  /// Whether there are more older messages to load.
  bool _hasMore = true;

  /// Whether older messages are currently being fetched.
  bool _isLoadingOlder = false;

  /// Whether there are more older messages available.
  bool get hasMore => _hasMore;

  /// Whether a pagination fetch is in progress.
  bool get isLoadingOlder => _isLoadingOlder;

  @override
  Future<List<ChatMessage>> build(String orderId) async {
    _log.d('build: orderId=$orderId');

    // Fetch initial messages
    final messages = await ref
        .watch(chatRepositoryProvider)
        .getMessages(orderId: orderId);

    // Subscribe to realtime
    _subscribeRealtime();

    // Clean up on dispose
    ref.onDispose(() {
      _log.d('dispose: unsubscribing from realtime');
      if (_channel != null) {
        ref.read(chatRepositoryProvider).unsubscribe(_channel!);
        _channel = null;
      }
      _typingTimer?.cancel();
      _typingDisplayTimer?.cancel();
    });

    _log.d('build: loaded ${messages.length} messages');
    return messages;
  }

  /// Register a callback for typing indicator changes.
  void setOnTypingChanged(void Function(String?) callback) {
    _onTypingChanged = callback;
  }

  /// Load older messages (pagination).
  ///
  /// Fetches messages older than the oldest currently loaded message
  /// and prepends them to the state. Returns true if more messages exist.
  Future<bool> loadOlderMessages() async {
    if (!_hasMore || _isLoadingOlder) return _hasMore;

    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return false;

    _isLoadingOlder = true;
    _log.d('loadOlderMessages: fetching older than ${current.first.createdAt}');

    try {
      final older = await ref.read(chatRepositoryProvider).getOlderMessages(
            orderId: orderId,
            before: current.first.createdAt,
          );

      _hasMore = older.isNotEmpty;
      _isLoadingOlder = false;

      if (older.isNotEmpty) {
        state = state.whenData((messages) => [...older, ...messages]);
        _log.d('loadOlderMessages: prepended ${older.length} messages');
      }

      return _hasMore;
    } catch (e) {
      _log.e('loadOlderMessages: error: $e');
      _isLoadingOlder = false;
      return _hasMore;
    }
  }

  /// Subscribe to Supabase Realtime for new messages.
  void _subscribeRealtime() {
    final repo = ref.read(chatRepositoryProvider);
    final currentUserId = ref.read(currentUserProvider)?.id;

    _channel = repo.subscribeToMessages(
      orderId: orderId,
      onNewMessage: (message) {
        _log.d('_subscribeRealtime: new message id=${message.id}, '
            'sender=${message.senderId}');

        // Skip if this is our own message (we already added it optimistically)
        if (message.senderId == currentUserId) {
          // Update the optimistic message with the real one
          _updateOptimisticMessage(message);
          return;
        }

        // Add the new message from another user
        state = state.whenData((messages) {
          // Avoid duplicates
          if (messages.any((m) => m.id == message.id)) return messages;
          return [...messages, message];
        });
      },
    );

    // Listen for typing broadcasts
    if (_channel != null) {
      repo.onTypingIndicator(
        channel: _channel!,
        onTyping: (userId, userName) {
          // Ignore own typing
          if (userId == currentUserId) return;

          _log.d('typing indicator from: $userName');
          _typingUserName = userName.isNotEmpty ? userName : 'Кто-то';
          _onTypingChanged?.call(_typingUserName);

          // Clear typing after 3 seconds of inactivity
          _typingDisplayTimer?.cancel();
          _typingDisplayTimer = Timer(const Duration(seconds: 3), () {
            _typingUserName = null;
            _onTypingChanged?.call(null);
          });
        },
      );
    }
  }

  /// Update an optimistic message with the real server response.
  void _updateOptimisticMessage(ChatMessage realMessage) {
    state = state.whenData((messages) {
      final idx = messages.indexWhere(
        (m) => m.status == MessageStatus.sending && m.text == realMessage.text,
      );
      if (idx >= 0) {
        final updated = List<ChatMessage>.from(messages);
        updated[idx] = realMessage;
        return updated;
      }
      // If no optimistic match found, check if already exists
      if (messages.any((m) => m.id == realMessage.id)) return messages;
      return [...messages, realMessage];
    });
  }

  /// Send a text message with optimistic UI.
  Future<void> sendMessage(String text) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      _log.w('sendMessage: no current user');
      return;
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _log.d('sendMessage: text="${trimmed.substring(0, trimmed.length > 30 ? 30 : trimmed.length)}..."');

    // Create optimistic message
    final optimistic = ChatMessage(
      id: 'temp-${_uuid.v4()}',
      orderId: orderId,
      senderId: currentUser.id,
      senderName: currentUser.userMetadata?['full_name'] as String?,
      text: trimmed,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
    );

    // Add to state immediately
    state = state.whenData((messages) => [...messages, optimistic]);

    try {
      final sent = await ref.read(chatRepositoryProvider).sendMessage(
            orderId: orderId,
            senderId: currentUser.id,
            text: trimmed,
          );

      // Replace optimistic with real message
      state = state.whenData((messages) {
        final updated = List<ChatMessage>.from(messages);
        final idx = updated.indexWhere((m) => m.id == optimistic.id);
        if (idx >= 0) {
          updated[idx] = sent;
        }
        return updated;
      });

      _log.d('sendMessage: sent successfully id=${sent.id}');

      // [FIX] Invalidate message count so order detail screen refreshes
      ref.invalidate(chatMessageCountProvider(orderId));
    } catch (e) {
      _log.e('sendMessage: error: $e');
      // Mark optimistic message as error
      state = state.whenData((messages) {
        return messages.map((m) {
          if (m.id == optimistic.id) {
            return m.copyWith(status: MessageStatus.error);
          }
          return m;
        }).toList();
      });
    }
  }

  /// Send a message with file attachments.
  Future<void> sendMessageWithAttachments({
    String? text,
    required List<XFile> files,
  }) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    _log.d('sendMessageWithAttachments: files=${files.length}, text=$text');

    // Create optimistic message
    final optimistic = ChatMessage(
      id: 'temp-${_uuid.v4()}',
      orderId: orderId,
      senderId: currentUser.id,
      senderName: currentUser.userMetadata?['full_name'] as String?,
      text: text,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
    );

    state = state.whenData((messages) => [...messages, optimistic]);

    try {
      final sent =
          await ref.read(chatRepositoryProvider).sendMessageWithAttachments(
                orderId: orderId,
                senderId: currentUser.id,
                text: text,
                files: files,
              );

      // [FIX] Race condition: Realtime INSERT event fires BEFORE attachments
      // are uploaded, so _updateOptimisticMessage replaces the optimistic msg
      // with a version that has EMPTY attachments. By the time we get `sent`
      // (with full attachments), the optimistic temp ID no longer exists.
      // Fix: also search by the real message ID as fallback.
      state = state.whenData((messages) {
        final updated = List<ChatMessage>.from(messages);
        var idx = updated.indexWhere((m) => m.id == optimistic.id);
        if (idx < 0) {
          // Optimistic was already replaced by realtime — find by real ID
          idx = updated.indexWhere((m) => m.id == sent.id);
          _log.d('[FIX] sendMessageWithAttachments: optimistic not found, '
              'fallback to real id, idx=$idx');
        }
        if (idx >= 0) {
          updated[idx] = sent;
        }
        return updated;
      });

      _log.d('sendMessageWithAttachments: sent successfully id=${sent.id}');

      // [FIX] Invalidate message count so order detail screen refreshes
      ref.invalidate(chatMessageCountProvider(orderId));
    } catch (e) {
      _log.e('sendMessageWithAttachments: error: $e');
      state = state.whenData((messages) {
        return messages.map((m) {
          if (m.id == optimistic.id) {
            return m.copyWith(status: MessageStatus.error);
          }
          return m;
        }).toList();
      });
    }
  }

  /// Retry sending a failed message.
  Future<void> retryMessage(String messageId) async {
    _log.d('retryMessage: id=$messageId');
    final currentMessages = state.valueOrNull;
    if (currentMessages == null) return;

    final failedMsg = currentMessages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => throw StateError('Message not found'),
    );

    // Remove the failed message
    state = state.whenData(
      (messages) => messages.where((m) => m.id != messageId).toList(),
    );

    // Re-send
    if (failedMsg.text != null) {
      await sendMessage(failedMsg.text!);
    }
  }

  /// Current typing user name (null if nobody is typing).
  String? get typingUserName => _typingUserName;

  /// Notify that current user is typing.
  void notifyTyping() {
    if (_channel == null) return;
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    ref.read(chatRepositoryProvider).sendTypingIndicator(
          channel: _channel!,
          userId: currentUser.id,
          userName: currentUser.userMetadata?['full_name'] as String? ?? '',
        );
  }
}
