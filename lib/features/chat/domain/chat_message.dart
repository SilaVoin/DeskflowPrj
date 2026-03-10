/// Message status for optimistic UI.
enum MessageStatus { sending, sent, error }

/// Attachment model for chat messages.
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

  /// Whether this attachment is an image.
  bool get isImage =>
      mimeType.startsWith('image/') ||
      fileName.endsWith('.jpg') ||
      fileName.endsWith('.jpeg') ||
      fileName.endsWith('.png') ||
      fileName.endsWith('.gif') ||
      fileName.endsWith('.webp');

  /// Human-readable file size.
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'file_name': fileName,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
      };
}

/// Chat message domain model.
class ChatMessage {
  final String id;
  final String orderId;
  final String senderId;
  final String? senderName;
  final String? text;
  final List<Attachment> attachments;
  final MessageStatus status;
  final DateTime createdAt;

  /// Whether this is a system message (status change, item added, etc.)
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

  /// Display initials for the sender avatar.
  String get senderInitials {
    if (senderName == null || senderName!.isEmpty) return '?';
    final parts = senderName!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  /// Create a copy with updated status (for optimistic UI).
  ChatMessage copyWith({MessageStatus? status, String? id}) {
    return ChatMessage(
      id: id ?? this.id,
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

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Parse sender name from joined profiles
    String? senderName;
    if (json['profiles'] != null) {
      senderName =
          (json['profiles'] as Map<String, dynamic>)['full_name'] as String?;
    }

    // Parse attachments
    List<Attachment> attachments = [];
    if (json['chat_attachments'] != null) {
      attachments = (json['chat_attachments'] as List)
          .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return ChatMessage(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: senderName ?? json['sender_name'] as String?,
      text: json['text'] as String?,
      attachments: attachments,
      status: MessageStatus.sent,
      createdAt: DateTime.parse(json['created_at'] as String),
      isSystem: json['is_system'] as bool? ?? false,
      systemAction: json['system_action'] as String?,
    );
  }
}
