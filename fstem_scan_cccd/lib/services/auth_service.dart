import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

class AuthService {
  final String baseUrl = 'http://14.225.253.10:8080/api';
  final Logger logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: false,
      printTime: false,
    ),
  );

  /// Login user with email and password
  /// Returns a Future with a map containing success status and message
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      logger.i('Attempting login with email: ${email.trim()}');

      final response = await http.post(
        Uri.parse('$baseUrl/authentication/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}),
      );

      logger.i('Login response status: ${response.statusCode}');

      // Handle successful login (200 status code)
      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          logger.i('Login response body: ${response.body}');

          // Handle nested response structure
          if (responseData.containsKey('data') && responseData['data'] is Map) {
            final userData = responseData['data'];

            // Store the token from the nested data object
            final prefs = await SharedPreferences.getInstance();
            if (userData.containsKey('token') && userData['token'] != null) {
              await prefs.setString('accessToken', userData['token']);
            } else {
              logger.e('Token missing in response');
              return {
                'success': false,
                'message': 'Authentication failed: Missing token',
              };
            }

            // Store additional user info that might be useful
            if (userData.containsKey('role')) {
              await prefs.setString('userRole', userData['role']);
            }
            if (userData.containsKey('email')) {
              await prefs.setString('email', userData['email']);
              // Also store as username for backward compatibility
              await prefs.setString('username', userData['email']);
            }
            if (userData.containsKey('id')) {
              await prefs.setString('userId', userData['id'].toString());
            }

            logger.i(
              'Login successful for user: ${userData['email'] ?? 'unknown'}',
            );

            return {
              'success': true,
              'message': responseData['message'] ?? 'Login successful',
              'role': userData['role'] ?? '',
            };
          } else {
            // If data field is missing or not a map
            logger.e('Unexpected response format - missing data field');
            return {
              'success': false,
              'message': 'Server returned an unexpected response format',
            };
          }
        } catch (e) {
          logger.e('Error parsing success response: $e');
          return {
            'success': false,
            'message': 'Error processing server response',
          };
        }
      }
      // Handle error responses
      else {
        // Try to parse as JSON first
        try {
          final responseData = jsonDecode(response.body);
          String errorMessage =
              responseData['message'] ?? 'Login failed. Please try again.';
          logger.w('Login failed: $errorMessage');
          return {'success': false, 'message': errorMessage};
        } catch (_) {
          // If not JSON, use the raw response text
          String errorText = response.body.trim();

          // If empty response, use status code
          if (errorText.isEmpty) {
            errorText = 'Login failed (${response.statusCode})';
          }

          logger.w('Login failed with plain text error: $errorText');
          return {'success': false, 'message': errorText};
        }
      }
    } catch (e) {
      logger.e('Login error: $e');
      return {
        'success': false,
        'message': 'Connection error. Please check your internet.',
      };
    }
  }

  /// Logout user by removing token
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    logger.i('User logged out');
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    return token != null;
  }

  /// Get access token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }
}
