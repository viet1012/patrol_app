import 'package:dio/dio.dart';

import '../network/dio_error_handler.dart';
import 'dio_client.dart';

class SttApi {
  static String normalize(String? v) {
    return v == null ? '' : v.replaceAll(' ', '').trim();
  }

  static Future<int> getCurrentStt({
    required String fac,
    required String type,
  }) async {
    try {
      final res = await DioClient.get(
        '/api/stt/crt',
        queryParameters: {'fac': normalize(fac), 'type': normalize(type)},
      );

      if (res.statusCode == 200) {
        final data = res.data;

        if (data is int) return data;

        if (data is String) {
          return int.tryParse(data) ?? 0;
        }

        if (data is Map && data['value'] != null) {
          return int.tryParse(data['value'].toString()) ?? 0;
        }
      }

      throw Exception(
        'Invalid response | status=${res.statusCode} | data=${res.data}',
      );
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.handle(e));
    }
  }
}
