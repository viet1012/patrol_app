import 'package:flutter/foundation.dart';

import 'package:chuphinh/core/models/auth_me.dart';
import 'package:chuphinh/core/network/dio_client.dart';

class AuthMeApi {
  /// Quyền của user; `null` nếu lỗi (không làm fail cả màn hình).
  static Future<AuthMe?> fetch(String accountCode) async {
    try {
      final response = await DioClient.get(
        '/api/hr/me',
        queryParameters: {'code': accountCode},
      );

      if (response.statusCode == 200 && response.data != null) {
        return AuthMe.fromJson(Map<String, dynamic>.from(response.data));
      }
    } catch (error) {
      debugPrint('Load auth me error: $error');
    }

    return null;
  }
}
