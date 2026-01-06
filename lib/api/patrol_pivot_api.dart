import '../model/pivot_response.dart';
import 'dio_client.dart';

class PatrolPivotApi {
  static Future<RiskPivotResponse> fetchPivot({
    required String plant,
    required String atStatus,
  }) async {
    final endpoint = '/api/patrol_report/pivot'; // ví dụ endpoint
    final res = await DioClient.dio.get(
      endpoint,
      queryParameters: {'plant': plant, 'at_status': atStatus},
    );

    if (res.statusCode == 200 && res.data is Map) {
      return RiskPivotResponse.fromJson(Map<String, dynamic>.from(res.data));
    }
    throw Exception('Failed to load pivot');
  }
}
