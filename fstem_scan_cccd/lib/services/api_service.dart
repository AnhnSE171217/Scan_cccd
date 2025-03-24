import 'package:http/http.dart' as http;

class ApiService {
  final String _apiEndpoint =
      'https://your-api-endpoint.com/upload'; // Replace with your actual API endpoint

  Future<String> uploadImage(String imagePath) async {
    try {
      // Create a multipart request
      var request = http.MultipartRequest('POST', Uri.parse(_apiEndpoint));

      // Add the image file to the request
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));

      // Send the request
      var response = await request.send();

      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var responseString = String.fromCharCodes(responseData);
        return 'Image uploaded successfully! Response: $responseString';
      } else {
        return 'Failed to upload image. Status code: ${response.statusCode}';
      }
    } catch (e) {
      throw Exception('API service error: $e');
    }
  }
}
