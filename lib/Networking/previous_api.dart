import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Electrony/Custom/snacbar.dart';
import 'package:Electrony/models/sign_model.dart';
import 'package:Electrony/networking/api_error_handler.dart';
import 'package:Electrony/screens/chat/chat_logic/add_to_existing_chat.dart';
import 'package:Electrony/theming/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthApiService {
  final String baseUrl;

  AuthApiService({required this.baseUrl});
  final storage = FlutterSecureStorage();

  Future<void> storeToken(String token) async {
    await storage.write(key: 'authToken', value: token);
    print("Token stored: $token");
  }

  Future<String> getValidToken() async {
    String? token = await getToken();

    if (token == null || isTokenExpired(token)) {
      print("Token is expired or missing, attempting to refresh...");
      token = await refreshToken();
      if (token == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }
    return token;
  }

  Future<void> renameDocument(String documentId, String newName) async {
    try {
      String? token = await getToken();

      if (token == null || isTokenExpired(token)) {
        print("Token is expired or missing, attempting to refresh...");
        token = await refreshToken();
        if (token == null) {
          throw Exception("Failed to refresh token. Please log in again.");
        }
      }

      // Get the file ID from the docs collection
      final docUrl = Uri.parse('$baseUrl/items/docs/$documentId');
      final docResponse = await http.get(
        docUrl,
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      if (docResponse.statusCode != 200) {
        throw Exception('Failed to fetch document details');
      }

      final docData = json.decode(docResponse.body);
      final fileId = docData['data']['created_file'];

      if (fileId == null) {
        throw Exception('No file ID found');
      }

      // Update the file directly in the files collection
      final updateUrl = Uri.parse('$baseUrl/files/$fileId');
      final response = await http.patch(
        updateUrl,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body:
            json.encode({"title": newName, "type": "application/octet-stream"}),
      );

      if (response.statusCode != 200) {
        print('Failed to rename document. Status: ${response.statusCode}');
        print('Response: ${response.body}');
        throw Exception('Failed to rename document');
      }
    } catch (e) {
      print('Error renaming document: $e');
      throw e;
    }
  }

  bool isTokenExpired(String? token) {
    if (token == null || token.isEmpty) return true;
    try {
      final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      final int? expirationTimestamp = decodedToken['exp'];

      if (expirationTimestamp == null) return true;

      final DateTime expirationDate =
          DateTime.fromMillisecondsSinceEpoch(expirationTimestamp * 1000);
      final DateTime now = DateTime.now();

      // Add a 5-minute buffer before actual expiration
      final bool isExpired =
          now.isAfter(expirationDate.subtract(Duration(minutes: 5)));

      if (isExpired) {
        print(
            "Token will expire soon or has expired. Expiration date: $expirationDate");
      }

      return isExpired;
    } catch (e) {
      print("Error decoding token: $e");
      // Only delete tokens if there's a serious decoding error
      if (e.toString().contains("Invalid token")) {
        storage.delete(key: 'accessToken');
        storage.delete(key: 'refreshToken');
        storage.delete(key: 'expiry');
      }
      return true;
    }
  }

  Future<String?> getToken() async {
    final storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'accessToken');

    if (token == null || token.isEmpty) {
      print("Token is null or empty.");
      return null;
    }

    try {
      if (isTokenExpired(token)) {
        print("Token is expired.");

        await refreshToken();
        return null;
      }
    } catch (e) {
      print("Error checking token expiration: $e");
      return null;
    }

    print("Retrieved token: $token");
    return token;
  }

  Future<Map<String, dynamic>> requestRegisteredOtp(String emailOrPhone) async {
    try {
      final url = Uri.parse('${dotenv.env['API_BASE_URL']}/auth/otp/request');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'emailOrPhone': emailOrPhone}),
      );

      final result = ApiErrorHandler.processApiResponse(response);

      if (result['success']) {
        print('Response: ${result['data']}');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('otp_token', result['data']['token']);
        return result['data'];
      } else {
        throw result['message'];
      }
    } catch (e) {
      throw ApiErrorHandler.handleException(e);
    }
  }

  Future<Map<String, dynamic>> requestRestOtp(String emailOrPhone) async {
    final url = Uri.parse(
        '${dotenv.env['API_BASE_URL']}/auth/otp/request-password-reset');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'emailOrPhone': emailOrPhone}),
    );
    final Map<String, dynamic> data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      print('Response: $data');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('otp_token', data['token']);
      return data;
    } else {
      throw ('${data['extensions'] ?? 'Unknown error'}');
    }
  }

  Future<void> resetPassword(String token, String password, String otp) async {
    final storage = FlutterSecureStorage(); // ✅ secure storage instance

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/otp/password-reset'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'token': token,
              'password': password,
              'otp': otp,
            }),
          )
          .timeout(Duration(seconds: 10));

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ Password updated successfully.");
        print('Response: $data');
      } else {
        throw ('${data['extensions'] ?? 'Unknown error'}');
      }
    } catch (e) {
      throw ApiErrorHandler.handleException(e);
    }
  }

  // Login request (email and password only)
  Future<void> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/otp/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'emailOrPhone': email, 'password': password}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['data'] != null) {
        print("Login successful: ${response.body}");
        final token = data['data']['accessToken'];
        final refreshToken = data['data']['refreshToken'];
        final expiry = data['data']['expiry'].toString();
        print(token);
        print(refreshToken);
        // Store tokens securely
        await storage.write(key: 'accessToken', value: token);
        await storage.write(key: 'refreshToken', value: refreshToken);
        await storage.write(key: 'expiry', value: expiry);
      } else {
        // Parse and throw error message from the response
        final errorMessage =
            data['extensions'] != null && data['extensions'].isNotEmpty
                ? data['extensions']
                : 'Invalid email or password.';
        throw (errorMessage);
      }
    } catch (e) {
      print("Error during login: $e");

      throw ApiErrorHandler.handleException(e);
    }
  }

  Future<void> register(String password, String first_name, String last_name,
      String token, String otp) async {
    final storage = FlutterSecureStorage(); // ✅ secure storage instance

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/otp/signup'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'password': password,
              'first_name': first_name,
              'last_name': last_name,
              'token': token,
              'otp': otp,
            }),
          )
          .timeout(Duration(seconds: 10));

      final data = jsonDecode(response.body);
      print("Registration Response: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ User registered successfully.");

        final accessToken = data['data']['accessToken'];
        final refreshToken = data['data']['refreshToken'];
        final expiry = data['data']['expiry'].toString();

        await storage.write(key: 'accessToken', value: accessToken);
        await storage.write(key: 'refreshToken', value: refreshToken);
        await storage.write(key: 'expiry', value: expiry);
/* 
To read those values later:
final storage = FlutterSecureStorage();
String? token = await storage.read(key: 'access_token');
String? refreshToken = await storage.read(key: 'refresh_token');
String? expiry = await storage.read(key: 'expiry');
*/
        print("🔐 Tokens saved to secure storage.");
      } else {
        String errorMessage = data['extensions'] != null
            ? data['extensions']
            : 'An unknown error occurred.';
        print("❌ Failed to register");
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw ApiErrorHandler.handleException(e);
    }
  }

  Future<void> addUserEmail(String email, String birth) async {
    String? accessToken = await getToken();

    if (accessToken == null || isTokenExpired(accessToken)) {
      print("Token is expired or missing, attempting to refresh...");
      accessToken = await refreshToken();
      if (accessToken == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }

    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl/users/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({
              'email': email,
              'birth_date': birth,
            }),
          )
          .timeout(Duration(seconds: 10));
      print(birth);
      print(email);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        print("Registration Response: ${response.body}");
        print("✅ User registered successfully.");
        return;
      } else {
        String errorMessage =
            data['errors']?[0]?['message'] ?? 'An unknown error occurred.';
        print("❌ Failed to register");
        throw Exception(errorMessage);
      }
    } catch (e) {
      print("❗ Unexpected error: $e");
      throw Exception("Error during registration: $e");
    }
  }

  Future<void> addUserStatus(String status) async {
    String? accessToken = await getToken();

    if (accessToken == null || isTokenExpired(accessToken)) {
      print("Token is expired or missing, attempting to refresh...");
      accessToken = await refreshToken();
      if (accessToken == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }

    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl/users/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({
              'status': status,
            }),
          )
          .timeout(Duration(seconds: 10));
      print(status);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        print("Registration Response: ${response.body}");
        print("✅ User registered successfully.");
        return;
      } else {
        String errorMessage =
            data['errors']?[0]?['message'] ?? 'An unknown error occurred.';
        print("❌ Failed to register");
        throw Exception(errorMessage);
      }
    } catch (e) {
      print("❗ Unexpected error: $e");
      throw Exception("Error during registration: $e");
    }
  }

  Future<String?> refreshToken() async {
    final storage = FlutterSecureStorage();
    String? refreshToken = await storage.read(key: 'refreshToken');

    if (refreshToken == null) {
      print("No refresh token available");
      await storage.delete(key: 'accessToken');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['data'] != null) {
        final accessToken = data['data']['access_token'];
        final newRefreshToken = data['data']['refresh_token'];
        final expiry = data['data']['expires'].toString();

        await storage.write(key: 'accessToken', value: accessToken);
        await storage.write(key: 'refreshToken', value: newRefreshToken);
        await storage.write(key: 'expiry', value: expiry);

        print("Token refreshed successfully");
        return accessToken;
      }

      print("Failed to refresh token: ${response.body}");
      // Clear tokens on refresh failure
      await storage.delete(key: 'accessToken');
      await storage.delete(key: 'refreshToken');
      await storage.delete(key: 'expiry');
    } catch (e) {
      print("Error during token refresh: $e");
      await storage.delete(key: 'accessToken');
      await storage.delete(key: 'refreshToken');
      await storage.delete(key: 'expiry');
    }
    return null;
  }

  Future<void> logout() async {
    try {
      final refreshToken = await storage.read(key: 'refreshToken');

      if (refreshToken == null) {
        throw Exception('No refresh token found. Please login again.');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Logout successful, clear tokens
        await storage.delete(key: 'accessToken');
        await storage.delete(key: 'refreshToken');
        await storage.delete(key: 'expiry');
        print("Logout successful");
      } else if (response.body.isNotEmpty) {
        // Handle error details if the body exists
        final data = jsonDecode(response.body);
        final errorMessage = data['errors'] != null && data['errors'].isNotEmpty
            ? data['errors'][0]['message']
            : 'Failed to log out.';
        throw Exception(errorMessage);
      } else {
        // Handle unexpected or empty error responses
        throw Exception('Unexpected server response.');
      }
    } catch (e) {
      print("Error during logout: $e");
      if (e is SocketException) {
        throw Exception('Network error. Please check your connection.');
      } else if (e is TimeoutException) {
        throw Exception('Request timed out. Please try again later.');
      } else {
        throw Exception('An unexpected error occurred.');
      }
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    String? token = await getToken();

    if (token == null || isTokenExpired(token)) {
      print("Token is expired or missing, attempting to refresh...");
      token = await refreshToken();
      if (token == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      print("Profile response: ${response.body}");

      if (response.statusCode == 200) {
        return data['data'] ?? {};
      } else {
        throw Exception(
            "Failed to load user profile: ${data['errors']?[0]?['message'] ?? 'Unknown error'}");
      }
    } catch (e) {
      print("Error fetching profile: $e");
      throw Exception("Error fetching profile: $e");
    }
  }

  Future<String> getUserId() async {
    String? token = await getToken();

    if (token == null || isTokenExpired(token)) {
      print("Token is expired or missing, attempting to refresh...");
      token = await refreshToken();
      if (token == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }
    // print(JwtDecoder.decode(token!)['id']);
    return JwtDecoder.decode(token)['id'];
  }

  Future<void> saveUserDocumentRecords(List<String> fileIds) async {
    if (fileIds.isEmpty) throw Exception('No file IDs to save.');

    String? token = await getToken();
    if (token == null || isTokenExpired(token)) {
      print("Token is expired or missing, attempting to refresh...");
      token = await refreshToken();
      if (token == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }
    final userId = JwtDecoder.decode(token)['id'];
    if (userId == null) throw Exception('Invalid token: No user ID found.');

    final createArray = fileIds.map((fileId) {
      return {
        "directus_users_id": userId,
        "directus_files_id": fileId // Simplified structure
      };
    }).toList();

    final body = json.encode({
      'verification_documents': {
        'create': createArray,
        'update': [],
        'delete': []
      }
    });
    print('Save request body: $body');

    final response = await http.patch(
      Uri.parse('$baseUrl/users/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    print('Save response: ${response.statusCode} - ${response.body}');
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to save documents: ${response.statusCode} - ${response.body}');
    }
  }

  Future<String> uploadProfileImage(File imageFile) async {
    String? token = await getToken();

    if (token == null || isTokenExpired(token)) {
      print("Token is expired or missing, attempting to refresh...");
      token = await refreshToken();
      if (token == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }
    try {
      final uri = Uri.parse('$baseUrl/files');
      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      var stream = http.ByteStream(imageFile.openRead());
      var length = await imageFile.length();
      var multipartFile = http.MultipartFile(
        'file',
        stream,
        length,
        filename: basename(imageFile.path),
      );

      request.files.add(multipartFile);
      var response = await request.send();

      if (response.statusCode == 200) {
        var responseData = await http.Response.fromStream(response);
        var jsonResponse = json.decode(responseData.body);
        print('Upload response: $jsonResponse'); // Debugging line
        return jsonResponse['data']
            ['id']; // Make sure this matches the response structure
      } else {
        final responseData = await response.stream.bytesToString();
        print(
            'Upload failed with status: ${response.statusCode}, response: $responseData');
        throw Exception('Failed to upload profile image: ${responseData}');
      }
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Error uploading image: $e');
    }
  }

  Future<void> updateUserProfileImage(String imageFileId) async {
    String? token = await getToken();

    if (token == null || isTokenExpired(token)) {
      print("Token is expired or missing, attempting to refresh...");
      token = await refreshToken();
      if (token == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }
    final response = await http.patch(
      Uri.parse('$baseUrl/users/me'), // Update the current user's profile
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'avatar': imageFileId, // Use the correct field name for the avatar
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update profile image');
    }
  }

  Future<void> updateUserVerificationImage(String imageFileId) async {
    String? token = await getToken();

    if (token == null || isTokenExpired(token)) {
      print("Token is expired or missing, attempting to refresh...");
      token = await refreshToken();
      if (token == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }
    final response = await http.patch(
      Uri.parse('$baseUrl/users/me'), // Update the current user's profile
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'user_face': imageFileId, // Use the correct field name for the avatar
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update profile image');
    }
  }

  Future<void> sendSignatureData({
    required File pdfFile,
    required String userEmail,
    required List<SignModel> signModelList,
    String? status,
    BuildContext? context,
  }) async {
    final url = Uri.parse('$baseUrl/items/docs');

    try {
      // Upload the file and get the file ID
      final fileIds = await uploadFile([pdfFile]);
      final fileId = fileIds.firstOrNull;
      if (fileId == null) {
        throw Exception('No file ID returned from upload');
      }

      String? token = await getValidToken();
      if (token == null) {
        throw Exception('Failed to retrieve a valid token');
      }

      // Fetch the user's ID using their email
      final userId = JwtDecoder.decode(token)['id'];
      if (userId == null) {
        throw Exception('Failed to extract user ID from token');
      }

      // Construct the document payload
      final Map<String, dynamic> body = {
        'signer': {
          'create': signModelList.map((item) {
            return {
              'signer_id': {
                'status': item.status,
                'x_offset': item.xOffset,
                'y_offset': item.yOffset,
                'contriputer_email': item.contributorEmail,
                'sign': item.signatureText ?? '',
                'user_id': userId,
                'current_page': item.currentPage,
                'type': item.type.name,
                'signature_id': item.signatureId ?? null,
              },
            };
          }).toList(),
        },
        'status': status,
        'created_file': fileId,
        'user_id': userId,
      };

      // Debug: Print the document payload
      print('Document Payload: $body');

      // Send the document creation request
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      // Debug: Print the document response
      print('Document Response Status Code: ${response.statusCode}');
      print('Document Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final documentId = responseData['data']['id'];
        if (documentId == null) {
          throw Exception('Failed to retrieve document ID from response');
        }

        print('Data sent successfully: ${response.body}');

        // Fetch the signature fee
        final feeResponse = await http.get(
          Uri.parse('$baseUrl/items/signature_fee'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        );
        if (feeResponse.statusCode != 200) {
          throw Exception('Failed to fetch signature fee: ${feeResponse.body}');
        }
        final feeData = json.decode(feeResponse.body);
        final int fee = feeData['data']['fee'] ?? 0;

        // Create a transaction record with the correct payload structure
        final transactionBody = {
          'type': 'signature',
          'sender': userId,
          'receiver': null,
          'amount': fee,
          'status': 'success',
          'document': documentId, // Numeric document ID
        };
        final transactionResponse = await http.post(
          Uri.parse('$baseUrl/items/point_transactions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(transactionBody),
        );
        print('Transaction Body: $transactionBody');
        print(
            'Transaction Response Status Code: ${transactionResponse.statusCode}');
        print('Transaction Response Body: ${transactionResponse.body}');
        final activityBody = {'user_id': userId, 'signed_document': documentId};
        final activityResponse = await http.post(
          Uri.parse('$baseUrl/items/activity'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(activityBody),
        );
        print('Activity Body: $activityBody');
        if (transactionResponse.statusCode != 200 &&
            transactionResponse.statusCode != 201) {
          throw Exception(
              'Failed to create Activity record: ${activityResponse.statusCode} - ${activityResponse.body}');
        }

        // Only proceed with chat dialog if context is valid
        if (context != null && context.mounted) {
          final String documentName = pdfFile.path.split('/').last;
          final result = await showDocumentChatDialog(context, documentName);
          print('Chat Dialog Result: $result');

          if (result != null) {
            if (result['action'] == 'create_new') {
              // Create a new chat
              await _createNewChat(
                  token, userId, fileId, documentName, signModelList);
            } else if (result['action'] == 'add_to_existing') {
              // Navigate to chat list for selection
              final selectedChatId = await Navigator.push<int>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ChatListSelectionScreen(documentId: fileId),
                ),
              );

              if (selectedChatId != null) {
                // Link document to the selected chat
                await _linkDocumentToExistingChat(
                    token, selectedChatId, fileId);
                // Add participants to the selected chat
                await _addParticipantsToChat(
                    token, selectedChatId, signModelList);
              } else {
                print('No chat selected for linking');
              }
            }
          } else {
            print('User cancelled the chat creation');
          }
        } else {
          print('Context is null or not mounted, skipping chat dialog');
        }
      } else {
        print('Failed to send document data: ${response.statusCode}');
        print('Document Response: ${response.body}');
        throw Exception('Failed to send document data: ${response.body}');
      }
    } catch (e) {
      print('Error occurred while sending data: $e');
      if (context != null && context.mounted) {
        showCustomSnackBar(context, 'Failed to submit document: $e',
            isError: true);
      }
      rethrow;
    }
  }

// Create a new chat for the document
  Future<void> _createNewChat(
    String token,
    String userId,
    String? documentId,
    String chatTitle,
    List<SignModel> signModelList,
  ) async {
    final createChatResponse = await http.post(
      Uri.parse('$baseUrl/items/chats'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: json.encode({
        "chat_title": chatTitle,
        "creator": userId,
        "related_document": documentId
      }),
    );

    if (createChatResponse.statusCode == 200 ||
        createChatResponse.statusCode == 201) {
      final chatData = json.decode(createChatResponse.body)['data'];
      final int chatId = chatData['id'];
      print('✅ Chat created with ID: $chatId');

      // Add participants to the chat
      await _addParticipantsToChat(token, chatId, signModelList);
    } else {
      print('❌ Failed to create chat: ${createChatResponse.body}');
    }
  }

// Link document to an existing chat
  Future<void> _linkDocumentToExistingChat(
    String token,
    int chatId,
    String? documentId,
  ) async {
    if (documentId == null) return;

    final updateChatResponse = await http.patch(
      Uri.parse('$baseUrl/items/chats/$chatId'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: json.encode({"related_document": documentId}),
    );

    if (updateChatResponse.statusCode == 200) {
      print('✅ Document linked to existing chat ID: $chatId');
    } else {
      print('❌ Failed to link document to chat: ${updateChatResponse.body}');
    }
  }

// Add participants from the signature list to the chat
  Future<void> _addParticipantsToChat(
    String token,
    int chatId,
    List<SignModel> signModelList,
  ) async {
    // Collect unique contributor emails to avoid duplicates
    final Set<String> uniqueContributorEmails = {};

    // Extract unique contributor emails from signModelList
    for (var signer in signModelList) {
      if (signer.contributorEmail != null) {
        uniqueContributorEmails.add(signer.contributorEmail!);
      }
    }

    // Add each unique contributor as a participant
    for (var contributorEmail in uniqueContributorEmails) {
      // Fetch user ID by contributor email
      final userResponse = await http.get(
        Uri.parse('$baseUrl/users?filter[email][_eq]=$contributorEmail'),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      if (userResponse.statusCode == 200) {
        final usersData = json.decode(userResponse.body)['data'];
        if (usersData.isNotEmpty) {
          final participantUserId = usersData[0]['id'];

          // Check if user is already a participant
          final existingParticipantResponse = await http.get(
            Uri.parse(
                '$baseUrl/items/chat_participants?filter[chat][_eq]=$chatId&filter[user_id][_eq]=$participantUserId'),
            headers: {
              "Authorization": "Bearer $token",
            },
          );

          if (existingParticipantResponse.statusCode == 200) {
            final existingParticipants =
                json.decode(existingParticipantResponse.body)['data'];

            // Only add if not already a participant
            if (existingParticipants.isEmpty) {
              // Create chat participant
              final participantResponse = await http.post(
                Uri.parse('$baseUrl/items/chat_participants'),
                headers: {
                  "Content-Type": "application/json",
                  "Authorization": "Bearer $token",
                },
                body: json.encode({
                  "chat": chatId,
                  "user_id": participantUserId,
                }),
              );

              if (participantResponse.statusCode == 200 ||
                  participantResponse.statusCode == 201) {
                print('👥 Added participant with user ID: $participantUserId');
              } else {
                print(
                    '❌ Failed to add participant: ${participantResponse.body}');
              }
            } else {
              print(
                  '👤 User $participantUserId is already a participant in chat $chatId');
            }
          }
        }
      } else {
        print('❌ Failed to fetch user for email: $contributorEmail');
      }
    }
  }

// Create a function to show a dialog asking if the user wants to create a chat
  Future<Map<String, dynamic>?> showDocumentChatDialog(
      BuildContext context, String documentName) async {
    bool createNewChat = true;
    bool addToExistingChat = false;

    Map<String, dynamic>? result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with checkmark and close button
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(0xFFE7F9EF),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: Color(0xFF10B981),
                            size: 24,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.close, color: Color(0xFF6B7280)),
                          onPressed: () {
                            Navigator.of(context).pop(null);
                          },
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Title and subtitle
                    Text(
                      'Link document to chat',
                      style: textStyleVersion2(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Do you want to create a new chat for this document?',
                      style: textStyleVersion2(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 16),

                    // Option 1: Create a new chat
                    Row(
                      children: [
                        Text(
                          'Create a new chat',
                          style: textStyleVersion2(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Spacer(),
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: createNewChat,
                            activeColor: Color(0xFF3F90C3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (bool? value) {
                              setState(() {
                                createNewChat = value ?? false;
                                if (createNewChat) {
                                  addToExistingChat = false;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),

                    // Option 2: Add to existing chat
                    Row(
                      children: [
                        Text(
                          'Add to existing chat',
                          style: textStyleVersion2(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Spacer(),
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: addToExistingChat,
                            activeColor: Color(0xFF3F90C3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (bool? value) {
                              setState(() {
                                addToExistingChat = value ?? false;
                                if (addToExistingChat) {
                                  createNewChat = false;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(null);
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Color(0xFFD1D5DB)),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: textStyleVersion2(
                                fontSize: 16,
                                color: Color(0xFF374151),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (addToExistingChat) {
                                // Return a result indicating user wants to select from existing chats
                                Navigator.of(context).pop({
                                  'action': 'add_to_existing',
                                });
                              } else {
                                // Return a result for creating a new chat
                                Navigator.of(context).pop({
                                  'action': 'create_new',
                                  'chat_title': documentName,
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF3F90C3),
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Confirm',
                              style: textStyleVersion2(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return result;
  }

  Future<void> updateSignatureData({
    required List<Signer> signModelList,
    required String documentId,
    required String userEmail,
    String? status,
    bool? isSignedReceiver,
  }) async {
    final url = Uri.parse(
        '$baseUrl/items/docs/$documentId?fields=signer.signer_id.*,status');
    print("Request URL: $url");

    try {
      String? token = await getToken();
      if (token == null) throw Exception("Failed to retrieve token.");

      final userId = JwtDecoder.decode(token)['id'];
      if (userId == null) {
        throw Exception("Failed to extract user ID from token.");
      }

      final Map<String, dynamic> body = {
        "status": status,
        "signer": {
          "create": [],
          "update": signModelList.map((item) {
            return {
              "signer_id": {
                "status": (isSignedReceiver == true &&
                        item.contriputerEmail == userEmail)
                    ? SignerStatus.Submitted.name
                    : item.status,
                "id": item.id,
                if (item.sign != null) "sign": item.sign,
                if (item.signatureId != null) "signature_id": item.signatureId,
                "x_offset": item.xOffset.toString(),
                "y_offset": item.yOffset.toString(),
              },
              "id": (item.id + 6),
            };
          }).toList(),
          "delete": []
        },
      };

      print('Payload: ${jsonEncode(body)}');

      final response = await http.patch(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Data sent successfully: ${response.body}');
        final responseData = json.decode(response.body);

        if (responseData['data'] == null) {
          throw Exception('Unexpected response: missing data field.');
        }

        /// Fetch the signature fee
        final feeResponse = await http.get(
          Uri.parse('$baseUrl/items/signature_fee'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        );
        if (feeResponse.statusCode != 200) {
          throw Exception('Failed to fetch signature fee: ${feeResponse.body}');
        }
        final feeData = json.decode(feeResponse.body);
        final int fee = feeData['data']['fee'] ?? 0;

        /// Create a transaction record
        final transactionBody = {
          'type': 'signature',
          'sender': userId,
          'receiver': null,
          'amount': fee,
          'status': 'success',
          'document': int.tryParse(documentId),
        };

        final transactionResponse = await http.post(
          Uri.parse('$baseUrl/items/point_transactions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(transactionBody),
        );

        print('Transaction Body: $transactionBody');
        print(
            'Transaction Response Status Code: ${transactionResponse.statusCode}');
        print('Transaction Response Body: ${transactionResponse.body}');

        if (transactionResponse.statusCode != 200 &&
            transactionResponse.statusCode != 201) {
          throw Exception(
              'Failed to create transaction record: ${transactionResponse.statusCode} - ${transactionResponse.body}');
        }
      } else {
        print('Failed to send data: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('Error occurred while sending data: $e');
    }
  }

  Future<void> deleteSigner(int signerId) async {
    try {
      String? token = await getToken();
      if (token == null) {
        throw Exception("Failed to retrieve token.");
      }

      final url = Uri.parse('$baseUrl/items/signer/$signerId');

      final response = await http.delete(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token", // Added Authorization
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('Signer deleted successfully.');
      } else {
        print('Failed to delete Signer. Status: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('Error deleting Signer: $e');
    }
  }

  Future<void> deleteSignatureDataDocument(String documentId) async {
    try {
      String? token = await getToken();
      if (token == null) {
        throw Exception("Failed to retrieve token.");
      }

      final url = Uri.parse('$baseUrl/items/docs/$documentId');

      final response = await http.delete(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token", // Added Authorization
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('Document deleted successfully.');
      } else {
        print('Failed to delete document. Status: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('Error deleting document: $e');
    }
  }

  Future<void> saveSignatureRecords(List<String> fileIds) async {
    String? token = await getToken();

    if (token == null || isTokenExpired(token)) {
      print("Token is expired or missing, attempting to refresh...");
      token = await refreshToken();
      if (token == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }
    final userId = JwtDecoder.decode(token)['id'];
    if (token.isEmpty) throw Exception("No valid token available.");

    print("Attempting to save signatures with token: $token");
    final createArray = fileIds.map((fileId) {
      return {
        "directus_users_id": userId,
        "directus_files_id": {"id": fileId}
      };
    }).toList();

    final response = await http.patch(
      Uri.parse('$baseUrl/users/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'signature': {
          "create": createArray,
          "update": [],
          "delete": []
        }, // Ensure this matches your schema
      }),
    );
    if (response.statusCode != 200) {
      print(
          'Failed to save signatures: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to save signatures');
    } else {
      print("Signatures saved successfully!");
    }
  }

  Future<List<String>> uploadFile(List<File> documents) async {
    String? token = await getToken();

    if (token == null || isTokenExpired(token)) {
      print("Token is expired or missing, attempting to refresh...");
      token = await refreshToken();
      if (token == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }
    final uri = Uri.parse('$baseUrl/files');
    List<String> fileIds = [];

    for (final document in documents) {
      var request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(http.MultipartFile(
          'file',
          document.openRead(),
          await document.length(),
          filename: basename(document.path),
        ));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await http.Response.fromStream(response);
        final jsonResponse = json.decode(responseData.body);
        fileIds.add(jsonResponse['data']['id']); // Collect file IDs
      } else {
        throw Exception('Failed to upload document: ${response.statusCode}');
      }
    }

    return fileIds; // Return list of file IDs
  }

  Future<void> deleteSignature(List<int> fileIds) async {
    String? token = await getToken();

    if (token == null || isTokenExpired(token)) {
      print("Token is expired or missing, attempting to refresh...");
      token = await refreshToken();
      if (token == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }

    final userId = JwtDecoder.decode(token)['id'];
    if (userId == null)
      throw Exception("Failed to extract user ID from token.");

    print("Attempting to delete Signature with token: $token");
    print("Deleting Signature file IDs: $fileIds");

    try {
      // Construct the final request body with string IDs in the delete array
      final requestBody = {
        "signature": {
          "create": [],
          "update": [],
          "delete": fileIds, // Use string IDs for delete
        }
      };

      print('Request body: ${json.encode(requestBody)}');

      final response = await http.patch(
        Uri.parse('$baseUrl/users/me?fields=signature'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode != 200) {
        print(
            'Failed to delete signature: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to delete signature');
      } else {
        print('signature successfully deleted.');
      }
    } catch (e) {
      print("Error deleting signature: $e");
    }
  }

  Future<void> saveOriginalDocumentRecords(List<String> fileIds) async {
    String? token = await getToken();

    if (token == null || isTokenExpired(token)) {
      print("Token is expired or missing, attempting to refresh...");
      token = await refreshToken();
      if (token == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }
    final userId = JwtDecoder.decode(token)['id'];
    if (userId == null)
      throw Exception("Failed to extract user ID from token.");

    print("Attempting to save documents with token: $token");
    print("Saving document file IDs: $fileIds");

    // Build the "create" array dynamically based on file IDs
    final createArray = fileIds.map((fileId) {
      return {
        "directus_users_id": userId,
        "directus_files_id": {"id": fileId},
      };
    }).toList();

    // Construct the final request body
    final requestBody = {
      "original_document": {"create": createArray, "update": [], "delete": []}
    };

    final response = await http.patch(
      Uri.parse('$baseUrl/users/me?fields=*.*'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(requestBody),
    );

    if (response.statusCode != 200) {
      print(
          'Failed to save documents: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to save documents');
    }
  }

  Future<List<int>> fetchSignatureIntIds() async {
    String? token = await getToken();

    if (token == null || isTokenExpired(token)) {
      print("Token is expired or missing, attempting to refresh...");
      token = await refreshToken();
      if (token == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }

    final url =
        Uri.parse('${dotenv.env['API_BASE_URL']}/users/me?fields=signature.id');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      List<dynamic> signature = responseData['data']['signature'];

      // Extract and map the document IDs as integers
      List<int> fileIds = signature
          .map((doc) =>
              doc['id'] as int) // Extracts the 'id' field as an integer
          .toList();

      print("Fetched signed signature IDs: $fileIds");
      return fileIds;
    } else {
      print(
          "Failed to fetch signature IDs, status code: ${response.statusCode}, response: ${response.body}");
      throw Exception(
          "Failed to fetch signature IDs, status code: ${response.statusCode}");
    }
  }

  Future<List<String>> getPdfUrls(List<String> fileIds) async {
    // Generate the URLs directly using each file ID
    List<String> pdfUrls =
        fileIds.map((fileId) => '$baseUrl/assets/$fileId').toList();
    return pdfUrls;
  }

  Future<List<String>> getSignatureUrls(List<String> signatureIds) async {
    String? token = await getToken();

    if (token == null || isTokenExpired(token)) {
      print("Token is expired or missing, attempting to refresh...");
      token = await refreshToken();
      if (token == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }
    List<String> signatureUrls =
        signatureIds.map((fileId) => '$baseUrl/assets/$fileId').toList();
    return signatureUrls;
  }

  Future<List<String>> fetchSignatureIds() async {
    String? token = await getToken();

    if (token == null || isTokenExpired(token)) {
      print("Token is expired or missing, attempting to refresh...");
      token = await refreshToken();
      if (token == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }

    final url =
        Uri.parse('$baseUrl/users/me?fields=signature.directus_files_id');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      List<dynamic> signatureData = responseData['data']['signature'];
      List<String> signatureIds = signatureData
          .map((sig) => sig['directus_files_id'] as String)
          .toList();

      print("Fetched signature IDs: $signatureIds");
      return signatureIds;
    } else {
      print(
          "Failed to fetch signature IDs, status code: ${response.statusCode}, response: ${response.body}");
      throw Exception(
          "Failed to fetch signature IDs, status code: ${response.statusCode}");
    }
  }

  Future<bool> validateAndDeductSignatureFee(BuildContext context) async {
    try {
      String? token = await getToken();
      final userId = JwtDecoder.decode(token!)['id'];
      if (userId == null)
        throw Exception("Failed to extract user ID from token.");

      // Fetch user status and points
      final userResponse = await http.get(
          Uri.parse('$baseUrl/users/$userId?fields=points_balance,status'));
      if (userResponse.statusCode != 200) {
        throw Exception('Failed to fetch user details');
      }

      final userData = json.decode(userResponse.body)['data'];
      final int balance = userData['points_balance'] ?? 0;
      final String status = userData['status'] ?? 'unverified';

      // Check status
      if (status != 'active') {
        String message = '';
        if (status == 'archived') {
          message = 'Your account is currently under review.';
        } else {
          message = 'Your account must be verified before signing.';
        }

        // Show dialog
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            backgroundColor: Colors.white,
            titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24),
            contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
            title: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Colors.orange, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Account Notice',
                    style: textStyleVersion2(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              message,
              style: textStyleVersion2(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // close Account Notice dialog
                  Navigator.of(context).pop(); // close waitingToSave dialog
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  textStyle: textStyleVersion2(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        return false;
      }

      // Fetch signature fee
      final feeResponse =
          await http.get(Uri.parse('$baseUrl/items/signature_fee'));
      if (feeResponse.statusCode != 200) {
        throw Exception('Failed to fetch signature fee');
      }
      final int fee = json.decode(feeResponse.body)['data']['fee'] ?? 0;

      if (balance < fee) {
        // Insufficient points dialog
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Insufficient Points'),
            content:
                const Text('You do not have enough ECP to sign this document.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // close Account Notice dialog
                  Navigator.of(context).pop(); // close waitingToSave dialog
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return false;
      }

      // Deduct points
      final deductResponse = await http.patch(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'points_balance': balance - fee}),
      );
      if (deductResponse.statusCode != 200) {
        throw Exception('Failed to deduct points');
      }

      return true;
    } catch (e) {
      print('Error in validateAndDeductSignatureFee: $e');
      return false;
    }
  }

  Future<dynamic> getRequest(String endpoint) async {
    String? token = await getToken();

    if (token == null || isTokenExpired(token)) {
      print("Token is expired or missing, attempting to refresh...");
      token = await refreshToken();
      if (token == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }

    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load data');
    }
  }
}
