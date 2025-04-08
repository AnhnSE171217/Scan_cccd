import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'camera_screen.dart';

class CheckEventScreen extends StatefulWidget {
  final CameraDescription camera;
  const CheckEventScreen({super.key, required this.camera});

  @override
  State<CheckEventScreen> createState() => _CheckEventScreenState();
}

class _CheckEventScreenState extends State<CheckEventScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Map<String, dynamic>>> _eventsFuture;
  final DateFormat _displayFormatter = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _eventsFuture = _loadEvents();
  }

  Future<List<Map<String, dynamic>>> _loadEvents() async {
    try {
      final events = await _apiService.fetchEventsFromApi();
      debugPrint("Fetched ${events.length} events from backend");
      return events;
    } catch (e, s) {
      debugPrint("Lỗi khi fetch event từ backend: $e\n$s");
      rethrow;
    }
  }

  void _navigateToCameraScreen(String eventName) async {
    try {
      debugPrint('Chuyển sang CameraScreen với event: $eventName');
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
      appBar: AppBar(
        title: const Text(
          'Danh sách sự kiện',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF7F50), Color(0xFFFF4500)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _eventsFuture = _loadEvents();
              });
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFFFF3E0),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _eventsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7F50)),
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Lỗi: ${snapshot.error}',
                style: const TextStyle(color: Colors.red, fontSize: 18),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'Không có sự kiện khả dụng',
                style: TextStyle(color: Colors.grey[700], fontSize: 18),
              ),
            );
          }

          final events = snapshot.data!;

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF3E0), Color(0xFFFFF8E1)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                final isActive = event['status'] == 'scheduled';

                String startFormatted = 'N/a';
                String endFormatted = 'N/a';
                try {
                  DateTime start = DateTime.parse(event['start_time']);
                  DateTime end = DateTime.parse(event['end_time']);
                  startFormatted = _displayFormatter.format(start);
                  endFormatted = _displayFormatter.format(end);
                } catch (e) {
                  debugPrint('Lỗi định dạng ngày: $e');
                }

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors:
                          isActive
                              ? [Colors.white, Colors.grey[100]!]
                              : [Colors.grey[200]!, Colors.grey[300]!],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ListTile(
                    title: Text(
                      "- ${event['name']}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      '⏰ $startFormatted → $endFormatted',
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                    trailing: Icon(
                      isActive ? Icons.check_circle : Icons.cancel,
                      color: isActive ? Colors.green : Colors.red,
                      size: 30,
                    ),
                    onTap: () {
                      if (isActive) {
                        _navigateToCameraScreen(event['name']);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Sự kiện không khả dụng'),
                            backgroundColor: Colors.red[400],
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
