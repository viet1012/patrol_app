import 'package:dio/dio.dart';
import 'dart:developer';

import 'api_config.dart';

class SttApi {
  static final Dio _dio = Dio();

  static String normalizeGroup(String? group) {
    return group == null ? '' : group.replaceAll(' ', '').trim();
  }

  static Future<int> getCurrentStt({
    required String fac,
    required String group,
  }) async {
    final normalizedGroup = normalizeGroup(group);

    final url = "${ApiConfig.baseUrl}/api/stt/crt";

    final params = {'fac': fac, 'grp': normalizedGroup};

    try {
      log("?? GET STT API");
      log("URL: $url");
      log("Params: $params");

      final response = await _dio.get(
        url,
        queryParameters: params,
        options: Options(headers: {'ngrok-skip-browser-warning': 'true'}),
      );

      log("?? RESPONSE");
      log("StatusCode: ${response.statusCode}");
      log("Body: ${response.data}");

      if (response.statusCode == 200) {
        // response.data là dynamic, n?u tr? v? text, c?n parse thành int
        if (response.data is String) {
          return int.parse(response.data);
        } else if (response.data is int) {
          return response.data;
        } else {
          throw Exception("Unexpected response data format: ${response.data}");
        }
      } else {
        throw Exception(
          "Cannot get current STT | status=${response.statusCode} body=${response.data}",
        );
      }
    } on DioError catch (e) {
      log("DioError: ${e.message}");
      if (e.response != null) {
        log("DioError response data: ${e.response?.data}");
      }
      rethrow;
    }
  }
}
