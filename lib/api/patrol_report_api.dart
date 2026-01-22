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
    try {
      final endpoint = '/api/patrol_report/filter';

      /// ? CH? ADD PARAM KHI CÓ GIÁ TR?
      final Map<String, String> queryParams = {'plant': ?plant};

      void addIfNotEmpty(String key, String? value) {
        if (value != null && value.trim().isNotEmpty) {
          queryParams[key] = value.trim();
        }
      }

      // ✅ Cho phép gửi param ngay cả khi rỗng (dùng cho pic='')
      void addEvenIfEmpty(String key, String? value) {
        if (value != null) {
          queryParams[key] = value.trim(); // có thể là ''
        }
      }

      addIfNotEmpty('qrKey', qrKey);
      if (id != null) queryParams['id'] = id.toString();
      addIfNotEmpty('division', division);
      addIfNotEmpty('area', area);
      addIfNotEmpty('machine', machine);
      addIfNotEmpty('type', type);
      addIfNotEmpty('afStatus', afStatus);
      addIfNotEmpty('grp', grp);
      addEvenIfEmpty('pic', pic);
      addIfNotEmpty('patrolUser', patrolUser);
      addIfNotEmpty('fromD', fromD);
      addIfNotEmpty('toD', toD);

      /// ?? DEBUG
      final uri = Uri.parse(
        '${DioClient.dio.options.baseUrl}$endpoint',
      ).replace(queryParameters: queryParams);

      debugPrint('?? API CALL: $uri');

      final response = await DioClient.dio.get(
        endpoint,
        queryParameters: queryParams,
      );

      // debugPrint('?? RAW RESPONSE = ${response.data}');
      // debugPrint('? STATUS: ${response.statusCode}');

      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => PatrolReportModel.fromJson(e))
            .toList();
      }

      return [];
    } on DioException catch (e) {
      debugPrint('? API ERROR: ${e.message}');
      debugPrint('? RESPONSE: ${e.response?.data}');
      throw Exception(
        e.response?.data?['message'] ?? 'Failed to load patrol reports',
      );
    }
  }
}
