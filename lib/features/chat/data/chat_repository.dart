import 'dart:async';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:deskflow/core/errors/supabase_error_handler.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/chat/domain/chat_message.dart';

const _uuid = Uuid();

final _log = AppLogger.getLogger('ChatRepository');

class ChatRepository {
  final SupabaseClient _client;

  ChatRepository(this._client);


  Future<List<ChatMessage>> getMessages({
    required String orderId,
    int limit = 50,
    int offset = 0,
  }) async {
    _log.d('getMessages: orderId=$orderId, limit=$limit, offset=$offset');
    return supabaseGuard(() async {
      final data = await _client
          .from('chat_messages')
          .select('*, profiles!chat_messages_sender_id_fkey(full_name), chat_attachments(*)')
          .eq('order_id', orderId)
          .order('created_at', ascending: true)
          .range(offset, offset + limit - 1);

      final messages = (data as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();

      _log.d('getMessages: fetched ${messages.length} messages');
      return messages;
    });
  }

  Future<List<ChatMessage>> getLatestMessages({
    required String orderId,
    int count = 3,
  }) async {
    _log.d('getLatestMessages: orderId=$orderId, count=$count');
    return supabaseGuard(() async {
      final data = await _client
          .from('chat_messages')
          .select('*, profiles!chat_messages_sender_id_fkey(full_name)')
          .eq('order_id', orderId)
          .order('created_at', ascending: false)
          .limit(count);

      final messages = (data as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList()
          .reversed
          .toList();

      return messages;
    });
  }

  Future<List<ChatMessage>> getOlderMessages({
    required String orderId,
    required DateTime before,
    int limit = 30,
  }) async {
    _log.d('getOlderMessages: orderId=$orderId, before=$before');
    return supabaseGuard(() async {
      final data = await _client
          .from('chat_messages')
          .select(
              '*, profiles!chat_messages_sender_id_fkey(full_name), chat_attachments(*)')
          .eq('order_id', orderId)
          .lt('created_at', before.toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);

      final messages = (data as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList()
          .reversed
          .toList();

      _log.d('getOlderMessages: fetched ${messages.length} messages');
      return messages;
    });
  }

  Future<int> getMessageCount(String orderId) async {
    _log.d('getMessageCount: orderId=$orderId');
    return supabaseGuard(() async {
      final response = await _client
          .from('chat_messages')
          .select()
          .eq('order_id', orderId)
          .count(CountOption.exact);

      return response.count;
    });
  }

  Future<ChatMessage> sendMessage({
    required String orderId,
    required String senderId,
    required String text,
  }) async {
    _log.d('sendMessage: orderId=$orderId, text=${text.substring(0, min(30, text.length))}...');
    return supabaseGuard(() async {
      final data = await _client
          .from('chat_messages')
          .insert({
            'order_id': orderId,
            'sender_id': senderId,
            'text': text,
            'is_system': false,
          })
          .select('*, profiles!chat_messages_sender_id_fkey(full_name)')
          .single();

      final message = ChatMessage.fromJson(data);
      _log.d('sendMessage: sent id=${message.id}');
      return message;
    });
  }

  Future<ChatMessage> sendMessageWithAttachments({
    required String orderId,
    required String senderId,
    String? text,
    required List<XFile> files,
  }) async {
    _log.d('sendMessageWithAttachments: orderId=$orderId, '
        'files=${files.length}, text=$text');
    return supabaseGuard(() async {
      final msgData = await _client
          .from('chat_messages')
          .insert({
            'order_id': orderId,
            'sender_id': senderId,
            'text': text,
            'is_system': false,
          })
          .select('*, profiles!chat_messages_sender_id_fkey(full_name)')
          .single();

      final messageId = msgData['id'] as String;

      for (final file in files) {
        final originalName = file.name;
        final bytes = await file.readAsBytes();

        final mimeType = _guessMimeType(originalName);

        final ext = originalName.contains('.')
            ? '.${originalName.split('.').last.toLowerCase()}'
            : '';
        final safeFileName = '${_uuid.v4()}$ext';
        final storagePath = 'chat/$orderId/$messageId/$safeFileName';

        _log.d('[FIX] sendMessageWithAttachments: uploading '
            '"$originalName" as "$safeFileName" '
            '(${bytes.length} bytes, $mimeType)');

        await _client.storage
            .from('chat-attachments')
            .uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(contentType: mimeType),
            );

        _log.d('[FIX] sendMessageWithAttachments: upload success for '
            '"$originalName"');

        final publicUrl = _client.storage
            .from('chat-attachments')
            .getPublicUrl(storagePath);

        await _client.from('chat_attachments').insert({
          'message_id': messageId,
          'url': publicUrl,
          'file_name': originalName,
          'mime_type': mimeType,
          'size_bytes': bytes.length,
        });

        _log.d('[FIX] sendMessageWithAttachments: attachment record '
            'inserted for "$originalName"');
      }

      final fullData = await _client
          .from('chat_messages')
          .select('*, profiles!chat_messages_sender_id_fkey(full_name), chat_attachments(*)')
          .eq('id', messageId)
          .single();

      return ChatMessage.fromJson(fullData);
    });
  }


  RealtimeChannel subscribeToMessages({
    required String orderId,
    required void Function(ChatMessage message) onNewMessage,
  }) {
    _log.d('subscribeToMessages: orderId=$orderId');

    final channel = _client
        .channel('order-chat:$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: orderId,
          ),
          callback: (payload) {
            _log.d('subscribeToMessages: INSERT event received');
            try {
              final newRecord = payload.newRecord;
              _fetchAndDeliver(newRecord['id'] as String, onNewMessage);
            } catch (e) {
              _log.e('subscribeToMessages: error processing event: $e');
            }
          },
        )
        .subscribe();

    return channel;
  }

  Future<void> _fetchAndDeliver(
    String messageId,
    void Function(ChatMessage) onNewMessage,
  ) async {
    try {
      final data = await _client
          .from('chat_messages')
          .select('*, profiles!chat_messages_sender_id_fkey(full_name), chat_attachments(*)')
          .eq('id', messageId)
          .single();

      onNewMessage(ChatMessage.fromJson(data));
    } catch (e) {
      _log.e('_fetchAndDeliver: error fetching message $messageId: $e');
    }
  }

  Future<void> unsubscribe(RealtimeChannel channel) async {
    _log.d('unsubscribe: removing channel');
    await _client.removeChannel(channel);
  }


  void sendTypingIndicator({
    required RealtimeChannel channel,
    required String userId,
    required String userName,
  }) {
    channel.sendBroadcastMessage(
      event: 'typing',
      payload: {
        'user_id': userId,
        'user_name': userName,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  void onTypingIndicator({
    required RealtimeChannel channel,
    required void Function(String userId, String userName) onTyping,
  }) {
    channel.onBroadcast(
      event: 'typing',
      callback: (payload) {
        final userId = payload['user_id'] as String? ?? '';
        final userName = payload['user_name'] as String? ?? '';
        onTyping(userId, userName);
      },
    );
  }


  String _guessMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'txt' => 'text/plain',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      _ => 'application/octet-stream',
    };
  }
}
