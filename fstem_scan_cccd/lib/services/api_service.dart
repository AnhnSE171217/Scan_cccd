import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:logger/logger.dart';

class ApiService {
  // Use secure wss:// instead of ws:// for production
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

  // Production mode flag - set to true in production to minimize logging
  final bool _productionMode = true;

  // Connection state tracking
  bool _isConnecting = false;
  bool _connectionActive = false;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;

  // Enhanced method for reading image file with size verification
  Future<List<int>> _readImageFile(String imagePath) async {
    final File imageFile = File(imagePath);

    try {
      // Check if file exists and has content
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      final fileSize = await imageFile.length();
      if (fileSize <= 1) {
        throw Exception('Image file is empty or corrupted: $fileSize bytes');
      }

      final bytes = await imageFile.readAsBytes();

      // Verify bytes were actually read
      if (bytes.isEmpty || bytes.length <= 1) {
        throw Exception('Failed to read image data (${bytes.length} bytes)');
      }

      // Always log the image size in this scenario to help debug
      logger.i('Image read: ${bytes.length >> 10}KB (${bytes.length} bytes)');

      return bytes;
    } catch (e) {
      logger.e('Error reading image file: $e');
      throw Exception('Error reading image: $e');
    }
  }

  // Connect to WebSocket server with improved connection management
  Future<void> connectToWebSocket() async {
    // Don't try to connect if already connecting or connected
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
          // No logging of messages in production for performance
        },
        onError: (error) {
          // Always log errors even in production
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

      // Start heartbeat to keep connection alive
      _startHeartbeat();
    } catch (e) {
      logger.e('WebSocket connection failed: $e');
      _isConnecting = false;
      _connectionActive = false;
      _socket = null;
      _scheduleReconnect();
      throw Exception('Connection error: $e');
    }
  }

  // Start heartbeat timer to keep connection alive
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_socket != null && _connectionActive) {
        try {
          // Send a ping message to keep the connection alive
          // Some servers require specific ping format, adjust as needed
          _socket!.add([0]); // Minimal ping
        } catch (e) {
          if (!_productionMode) logger.e('Heartbeat error: $e');
          _connectionActive = false;
          _scheduleReconnect();
        }
      }
    });
  }

  // Schedule reconnection attempt with exponential backoff
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

  // Calculate exponential backoff delay
  int _calculateBackoff(int attempt) {
    // Start with 1s, then 2s, 4s, 8s, etc. up to max 30s
    final int delay = 1000 * (1 << attempt);
    return delay > 30000 ? 30000 : delay;
  }

  // Disconnect from WebSocket server
  Future<void> disconnectFromWebSocket() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

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
      // Only log if not in production mode
      if (!_productionMode) logger.e('Error disconnecting WebSocket: $e');
    }
  }

  // Improved method for sending images via WebSocket with more robust error handling
  Future<String> sendImageViaWebSocket(String imagePath) async {
    try {
      // Ensure we have a connection
      if (!_connectionActive) {
        await connectToWebSocket();
      } else {
        // Check if socket is in good state
        if (_socket == null || _socket!.closeCode != null) {
          logger.w('Socket in bad state, reconnecting...');
          await disconnectFromWebSocket();
          await connectToWebSocket();
        }
      }

      // Read image bytes with verification
      final List<int> imageBytes = await _readImageFile(imagePath);

      // Double-check we have valid image data
      if (imageBytes.length <= 1) {
        throw Exception(
          'Invalid image data detected before sending (${imageBytes.length} bytes)',
        );
      }

      // Send data with explicit length check
      if (_socket != null && _connectionActive) {
        _socket!.add(imageBytes);
        logger.i('Sent ${imageBytes.length} bytes over WebSocket');
      } else {
        throw Exception('WebSocket not available for sending');
      }

      return 'Image sent successfully (${imageBytes.length >> 10}KB)';
    } catch (e) {
      logger.e('Error sending image: $e');

      // Try to recover the connection for future attempts
      if (_connectionActive && _socket != null) {
        logger.i('Attempting to reset WebSocket connection after error');
        await disconnectFromWebSocket();
        await Future.delayed(const Duration(seconds: 1));
        await connectToWebSocket();
      }

      throw Exception('Send error: $e');
    }
  }

  // Create a dedicated method for one-time image sending with fresh WebSocket
  Future<String> sendImageViaOneTimeWebSocket(String imagePath) async {
    WebSocket? oneTimeSocket;
    StreamSubscription? oneTimeSubscription;

    try {
      // Read image bytes with verification first to avoid connection if image is invalid
      final List<int> imageBytes = await _readImageFile(imagePath);

      // Double-check we have valid image data
      if (imageBytes.length <= 1) {
        throw Exception(
          'Invalid image data detected (${imageBytes.length} bytes)',
        );
      }

      logger.i(
        'Creating fresh WebSocket connection for sending ${imageBytes.length >> 10}KB image',
      );

      // Create a fresh WebSocket connection just for this transfer
      oneTimeSocket = await WebSocket.connect(_wsEndpoint).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Connection timeout'),
      );

      // Set up basic error handling for this one-time socket
      oneTimeSubscription = oneTimeSocket.listen(
        (dynamic message) {
          // We don't expect any messages back
        },
        onError: (error) {
          logger.e('One-time WebSocket error: $error');
        },
        onDone: () {
          if (!_productionMode) {
            logger.i('One-time WebSocket connection closed');
          }
        },
      );

      // Send the image data
      oneTimeSocket.add(imageBytes);
      logger.i('Sent ${imageBytes.length} bytes over one-time WebSocket');

      // Give the socket a moment to finish sending before closing
      await Future.delayed(const Duration(milliseconds: 500));

      return 'Image sent successfully (${imageBytes.length >> 10}KB)';
    } catch (e) {
      logger.e('Error in one-time image send: $e');
      throw Exception('Send error: $e');
    } finally {
      // Always clean up the connection
      try {
        await oneTimeSubscription?.cancel();
        await oneTimeSocket?.close();
      } catch (e) {
        logger.w('Error closing one-time socket: $e');
      }
    }
  }

  // Call this method when the app is being disposed
  void dispose() {
    disconnectFromWebSocket();
  }

  /// Hàm gửi file Excel (.xlsx) từ ứng dụng Flutter đến backend server.
  /// Server sẽ xử lý upload và chuyển đổi file Excel sang Google Sheets.
  /// Nếu bạn đang test trên Android emulator và server chạy trên máy tính,
  /// sử dụng '10.0.2.2' để trỏ tới localhost.
  Future<Map<String, dynamic>> uploadExcelFile(String filePath) async {
    // Địa chỉ backend server; điều chỉnh nếu cần (ví dụ: dùng IP cụ thể hoặc domain)
    final String baseUrl = 'http://10.0.2.2:3000';
    final Uri uri = Uri.parse('$baseUrl/upload');

    // Tạo MultipartRequest với method POST để gửi file dạng multipart/form-data
    final http.MultipartRequest request = http.MultipartRequest('POST', uri);

    // Thêm file Excel vào request với field name 'file'
    // Đảm bảo contentType phù hợp với định dạng file Excel (.xlsx)
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: MediaType(
          'application',
          'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ),
    );

    // Gửi request và nhận phản hồi từ server
    final http.StreamedResponse streamedResponse = await request.send();
    final http.Response response = await http.Response.fromStream(
      streamedResponse,
    );

    if (response.statusCode == 200) {
      // Nếu upload thành công, parse JSON trả về từ server
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Upload failed with status code: ${response.statusCode}');
    }
  }
}
