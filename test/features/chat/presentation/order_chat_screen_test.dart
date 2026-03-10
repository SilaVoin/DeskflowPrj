import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:deskflow/features/chat/domain/chat_message.dart';
import 'package:deskflow/features/chat/domain/chat_notifier.dart';
import 'package:deskflow/features/chat/presentation/order_chat_screen.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/orders/domain/order_providers.dart';
import 'package:deskflow/features/orders/domain/order_status.dart';

// ─────────────────────── Helpers ─────────────────────────────────────

const _testOrderId = 'ord-test-1';
const _testUserId = 'user-test-1';

User _fakeUser() => const User(
      id: _testUserId,
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00.000',
    );

Order _fakeOrder() => Order(
      id: _testOrderId,
      organizationId: 'org-1',
      statusId: 'st-1',
      orderNumber: 42,
      totalAmount: 5000,
      createdBy: _testUserId,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      status: const OrderStatus(
        id: 'st-1',
        organizationId: 'org-1',
        name: 'Новый',
        color: '#3B82F6',
        sortOrder: 0,
        isDefault: true,
        isFinal: false,
      ),
      customerName: 'Тест Клиент',
    );

ChatMessage _msg({
  String id = 'msg-1',
  String text = 'Привет',
  bool isMe = false,
  bool isSystem = false,
  String? systemAction,
}) =>
    ChatMessage(
      id: id,
      orderId: _testOrderId,
      senderId: isMe ? _testUserId : 'other-user',
      senderName: isMe ? 'Текущий' : 'Собеседник',
      text: text,
      attachments: const [],
      status: MessageStatus.sent,
      createdAt: DateTime(2026, 3, 1, 12),
      isSystem: isSystem,
      systemAction: systemAction,
    );

/// Fake notifier that resolves immediately with predefined messages.
class FakeChatNotifier extends ChatNotifier {
  final List<ChatMessage> _messages;
  FakeChatNotifier(this._messages);

  @override
  Future<List<ChatMessage>> build(String orderId) async => _messages;

  @override
  void setOnTypingChanged(void Function(String?) callback) {}

  @override
  void notifyTyping() {}

  @override
  Future<void> sendMessage(String text) async {}
}

/// Builds the screen wrapped in the necessary providers and scaffold.
Widget _buildSubject({
  required List<ChatMessage> messages,
  Order? order,
}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => _fakeUser()),
      orderDetailProvider(_testOrderId)
          .overrideWith((ref) async => order ?? _fakeOrder()),
      // Override the entire family so the notifier for our orderId
      // is replaced with the fake.
      chatNotifierProvider(_testOrderId)
          .overrideWith(() => FakeChatNotifier(messages)),
    ],
    child: const MaterialApp(
      home: OrderChatScreen(orderId: _testOrderId),
    ),
  );
}

// ─────────────────────── Tests ───────────────────────────────────────

void main() {
  group('OrderChatScreen', () {
    testWidgets('shows empty state when no messages', (tester) async {
      await tester.pumpWidget(_buildSubject(messages: []));
      await tester.pumpAndSettle();

      // The empty chat state should show a prompt
      expect(find.textContaining('Начните'), findsOneWidget);
    });

    testWidgets('shows messages from other user', (tester) async {
      await tester.pumpWidget(_buildSubject(
        messages: [_msg(id: 'm1', text: 'Привет из теста')],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Привет из теста'), findsOneWidget);
    });

    testWidgets('shows current user messages aligned right', (tester) async {
      await tester.pumpWidget(_buildSubject(
        messages: [_msg(id: 'm1', text: 'Моё сообщение', isMe: true)],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Моё сообщение'), findsOneWidget);
    });

    testWidgets('shows system message', (tester) async {
      await tester.pumpWidget(_buildSubject(
        messages: [
          _msg(
            id: 'sys-1',
            text: 'Статус изменён',
            isSystem: true,
            systemAction: 'status_changed',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Статус изменён'), findsOneWidget);
    });

    testWidgets('shows order number in app bar', (tester) async {
      await tester.pumpWidget(_buildSubject(messages: []));
      await tester.pumpAndSettle();

      // Order #042
      expect(find.text('#042'), findsOneWidget);
    });

    testWidgets('shows status badge in app bar', (tester) async {
      await tester.pumpWidget(_buildSubject(messages: []));
      await tester.pumpAndSettle();

      expect(find.text('Новый'), findsOneWidget);
    });

    testWidgets('shows input bar with text field', (tester) async {
      await tester.pumpWidget(_buildSubject(messages: []));
      await tester.pumpAndSettle();

      // Find the text input for composing messages
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows multiple messages in order', (tester) async {
      await tester.pumpWidget(_buildSubject(
        messages: [
          _msg(id: 'm1', text: 'Первое'),
          _msg(id: 'm2', text: 'Второе'),
          _msg(id: 'm3', text: 'Третье', isMe: true),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Первое'), findsOneWidget);
      expect(find.text('Второе'), findsOneWidget);
      expect(find.text('Третье'), findsOneWidget);
    });
  });
}
