import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

import 'dio_client.dart';

Future<String> replaceImageApi({
  required int id,
  required String oldImage,
  required Uint8List newImageBytes,
}) async {
  final String path = '/api/patrol_report/$id/replace_image';

  debugPrint('PUT ${DioClient.dio.options.baseUrl}$path');
  debugPrint('oldImage = $oldImage');
  debugPrint('bytes length = ${newImageBytes.length}');

  final formData = FormData.fromMap({
    'oldImage': oldImage,
    'newImage': MultipartFile.fromBytes(
      newImageBytes,
      filename: 'replace_${DateTime.now().millisecondsSinceEpoch}.jpg',
      contentType: DioMediaType('image', 'jpeg'),
    ),
  });

  final response = await DioClient.putUpload(path, data: formData);

  debugPrint('status = ${response.statusCode}');
  debugPrint('data = ${response.data}');

  if (response.statusCode != 200) {
    throw Exception('Replace image failed: ${response.data}');
  }

  if (response.data == null || response.data['newImage'] == null) {
    throw Exception('Response missing newImage: ${response.data}');
  }

  return response.data['newImage'] as String;
}

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

    final response = await DioClient.postUpload(path, data: formData);

    debugPrint('✅ ADD IMAGE SUCCESS');
    debugPrint('Status: ${response.statusCode}');
    debugPrint('Data: ${response.data}');

    if (response.statusCode != 200) {
      throw Exception(
        'Add image failed | status=${response.statusCode} | data=${response.data}',
      );
    }

    if (response.data == null || response.data['newImage'] == null) {
      throw Exception('Response missing newImage: ${response.data}');
    }

    return response.data['newImage'] as String;
  } on DioException catch (e) {
    debugPrint('❌ DIO ERROR - ADD IMAGE');
    debugPrint('Message: ${e.message}');
    debugPrint('Type: ${e.type}');
    debugPrint('Path: ${e.requestOptions.path}');
    debugPrint('StatusCode: ${e.response?.statusCode}');
    debugPrint('ResponseData: ${e.response?.data}');

    throw Exception('Add image Dio error: ${e.response?.data ?? e.message}');
  } catch (e, stack) {
    debugPrint('❌ UNKNOWN ERROR - ADD IMAGE');
    debugPrint('Error: $e');
    debugPrint('StackTrace: $stack');
    rethrow;
  }
}

Future<void> deleteImageApi({
  required int id,
  required String imageName,
}) async {
  final String path = '/api/patrol_report/$id/delete_image';

  final response = await DioClient.delete(
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

  String? grp,
  String? plant,
  String? division,
  String? area,
  String? machine,

  String? riskFreq,
  String? riskProb,
  String? riskSev,
  String? riskTotal,

  String? editUser,

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
              contentType: DioMediaType('image', 'jpeg'),
            ),
          )
          .toList(),
  });

  final response = await DioClient.postUpload(path, data: formData);

  if (response.statusCode != 200) {
    throw Exception('Update failed: ${response.statusCode}');
  }
}
