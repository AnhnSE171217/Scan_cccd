import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

// Import màn hình CameraScreen và UploadExcelScreen
// vì chúng cùng nằm trong thư mục screens
import 'camera_screen.dart';
import 'upload_excel_screen.dart';

class HomeScreen extends StatelessWidget {
  final CameraDescription camera;

  const HomeScreen({Key? key, required this.camera}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trang chủ')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Nút chuyển sang CameraScreen
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CameraScreen(camera: camera),
                  ),
                );
              },
              child: const Text('Mở Camera'),
            ),
            const SizedBox(height: 20),
            // Nút chuyển sang UploadExcelScreen
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UploadExcelScreen(),
                  ),
                );
              },
              child: const Text('Upload Excel'),
            ),
          ],
        ),
      ),
    );
  }
}
