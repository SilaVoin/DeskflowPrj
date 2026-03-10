import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:deskflow/core/providers/supabase_provider.dart';
import 'package:deskflow/features/chat/data/chat_repository.dart';
import 'package:deskflow/features/chat/domain/chat_message.dart';

part 'chat_providers.g.dart';

/// Chat repository singleton.
@Riverpod(keepAlive: true)
ChatRepository chatRepository(Ref ref) {
  return ChatRepository(ref.watch(supabaseClientProvider));
}

/// Chat messages for a specific order.
@riverpod
Future<List<ChatMessage>> chatMessages(Ref ref, String orderId) async {
  return ref.watch(chatRepositoryProvider).getMessages(orderId: orderId);
}

/// Latest messages preview for order detail screen.
@riverpod
Future<List<ChatMessage>> chatPreview(Ref ref, String orderId) async {
  return ref.watch(chatRepositoryProvider).getLatestMessages(
        orderId: orderId,
        count: 3,
      );
}

/// Message count for an order.
@riverpod
Future<int> chatMessageCount(Ref ref, String orderId) async {
  return ref.watch(chatRepositoryProvider).getMessageCount(orderId);
}
