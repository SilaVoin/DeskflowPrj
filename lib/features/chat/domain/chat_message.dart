enum MessageStatus {
  sending,
  sent,
  error,
}

class Attachment {
  final String id;
  final String url;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  const Attachment({
    required this.id,
    required this.url,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
  });

  bool get isImage => mimeType.startsWith('image/');

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes \u0411';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} \u041a\u0411';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} \u041c\u0411';
  }

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] as String,
      url: json['url'] as String,
      fileName: json['file_name'] as String,
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      sizeBytes: json['size_bytes'] as int? ?? 0,
    );
  }
}

class ChatMessage {
  final String id;
  final String orderId;
  final String senderId;
  final String? senderName;
  final String? text;
  final List<Attachment> attachments;
  final MessageStatus status;
  final DateTime createdAt;
  final bool isSystem;
  final String? systemAction;

  const ChatMessage({
    required this.id,
    required this.orderId,
    required this.senderId,
    this.senderName,
    this.text,
    this.attachments = const [],
    this.status = MessageStatus.sent,
    required this.createdAt,
    this.isSystem = false,
    this.systemAction,
  });

  String get senderInitials {
    if (senderName == null || senderName!.isEmpty) return '?';
    final parts = senderName!.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    String? senderName;
    if (json['profiles'] != null) {
      final profile = json['profiles'] as Map<String, dynamic>;
      senderName = profile['full_name'] as String?;
    }
    senderName ??= '\u041f\u043e\u043b\u044c\u0437\u043e\u0432\u0430\u0442\u0435\u043b\u044c';

    List<Attachment> attachments = const [];
    if (json['chat_attachments'] != null) {
      attachments = (json['chat_attachments'] as List)
          .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return ChatMessage(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: senderName,
      text: json['text'] as String?,
      attachments: attachments,
      status: MessageStatus.sent,
      createdAt: DateTime.parse(json['created_at'] as String),
      isSystem: json['is_system'] as bool? ?? false,
      systemAction: json['system_action'] as String?,
    );
  }

  ChatMessage copyWith({MessageStatus? status}) {
    return ChatMessage(
      id: id,
      orderId: orderId,
      senderId: senderId,
      senderName: senderName,
      text: text,
      attachments: attachments,
      status: status ?? this.status,
      createdAt: createdAt,
      isSystem: isSystem,
      systemAction: systemAction,
    );
  }
}
