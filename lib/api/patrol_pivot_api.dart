import 'package:flutter/cupertino.dart';

import '../model/pivot_response.dart';
import 'dio_client.dart';

class PatrolPivotApi {
  static Future<RiskPivotResponse> fetchPivot({
    required String plant,
    required List<String> atStatus,
    required String type,
  }) async {
    final endpoint = '/api/patrol_report/pivot';

    final uri = Uri(
      path: endpoint,
      queryParameters: {
        'plant': plant,
        'type': type,
        // List -> multi param
        'at_status': atStatus,
      },
    );

    debugPrint('➡️ REQUEST URL: ${uri.toString()}');

    final res = await DioClient.dio.get(
      endpoint,
      queryParameters: {'plant': plant, 'type': type, 'at_status': atStatus},
    );

    if (res.statusCode == 200 && res.data is Map) {
      return RiskPivotResponse.fromJson(Map<String, dynamic>.from(res.data));
    }
    throw Exception('Failed to load pivot');
  }
}
