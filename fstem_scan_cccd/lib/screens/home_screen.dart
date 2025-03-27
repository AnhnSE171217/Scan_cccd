import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'check_event_screen.dart';

class HomeScreen extends StatelessWidget {
  final CameraDescription camera;

  const HomeScreen({Key? key, required this.camera}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sử dụng màu cam nhạt làm màu nền cho toàn bộ trang
      backgroundColor: Color(0xFFFFF3E0),

      // Thanh AppBar với thiết kế hiện đại
      appBar: AppBar(
        title: Text(
          'Trang chủ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFFFF7F50), // Màu cam san hô
        elevation: 4, // Hiệu ứng bóng nhẹ
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),

      // Thiết kế body với hiệu ứng gradient và căn giữa
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF3E0), Color(0xFFFFF8E1)],
          ),
        ),
        child: Center(
          child: Container(
            width: 250,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFF7F50), // Màu cam chính
                  Color(0xFFFF6347), // Màu cam sáng
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  offset: Offset(0, 4),
                  blurRadius: 5.0,
                ),
              ],
            ),
            child: ElevatedButton(
              // Loại bỏ màu nền mặc định của button
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckEventScreen(camera: camera),
                  ),
                );
              },
              child: Text(
                'Kiểm tra sự kiện',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
