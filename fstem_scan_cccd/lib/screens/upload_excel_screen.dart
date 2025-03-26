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
  String _sheetUrl = '';

  // Tạo một instance của ApiService
  final ApiService _apiService = ApiService();

  Future<void> _pickAndUploadFile() async {
    // Mở hộp thoại chọn file Excel (.xlsx)
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result == null) return; // Người dùng hủy chọn file

    final filePath = result.files.single.path;
    if (filePath == null) return;

    try {
      // Gọi hàm uploadExcelFile thông qua instance _apiService
      final responseBody = await _apiService.uploadExcelFile(filePath);
      setState(() {
        // Cập nhật _sheetUrl với giá trị trả về từ server
        _sheetUrl = responseBody['webViewLink'] ?? 'Không lấy được link';
      });
    } catch (e) {
      print('Lỗi khi upload file: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi upload file: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Excel -> Google Sheets')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _pickAndUploadFile,
              child: const Text('Chọn file Excel và chuyển đổi'),
            ),
            const SizedBox(height: 20),
            if (_sheetUrl.isNotEmpty) ...[
              const Text('Đường dẫn Google Sheets:'),
              const SizedBox(height: 8),
              SelectableText(_sheetUrl),
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
