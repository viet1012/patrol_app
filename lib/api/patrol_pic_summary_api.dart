import 'package:dio/dio.dart';

import '../api/dio_client.dart';
import '../model/patrol_pic_summary.dart';

class PatrolPicSummaryApi {
  const PatrolPicSummaryApi();

  Future<List<PatrolPicSummary>> fetchPicSummary({
    required String fromDate,
    required String toDate,
    required String plant,
  }) async {
    try {
      final res = await DioClient.get(
        '/api/patrol_report/summary/pic',
        queryParameters: {
          'fromDate': '${fromDate}T00:00:00',
          'toDate': '${toDate}T00:00:00',
          'plant': plant.trim(),
        },
      );

      if (res.statusCode != 200) {
        throw Exception(
          'Fetch patrol pic summary failed '
          '| status=${res.statusCode} '
          '| data=${res.data}',
        );
      }

      final data = res.data;

      if (data is List) {
        return data
            .map((e) => PatrolPicSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .map((e) => PatrolPicSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      throw Exception('Unexpected response format: ${data.runtimeType}');
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ??
            e.message ??
            'Failed to fetch patrol pic summary',
      );
    }
  }
}
