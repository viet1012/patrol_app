import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

import '../model/pivot_response.dart';
import 'dio_client.dart';

class PatrolPivotApi {
  static Future<RiskPivotResponse> fetchPivot({
    required String plant,
    required List<String> atStatus,
    required String type,
  }) async {
    const endpoint = '/api/patrol_report/pivot';

    final queryParameters = {
      'plant': plant.trim(),
      'type': type.trim(),

      // multi query param
      // at_status=A&at_status=B
      'at_status': atStatus,
    };

    try {
      final uri = Uri.parse(
        '${DioClient.dio.options.baseUrl}$endpoint',
      ).replace(queryParameters: {'plant': plant, 'type': type});

      debugPrint('➡️ FETCH PIVOT');
      debugPrint('URL    : $uri');
      debugPrint('PARAMS : $queryParameters');

      final res = await DioClient.get(
        endpoint,
        queryParameters: queryParameters,
      );

      if (res.statusCode != 200) {
        throw Exception(
          'Failed to load pivot '
          '| status=${res.statusCode} '
          '| data=${res.data}',
        );
      }

      final data = res.data;

      if (data is Map) {
        return RiskPivotResponse.fromJson(Map<String, dynamic>.from(data));
      }

      throw Exception('Unexpected response format: ${data.runtimeType}');
    } on DioException catch (e) {
      debugPrint('❌ FETCH PIVOT ERROR');
      debugPrint('MESSAGE : ${e.message}');
      debugPrint('STATUS  : ${e.response?.statusCode}');
      debugPrint('DATA    : ${e.response?.data}');

      final data = e.response?.data;

      if (data is Map && data['message'] != null) {
        throw Exception(data['message']);
      }

      throw Exception(e.message ?? 'Failed to load pivot');
    }
  }
}
