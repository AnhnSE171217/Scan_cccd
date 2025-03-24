import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:logger/logger.dart';

class ApiService {
  final String _wsEndpoint =
      'ws://34.143.211.188:8001/ws'; // WebSocket endpoint
  WebSocket? _socket;
  StreamSubscription? _socketSubscription;
  final Logger logger = Logger();

  // Method to convert image to base64
  Future<String> _imageToBase64(String imagePath) async {
    final File imageFile = File(imagePath);
    final List<int> imageBytes = await imageFile.readAsBytes();
    logger.d('Image size before encoding: ${imageBytes.length} bytes');
    return base64Encode(imageBytes);
  }

  // Connect to WebSocket server
  Future<void> connectToWebSocket() async {
    if (_socket != null) {
      await disconnectFromWebSocket();
    }

    try {
      logger.i('Connecting to WebSocket at $_wsEndpoint');
      _socket = await WebSocket.connect(_wsEndpoint).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Connection timeout after 10 seconds'),
      );

      logger.i('WebSocket connected successfully');
      _socketSubscription = _socket!.listen(
        (dynamic message) {
          // Handle incoming messages
          logger.d('Received message: $message');
        },
        onError: (error) {
          logger.e('WebSocket error: $error');
        },
        onDone: () {
          logger.i('WebSocket connection closed');
          _socket = null;
        },
      );
    } catch (e) {
      logger.e('WebSocket connection failed: $e');
      _socket = null;
      throw Exception('WebSocket connection error: $e');
    }
  }

  // Disconnect from WebSocket server
  Future<void> disconnectFromWebSocket() async {
    try {
      await _socketSubscription?.cancel();
      _socketSubscription = null;
      await _socket?.close();
      _socket = null;
      logger.i('WebSocket disconnected successfully');
    } catch (e) {
      logger.e('Error disconnecting WebSocket: $e');
    }
  }

  // Send image via WebSocket as base64
  Future<String> sendImageViaWebSocket(String imagePath) async {
    try {
      logger.i('Preparing to send image via WebSocket');

      // Ensure we have a connection
      if (_socket == null) {
        logger.i('No WebSocket connection, connecting now...');
        await connectToWebSocket();
      }

      // Convert image to base64
      logger.d('Converting image to base64');
      final String base64Image = await _imageToBase64(imagePath);

      // Log base64 information (but not the whole string as it would be too large)
      logger.d('Image converted, length: ${base64Image.length} characters');

      // Log the first 50 and last 50 characters of the base64 string
      if (base64Image.length > 100) {
        logger.d('Base64 prefix: ${base64Image.substring(0, 50)}...');
        logger.d(
          'Base64 suffix: ...${base64Image.substring(base64Image.length - 50)}',
        );
      } else {
        logger.d('Base64 content: $base64Image');
      }

      // Validate the base64 string format
      if (!base64Image.startsWith('/9j/') &&
          !base64Image.startsWith('iVBOR') &&
          !base64Image.startsWith('R0lGOD') &&
          !base64Image.startsWith('UEs')) {
        logger.w(
          'Base64 string may not be in expected format. Check the encoding.',
        );
      }

      // Create a message with the base64 image
      final Map<String, dynamic> message = {
        'type': 'id_card',
        'image': base64Image,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Log the entire JSON message excluding the base64 part
      final Map<String, dynamic> logMessage = {
        'type': message['type'],
        'image': '[BASE64_DATA]',
        'timestamp': message['timestamp'],
      };
      logger.d('Sending message structure: ${jsonEncode(logMessage)}');

      // Send the message as JSON
      logger.d('Sending message to server...');
      _socket!.add(jsonEncode(message));
      logger.i('Message sent successfully');

      return 'Image sent successfully!';
    } catch (e) {
      logger.e('Error in sendImageViaWebSocket: $e');
      throw Exception('Error sending image via WebSocket: $e');
    }
  }
}
