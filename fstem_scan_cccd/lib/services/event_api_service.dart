import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class EventApiService {
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

  Future<String?> getAuthToken() async {
    final authService = AuthService();
    return authService.getToken();
  }

  Future<List<Map<String, dynamic>>> fetchEventsFromApi() async {
    try {
      // Get token from SharedPreferences
      final token = await getAuthToken();

      if (token == null) {
        throw Exception('Authentication token not found. Please login again.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/event/allEvent'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        logger.i('Events fetched successfully');

        try {
          // Parse the JSON response
          final dynamic parsedData = jsonDecode(response.body);

          // Extract events from "content" field in the paginated response
          if (parsedData is Map && parsedData.containsKey('content')) {
            final content = parsedData['content'];

            if (content is List) {
              logger.i('Found ${content.length} events in paginated response');

              // Convert to List<Map<String, dynamic>>
              final events = List<Map<String, dynamic>>.from(content);

              // Store event data in SharedPreferences for lookup
              if (events.isNotEmpty) {
                final Map<String, Map<String, dynamic>> eventDataMap = {};

                for (var event in events) {
                  final String name = event['name'] ?? 'Unnamed Event';
                  final String id = (event['id'] ?? '').toString();
                  final String status = event['eventStatus'] ?? 'UNKNOWN';

                  if (id.isNotEmpty) {
                    eventDataMap[name] = {
                      'id': id,
                      'status': status,
                      'startTime': event['startTime'],
                      'endTime': event['endTime'],
                    };
                  }
                }

                // Store in SharedPreferences
                if (eventDataMap.isNotEmpty) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(
                    'eventDataMap',
                    jsonEncode(eventDataMap),
                  );
                  logger.i('Stored data for ${eventDataMap.length} events');
                }
              }

              return events;
            }
          }

          // If we get here, the response format wasn't as expected
          logger.w('Unexpected response format: ${parsedData.runtimeType}');
          if (parsedData is Map) {
            logger.w('Response keys: ${parsedData.keys.join(', ')}');
          }

          throw Exception('Unexpected API response format');
        } catch (e) {
          logger.e('Error parsing JSON from API: $e');
          throw Exception('Error parsing JSON from API: $e');
        }
      } else if (response.statusCode == 401) {
        logger.e('Authentication failed. Token may have expired.');
        throw Exception('Authentication failed. Please login again.');
      } else {
        logger.e(
          'API request failed: ${response.statusCode} - ${response.reasonPhrase}',
        );
        throw Exception('API request failed: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Error fetching events: $e');
      throw Exception('Failed to fetch events: $e');
    }
  }

  // Helper method to get event data by name
  Future<Map<String, dynamic>?> getEventDataByName(String eventName) async {
    final prefs = await SharedPreferences.getInstance();
    final String? eventDataMapJson = prefs.getString('eventDataMap');

    if (eventDataMapJson != null) {
      final Map<String, dynamic> decodedMap = jsonDecode(eventDataMapJson);
      if (decodedMap.containsKey(eventName)) {
        return Map<String, dynamic>.from(decodedMap[eventName]);
      }
    }
    return null;
  }

  // Get event ID by name (compatibility with existing code)
  Future<String?> getEventIdByName(String eventName) async {
    final eventData = await getEventDataByName(eventName);
    return eventData?['id'];
  }
}
