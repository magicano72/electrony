import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatModel {
  final int id;
  final String title;
  final String? lastMessage;
  final String? lastMessageTime;
  final DateTime? timestamp;
  final DateTime? chatCreationDate;
  final String? avatarUrl;
  final String? relatedDocument; // New field for related document
  final int unseenCount;
  ChatModel({
    required this.id,
    required this.title,
    this.lastMessage,
    this.lastMessageTime,
    this.timestamp,
    this.chatCreationDate,
    this.avatarUrl,
    this.relatedDocument,
    this.unseenCount = 0,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    DateTime? creationDate;
    if (json['created_at'] != null) {
      creationDate = DateTime.parse(json['created_at']);
    }

    String? avatarUrl;
    if (json['avatar'] != null) {
      avatarUrl = "${dotenv.env['API_BASE_URL']}/assets/${json['avatar']}";
    }

    return ChatModel(
      id: json['id'],
      title: json['chat_title'] ?? 'Untitled Chat',
      lastMessage: json['text'] ?? 'No messages yet',
      lastMessageTime: json['created_at'] ?? '',
      timestamp: creationDate,
      chatCreationDate: creationDate,
      avatarUrl: avatarUrl,
      relatedDocument: json['related_document'], // Add related document
    );
  }
}
