import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:logger/logger.dart';
import 'event_api_service.dart';
import 'auth_service.dart';

class ApiService {
  final String _wsEndpoint = 'ws://34.143.211.188:8080/Scan';
  WebSocket? _socket;
  StreamSubscription? _socketSubscription;
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

  final bool _productionMode = true;
  bool _isConnecting = false;
  bool _connectionActive = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;
  final EventApiService _eventApiService = EventApiService();
  final AuthService _authService = AuthService();

  // Read image file and return as bytes
  Future<List<int>> _readImageFile(String imagePath) async {
    final File imageFile = File(imagePath);

    try {
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      final fileSize = await imageFile.length();
      if (fileSize <= 1) {
        throw Exception('Image file is empty or corrupted: $fileSize bytes');
      }

      final bytes = await imageFile.readAsBytes();

      if (bytes.isEmpty || bytes.length <= 1) {
        throw Exception('Failed to read image data (${bytes.length} bytes)');
      }

      logger.i('Image read: ${bytes.length >> 10}KB (${bytes.length} bytes)');
      return bytes;
    } catch (e) {
      logger.e('Error reading image file: $e');
      throw Exception('Error reading image: $e');
    }
  }

  // Connect to WebSocket
  Future<void> connectToWebSocket() async {
    if (_isConnecting || _connectionActive) {
      return;
    }

    _isConnecting = true;

    try {
      if (!_productionMode) logger.i('Connecting to WebSocket');
      _socket = await WebSocket.connect(_wsEndpoint).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Connection timeout'),
      );

      _connectionActive = true;
      _isConnecting = false;
      _reconnectAttempts = 0;

      if (!_productionMode) logger.i('WebSocket connected');
      _socketSubscription = _socket!.listen(
        (dynamic message) {
          // Handle incoming messages if needed
        },
        onError: (error) {
          logger.e('WebSocket error: $error');
          _connectionActive = false;
          _scheduleReconnect();
        },
        onDone: () {
          if (!_productionMode) logger.i('WebSocket connection closed');
          _connectionActive = false;
          _socket = null;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      logger.e('WebSocket connection failed: $e');
      _isConnecting = false;
      _connectionActive = false;
      _socket = null;
      _scheduleReconnect();
      throw Exception('Connection error: $e');
    }
  }

  // Schedule reconnection with backoff
  void _scheduleReconnect() {
    if (_reconnectTimer != null ||
        _isConnecting ||
        _connectionActive ||
        _reconnectAttempts >= _maxReconnectAttempts) {
      return;
    }

    final int delay = _calculateBackoff(_reconnectAttempts);
    if (!_productionMode) logger.i('Scheduling reconnect in $delay ms');

    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      _reconnectTimer = null;
      _reconnectAttempts++;
      connectToWebSocket();
    });
  }

  // Calculate backoff delay
  int _calculateBackoff(int attempt) {
    final int delay = 1000 * (1 << attempt);
    return delay > 30000 ? 30000 : delay;
  }

  // Disconnect from WebSocket
  Future<void> disconnectFromWebSocket() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _reconnectAttempts = 0;
    _connectionActive = false;
    _isConnecting = false;

    try {
      await _socketSubscription?.cancel();
      _socketSubscription = null;
      await _socket?.close();
      _socket = null;
    } catch (e) {
      if (!_productionMode) logger.e('Error disconnecting WebSocket: $e');
    }
  }

  // Main method to send event ID, token, and binary image in sequence
  Future<String> sendImageAndEventViaWebSocket(
    String imagePath,
    String eventName,
  ) async {
    try {
      // Ensure we have a valid WebSocket connection
      if (!_connectionActive) {
        await connectToWebSocket();
      } else if (_socket == null || _socket!.closeCode != null) {
        logger.w('Socket in bad state, reconnecting...');
        await disconnectFromWebSocket();
        await connectToWebSocket();
      }

      // Get event ID from event name
      final eventId = await _eventApiService.getEventIdByName(eventName);
      if (eventId == null) {
        throw Exception('Could not find ID for event: $eventName');
      }

      // Get auth token
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found. Please login again.');
      }

      // Read raw image bytes (not base64 encoded)
      final List<int> imageBytes = await _readImageFile(imagePath);
      if (imageBytes.length <= 1) {
        throw Exception('Invalid image data detected before sending');
      }

      logger.i('Sending data sequence for event: $eventName (ID: $eventId)');

      // STEP 1: Send event ID as JSON
      logger.i('Step 1: Sending event ID: $eventId');
      _socket!.add(jsonEncode({'eventId': eventId}));
      await Future.delayed(const Duration(milliseconds: 300));

      // STEP 2: Send token as JSON
      logger.i('Step 2: Sending auth token');
      _socket!.add(jsonEncode({'token': token}));
      await Future.delayed(const Duration(milliseconds: 300));

      // STEP 3: Send raw binary image data
      logger.i('Step 3: Sending binary image (${imageBytes.length >> 10}KB)');
      _socket!.add(imageBytes);

      logger.i('All data sent successfully');
      return 'Data sequence sent for event "$eventName"';
    } catch (e) {
      logger.e('Error in send sequence: $e');

      // Try to reconnect on failure
      if (_connectionActive && _socket != null) {
        logger.i('Attempting to reset WebSocket connection after error');
        await disconnectFromWebSocket();
        await Future.delayed(const Duration(seconds: 1));
        await connectToWebSocket();
      }

      throw Exception('Send failed: $e');
    }
  }

  // Clean up resources
  void dispose() {
    disconnectFromWebSocket();
  }
}
