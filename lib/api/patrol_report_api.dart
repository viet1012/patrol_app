import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

import '../model/patrol_report_model.dart';
import 'dio_client.dart';

class PatrolReportApi {
  static Future<List<PatrolReportModel>> fetchReports({
    String? plant,
    String? qrKey,
    int? id,
    String? division,
    String? area,
    String? machine,
    String? type,
    String? afStatus,
    String? grp,
    String? pic,
    String? patrolUser,
    String? fromD,
    String? toD,
  }) async {
    const endpoint = '/api/patrol_report/filter';

    final Map<String, dynamic> queryParams = {};

    void addIfNotEmpty(String key, String? value) {
      final v = value?.trim();
      if (v != null && v.isNotEmpty) {
        queryParams[key] = v;
      }
    }

    void addEvenIfEmpty(String key, String? value) {
      if (value != null) {
        queryParams[key] = value.trim();
      }
    }

    addIfNotEmpty('plant', plant);
    addIfNotEmpty('qrKey', qrKey);

    if (id != null) {
      queryParams['id'] = id;
    }

    addIfNotEmpty('division', division);
    addIfNotEmpty('area', area);
    addIfNotEmpty('machine', machine);
    addIfNotEmpty('type', type);
    addIfNotEmpty('afStatus', afStatus);
    addIfNotEmpty('grp', grp);

    // Cho phép gửi pic = ''
    addEvenIfEmpty('pic', pic);

    addIfNotEmpty('patrolUser', patrolUser);
    addIfNotEmpty('fromD', fromD);
    addIfNotEmpty('toD', toD);

    try {
      final uri = Uri.parse('${DioClient.dio.options.baseUrl}$endpoint')
          .replace(
            queryParameters: queryParams.map(
              (key, value) => MapEntry(key, value.toString()),
            ),
          );

      debugPrint('➡️ API CALL: $uri');

      final response = await DioClient.get(
        endpoint,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map(
              (e) => PatrolReportModel.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList();
      }

      throw Exception(
        'Failed to load patrol reports | status=${response.statusCode} | data=${response.data}',
      );
    } on DioException catch (e) {
      debugPrint('❌ API ERROR: ${e.message}');
      debugPrint('❌ RESPONSE: ${e.response?.data}');

      final data = e.response?.data;

      if (data is Map && data['message'] != null) {
        throw Exception(data['message']);
      }

      throw Exception('Failed to load patrol reports');
    }
  }
}
