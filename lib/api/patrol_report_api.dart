import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import '../model/patrol_report_model.dart';
import 'dio_client.dart';

class PatrolReportApi {
  static Future<List<PatrolReportModel>> fetchReports({
    required String plant,
    required String division,
    required String area,
    required String machine,
    required String type,
    required String afStatus,
    required String grp,
  }) async {
    try {
      final endpoint = '/api/patrol_report/filter';

      final queryParams = {
        'plant': plant,
        'division': division,
        'area': area,
        'machine': machine,
        'type': type,
        'afStatus': afStatus,
        'grp': grp,
      };

      /// 🔥 IN RA ENDPOINT + QUERY
      debugPrint('👉 API CALL: ${DioClient.dio.options.baseUrl}$endpoint');
      debugPrint('👉 QUERY PARAMS: $queryParams');

      final response = await DioClient.dio.get(
        endpoint,
        queryParameters: queryParams,
      );

      /// 🔥 IN RESPONSE
      debugPrint('✅ STATUS: ${response.statusCode}');

      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => PatrolReportModel.fromJson(e))
            .toList();
      } else {
        throw Exception('Invalid response format');
      }
    } on DioException catch (e) {
      debugPrint('❌ API ERROR: ${e.message}');
      debugPrint('❌ RESPONSE: ${e.response?.data}');
      throw Exception(
        e.response?.data?['message'] ?? 'Failed to load patrol reports',
      );
    }
  }
}
