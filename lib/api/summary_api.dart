import 'package:dio/dio.dart';

import '../api/dio_client.dart';
import '../model/division_summary.dart';
import '../model/pic_summary.dart'; // bạn đổi path theo project

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

  Future<List<PicSummary>> fetchPicSummary({
    required String fromD,
    required String toD,
    required String fac,
    required String type,
    required List<String> lvls,
  }) async {
    final uri = Uri.parse('http://localhost:9299/api/patrol_report/pic-summary')
        .replace(
          queryParameters: {
            'fromD': fromD,
            'toD': toD,
            'fac': fac,
            'type': type,
            // query param trùng key: lvls=I&lvls=II...
            // Uri.replace không hỗ trợ multi-value trực tiếp, nên ta build thủ công:
          },
        );

    // build query multi lvls
    final q = <String>[
      'fromD=$fromD',
      'toD=$toD',
      'fac=$fac',
      'type=$type',
      ...lvls.map((e) => 'lvls=${Uri.encodeQueryComponent(e)}'),
    ].join('&');

    final url = Uri.parse(
      'http://localhost:9299/api/patrol_report/pic-summary?$q',
    );

    // dùng http/dio tùy project bạn
    final res = await Dio().getUri(url);
    final data = res.data;

    final list = (data is List) ? data : (data['data'] as List? ?? const []);
    return list
        .map((e) => PicSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
