import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

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

/// ===============================
/// ➕ ADD IMAGE
/// ===============================
Future<String> addImageApi({
  required int id,
  required Uint8List imageBytes,
}) async {
  final String path = '/api/patrol_report/$id/add_image';

  try {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        imageBytes,
        filename: 'add_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: DioMediaType('image', 'jpeg'),
      ),
    });

    final response = await DioClient.dio.post(
      path,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    /// LOG RESPONSE
    debugPrint('✅ ADD IMAGE SUCCESS');
    debugPrint('Status: ${response.statusCode}');
    debugPrint('Data: ${response.data}');

    if (response.statusCode != 200) {
      throw Exception(
        'Add image failed | status=${response.statusCode} | data=${response.data}',
      );
    }

    if (response.data == null || response.data['newImage'] == null) {
      throw Exception('Response thiếu imageName: ${response.data}');
    }

    return response.data['newImage'] as String;
  }
  /// 🎯 BẮT LỖI DIO
  on DioException catch (e) {
    debugPrint('❌ DIO ERROR - ADD IMAGE');
    debugPrint('Message: ${e.message}');
    debugPrint('Type: ${e.type}');
    debugPrint('Path: ${e.requestOptions.path}');

    if (e.response != null) {
      debugPrint('StatusCode: ${e.response?.statusCode}');
      debugPrint('ResponseData: ${e.response?.data}');
      debugPrint('Headers: ${e.response?.headers}');
    } else {
      debugPrint('No response from server');
    }

    throw Exception('Add image Dio error: ${e.response?.data ?? e.message}');
  }
  /// 🎯 BẮT LỖI KHÁC
  catch (e, stack) {
    debugPrint('❌ UNKNOWN ERROR - ADD IMAGE');
    debugPrint('Error: $e');
    debugPrint('StackTrace: $stack');
    rethrow;
  }
}

/// ===============================
/// 🗑 DELETE IMAGE
/// ===============================
Future<void> deleteImageApi({
  required int id,
  required String imageName,
}) async {
  final String path = '/api/patrol_report/$id/delete_image';

  final response = await DioClient.dio.delete(
    path,
    queryParameters: {'image': imageName},
  );

  if (response.statusCode != 200) {
    throw Exception('Delete image failed: ${response.data}');
  }
}

Future<void> updateReportApi({
  required int id,
  String? comment,
  String? countermeasure,
  String? pic,

  // ✅ meta fields
  String? grp,
  String? plant,
  String? division,
  String? area,
  String? machine,

  // ✅ risk fields (NEW)
  String? riskFreq,
  String? riskProb,
  String? riskSev,
  String? riskTotal,

  // ✅ audit
  String? editUser,

  // ✅ images
  List<Uint8List>? images,
  List<String>? deleteImages,

  String? atComment,
  String? atStatus,
  String? atUser,
  String? atAssign,
  String? needRecheck,
}) async {
  final path = '/api/patrol_report/$id/edit';

  final dto = <String, dynamic>{
    if (comment != null) 'comment': comment,
    if (countermeasure != null) 'countermeasure': countermeasure,
    if (pic != null) 'pic': pic,

    if (grp != null) 'grp': grp,
    if (plant != null) 'plant': plant,
    if (division != null) 'division': division,
    if (area != null) 'area': area,
    if (machine != null) 'machine': machine,

    // ✅ risk (NEW)
    if (riskFreq != null) 'riskFreq': riskFreq,
    if (riskProb != null) 'riskProb': riskProb,
    if (riskSev != null) 'riskSev': riskSev,
    if (riskTotal != null) 'riskTotal': riskTotal,

    if (editUser != null) 'editUser': editUser,
    if (deleteImages != null) 'deleteImages': deleteImages,

    if (atComment != null) 'atComment': atComment,
    if (atStatus != null) 'atStatus': atStatus,
    if (atUser != null) 'atUser': atUser,
    if (atAssign != null) 'atAssign': atAssign,
    if (needRecheck != null) 'checkInfo': needRecheck,
  };

  final formData = FormData.fromMap({
    'data': jsonEncode(dto),
    if (images != null && images.isNotEmpty)
      'images': images
          .map(
            (e) => MultipartFile.fromBytes(
              e,
              filename: 'edit_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          )
          .toList(),
  });

  final res = await DioClient.dio.post(
    path,
    data: formData,
    options: Options(contentType: 'multipart/form-data'),
  );

  if (res.statusCode != 200) {
    throw Exception('Update failed: ${res.statusCode}');
  }
}
