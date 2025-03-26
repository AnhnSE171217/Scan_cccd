import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart' as path_provider;
import '../services/api_service.dart';
import 'dart:ui';
import 'dart:async';

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({super.key, required this.camera});

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  String? _imagePath;
  bool _isSending = false;
  String _statusMessage = '';
  bool _isError = false;
  final ApiService _apiService = ApiService();

  // Initialize controller without using 'late' or null
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _showControls = true;
  bool _flashEnabled = false;
  final List<String> _scanTips = [
    'Place ID card within the frame',
    'Ensure good lighting',
    'Hold camera steady for best results',
    'Make sure the photo is clearly visible',
  ];
  int _currentTipIndex = 0;
  Timer? _tipTimer;

  @override
  void initState() {
    super.initState();
    // Initialize camera controller with high resolution for better document scanning
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    // Initialize animation controller first
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Initialize animation after controller is created
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    // Initialize controller future - fixed to not return null
    _initializeControllerFuture = _controller
        .initialize()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((error) {
          if (mounted) {
            setState(() {
              _statusMessage = 'Camera initialization failed: $error';
              _isError = true;
            });
          }
        });

    // Remove the call to _connectToWebSocket() since we're using one-time connections

    // Rotate through scanning tips
    _tipTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _scanTips.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    _tipTimer?.cancel();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      // Animation for button press
      _animationController.forward().then(
        (_) => _animationController.reverse(),
      );

      // Ensure camera is initialized
      await _initializeControllerFuture;

      // Get directory path where image will be saved
      final Directory appDir = await path_provider.getTemporaryDirectory();
      final String dirPath = '${appDir.path}/Pictures';
      await Directory(dirPath).create(recursive: true);

      // Create a unique file name
      final String filePath =
          '$dirPath/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Take the picture
      final XFile image = await _controller.takePicture();
      await image.saveTo(filePath);

      setState(() {
        _imagePath = filePath;
        _statusMessage = 'Image captured successfully!';
        _isError = false;
        _showControls = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error capturing image: $e';
        _isError = true;
      });
      debugPrint('Camera error: $e');
    }
  }

  void _clearImage() {
    setState(() {
      _imagePath = null;
      _statusMessage = '';
      _showControls = true;
    });
  }

  Future<void> _sendToApi() async {
    if (_imagePath == null) {
      setState(() {
        _statusMessage = 'No image to send!';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isSending = true;
      _statusMessage = 'Sending image to server...';
      _isError = false;
    });

    try {
      // Change this line to use the one-time WebSocket connection instead
      final result = await _apiService.sendImageViaOneTimeWebSocket(
        _imagePath!,
      );

      setState(() {
        _isSending = false;
        _statusMessage = result;
        _isError = false;
      });

      // Return to camera capture mode after a short delay to show success message
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _imagePath = null; // Clear the image path
            _showControls = true; // Show camera controls
            _statusMessage = ''; // Clear status message
          });
        }
      });
    } catch (e) {
      setState(() {
        _isSending = false;
        _statusMessage = 'Error sending image: $e';
        _isError = true;
      });
      debugPrint('WebSocket error: $e');
    }
  }

  void _toggleFlash() async {
    try {
      if (_flashEnabled) {
        await _controller.setFlashMode(FlashMode.off);
      } else {
        await _controller.setFlashMode(FlashMode.torch);
      }

      setState(() {
        _flashEnabled = !_flashEnabled;
      });
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withAlpha(100),
        elevation: 0,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(150),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'SCAN ID CARD',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
              color: Colors.white.withAlpha(255),
              fontSize: 18,
            ),
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false, // Prevents automatic back button
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(150),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _flashEnabled ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
              ),
              onPressed: _toggleFlash,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Camera error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child:
                      _imagePath == null
                          ? SizedBox.expand(
                            key: const ValueKey('camera'),
                            child: CameraPreview(_controller),
                          )
                          : SizedBox.expand(
                            key: const ValueKey('image'),
                            child: Image.file(
                              File(_imagePath!),
                              fit: BoxFit.cover,
                            ),
                          ),
                );
              } else {
                return Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Setting up camera...',
                          style: TextStyle(
                            color: Colors.white.withAlpha(204),
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),

          // ID Card Overlay
          if (_imagePath == null)
            Positioned.fill(
              child: CustomPaint(painter: IDCardOverlayPainter()),
            ),

          // Scanning Tips
          if (_imagePath == null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(77),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withAlpha(77),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            child: Text(
                              _scanTips[_currentTipIndex],
                              key: ValueKey(_currentTipIndex),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Status message with blur effect
          if (_statusMessage.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors:
                            _isError
                                ? [
                                  Colors.red.withAlpha(80),
                                  Colors.redAccent.withAlpha(100),
                                ]
                                : [
                                  Colors.teal.withAlpha(100),
                                  Colors.blue.withAlpha(120),
                                ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            _isError
                                ? Colors.red.withAlpha(150)
                                : Colors.cyanAccent.withAlpha(150),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(50),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isError
                              ? Icons.error_outline
                              : Icons.check_circle_outline,
                          color: _isError ? Colors.white : Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withAlpha(100),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isError)
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                            onPressed: () {
                              setState(() {
                                _statusMessage = '';
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Bottom controls area with glass effect
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    24 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(26),
                        Colors.black.withAlpha(153),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    border: Border.all(
                      color: Colors.white.withAlpha(26),
                      width: 1,
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child:
                        _showControls
                            ? _buildCameraControls()
                            : _buildPreviewControls(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraControls() {
    return Center(
      key: const ValueKey('camera_controls'),
      child: GestureDetector(
        onTap: _takePicture,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Center(
                  child: Container(
                    width: 65,
                    height: 65,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreviewControls() {
    return Row(
      key: const ValueKey('preview_controls'),
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Discard button
        GestureDetector(
          onTap: _clearImage,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(77),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withAlpha(77),
                    width: 1,
                  ),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(180),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Retake',
                  style: TextStyle(
                    color: Colors.white.withAlpha(255),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Upload button
        GestureDetector(
          onTap: _isSending ? null : _sendToApi,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4FACFE).withAlpha(128),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child:
                    _isSending
                        ? const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                        : const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 30,
                        ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(180),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isSending ? 'Processing...' : 'Send ID Data',
                  style: TextStyle(
                    color: Colors.white.withAlpha(255),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ID Card overlay painter specifically designed for ID cards
class IDCardOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint framePaint =
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;

    final Paint backgroundPaint =
        Paint()
          ..color = Colors.black.withAlpha(120)
          ..style = PaintingStyle.fill;

    // Calculate ID card frame dimensions (standard ID ratio is about 85.6 x 53.98 mm ~ 1.59:1)
    final double cardWidth = size.width * 0.8;
    final double cardHeight = cardWidth / 1.59; // Maintain ID card aspect ratio

    // Calculate rectangle for ID card frame
    final Rect cardRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cardWidth,
      height: cardHeight,
    );

    // Draw transparent rectangle inside an opaque background
    final Path backgroundPath =
        Path()
          ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
          ..addRect(cardRect);

    canvas.drawPath(backgroundPath, backgroundPaint);

    // Draw white frame around ID card area
    canvas.drawRect(cardRect, framePaint);

    // Draw corners for better visibility
    final double cornerLength = cardWidth * 0.1;

    // Draw corner indicators
    _drawCorners(canvas, cardRect, cornerLength, framePaint);

    // Add front-specific visual indicators
    _drawFrontCardGuides(canvas, cardRect);

    // Add text label
    final TextPainter painter = TextPainter(
      text: const TextSpan(
        text: 'Front of ID Card',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black, offset: Offset(0, 0), blurRadius: 5),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    painter.layout(maxWidth: size.width);

    // Draw a background for the text
    final backgroundRect = Rect.fromCenter(
      center: Offset(size.width / 2, cardRect.bottom + 20 + painter.height / 2),
      width: painter.width + 24,
      height: painter.height + 10,
    );

    canvas.drawRect(
      backgroundRect,
      Paint()..color = Colors.black.withAlpha(180),
    );

    painter.paint(
      canvas,
      Offset((size.width - painter.width) / 2, cardRect.bottom + 20),
    );
  }

  void _drawCorners(Canvas canvas, Rect rect, double length, Paint paint) {
    // Top left
    canvas.drawLine(rect.topLeft, rect.topLeft.translate(length, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft.translate(0, length), paint);

    // Top right
    canvas.drawLine(rect.topRight, rect.topRight.translate(-length, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight.translate(0, length), paint);

    // Bottom left
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft.translate(length, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft.translate(0, -length),
      paint,
    );

    // Bottom right
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight.translate(-length, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight.translate(0, -length),
      paint,
    );
  }

  void _drawFrontCardGuides(Canvas canvas, Rect cardRect) {
    final Paint guidePaint =
        Paint()
          ..color = Colors.white.withAlpha(180)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;

    // Photo area (typically on the right side)
    final Rect photoRect = Rect.fromLTWH(
      cardRect.left + cardRect.width * 0.65,
      cardRect.top + cardRect.height * 0.2,
      cardRect.width * 0.25,
      cardRect.height * 0.6,
    );

    canvas.drawRect(photoRect, guidePaint);

    // Text lines for name, ID number, etc.
    double lineY = cardRect.top + cardRect.height * 0.25;
    const double lineSpacing = 18;

    for (int i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(cardRect.left + cardRect.width * 0.1, lineY),
        Offset(cardRect.left + cardRect.width * 0.6, lineY),
        guidePaint,
      );
      lineY += lineSpacing;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
