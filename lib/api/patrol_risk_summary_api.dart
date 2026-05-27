import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

import '../model/risk_summary.dart';
import 'dio_client.dart';

class PatrolRiskSummaryApi {
  const PatrolRiskSummaryApi();

  Future<List<RiskSummary>> fetchRiskSummary({
    required String fromD,
    required String toD,
    required String fac,
    required String type,
  }) async {
    const endpoint = '/api/patrol_report/risk_summary';

    final queryParameters = {
      'fromD': fromD,
      'toD': toD,
      'fac': fac,
      'type': type,
    };

    debugPrint('=========== FETCH RISK SUMMARY ===========');
    debugPrint('ENDPOINT : $endpoint');
    debugPrint('PARAMS   : $queryParameters');
    debugPrint('==========================================');

    try {
      final res = await DioClient.get(
        endpoint,
        queryParameters: queryParameters,
      );

      if (res.statusCode != 200) {
        throw Exception(
          'Fetch risk summary failed '
          '| status=${res.statusCode} '
          '| data=${res.data}',
        );
      }

      final data = res.data;

      if (data is! List) {
        throw Exception('Unexpected response format: ${data.runtimeType}');
      }

      return data
          .whereType<Map>()
          .map((e) => RiskSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      debugPrint('============= RISK SUMMARY ERROR =========');
      debugPrint('TYPE    : ${e.type}');
      debugPrint('MESSAGE : ${e.message}');
      debugPrint('STATUS  : ${e.response?.statusCode}');
      debugPrint('DATA    : ${e.response?.data}');
      debugPrint('==========================================');

      final data = e.response?.data;

      if (data is Map && data['message'] != null) {
        throw Exception(data['message']);
      }

      throw Exception(e.message ?? 'Failed to fetch risk summary');
    }
  }
}
