import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:deskflow/core/providers/supabase_provider.dart';
import 'package:deskflow/features/chat/data/chat_repository.dart';
import 'package:deskflow/features/chat/domain/chat_message.dart';

part 'chat_providers.g.dart';

@Riverpod(keepAlive: true)
ChatRepository chatRepository(Ref ref) {
  return ChatRepository(ref.watch(supabaseClientProvider));
}

@riverpod
Future<List<ChatMessage>> chatMessages(Ref ref, String orderId) async {
  return ref.watch(chatRepositoryProvider).getMessages(orderId: orderId);
}

@riverpod
Future<List<ChatMessage>> chatPreview(Ref ref, String orderId) async {
  return ref.watch(chatRepositoryProvider).getLatestMessages(
        orderId: orderId,
        count: 3,
      );
}

@riverpod
Future<int> chatMessageCount(Ref ref, String orderId) async {
  return ref.watch(chatRepositoryProvider).getMessageCount(orderId);
}
