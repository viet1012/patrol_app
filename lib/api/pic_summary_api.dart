import '../model/pic_summary_response_dto.dart';
import 'dio_client.dart';

/// Summary theo PIC, chia theo fac: GET /api/patrol_report/summary.
class PicSummaryApi {
  const PicSummaryApi();

  Future<PicSummaryResponseDto> fetchSummary({
    required String from,
    required String to,
    required String plant,
    required String type,
  }) async {
    final res = await DioClient.get(
      '/api/patrol_report/summary',
      queryParameters: {'from': from, 'to': to, 'plant': plant, 'type': type},
    );

    final status = res.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw Exception('HTTP $status: ${res.data}');
    }

    final data = res.data;
    if (data is! Map) {
      throw Exception('Unexpected response format: ${data.runtimeType}');
    }

    return PicSummaryResponseDto.fromJson(Map<String, dynamic>.from(data));
  }
}
