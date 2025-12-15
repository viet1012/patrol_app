import 'package:http/http.dart' as http;
import 'dart:developer';

class SttApi {
  static Future<int> getCurrentStt({
    required String fac,
    required String group,
  }) async {
    final uri = Uri.parse(
      "http://localhost:9299/api/stt/crt"
      "?fac=$fac&grp=$group",
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
