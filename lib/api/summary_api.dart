import 'package:dio/dio.dart';

import '../api/dio_client.dart';
import '../model/division_summary.dart'; // bạn đổi path theo project

class SummaryApi {
  const SummaryApi();

  Future<List<DivisionSummary>> fetchDivisionSummary({
    required String fromD, // yyyy-MM-dd
    required String toD,
    required String fac,
    required String type,
  }) async {
    final Response res = await DioClient.dio.get(
      '/api/patrol_report/summary/division',
      queryParameters: {'fromD': fromD, 'toD': toD, 'fac': fac, 'type': type},
      // ❌ không cần options nữa vì DioClient đã set headers/timeout
      // nếu muốn override timeout riêng cho API này thì mở lại Options ở dưới
    );

    final data = res.data;

    // ✅ Backend chuẩn: trả List JSON
    if (data is List) {
      return data
          .map((e) => DivisionSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    // ✅ Nếu backend lỡ trả Map (rare) -> try get "data"
    if (data is Map && data['data'] is List) {
      final list = data['data'] as List;
      return list
          .map((e) => DivisionSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    // ❌ Sai format
    throw DioException(
      requestOptions: res.requestOptions,
      error: 'Invalid response format: ${data.runtimeType}',
    );
  }
}
