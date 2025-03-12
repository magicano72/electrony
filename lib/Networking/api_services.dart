import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Electrony/models/sign_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:path/path.dart';

class AuthApiService {
  final String baseUrl;

  AuthApiService({required this.baseUrl});
  final storage = FlutterSecureStorage();

  Future<void> storeToken(String token) async {
    await storage.write(key: 'authToken', value: token);
    print("Token stored: $token");
  }

  Future<String?> getToken() async {
    final token = await storage.read(
        key: 'authToken'); // Must match the key used in storeToken
    print("Retrieved token: $token");
    return token;
  }

  // Login request (email and password only)
  Future<void> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['data'] != null) {
        final token = data['data']['access_token'];
        final refreshToken = data['data']['refresh_token'];
        print(token);
        print(refreshToken);
        // Store tokens securely
        await storage.write(key: 'authToken', value: token);
        await storage.write(key: 'refreshToken', value: refreshToken);
      } else {
        // Parse and throw error message from the response
        final errorMessage = data['errors'] != null && data['errors'].isNotEmpty
            ? data['errors'][0]['message']
            : 'Invalid email or password.';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print("Error during login: $e");

      // Throw a user-friendly exception
      if (e is SocketException) {
        throw Exception('Network error. Please check your connection.');
      } else if (e is TimeoutException) {
        throw Exception('Request timed out. Please try again later.');
      } else if (e is FormatException) {
        throw Exception('Invalid server response format.');
      } else {
        throw Exception('An unexpected error occurred.');
      }
    }
  }

  // Register request (email and password only)
  Future<void> register(String email, String password, String first_name,
      String last_name, String phoneNumber, String birthDate) async {
    try {
      // Step 1: Register the user
      final response = await http
          .post(
            Uri.parse('$baseUrl/users'), // Directus registration endpoint
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'email': email,
              'password': password,
              'first_name': first_name,
              'last_name': last_name,
              "phone_number": phoneNumber,
              "birth_date": birthDate
            }),
          )
          .timeout(Duration(seconds: 10));

      final data = jsonDecode(response.body);
      print("Registration Response: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("User registered successfully.");
        // Proceed to auto-login or next step
        await login(email, password); // Assuming login function exists
      } else {
        String errorMessage = data['errors'] != null
            ? data['errors'][0]['message']
            : 'An unknown error occurred.';
        print("Failed to register");
        throw Exception(
            errorMessage); // Throw an exception to handle it in the Bloc
      }
    } catch (e) {
      if (e is TimeoutException) {
        print("Request timed out. Please check your connection.");
      } else if (e is SocketException) {
        print("No Internet connection. Please try again later.");
      } else {
        print("Unexpected error: $e");
      }
      throw Exception("Error during registration: $e");
    }
  }

  // Logout request
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
        await storage.delete(key: 'authToken');
        await storage.delete(key: 'refreshToken');
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

    if (token == null || JwtDecoder.isExpired(token)) {
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
        return data['data'] ?? {}; // Safely return data if it exists
      } else {
        throw Exception(
            "Failed to load user profile: ${data['errors']?[0]?['message'] ?? 'Unknown error'}");
      }
    } catch (e) {
      print("Error fetching profile: $e");
      throw Exception("Error fetching profile: $e");
    }
  }

  Future<String?> refreshToken() async {
    final refreshToken = await storage.read(key: 'refreshToken');
    if (refreshToken == null) {
      print("No refresh token available. Cannot refresh access token.");
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final newTokenData = jsonDecode(response.body);
        final newToken = newTokenData['data']['access_token'];
        await storeToken(newToken); // Save the new token
        print("Token refreshed successfully.");
        return newToken;
      } else {
        print("Failed to refresh token: ${response.body}");
      }
    } catch (e) {
      print("Exception during token refresh: $e");
    }
    return null;
  }

  bool isTokenExpired(String token) {
    return JwtDecoder.isExpired(token);
  }

  Future<String> uploadProfileImage(File imageFile) async {
    String? token = await getToken();

    if (token == null || JwtDecoder.isExpired(token)) {
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

    if (token == null || JwtDecoder.isExpired(token)) {
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

  Future<List<String>> uploadSignatures(List<File> signatureImages) async {
    String? token = await getToken();

    if (token == null || JwtDecoder.isExpired(token)) {
      print("Token is expired or missing, attempting to refresh...");
      token = await refreshToken();
      if (token == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }
    final uri = Uri.parse('$baseUrl/files');
    List<String> fileIds = [];

    for (final signatureImage in signatureImages) {
      var request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(http.MultipartFile(
          'file',
          signatureImage.openRead(),
          await signatureImage.length(),
          filename: basename(signatureImage.path),
        ));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await http.Response.fromStream(response);
        final jsonResponse = json.decode(responseData.body);
        fileIds.add(jsonResponse['data']['id']); // Collect file IDs
      } else {
        throw Exception('Failed to upload signature: ${response.statusCode}');
      }
    }

    return fileIds; // Return list of file IDs
  }

  Future<List<String>> uploadSignedDocuments(List<File> documents) async {
    String? token = await getToken();

    if (token == null || JwtDecoder.isExpired(token)) {
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

  Future<void> sendSignatureData({
    required File pdfFile,
    required String userEmail,
    required List<SignModel> signModelList,
    String? status,
  }) async {
    final url = Uri.parse('$baseUrl/items/docs');

    try {
      // Upload the file and get the documentId
      final documentId = await uploadOriginalDocuments([pdfFile]);
      String? token = await getToken();
      // Fetch the user's ID using their email
      final userId = JwtDecoder.decode(token!)['id'];
      if (userId == null)
        throw Exception("Failed to extract user ID from token.");

      // Construct the payload
      final Map<String, dynamic> body = {
        "signer": {
          "create": signModelList.map((item) {
            return {
              "signer_id": {
                "status": item.status,
                "x_offset": item.xOffset,
                "y_offset": item.yOffset,
                "contriputer_email": item.contributorEmail,
                "sign": item.signatureText ?? '',
                "user_id": userId,
                "current_page": item.currentPage,
                "created_at":
                    DateTime.now().toIso8601String(), //created at file
                "type": item.type.name,
                "signature_id": item.signatureId ?? null
              }
            };
          }).toList()
        },
        "status": status,
        "created_file": documentId.firstOrNull,
        "user_id": userId
      };
      //
      // Debug: Print the payload
      print('Payload: $body');

      // Send the request
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: json.encode(body),
      );

      // Debug: Print the response
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Data sent successfully: ${response.body}');
      } else {
        print('Failed to send data: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('Error occurred while sending data: $e');
    }
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
      if (userId == null)
        throw Exception("Failed to extract user ID from token.");

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
          "Authorization": "Bearer $token", // Ensure authentication is included
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Data sent successfully: ${response.body}');
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

    if (token == null || JwtDecoder.isExpired(token)) {
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

  Future<void> saveSignedDocumentRecords(
      List<String> fileIds, String name) async {
    String? token = await getToken();

    if (token == null || JwtDecoder.isExpired(token)) {
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
    String timestamp = DateTime.now().toIso8601String();

    // Build the "create" array dynamically based on file IDs
    final createArray = fileIds.map((fileId) {
      return {
        "directus_users_id": userId,
        "directus_files_id": {"id": fileId},
        "create_at": timestamp,
        "name": name
      };
    }).toList();

    // Construct the final request body
    final requestBody = {
      "signedDocument": {"create": createArray, "update": [], "delete": []}
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

  Future<List<String>> uploadOriginalDocuments(List<File> documents) async {
    String? token = await getToken();

    if (token == null || JwtDecoder.isExpired(token)) {
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

  Future<void> deleteSignedDocuments(List<int> fileIds) async {
    String? token = await getToken();

    if (token == null || JwtDecoder.isExpired(token)) {
      print("Token is expired or missing, attempting to refresh...");
      token = await refreshToken();
      if (token == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }

    final userId = JwtDecoder.decode(token)['id'];
    if (userId == null)
      throw Exception("Failed to extract user ID from token.");

    print("Attempting to delete documents with token: $token");
    print("Deleting document file IDs: $fileIds");

    try {
      // Construct the final request body with string IDs in the delete array
      final requestBody = {
        "signedDocument": {
          "create": [],
          "update": [],
          "delete": fileIds, // Use string IDs for delete
        }
      };

      print('Request body: ${json.encode(requestBody)}');

      final response = await http.patch(
        Uri.parse('$baseUrl/users/me?fields=*.*'),
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
            'Failed to delete documents: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to delete documents');
      } else {
        print('Documents successfully deleted.');
      }
    } catch (e) {
      print("Error deleting document: $e");
    }
  }

  Future<void> deleteSignature(List<int> fileIds) async {
    String? token = await getToken();

    if (token == null || JwtDecoder.isExpired(token)) {
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
        Uri.parse('$baseUrl/users/me?fields=*.*'),
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

    if (token == null || JwtDecoder.isExpired(token)) {
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

  Future<List<String>> fetchCreatedDocumentStringIds() async {
    print("Attempting to read access token from storage.");
    String? token = await getToken();
    print("Retrieved access token: $token");

    if (token == null || JwtDecoder.isExpired(token)) {
      print("Token is expired or missing, attempting to refresh...");
      token = await refreshToken();
      if (token == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }

    final url = Uri.parse('$baseUrl/items/docs?fields=created_file');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      List<dynamic> signedDocuments = responseData['data'];

      // Reverse the list to achieve FILO order
      List<String> fileIds = signedDocuments
          .map((doc) => doc['created_file'] as String)
          .toList()
          .reversed
          .toList();

      print("Fetched signed document IDs in FILO order: $fileIds");
      return fileIds;
    } else {
      print(
          "Failed to fetch document IDs, status code: ${response.statusCode}, response: ${response.body}");
      throw Exception(
          "Failed to fetch document IDs, status code: ${response.statusCode}");
    }
  }

  Future<List<int>> fetchCreatedDocumentIntIds() async {
    print("Attempting to read access token from storage.");
    String? token = await getToken();
    print("Retrieved access token: $token");

    if (token == null) {
      print("Access token is missing when attempting to fetch document IDs.");
      throw Exception("Access token is missing.");
    }

    final url = Uri.parse('$baseUrl/items/signer?fields=created_file.id');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      List<dynamic> signedDocuments = responseData['data'];

      // Extract and map the document IDs as integers
      List<int> fileIds = signedDocuments
          .map((doc) =>
              doc['id'] as int) // Extracts the 'id' field as an integer
          .toList();

      // Reverse the list to achieve LIFO order
      List<int> reversedFileIds = fileIds.reversed.toList();

      print("Fetched signed document IDs in LIFO order: $reversedFileIds");
      return reversedFileIds;
    } else {
      print(
          "Failed to fetch document IDs, status code: ${response.statusCode}, response: ${response.body}");
      throw Exception(
          "Failed to fetch document IDs, status code: ${response.statusCode}");
    }
  }

  Future<List<String>> fetchSignedDocumentStringIds() async {
    print("Attempting to read access token from storage.");
    String? token = await getToken();
    print("Retrieved access token: $token");

    if (token == null || JwtDecoder.isExpired(token)) {
      print("Token is expired or missing, attempting to refresh...");
      token = await refreshToken();
      if (token == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }

    final url =
        Uri.parse('$baseUrl/users/me?fields=signedDocument.directus_files_id');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      List<dynamic> signedDocuments = responseData['data']['signedDocument'];

      // Reverse the list to achieve FILO order
      List<String> fileIds = signedDocuments
          .map((doc) => doc['directus_files_id'] as String)
          .toList()
          .reversed
          .toList();

      print("Fetched signed document IDs in FILO order: $fileIds");
      return fileIds;
    } else {
      print(
          "Failed to fetch document IDs, status code: ${response.statusCode}, response: ${response.body}");
      throw Exception(
          "Failed to fetch document IDs, status code: ${response.statusCode}");
    }
  }

  Future<List<String>> fetchSignedDocumentName() async {
    print("Attempting to read access token from storage.");
    String? token = await getToken();
    print("Retrieved access token: $token");

    if (token == null) {
      print("Access token is missing when attempting to fetch document IDs.");
      throw Exception("Access token is missing.");
    }

    final url = Uri.parse('$baseUrl/users/me?fields=signedDocument.name');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      List<dynamic> signedDocuments = responseData['data']['signedDocument'];

      // Reverse the list to achieve LIFO order
      List<String> fileIds = signedDocuments
          .map((doc) => doc['name'] as String)
          .toList()
          .reversed
          .toList();

      print("Fetched names in LIFO order: $fileIds");
      return fileIds;
    } else {
      print(
          "Failed to fetch names, status code: ${response.statusCode}, response: ${response.body}");
      throw Exception(
          "Failed to fetch names, status code: ${response.statusCode}");
    }
  }

  Future<List<String>> fetchSignedDocumentDate() async {
    print("Attempting to read access token from storage.");
    String? token = await getToken();
    print("Retrieved access token: $token");

    if (token == null) {
      print("Access token is missing when attempting to fetch document dates.");
      throw Exception("Access token is missing.");
    }

    final url = Uri.parse('$baseUrl/users/me?fields=signedDocument.create_at');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      List<dynamic> signedDocuments = responseData['data']['signedDocument'];

      // Convert and format each document creation date to Egypt's time zone
      List<String> formattedDates = signedDocuments.map((doc) {
        String dateString = doc['create_at'] as String;
        DateTime utcDate = DateTime.parse(dateString).toUtc();
        DateTime egyptTime =
            utcDate.add(Duration(hours: 4)); // Convert to Egypt time (UTC+2)

        // Format the date and time for display
        String formattedDate =
            DateFormat('dd-MM-yyyy  HH:mm').format(egyptTime);
        return formattedDate;
      }).toList();

      // Reverse the list to achieve LIFO order
      List<String> reversedFormattedDates = formattedDates.reversed.toList();

      print(
          "Fetched signed document dates in LIFO order: $reversedFormattedDates");
      return reversedFormattedDates;
    } else {
      print(
          "Failed to fetch document dates, status code: ${response.statusCode}, response: ${response.body}");
      throw Exception(
          "Failed to fetch document dates, status code: ${response.statusCode}");
    }
  }

  Future<List<int>> fetchSignedDocumentIntIds() async {
    print("Attempting to read access token from storage.");
    String? token = await getToken();
    print("Retrieved access token: $token");

    if (token == null) {
      print("Access token is missing when attempting to fetch document IDs.");
      throw Exception("Access token is missing.");
    }

    final url = Uri.parse(
        'http://139.59.134.100:8055/users/me?fields=signedDocument.id');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      List<dynamic> signedDocuments = responseData['data']['signedDocument'];

      // Extract and map the document IDs as integers
      List<int> fileIds = signedDocuments
          .map((doc) =>
              doc['id'] as int) // Extracts the 'id' field as an integer
          .toList();

      // Reverse the list to achieve LIFO order
      List<int> reversedFileIds = fileIds.reversed.toList();

      print("Fetched signed document IDs in LIFO order: $reversedFileIds");
      return reversedFileIds;
    } else {
      print(
          "Failed to fetch document IDs, status code: ${response.statusCode}, response: ${response.body}");
      throw Exception(
          "Failed to fetch document IDs, status code: ${response.statusCode}");
    }
  }

  Future<List<int>> fetchSignatureIntIds() async {
    print("Attempting to read access token from storage.");
    String? token = await getToken();
    print("Retrieved access token: $token");

    if (token == null || JwtDecoder.isExpired(token)) {
      print("Token is expired or missing, attempting to refresh...");
      token = await refreshToken();
      if (token == null) {
        throw Exception("Failed to refresh token. Please log in again.");
      }
    }

    final url =
        Uri.parse('http://139.59.134.100:8055/users/me?fields=signature.id');

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
    if (token == null || JwtDecoder.isExpired(token)) {
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
    print("Attempting to read access token from storage.");
    String? token = await getToken();
    if (token == null || JwtDecoder.isExpired(token)) {
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
}
