class ChatMessage {
  final int id;
  final String sender;
  final String? receiver;
  final String? text;
  final DateTime timestamp;
  final String type;
  final String? imageUrl;
  final String? fileUrl;
  final String? audioUrl;
  String? senderEmail;
  String? receiverEmail;
  String? senderAvatarUrl;
  String? receiverAvatarUrl;
  String status;
  List<MessageSeenBy> seenBy; // Add this field

  ChatMessage({
    required this.id,
    required this.sender,
    this.receiver,
    this.text,
    required this.timestamp,
    required this.type,
    this.imageUrl,
    this.fileUrl,
    this.audioUrl,
    this.senderEmail,
    this.receiverEmail,
    this.senderAvatarUrl,
    this.receiverAvatarUrl,
    this.status = 'sent',
    this.seenBy = const [], // Initialize as empty list
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    List<MessageSeenBy> seenByList = [];

    // Parse the seen_by array if it exists
    if (json['seen_by'] != null && json['seen_by'] is List) {
      seenByList = (json['seen_by'] as List)
          .map((item) => MessageSeenBy.fromJson(item))
          .toList();
    }

    return ChatMessage(
      id: json['id'],
      sender: json['sender'],
      receiver: json['receiver'],
      text: json['text'],
      timestamp: DateTime.parse(json['timestamp']),
      type: json['type'],
      imageUrl: json['image_url'],
      fileUrl: json['file_url'],
      audioUrl: json['audio_url'],
      status: json['status'] ?? 'sent',
      seenBy: seenByList, // Add seen_by list
    );
  }
}

// Create a new class for the seen_by data
class MessageSeenBy {
  final int id;
  final int messageId;
  final DateTime seenAt;
  final UserInfo user;

  MessageSeenBy(
      {required this.id,
      required this.messageId,
      required this.seenAt,
      required this.user});

  factory MessageSeenBy.fromJson(Map<String, dynamic> json) {
    return MessageSeenBy(
      id: json['id'],
      messageId: json['message_id'],
      seenAt: DateTime.parse(json['seen_at']),
      user: UserInfo.fromJson(json['user_id']),
    );
  }
}

// Create a class for user info
class UserInfo {
  final String id;
  final String firstName;
  final String lastName;
  final String? avatar;

  UserInfo({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.avatar,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      avatar: json['avatar'],
    );
  }

  String get fullName => '$firstName $lastName';
}
