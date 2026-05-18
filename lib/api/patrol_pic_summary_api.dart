import 'package:dio/dio.dart';

import '../api/api_config.dart';
import '../model/patrol_pic_summary.dart';

class PatrolPicSummaryApi {
  final Dio dio;

  PatrolPicSummaryApi({Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 12),
            ),
          );

  Future<List<PatrolPicSummary>> fetchPicSummary({
    required String fromDate,
    required String toDate,
    required String plant,
  }) async {
    final res = await dio.get(
      '/api/patrol_report/summary/pic',
      queryParameters: {
        'fromDate': '${fromDate}T00:00:00',
        'toDate': '${toDate}T00:00:00',
        'plant': plant,
      },
    );

    final data = res.data as List;

    return data
        .map((e) => PatrolPicSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
