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

  // Hàm đọc file ảnh
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

  // Kết nối WebSocket
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

  // Gửi nhịp tim để giữ kết nối
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_socket != null && _connectionActive) {
        try {
          // Gửi một ping để giữ kết nối
          _socket!.add([0]);
        } catch (e) {
          if (!_productionMode) logger.e('Heartbeat error: $e');
          _connectionActive = false;
          _scheduleReconnect();
        }
      }
    });
  }

  // Tự động reconnect
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

  int _calculateBackoff(int attempt) {
    final int delay = 1000 * (1 << attempt);
    return delay > 30000 ? 30000 : delay;
  }

  // Ngắt kết nối WebSocket
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
      if (!_productionMode) logger.e('Error disconnecting WebSocket: $e');
    }
  }

  // Gửi ảnh qua WebSocket
  Future<String> sendImageViaWebSocket(String imagePath) async {
    try {
      if (!_connectionActive) {
        await connectToWebSocket();
      } else {
        if (_socket == null || _socket!.closeCode != null) {
          logger.w('Socket in bad state, reconnecting...');
          await disconnectFromWebSocket();
          await connectToWebSocket();
        }
      }

      final List<int> imageBytes = await _readImageFile(imagePath);

      if (imageBytes.length <= 1) {
        throw Exception('Invalid image data detected before sending');
      }

      if (_socket != null && _connectionActive) {
        _socket!.add(imageBytes);
        logger.i('Sent ${imageBytes.length} bytes over WebSocket');
      } else {
        throw Exception('WebSocket not available for sending');
      }

      return 'Image sent successfully (${imageBytes.length >> 10}KB)';
    } catch (e) {
      logger.e('Error sending image: $e');
      if (_connectionActive && _socket != null) {
        logger.i('Attempting to reset WebSocket connection after error');
        await disconnectFromWebSocket();
        await Future.delayed(const Duration(seconds: 1));
        await connectToWebSocket();
      }
      throw Exception('Send error: $e');
    }
  }

  // Gửi ảnh dùng WebSocket 1 lần (code cũ)
  Future<String> sendImageViaOneTimeWebSocket(String imagePath) async {
    WebSocket? oneTimeSocket;
    StreamSubscription? oneTimeSubscription;

    try {
      final List<int> imageBytes = await _readImageFile(imagePath);
      if (imageBytes.length <= 1) {
        throw Exception('Invalid image data detected');
      }

      logger.i('Creating fresh WebSocket connection for sending image');

      oneTimeSocket = await WebSocket.connect(_wsEndpoint).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Connection timeout'),
      );

      oneTimeSubscription = oneTimeSocket.listen(
        (dynamic message) {
          // No action
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

      oneTimeSocket.add(imageBytes);
      logger.i('Sent ${imageBytes.length} bytes over one-time WebSocket');

      await Future.delayed(const Duration(milliseconds: 500));
      return 'Image sent successfully (${imageBytes.length >> 10}KB)';
    } catch (e) {
      logger.e('Error in one-time image send: $e');
      throw Exception('Send error: $e');
    } finally {
      try {
        await oneTimeSubscription?.cancel();
        await oneTimeSocket?.close();
      } catch (e) {
        logger.w('Error closing one-time socket: $e');
      }
    }
  }

  /// Hàm đọc file (dùng cho .xlsx, .txt, v.v.)
  Future<List<int>> _readFile(String filePath) async {
    final File file = File(filePath);

    if (!await file.exists()) {
      throw Exception('File không tồn tại: $filePath');
    }

    final fileSize = await file.length();
    if (fileSize == 0) {
      throw Exception('File rỗng: $filePath');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Không đọc được dữ liệu từ file: $filePath');
    }

    logger.i('Đọc file thành công: $filePath (${bytes.length} bytes)');
    return bytes;
  }

  /// Hàm gửi file Excel (.xlsx) qua WebSocket.
  Future<String> sendExcelViaWebSocket(String excelFilePath) async {
    try {
      if (!_connectionActive) {
        await connectToWebSocket();
      } else {
        if (_socket == null || _socket!.closeCode != null) {
          logger.w('Socket ở trạng thái không sẵn sàng, đang reconnect...');
          await disconnectFromWebSocket();
          await connectToWebSocket();
        }
      }

      //Đọc file .xlsx thành mảng byte
      final List<int> excelBytes = await _readFile(excelFilePath);

      if (excelBytes.isEmpty) {
        throw Exception('File Excel không có dữ liệu');
      }

      // 3. Gửi qua WebSocket
      if (_socket != null && _connectionActive) {
        _socket!.add(excelBytes);
        logger.i('Đã gửi ${excelBytes.length} bytes file Excel qua WebSocket');
      } else {
        throw Exception('WebSocket chưa sẵn sàng để gửi file Excel');
      }

      return 'Gửi file Excel thành công (${excelBytes.length} bytes)';
    } catch (e) {
      logger.e('Lỗi khi gửi file Excel: $e');

      // Thử khôi phục kết nối nếu cần
      if (_connectionActive && _socket != null) {
        logger.i('Đang đặt lại kết nối WebSocket sau lỗi');
        await disconnectFromWebSocket();
        await Future.delayed(const Duration(seconds: 1));
        await connectToWebSocket();
      }

      throw Exception('Send error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchEventsFromApi() async {
    final response = await http.get(
      Uri.parse('https://scancccd.onrender.com/api/v1/event/'),
    ); // sửa URL nếu cần

    if (response.statusCode == 200) {
      logger.i('Response body: ${response.body}');
      if (response.body.trim().isEmpty) {
        throw Exception('Phản hồi từ API rỗng (empty body)');
      }
      try {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } catch (e) {
        throw Exception('Lỗi khi parse JSON từ API: $e');
      }
    } else {
      throw Exception(
        'Lỗi khi gọi API: ${response.statusCode} - ${response.reasonPhrase}',
      );
    }
  }

  Future<String> sendImageAndEventViaWebSocket(
    String imagePath,
    String eventName,
  ) async {
    try {
      if (!_connectionActive) {
        await connectToWebSocket();
      }

      final imageBytes = await _readImageFile(imagePath);
      final base64Image = base64Encode(imageBytes);

      final payload = {'event': eventName, 'image': base64Image};

      final jsonPayload = jsonEncode(payload);
      _socket!.add(jsonPayload);

      return 'Đã gửi ảnh kèm event "$eventName" qua WebSocket';
    } catch (e) {
      logger.e('Lỗi khi gửi dữ liệu: $e');
      throw Exception('Gửi thất bại: $e');
    }
  }

  // Gọi hàm này khi app dispose
  void dispose() {
    disconnectFromWebSocket();
  }
}
