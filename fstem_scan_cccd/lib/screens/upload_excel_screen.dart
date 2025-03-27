import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

class UploadExcelScreen extends StatefulWidget {
  const UploadExcelScreen({Key? key}) : super(key: key);

  @override
  _UploadExcelScreenState createState() => _UploadExcelScreenState();
}

class _UploadExcelScreenState extends State<UploadExcelScreen> {
  // Biến này dùng để hiển thị thông báo kết quả WebSocket (thay cho _sheetUrl ban đầu)
  String _wsMessage = '';

  // Tạo một instance của ApiService
  final ApiService _apiService = ApiService();

  Future<void> _pickAndSendFileViaWebSocket() async {
    // Mở hộp thoại chọn file Excel (.xlsx)
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null) return; // Người dùng hủy chọn file
    final filePath = result.files.single.path;
    if (filePath == null) return;

    try {
      // Gọi hàm sendExcelViaWebSocket
      final message = await _apiService.sendExcelViaWebSocket(filePath);

      // Cập nhật UI để hiển thị thông báo
      setState(() {
        _wsMessage = message;
      });
    } catch (e) {
      debugPrint('Lỗi khi gửi file Excel qua WebSocket: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi gửi file Excel qua WebSocket: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gửi Excel qua WebSocket')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _pickAndSendFileViaWebSocket,
              child: const Text('Chọn file Excel và gửi qua WS'),
            ),
            const SizedBox(height: 20),
            if (_wsMessage.isNotEmpty) ...[
              const Text('Trạng thái WebSocket:'),
              const SizedBox(height: 8),
              SelectableText(_wsMessage),
            ],
          ],
        ),
      ),
    );
  }
}

//=======================================================================
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:file_picker/file_picker.dart';
// import '../services/api_service.dart'; // import file api_service.dart

// class UploadExcelScreen extends StatefulWidget {
//   const UploadExcelScreen({Key? key}) : super(key: key);

//   @override
//   _UploadExcelScreenState createState() => _UploadExcelScreenState();
// }

// class _UploadExcelScreenState extends State<UploadExcelScreen> {
//   String _sheetUrl = '';

//   // Tạo một instance ApiService
//   final ApiService _apiService = ApiService();

//   Future<void> _pickAndUploadFile() async {
//     FilePickerResult? result = await FilePicker.platform.pickFiles(
//       type: FileType.custom,
//       allowedExtensions: ['xlsx'],
//     );
//     if (result == null) return; // Người dùng hủy chọn file

//     final filePath = result.files.single.path;
//     if (filePath == null) return;

//     try {
//       // Gọi hàm uploadExcelFile thông qua instance _apiService
//       final responseBody = await _apiService.uploadExcelFile(filePath);
//       setState(() {
//         _sheetUrl = responseBody['webViewLink'] ?? 'Không lấy được link';
//       });
//     } catch (e) {
//       print('Lỗi khi upload file: $e');
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Lỗi khi upload file: $e')));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Upload Excel -> Google Sheets')),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             ElevatedButton(
//               onPressed: _pickAndUploadFile,
//               child: const Text('Chọn file Excel và chuyển đổi'),
//             ),
//             const SizedBox(height: 20),
//             if (_sheetUrl.isNotEmpty) ...[
//               const Text('Đường dẫn Google Sheets:'),
//               const SizedBox(height: 8),
//               SelectableText(_sheetUrl),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }
