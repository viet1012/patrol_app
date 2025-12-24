import 'dart:typed_data';
import 'package:dio/dio.dart';

import 'api_config.dart';
import 'dio_client.dart';

Future<String> replaceImageApi({
  required int id,
  required String oldImage,
  required Uint8List newImageBytes,
}) async {
  final String path = '/api/patrol_report/$id/replace_image';

  print('PUT ${ApiConfig.baseUrl}$path');
  print('oldImage gửi lên = $oldImage');
  print('bytes length = ${newImageBytes.length}');

  final formData = FormData.fromMap({
    'oldImage': oldImage,
    'newImage': MultipartFile.fromBytes(
      newImageBytes,
      filename: 'replace_${DateTime.now().millisecondsSinceEpoch}.jpg',
      contentType: DioMediaType('image', 'jpeg'),
    ),
  });

  final response = await DioClient.dio.put(
    path,
    data: formData,
    options: Options(contentType: 'multipart/form-data'),
  );

  print('status = ${response.statusCode}');
  print('data = ${response.data}');

  if (response.statusCode != 200) {
    throw Exception('Replace image failed: ${response.data}');
  }

  /// backend PHẢI trả:
  /// { "newImage": "xxx.jpg" }
  return response.data['newImage'] as String;
}
