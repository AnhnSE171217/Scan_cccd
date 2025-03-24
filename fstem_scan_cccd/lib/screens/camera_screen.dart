import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart' as path_provider;
import '../services/api_service.dart';

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({super.key, required this.camera});

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  String? _imagePath;
  bool _isSending = false;
  String _statusMessage = '';
  bool _isError = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    // Initialize camera controller with high resolution for better document scanning
    _controller = CameraController(widget.camera, ResolutionPreset.high);

    // Initialize controller future
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
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
      });
    } catch (e) {
      // Improved error handling
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
      _statusMessage = 'Sending image to API...';
      _isError = false;
    });

    try {
      final result = await _apiService.uploadImage(_imagePath!);

      setState(() {
        _isSending = false;
        _statusMessage = result;
        _isError = false;
      });
    } catch (e) {
      setState(() {
        _isSending = false;
        _statusMessage = 'Error sending image: $e';
        _isError = true;
      });
      debugPrint('API error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera App')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CameraPreview(_controller);
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
          if (_imagePath != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  Image.file(File(_imagePath!), height: 200),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: _clearImage,
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color:
                    _isError
                        ? Colors.red.withAlpha(25)
                        : _statusMessage.isNotEmpty
                        ? Colors.green.withAlpha(25)
                        : null,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  color: _isError ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _takePicture,
                  child: const Text('Take Picture'),
                ),
                ElevatedButton(
                  onPressed: _isSending ? null : _sendToApi,
                  child:
                      _isSending
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.0),
                          )
                          : const Text('Send to API'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
