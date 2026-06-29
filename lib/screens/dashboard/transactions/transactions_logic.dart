import 'dart:async';
import 'dart:convert';

import 'package:Electrony/networking/api_services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

// Transaction model
class Transaction {
  final int id;
  final String type;
  final String createdAt;
  final dynamic sender; // can be String (id) or Map (user object)
  final dynamic receiver; // can be String (id) or Map (user object)
  final int amount;
  final String status;
  final int? document;

  Transaction({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.sender,
    this.receiver,
    required this.amount,
    required this.status,
    this.document,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      type: json['type'],
      createdAt: json['created_at'],
      sender: json['sender'],
      receiver: json['receiver'],
      amount: json['amount'],
      status: json['status'],
      document: json['document'],
    );
  }

  String? get senderName {
    if (sender is Map && sender['first_name'] != null) {
      return ((sender['first_name'] ?? '') + ' ' + (sender['last_name'] ?? ''))
          .trim();
    }
    return null;
  }

  String? get receiverName {
    if (receiver is Map && receiver['first_name'] != null) {
      return ((receiver['first_name'] ?? '') +
              ' ' +
              (receiver['last_name'] ?? ''))
          .trim();
    }
    return null;
  }

  String? get receiverId {
    if (receiver is Map && receiver['id'] != null) {
      return ((receiver['id'] ?? '')).trim();
    }
    return null;
  }
}

// Transaction service
class TransactionService {
  // Replace with your Directus API URL and access token
  final authApiService =
      AuthApiService(baseUrl: dotenv.env['API_BASE_URL'] ?? '');

  Future<List<Transaction>> fetchUserTransactions() async {
    String? token = await authApiService.getValidToken();
    final userId = JwtDecoder.decode(token!)['id'];
    if (userId == null)
      throw Exception("Failed to extract user ID from token.");

    final url = Uri.parse(
        '${dotenv.env['API_BASE_URL']}/items/point_transactions'
        '?filter[_or][0][sender][_eq]=$userId'
        '&filter[_or][1][receiver][_eq]=$userId'
        '&sort=-created_at'
        '&limit=10'
        '&fields=*,sender.first_name,sender.last_name,receiver.id,receiver.first_name,receiver.last_name');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        print('Fetched transactions: ${jsonData['data']}');
        final List<dynamic> data = jsonData['data'];
        return data.map((json) => Transaction.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load transactions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching transactions: $e');
    }
  }
}
