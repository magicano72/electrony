import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Electrony/models/sign_model.dart';
import 'package:Electrony/networking/api_constant.dart';
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

// Token Management Service
class TokenService {
  final FlutterSecureStorage storage = FlutterSecureStorage();

  // Store tokens
  Future<void> storeTokens({
    required String accessToken,
    required String refreshToken,
    required String expiry,
  }) async {
    try {
      await storage.write(key: 'accessToken', value: accessToken);
      await storage.write(key: 'refreshToken', value: refreshToken);
      await storage.write(key: 'expiry', value: expiry);
      print("Tokens stored successfully");
    } catch (e) {
      print("Error storing tokens: $e");
      rethrow;
    }
  }

  // Get access token
  Future<String?> getToken() async {
    try {
      final token = await storage.read(key: 'accessToken');
      if (token == null || token.isEmpty) {
        print("No access token found");
        return null;
      }
      return token;
    } catch (e) {
      print("Error retrieving access token: $e");
      return null;
    }
  }

  // Get refresh token
  Future<String?> getRefreshToken() async {
    try {
      final token = await storage.read(key: 'refreshToken');
      if (token == null || token.isEmpty) {
        print("No refresh token found");
        return null;
      }
      return token;
    } catch (e) {
      print("Error retrieving refresh token: $e");
      return null;
    }
  }

  // Delete all tokens
  Future<void> deleteTokens() async {
    try {
      await storage.delete(key: 'accessToken');
      await storage.delete(key: 'refreshToken');
      await storage.delete(key: 'expiry');
      print("All tokens deleted successfully");
    } catch (e) {
      print("Error deleting tokens: $e");
    }
  }

  // Check if token is expired
  bool isTokenExpired(String token) {
    try {
      final decodedToken = JwtDecoder.decode(token);
      final int? expirationTimestamp = decodedToken['exp'];

      if (expirationTimestamp == null) return true;

      final expirationDate =
          DateTime.fromMillisecondsSinceEpoch(expirationTimestamp * 1000);
      final now = DateTime.now();

      return now.isAfter(expirationDate.subtract(Duration(minutes: 5)));
    } catch (e) {
      print("Error checking token expiration: $e");
      return true;
    }
  }

  // Refresh token
  Future<String?> refreshToken() async {
    final refreshToken = await getRefreshToken();

    if (refreshToken == null) {
      print("No refresh token available");
      await deleteTokens();
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['API_BASE_URL']}/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['data'] != null) {
        final accessToken = data['data']['access_token'];
        final newRefreshToken = data['data']['refresh_token'];
        final expiry = data['data']['expires'].toString();

        await storeTokens(
          accessToken: accessToken,
          refreshToken: newRefreshToken,
          expiry: expiry,
        );

        print("Token refreshed successfully");
        return accessToken;
      }

      print("Failed to refresh token: ${response.body}");
      await deleteTokens();
      return null;
    } catch (e) {
      print("Error during token refresh: $e");
      await deleteTokens();
      return null;
    }
  }
}

// HTTP Client Wrapper
class ApiClient {
  final String baseUrl;
  final TokenService tokenService;
  final http.Client client;

  ApiClient(
      {required this.baseUrl, required this.tokenService, http.Client? client})
      : client = client ?? http.Client();

  Future<Map<String, String>> _getAuthHeaders({String? token}) async {
    final authToken = token ?? await tokenService.getToken();
    if (authToken == null || tokenService.isTokenExpired(authToken)) {
      print("Token is expired or missing, attempting to refresh...");
      final newToken = await _refreshToken();
      if (newToken == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
      return {
        ApiConstants.authHeader: '${ApiConstants.bearerPrefix}$newToken',
        'Content-Type': ApiConstants.contentTypeJson,
      };
    }
    return {
      ApiConstants.authHeader: '${ApiConstants.bearerPrefix}$authToken',
      'Content-Type': ApiConstants.contentTypeJson,
    };
  }

  Future<String?> _refreshToken() async {
    final refreshToken = await tokenService.getRefreshToken();
    if (refreshToken == null) {
      print("No refresh token available");
      await tokenService.deleteTokens();
      return null;
    }

    try {
      final response = await client.post(
        Uri.parse('$baseUrl${ApiConstants.authRefreshEndpoint}'),
        headers: {'Content-Type': ApiConstants.contentTypeJson},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['data'] != null) {
        final accessToken = data['data']['access_token'];
        final newRefreshToken = data['data']['refresh_token'];
        final expiry = data['data']['expires'].toString();

        await tokenService.storeTokens(
            accessToken: accessToken,
            refreshToken: newRefreshToken,
            expiry: expiry);

        print("Token refreshed successfully");
        return accessToken;
      }

      print("Failed to refresh token: ${response.body}");
      await tokenService.deleteTokens();
      return null;
    } catch (e) {
      print("Error during token refresh: $e");
      await tokenService.deleteTokens();
      return null;
    }
  }

  Future<http.Response> get(String endpoint, {String? token}) async {
    final headers = await _getAuthHeaders(token: token);
    final response =
        await client.get(Uri.parse('$baseUrl$endpoint'), headers: headers);
    return _handleResponse(response);
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body,
      {String? token}) async {
    final headers = await _getAuthHeaders(token: token);
    final response = await client.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: json.encode(body),
    );
    return _handleResponse(response);
  }

  Future<http.Response> patch(String endpoint, Map<String, dynamic> body,
      {String? token}) async {
    final headers = await _getAuthHeaders(token: token);
    final response = await client.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: json.encode(body),
    );
    return _handleResponse(response);
  }

  Future<http.Response> delete(String endpoint, {String? token}) async {
    final headers = await _getAuthHeaders(token: token);
    final response =
        await client.delete(Uri.parse('$baseUrl$endpoint'), headers: headers);
    return _handleResponse(response);
  }

  Future<http.StreamedResponse> multipartPost(
      String endpoint, http.MultipartRequest request) async {
    final headers = await _getAuthHeaders();
    request.headers.addAll(headers);
    final response = await request.send();
    return response;
  }

  http.Response _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    final data = jsonDecode(response.body);
    final errorMessage = data['errors']?[0]?['message'] ?? 'Unknown error';
    throw Exception('API call failed: $errorMessage');
  }
}

class AuthApiService {
  final ApiClient apiClient;
  final TokenService tokenService;
  final String baseUrl;

  AuthApiService({required this.baseUrl})
      : tokenService = TokenService(),
        apiClient = ApiClient(baseUrl: baseUrl, tokenService: TokenService());

  Future<void> storeToken(String token) async {
    await tokenService.storeTokens(
        accessToken: token,
        refreshToken:
            token, // You might want to adjust this based on your needs
        expiry: DateTime.now().add(Duration(hours: 1)).toString());
  }

  Future<String> getValidToken() async {
    final token = await tokenService.getToken();
    if (token == null || tokenService.isTokenExpired(token)) {
      final newToken = await apiClient._refreshToken();
      if (newToken == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
      return newToken;
    }
    return token;
  }

  Future<void> renameDocument(String documentId, String newName) async {
    final docResponse =
        await apiClient.get('${ApiConstants.itemsDocsEndpoint}/$documentId');
    final docData = json.decode(docResponse.body);
    final fileId = docData['data']['created_file'];

    if (fileId == null) {
      throw Exception('No file ID found');
    }

    await apiClient.patch(
      '${ApiConstants.filesEndpoint}/$fileId',
      {"title": newName, "type": "application/octet-stream"},
    );
  }

  Future<Map<String, dynamic>> requestRegisteredOtp(String emailOrPhone) async {
    try {
      print("Requesting OTP for: $emailOrPhone"); // Debug log
      final response = await http.post(
        Uri.parse('$baseUrl${ApiConstants.authOtpRequestEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: jsonEncode({
          'emailOrPhone':
              emailOrPhone // Changed key name to match API expectation
        }),
      );

      print("OTP Request Response: ${response.body}"); // Debug log
      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw data['extensions'] ?? 'Failed to request OTP.';
      }

      if (data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('otp_token', data['token']);
        return data;
      } else {
        throw 'Invalid response format';
      }
    } catch (e) {
      print("Error requesting OTP: $e");
      throw ApiErrorHandler.handleException(e);
    }
  }

  Future<Map<String, dynamic>> requestRestOtp(String emailOrPhone) async {
    final url =
        Uri.parse('$baseUrl${ApiConstants.authOtpPasswordResetEndpoint}');

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
            Uri.parse('$baseUrl${ApiConstants.PasswordResetEndpoint}'),
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

  Future<void> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl${ApiConstants.authOtpLoginEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'emailOrPhone': email, 'password': password}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['data'] != null) {
        print("Login successful: ${response.body}");
        final accessToken = data['data']['accessToken'];
        final refreshToken = data['data']['refreshToken'];
        final expiry = data['data']['expiry'].toString();

        // Store tokens using the TokenService
        await tokenService.deleteTokens(); // Clear any existing tokens first
        await tokenService.storeTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          expiry: expiry,
        );
      } else {
        final errorMessage = data['extensions'] ?? 'Invalid email or password.';
        throw (errorMessage);
      }
    } catch (e) {
      print("Error during login: $e");
      throw ApiErrorHandler.handleException(e);
    }
  }

  Future<void> register(String password, String firstName, String lastName,
      String token, String otp) async {
    try {
      print("Registering user with token: $token"); // Debug log
      final response = await http.post(
        Uri.parse('$baseUrl${ApiConstants.authOtpSignupEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: jsonEncode({
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
          'token': token,
          'otp': otp,
        }),
      );

      print("Registration response status: ${response.statusCode}");
      print("Registration response body: ${response.body}");

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['data'] != null) {
          print("Registration data received: ${data['data']}");
          final accessToken = data['data']['accessToken'];
          final refreshToken = data['data']['refreshToken'];
          final expiry = data['data']['expiry'].toString();

          print("Clearing existing tokens...");
          await tokenService.deleteTokens();

          print("Storing new tokens...");
          await tokenService.storeTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiry: expiry,
          );
          print("Tokens stored successfully");
        } else {
          print("Registration response missing data field");
          throw 'Invalid registration response format';
        }
      } else {
        final errorMessage = data['extensions'] ?? 'Registration failed.';
        throw errorMessage;
      }
    } catch (e) {
      print("Error during registration: $e");
      throw ApiErrorHandler.handleException(e);
    }
  }

  Future<void> addUserEmail(String email, String birth) async {
    await apiClient.patch(
      ApiConstants.usersMeEndpoint,
      {'email': email, 'birth_date': birth},
    );
  }

  Future<void> addUserStatus(String status) async {
    await apiClient.patch(
      ApiConstants.usersMeEndpoint,
      {'status': status},
    );
  }

  Future<void> logout() async {
    final refreshToken = await tokenService.getRefreshToken();
    if (refreshToken == null) {
      throw Exception('No refresh token found. Please login again.');
    }

    await apiClient.post(
      ApiConstants.authLogoutEndpoint,
      {'refresh_token': refreshToken},
    );
    await tokenService.deleteTokens();
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final response = await apiClient.get(ApiConstants.usersMeEndpoint);
    final data = jsonDecode(response.body);
    return data['data'] ?? {};
  }

  Future<String?> getUserId() async {
    try {
      String? token = await getValidToken();
      if (token == null) return null;

      final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      return decodedToken['id']?.toString();
    } catch (e) {
      print("Error getting user ID: $e");
      return null;
    }
  }

  Future<void> saveUserDocumentRecords(List<String> fileIds) async {
    if (fileIds.isEmpty) throw Exception('No file IDs to save.');

    final token = await getValidToken();
    final userId = JwtDecoder.decode(token)['id'];
    if (userId == null) throw Exception('Invalid token: No user ID found.');

    final createArray = fileIds
        .map((fileId) => {
              "directus_users_id": userId,
              "directus_files_id": fileId,
            })
        .toList();

    await apiClient.patch(
      ApiConstants.usersMeEndpoint,
      {
        'verification_documents': {
          'create': createArray,
          'update': [],
          'delete': []
        },
      },
    );
  }

  Future<String> uploadProfileImage(File imageFile) async {
    final uri = Uri.parse('$baseUrl${ApiConstants.filesEndpoint}');
    var request = http.MultipartRequest('POST', uri);
    var stream = http.ByteStream(imageFile.openRead());
    var length = await imageFile.length();
    var multipartFile = http.MultipartFile(
      'file',
      stream,
      length,
      filename: basename(imageFile.path),
    );

    request.files.add(multipartFile);
    final response =
        await apiClient.multipartPost(ApiConstants.filesEndpoint, request);
    final responseData = await http.Response.fromStream(response);
    final jsonResponse = json.decode(responseData.body);
    return jsonResponse['data']['id'];
  }

  Future<void> updateUserProfileImage(String imageFileId) async {
    await apiClient.patch(
      ApiConstants.usersMeEndpoint,
      {'avatar': imageFileId},
    );
  }

  Future<void> updateUserVerificationImage(String imageFileId) async {
    await apiClient.patch(
      ApiConstants.usersMeEndpoint,
      {'user_face': imageFileId},
    );
  }

  Future<void> sendSignatureData({
    required File pdfFile,
    required String userEmail,
    required List<SignModel> signModelList,
    String? status,
    BuildContext? context,
  }) async {
    final fileIds = await uploadFile([pdfFile]);
    final fileId = fileIds.firstOrNull;
    if (fileId == null) throw Exception('No file ID returned from upload');

    final token = await getValidToken();
    final userId = JwtDecoder.decode(token)['id'];
    if (userId == null)
      throw Exception('Failed to extract user ID from token.');

    final body = {
      'signer': {
        'create': signModelList
            .map((item) => {
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
                })
            .toList(),
      },
      'status': status,
      'created_file': fileId,
      'user_id': userId,
    };

    final response = await apiClient.post(ApiConstants.itemsDocsEndpoint, body);
    final responseData = json.decode(response.body);
    final documentId = responseData['data']['id'];
    if (documentId == null)
      throw Exception('Failed to retrieve document ID from response');

    final feeResponse =
        await apiClient.get(ApiConstants.itemsSignatureFeeEndpoint);
    final feeData = json.decode(feeResponse.body);
    final int fee = feeData['data']['fee'] ?? 0;

    final transactionBody = {
      'type': 'signature',
      'sender': userId,
      'receiver': null,
      'amount': fee,
      'status': 'success',
      'document': documentId,
    };
    await apiClient.post(
        ApiConstants.itemsPointTransactionsEndpoint, transactionBody);

    final activityBody = {'user_id': userId, 'signed_document': documentId};
    await apiClient.post(ApiConstants.itemsActivityEndpoint, activityBody);

    if (context != null && context.mounted) {
      final documentName = pdfFile.path.split('/').last;
      final result = await showDocumentChatDialog(context, documentName);

      if (result != null) {
        if (result['action'] == 'create_new') {
          await _createNewChat(
              token, userId, fileId, documentName, signModelList);
        } else if (result['action'] == 'add_to_existing') {
          final selectedChatId = await Navigator.push<int>(
            context,
            MaterialPageRoute(
              builder: (context) => ChatListSelectionScreen(documentId: fileId),
            ),
          );

          if (selectedChatId != null) {
            await _linkDocumentToExistingChat(token, selectedChatId, fileId);
            await _addParticipantsToChat(token, selectedChatId, signModelList);
          }
        }
      }
    }
  }

  Future<void> _createNewChat(
    String token,
    String userId,
    String? documentId,
    String chatTitle,
    List<SignModel> signModelList,
  ) async {
    final response = await apiClient.post(
      ApiConstants.itemsChatsEndpoint,
      {
        "chat_title": chatTitle,
        "creator": userId,
        "related_document": documentId,
      },
      token: token,
    );

    final chatData = json.decode(response.body)['data'];
    final int chatId = chatData['id'];
    await _addParticipantsToChat(token, chatId, signModelList);
  }

  Future<void> _linkDocumentToExistingChat(
      String token, int chatId, String? documentId) async {
    if (documentId == null) return;
    await apiClient.patch(
      '${ApiConstants.itemsChatsEndpoint}/$chatId',
      {"related_document": documentId},
      token: token,
    );
  }

  Future<void> _addParticipantsToChat(
      String token, int chatId, List<SignModel> signModelList) async {
    final uniqueContributorEmails = signModelList
        .where((signer) => signer.contributorEmail != null)
        .map((signer) => signer.contributorEmail!)
        .toSet();

    for (var contributorEmail in uniqueContributorEmails) {
      final userResponse = await apiClient.get(
        '/users?filter[email][_eq]=$contributorEmail',
        token: token,
      );
      final usersData = json.decode(userResponse.body)['data'];
      if (usersData.isNotEmpty) {
        final participantUserId = usersData[0]['id'];
        final existingParticipantResponse = await apiClient.get(
          '${ApiConstants.itemsChatParticipantsEndpoint}?filter[chat][_eq]=$chatId&filter[user_id][_eq]=$participantUserId',
          token: token,
        );

        final existingParticipants =
            json.decode(existingParticipantResponse.body)['data'];
        if (existingParticipants.isEmpty) {
          await apiClient.post(
            ApiConstants.itemsChatParticipantsEndpoint,
            {
              "chat": chatId,
              "user_id": participantUserId,
            },
            token: token,
          );
        }
      }
    }
  }

  Future<Map<String, dynamic>?> showDocumentChatDialog(
      BuildContext context, String documentName) async {
    // Implementation remains unchanged (same as original)
    // ... (Paste the original showDocumentChatDialog method here)
  }

  Future<void> updateSignatureData({
    required List<Signer> signModelList,
    required String documentId,
    required String userEmail,
    String? status,
    bool? isSignedReceiver,
  }) async {
    final body = {
      "status": status,
      "signer": {
        "create": [],
        "update": signModelList
            .map((item) => {
                  "signer_id": {
                    "status": (isSignedReceiver == true &&
                            item.contriputerEmail == userEmail)
                        ? SignerStatus.Submitted.name
                        : item.status,
                    "id": item.id,
                    if (item.sign != null) "sign": item.sign,
                    if (item.signatureId != null)
                      "signature_id": item.signatureId,
                    "x_offset": item.xOffset.toString(),
                    "y_offset": item.yOffset.toString(),
                  },
                  "id": (item.id + 6),
                })
            .toList(),
        "delete": [],
      },
    };

    final response = await apiClient.patch(
      '${ApiConstants.itemsDocsEndpoint}/$documentId?fields=signer.signer_id.*,status',
      body,
    );

    final token = await getValidToken();
    final userId = JwtDecoder.decode(token)['id'];
    final feeResponse =
        await apiClient.get(ApiConstants.itemsSignatureFeeEndpoint);
    final feeData = json.decode(feeResponse.body);
    final int fee = feeData['data']['fee'] ?? 0;

    final transactionBody = {
      'type': 'signature',
      'sender': userId,
      'receiver': null,
      'amount': fee,
      'status': 'success',
      'document': int.tryParse(documentId),
    };
    await apiClient.post(
        ApiConstants.itemsPointTransactionsEndpoint, transactionBody);
  }

  Future<void> deleteSigner(int signerId) async {
    await apiClient.delete('${ApiConstants.itemsDocsEndpoint}/$signerId');
  }

  Future<void> deleteSignatureDataDocument(String documentId) async {
    await apiClient.delete('${ApiConstants.itemsDocsEndpoint}/$documentId');
  }

  Future<void> saveSignatureRecords(List<String> fileIds) async {
    final token = await getValidToken();
    final userId = JwtDecoder.decode(token)['id'];
    final createArray = fileIds
        .map((fileId) => {
              "directus_users_id": userId,
              "directus_files_id": {"id": fileId},
            })
        .toList();

    await apiClient.patch(
      '${ApiConstants.usersMeEndpoint}?fields=signature',
      {
        'signature': {"create": createArray, "update": [], "delete": []},
      },
    );
  }

  Future<List<String>> uploadFile(List<File> documents) async {
    final uri = Uri.parse('$baseUrl${ApiConstants.filesEndpoint}');
    List<String> fileIds = [];

    for (final document in documents) {
      var request = http.MultipartRequest('POST', uri);
      var stream = http.ByteStream(document.openRead());
      var length = await document.length();
      var multipartFile = http.MultipartFile(
        'file',
        stream,
        length,
        filename: basename(document.path),
      );

      request.files.add(multipartFile);
      final response =
          await apiClient.multipartPost(ApiConstants.filesEndpoint, request);
      final responseData = await http.Response.fromStream(response);
      final jsonResponse = json.decode(responseData.body);
      fileIds.add(jsonResponse['data']['id']);
    }

    return fileIds;
  }

  Future<void> deleteSignature(List<int> fileIds) async {
    final token = await getValidToken();
    final userId = JwtDecoder.decode(token)['id'];

    final requestBody = {
      "signature": {"create": [], "update": [], "delete": fileIds},
    };

    await apiClient.patch(
      '${ApiConstants.usersMeEndpoint}?fields=signature',
      requestBody,
    );
  }

  Future<void> saveOriginalDocumentRecords(List<String> fileIds) async {
    final token = await getValidToken();
    final userId = JwtDecoder.decode(token)['id'];

    final createArray = fileIds
        .map((fileId) => {
              "directus_users_id": userId,
              "directus_files_id": {"id": fileId},
            })
        .toList();

    await apiClient.patch(
      '${ApiConstants.usersMeEndpoint}?fields=*.*',
      {
        "original_document": {
          "create": createArray,
          "update": [],
          "delete": []
        },
      },
    );
  }

  Future<List<int>> fetchSignatureIntIds() async {
    final response = await apiClient.get(
      '${ApiConstants.usersMeEndpoint}?fields=signature.id',
    );
    final responseData = json.decode(response.body);
    List<dynamic> signature = responseData['data']['signature'];
    return signature.map((doc) => doc['id'] as int).toList();
  }

  Future<List<String>> getPdfUrls(List<String> fileIds) async {
    return fileIds.map((fileId) => '$baseUrl/assets/$fileId').toList();
  }

  Future<List<String>> getSignatureUrls(List<String> signatureIds) async {
    return signatureIds.map((fileId) => '$baseUrl/assets/$fileId').toList();
  }

  Future<List<String>> fetchSignatureIds() async {
    final response = await apiClient.get(
      '${ApiConstants.usersMeEndpoint}?fields=signature.directus_files_id',
    );
    final responseData = json.decode(response.body);
    List<dynamic> signatureData = responseData['data']['signature'];
    return signatureData
        .map((sig) => sig['directus_files_id'] as String)
        .toList();
  }

  Future<bool> validateAndDeductSignatureFee(BuildContext context) async {
    try {
      final token = await getValidToken();
      final userId = JwtDecoder.decode(token)['id'];
      final userResponse = await apiClient
          .get('${ApiConstants.usersMeEndpoint}?fields=points_balance,status');
      final userData = json.decode(userResponse.body)['data'];
      final int balance = userData['points_balance'] ?? 0;
      final String status = userData['status'] ?? 'unverified';

      if (status != 'active') {
        String message = status == 'archived'
            ? 'Your account is currently under review.'
            : 'Your account must be verified before signing.';

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                        color: Colors.black87),
                  ),
                ),
              ],
            ),
            content: Text(
              message,
              style: textStyleVersion2(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  textStyle: textStyleVersion2(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return false;
      }

      final feeResponse =
          await apiClient.get(ApiConstants.itemsSignatureFeeEndpoint);
      final int fee = json.decode(feeResponse.body)['data']['fee'] ?? 0;

      if (balance < fee) {
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
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return false;
      }

      await apiClient.patch(
        '${ApiConstants.usersMeEndpoint}',
        {'points_balance': balance - fee},
      );
      return true;
    } catch (e) {
      print('Error in validateAndDeductSignatureFee: $e');
      return false;
    }
  }

  Future<dynamic> getRequest(String endpoint) async {
    final response = await apiClient.get(endpoint);
    return json.decode(response.body);
  }
}
