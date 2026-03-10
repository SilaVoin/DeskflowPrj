import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:deskflow/features/chat/data/chat_repository.dart';
import '../../../helpers/supabase_fakes.dart';

void main() {
  late MockSupabaseClient mockClient;
  late ChatRepository repo;

  setUp(() {
    mockClient = MockSupabaseClient();
    repo = ChatRepository(mockClient);
  });

  // ──────────────────── Sample JSON fixtures ─────────────────────────

  Map<String, dynamic> messageJson({
    String id = 'msg-1',
    String orderId = 'ord-1',
    String senderId = 'user-1',
    String? text = 'Привет',
    bool isSystem = false,
  }) =>
      {
        'id': id,
        'order_id': orderId,
        'sender_id': senderId,
        'text': text,
        'is_system': isSystem,
        'system_action': null,
        'created_at': '2026-03-01T12:00:00.000',
        'profiles': {'full_name': 'Test User'},
        'chat_attachments': <Map<String, dynamic>>[],
      };

  // ─────────────────────── getMessages ───────────────────────────────

  group('getMessages', () {
    test('returns parsed messages', () async {
      final fakeData = [
        messageJson(id: 'msg-1', text: 'Привет'),
        messageJson(id: 'msg-2', text: 'Здравствуйте'),
      ];

      when(() => mockClient.from('chat_messages'))
          .thenAnswer((_) => FakeQueryBuilder(fakeData));

      final result = await repo.getMessages(orderId: 'ord-1');

      expect(result.length, 2);
      expect(result[0].id, 'msg-1');
      expect(result[0].text, 'Привет');
      expect(result[0].senderName, 'Test User');
      expect(result[1].id, 'msg-2');
      expect(result[1].text, 'Здравствуйте');
    });

    test('returns empty list when no messages', () async {
      when(() => mockClient.from('chat_messages'))
          .thenAnswer((_) => FakeQueryBuilder(<Map<String, dynamic>>[]));

      final result = await repo.getMessages(orderId: 'ord-1');
      expect(result, isEmpty);
    });

    test('parses system messages', () async {
      final fakeData = [
        {
          'id': 'msg-sys',
          'order_id': 'ord-1',
          'sender_id': 'system',
          'text': 'Статус изменён на "В работе"',
          'is_system': true,
          'system_action': 'status_changed',
          'created_at': '2026-03-01T13:00:00.000',
          'profiles': null,
          'chat_attachments': [],
        },
      ];

      when(() => mockClient.from('chat_messages'))
          .thenAnswer((_) => FakeQueryBuilder(fakeData));

      final result = await repo.getMessages(orderId: 'ord-1');

      expect(result.length, 1);
      expect(result.first.isSystem, true);
      expect(result.first.systemAction, 'status_changed');
    });

    test('parses messages with attachments', () async {
      final fakeData = [
        {
          'id': 'msg-att',
          'order_id': 'ord-1',
          'sender_id': 'user-1',
          'text': 'Фото товара',
          'is_system': false,
          'system_action': null,
          'created_at': '2026-03-01T14:00:00.000',
          'profiles': {'full_name': 'Test User'},
          'chat_attachments': [
            {
              'id': 'att-1',
              'message_id': 'msg-att',
              'url': 'https://storage.test/photo.jpg',
              'file_name': 'photo.jpg',
              'mime_type': 'image/jpeg',
              'size_bytes': 1024,
            },
          ],
        },
      ];

      when(() => mockClient.from('chat_messages'))
          .thenAnswer((_) => FakeQueryBuilder(fakeData));

      final result = await repo.getMessages(orderId: 'ord-1');

      expect(result.length, 1);
      expect(result.first.attachments.length, 1);
      expect(result.first.attachments.first.fileName, 'photo.jpg');
      expect(result.first.attachments.first.mimeType, 'image/jpeg');
    });
  });

  // ─────────────────────── getLatestMessages ─────────────────────────

  group('getLatestMessages', () {
    test('returns last N messages in chronological order', () async {
      // The repo fetches descending and reverses — the fake just resolves
      // whatever data is pre‐configured.
      final fakeData = [
        messageJson(id: 'msg-3', text: 'Третье'),
        messageJson(id: 'msg-2', text: 'Второе'),
        messageJson(id: 'msg-1', text: 'Первое'),
      ];

      when(() => mockClient.from('chat_messages'))
          .thenAnswer((_) => FakeQueryBuilder(fakeData));

      final result = await repo.getLatestMessages(orderId: 'ord-1', count: 3);

      // The repo reverses the descending fetch for chronological order.
      expect(result.length, 3);
      expect(result.last.id, 'msg-3');
    });
  });

  // ─────────────────────── sendMessage ───────────────────────────────

  group('sendMessage', () {
    test('returns the sent message', () async {
      final insertedMsg = messageJson(id: 'msg-new', text: 'Новое сообщение');

      when(() => mockClient.from('chat_messages'))
          .thenAnswer((_) => FakeQueryBuilder([insertedMsg]));

      final result = await repo.sendMessage(
        orderId: 'ord-1',
        senderId: 'user-1',
        text: 'Новое сообщение',
      );

      expect(result.id, 'msg-new');
      expect(result.text, 'Новое сообщение');
      expect(result.senderName, 'Test User');
    });
  });
}
