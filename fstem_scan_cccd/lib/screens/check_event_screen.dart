import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/api_service.dart';
import 'camera_screen.dart';

class CheckEventScreen extends StatefulWidget {
  final CameraDescription camera;
  const CheckEventScreen({super.key, required this.camera});

  @override
  State<CheckEventScreen> createState() => _CheckEventScreenState();
}

class _CheckEventScreenState extends State<CheckEventScreen> {
  late Future<List<Map<String, dynamic>>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    // Dữ liệu mẫu để test khi backend chưa sẵn sàng:
    _eventsFuture = Future.delayed(
      const Duration(milliseconds: 300),
      () => [
        {'name': 'Sự kiện 1', 'status': true},
        {'name': 'Sự kiện 2', 'status': false},
        {'name': 'Sự kiện 3', 'status': true},
      ],
    );
  }

  void _navigateToCameraScreen(String eventName) async {
    try {
      debugPrint('Chuyển sang CameraScreen với event: $eventName');
      debugPrint('Camera lens: ${widget.camera.lensDirection}');

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => CameraScreen(camera: widget.camera, eventName: eventName),
        ),
      );
    } catch (e, s) {
      debugPrint('Lỗi khi mở CameraScreen: $e');
      debugPrint('Stack trace: $s');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể mở CameraScreen: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách sự kiện')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _eventsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Không có sự kiện khả dụng'));
          }

          final events = snapshot.data!;

          return Center(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListView.separated(
                itemCount: events.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return ListTile(
                    title: Text(
                      "- ${event['name']}",
                      style: const TextStyle(fontSize: 16),
                    ),
                    trailing: Icon(
                      event['status'] ? Icons.check_circle : Icons.cancel,
                      color: event['status'] ? Colors.green : Colors.red,
                    ),
                    onTap: () {
                      if (event['status']) {
                        _navigateToCameraScreen(event['name']);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sự kiện không khả dụng'),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
