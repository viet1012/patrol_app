import 'package:dio/dio.dart';
import 'dart:developer';

import 'api_config.dart';

class SttApi {
  static final Dio _dio = Dio();

  static String normalize(String? group) {
    return group == null ? '' : group.replaceAll(' ', '').trim();
  }

  static Future<int> getCurrentStt({
    required String fac,
    required String group,
  }) async {
    final facClean = normalize(fac);
    final grpClean = normalize(group);

    final url = "${ApiConfig.baseUrl}/api/stt/crt";
    final params = {'fac': facClean, 'grp': grpClean};

    try {
      log("🚀 GET STT API");
      log("URL: $url");
      log("Params: $params");

      final response = await _dio.get(
        url,
        queryParameters: params,
        options: Options(headers: {'ngrok-skip-browser-warning': 'true'}),
      );

      log("📥 RESPONSE");
      log("StatusCode: ${response.statusCode}");
      log("Body: ${response.data}");

      if (response.statusCode == 200) {
        if (response.data is int) {
          return response.data;
        }
        if (response.data is String) {
          return int.tryParse(response.data) ?? 0;
        }
        throw Exception("Unexpected response: ${response.data}");
      }

      throw Exception("Cannot get STT | ${response.statusCode}");
    } on DioError catch (e) {
      log("❌ DioError: ${e.message}");
      log("❌ Response: ${e.response?.data}");
      rethrow;
    }
  }
}
