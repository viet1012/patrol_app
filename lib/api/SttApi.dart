import 'package:http/http.dart' as http;
import 'dart:developer';

import 'api_config.dart';

class SttApi {
  String normalizeGroup(String? group) {
    return group == null ? '' : group.replaceAll(' ', '').trim();
  }

  static Future<int> getCurrentStt({
    required String fac,
    required String group,
  }) async {
    final uri = Uri.parse(
      "${ApiConfig.baseUrl}/api/stt/crt"
      "?fac=$fac&grp=${group.replaceAll(' ', '').trim()}",
    );

    // 🔹 LOG REQUEST
    log("➡️ GET STT API");
    log("URL: $uri");

    final res = await http.get(uri);

    // 🔹 LOG RESPONSE
    log("⬅️ RESPONSE");
    log("StatusCode: ${res.statusCode}");
    log("Body: ${res.body}");

    if (res.statusCode == 200) {
      return int.parse(res.body);
    } else {
      throw Exception(
        "Cannot get current STT | status=${res.statusCode} body=${res.body}",
      );
    }
  }
}
