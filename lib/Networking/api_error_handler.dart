import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ApiErrorHandler {
  /// Extracts a user-friendly error message from API response data
  static String extractErrorMessage(Map<String, dynamic> data) {
    String errorMessage = 'Something went wrong. Please try again.';

    if (data.containsKey('errors') &&
        data['errors'] is List &&
        data['errors'].isNotEmpty) {
      errorMessage = data['errors'][0]['message'] ?? errorMessage;
    } else if (data.containsKey('error')) {
      errorMessage = data['error'] ?? errorMessage;
    } else if (data.containsKey('message')) {
      errorMessage = data['message'] ?? errorMessage;
    } else if (data.containsKey('extensions')) {
      if (data['extensions'] is Map) {
        // If extensions contains a message
        if (data['extensions'].containsKey('message')) {
          errorMessage = data['extensions']['message'] ?? errorMessage;
        } else {
          // Try to create a readable message from the extensions
          errorMessage = data['extensions'].toString();
        }
      } else {
        errorMessage = data['extensions'].toString();
      }
    }

    // Handle specific error cases
    if (errorMessage.contains('not found') ||
        errorMessage.contains('Not found')) {
      errorMessage =
          'The requested information was not found. Please check and try again.';
    } else if (errorMessage.contains('invalid') ||
        errorMessage.contains('Invalid')) {
      if (errorMessage.toLowerCase().contains('email')) {
        errorMessage = 'Please enter a valid email address.';
      } else if (errorMessage.toLowerCase().contains('phone')) {
        errorMessage = 'Please enter a valid phone number.';
      } else if (errorMessage.toLowerCase().contains('password')) {
        errorMessage = 'Invalid password. Please try again.';
      } else {
        errorMessage = 'Please check your information and try again.';
      }
    } else if (errorMessage.contains('already exists')) {
      errorMessage = 'This information is already registered.';
    } else if (errorMessage.toLowerCase().contains('network')) {
      errorMessage =
          'Network error. Please check your connection and try again.';
    } else if (errorMessage.toLowerCase().contains('unauthorized') ||
        errorMessage.toLowerCase().contains('authentication') ||
        errorMessage.toLowerCase().contains('auth')) {
      errorMessage = 'Authentication failed. Please sign in again.';
    }

    return errorMessage;
  }

  /// Handles exceptions that might occur during API calls
  static String handleException(dynamic exception) {
    if (exception is SocketException) {
      return 'No internet connection.';
    } else if (exception is TimeoutException) {
      return 'Request timed out. Please try again.';
    } else if (exception is FormatException) {
      return 'Unable to process the request. Please try again later.';
    } else if (exception is String) {
      // If we've already formatted the error as a string, just pass it through
      return exception;
    } else {
      return 'Something went wrong. Please try again later.';
    }
  }

  /// Process the API response and extract error message if needed
  static Map<String, dynamic> processApiResponse(dynamic response) {
    try {
      // Safely parse the response body
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': extractErrorMessage(data),
          'raw': data
        };
      }
    } catch (e) {
      return {'success': false, 'message': handleException(e), 'raw': null};
    }
  }

  /// Wrapper function to perform API calls with consistent error handling
  static Future<Map<String, dynamic>> handleApiCall(
      Future<dynamic> apiCall) async {
    try {
      final response = await apiCall;
      return processApiResponse(response);
    } catch (e) {
      return {'success': false, 'message': handleException(e), 'raw': null};
    }
  }
}
