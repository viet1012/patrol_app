import 'package:dio/dio.dart';

import '../api/dio_client.dart';
import '../model/division_summary.dart';
import '../model/pic_summary.dart';

class SummaryApi {
  const SummaryApi();

  Future<List<DivisionSummary>> fetchDivisionSummary({
    required String fromD,
    required String toD,
    required String fac,
    required String type,
  }) async {
    final Response res = await DioClient.dio.get(
      '/api/patrol_report/summary/division',
      queryParameters: {'fromD': fromD, 'toD': toD, 'fac': fac, 'type': type},
    );

    final data = res.data;

    if (data is List) {
      return data
          .map((e) => DivisionSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    if (data is Map && data['data'] is List) {
      final list = data['data'] as List;
      return list
          .map((e) => DivisionSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    throw DioException(
      requestOptions: res.requestOptions,
      error: 'Invalid response format: ${data.runtimeType}',
    );
  }

  Future<List<PicSummary>> fetchPicSummary({
    required String fromD,
    required String toD,
    required String fac,
    required String type,
    required List<String> lvls,
  }) async {
    final Response res = await DioClient.dio.get(
      '/api/patrol_report/pic-summary',
      queryParameters: {
        'fromD': fromD,
        'toD': toD,
        'fac': fac,
        'type': type,
        // ✅ multi: lvls=I&lvls=II...
        'lvls': ListParam(lvls, ListFormat.multi),
      },
    );

    final data = res.data;

    if (data is List) {
      return data
          .map((e) => PicSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    if (data is Map && data['data'] is List) {
      final list = data['data'] as List;
      return list
          .map((e) => PicSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    throw DioException(
      requestOptions: res.requestOptions,
      error: 'Invalid response format: ${data.runtimeType}',
    );
  }
}
