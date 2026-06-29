// activity_model.dart
import 'package:flutter/material.dart';

class Activity {
  final String id;
  final String userId;
  final DateTime createdAt;
  final Map<String, dynamic>? signedDocument;
  final Map<String, dynamic>? transaction;

  Activity({
    required this.id,
    required this.userId,
    required this.createdAt,
    this.signedDocument,
    this.transaction,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      createdAt: DateTime.parse(
          json['created_at']?.toString() ?? DateTime.now().toString()),
      signedDocument: json['signed_document'] is Map
          ? Map<String, dynamic>.from(json['signed_document'])
          : null,
      transaction: json['transactions'] is Map
          ? Map<String, dynamic>.from(json['transactions'])
          : null,
    );
  }

  // Helper getters
  IconData get icon {
    if (signedDocument != null) return Icons.description;
    if (transaction != null) return Icons.attach_money;
    return Icons.history;
  }

  String get title {
    if (signedDocument != null) {
      return 'Signed: ${signedDocument!['created_file']?['title'] ?? 'Document'}';
    } else if (transaction != null) {
      return 'Transaction: ${transaction!['amount']} ECP';
    }
    return 'Activity';
  }

  String get timeString {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year} • ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  Color get iconBackgroundColor {
    if (signedDocument != null) return Color(0xffE0F1FF);
    if (transaction != null) return Color(0xffE1FFEA);
    return Colors.grey.shade100;
  }

  Color get iconColor {
    if (signedDocument != null) return Color(0xff3F90C3);
    if (transaction != null) return Color(0xff16A34A);
    return Colors.grey.shade100;
  }
}

class SignedDocument {
  final String id;
  final DateTime createdAt;
  final String userId;
  final String status;
  final List<int> signer;
  final CreatedFile createdFile;

  SignedDocument({
    required this.id,
    required this.createdAt,
    required this.userId,
    required this.status,
    required this.signer,
    required this.createdFile,
  });

  factory SignedDocument.fromJson(Map<String, dynamic> json) {
    return SignedDocument(
      id: json['id'].toString(),
      createdAt: DateTime.parse(json['created_at']),
      userId: json['user_id'],
      status: json['status'],
      signer: List<int>.from(json['signer']),
      createdFile: CreatedFile.fromJson(json['created_file']),
    );
  }
}

class CreatedFile {
  final String title;

  CreatedFile({required this.title});

  factory CreatedFile.fromJson(Map<String, dynamic> json) {
    return CreatedFile(
      title: json['title'],
    );
  }
}

class Transaction {
  final String id;
  final String type;
  final DateTime createdAt;
  final String sender;
  final String receiver;
  final double amount;
  final String status;
  final String? document;

  Transaction({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.sender,
    required this.receiver,
    required this.amount,
    required this.status,
    this.document,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'].toString(),
      type: json['type'],
      createdAt: DateTime.parse(json['created_at']),
      sender: json['sender'],
      receiver: json['receiver'],
      amount: json['amount']?.toDouble() ?? 0.0,
      status: json['status'],
      document: json['document'],
    );
  }
}
