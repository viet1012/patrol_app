import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_config.dart';

Future<void> replaceImageApi({
  required int id,
  required String oldImage,
  required Uint8List newImageBytes,
}) async {
  final uri = Uri.parse(
    '${ApiConfig.baseUrl}/api/patrol_report/$id/replace_image',
  );

  final request = http.MultipartRequest('PUT', uri);

  print("uri: ${uri}");

  /// param oldImage
  request.fields['oldImage'] = oldImage;

  /// file newImage
  request.files.add(
    http.MultipartFile.fromBytes(
      'newImage', // 👈 PHẢI TRÙNG TÊN @RequestParam MultipartFile newImage
      newImageBytes,
      filename: 'replace_${DateTime.now().millisecondsSinceEpoch}.jpg',
      contentType: MediaType('image', 'jpeg'),
    ),
  );

  final response = await request.send();

  if (response.statusCode == 200) {
    print('✅ Image replaced successfully');
  } else {
    final body = await response.stream.bytesToString();
    throw Exception('❌ Replace failed: $body');
  }
}
