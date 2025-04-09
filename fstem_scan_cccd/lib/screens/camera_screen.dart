import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart' as path_provider;
import '../services/api_service.dart';
import 'dart:async';
import 'package:logger/logger.dart';

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;
  final String eventName;

  const CameraScreen({
    super.key,
    required this.camera,
    required this.eventName,
  });

  @override
  State<CameraScreen> createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isCameraError = false;
  String _errorMessage = '';
  String? _imagePath;
  bool _isSending = false;
  final ApiService _apiService = ApiService();
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before we got the chance to initialize the camera
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final controller = CameraController(
        widget.camera,
        ResolutionPreset.medium, // Use medium instead of high for stability
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (!mounted) return;

      setState(() {
        _controller = controller;
        _isCameraInitialized = true;
        _isCameraError = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraError = true;
          _errorMessage = "Camera initialization failed: $e";
        });
      }
      logger.e('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  Future<void> _disposeCamera() async {
    try {
      await _controller?.dispose();
    } catch (e) {
      logger.e('Error disposing camera: $e');
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      setState(() {
        _errorMessage = 'Camera not ready';
      });
      return;
    }

    try {
      // Get directory path where image will be saved
      final directory = await path_provider.getTemporaryDirectory();
      final dirPath = '${directory.path}/Pictures';
      await Directory(dirPath).create(recursive: true);

      // Create a unique file name
      final filePath = '$dirPath/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Take the picture
      final xFile = await _controller!.takePicture();
      await xFile.saveTo(filePath);

      setState(() {
        _imagePath = filePath;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to take picture: $e';
      });
      logger.e('Error taking picture: $e');
    }
  }

  Future<void> _sendToApi() async {
    if (_imagePath == null) {
      setState(() {
        _errorMessage = 'No image to send';
      });
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final result = await _apiService.sendImageAndEventViaWebSocket(
        _imagePath!,
        widget.eventName,
      );

      if (!mounted) return;

      setState(() {
        _isSending = false;
        _errorMessage = '';
        // Show success and reset after a delay
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Success: $result')));
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _imagePath = null;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _errorMessage = 'Error sending image: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black.withAlpha(180),
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(150),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back to events',
          ),
        ),
        title: Column(
          children: [
            Text(
              'SCAN ID CARD',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(100),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(50), width: 1),
              ),
              child: Text(
                'Event: ${widget.eventName}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Container(color: Colors.black, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    // Error case
    if (_isCameraError) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF424242), Color(0xFF212121)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xFFFF7043),
                size: 64,
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7043),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text('Go Back', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      );
    }

    // Camera not initialized yet
    if (!_isCameraInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7043)),
              ),
              SizedBox(height: 24),
              Text(
                'Initializing camera...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Image preview mode
    if (_imagePath != null) {
      return Stack(
        children: [
          // Full screen image preview
          Positioned.fill(
            child: Image.file(File(_imagePath!), fit: BoxFit.contain),
          ),

          // Bottom controls with gradient background
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Retake button
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _imagePath = null),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retake'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),

                  // Send button
                  ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendToApi,
                    icon:
                        _isSending
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Icon(Icons.send),
                    label: Text(_isSending ? 'Sending...' : 'Send'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7043),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Camera preview mode
    return Stack(
      children: [
        // Camera preview
        Positioned.fill(
          child:
              _controller!.value.isInitialized
                  ? ClipRect(child: CameraPreview(_controller!))
                  : Container(
                    color: Colors.black,
                    child: const Center(
                      child: Text(
                        'Preparing camera...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
        ),

        // Capture button at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 30,
          child: Center(
            child: GestureDetector(
              onTap: _takePicture,
              child: Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x33FFFFFF), // This is 0.2 opacity white
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Center(
                  child: SizedBox(
                    height: 60,
                    width: 60,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Error message if any
        if (_errorMessage.isNotEmpty)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xCCFF0000), // Red with 0.8 opacity
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),

        // Camera guide overlay
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0x4DFFFFFF), // White with 0.3 opacity
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(50),
            ),
          ),
        ),

        // Instruction text
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x80000000), // Black with 0.5 opacity
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Position ID card within frame',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
