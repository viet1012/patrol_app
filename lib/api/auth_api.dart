import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dio_client.dart';

class AuthApi {
  static const String _basePath = '/api/auth';

  /// ===================== LOGIN =====================
  static Future<AuthResult> login({
    required String account,
    required String password,
  }) async {
    try {
      final endpoint = '$_basePath/login';

      final body = {'account': account, 'password': password};

      /// 🔥 LOG REQUEST
      debugPrint('👉 API CALL: ${DioClient.dio.options.baseUrl}$endpoint');
      debugPrint('👉 BODY: $body');

      final response = await DioClient.dio.post(endpoint, data: body);

      debugPrint('✅ STATUS: ${response.statusCode}');
      debugPrint('✅ RESPONSE: ${response.data}');

      if (response.statusCode == 200 && response.data is Map) {
        return AuthResult(
          success: response.data['success'] ?? false,
          message: response.data['message'] ?? 'Login failed',
        );
      }

      return AuthResult(success: false, message: 'Invalid response format');
    } on DioException catch (e) {
      debugPrint('❌ LOGIN ERROR: ${e.message}');
      debugPrint('❌ RESPONSE: ${e.response?.data}');

      return AuthResult(
        success: false,
        message:
            e.response?.data?['message'] ?? 'Unable to login. Please try again',
      );
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }

  /// ===================== REGISTER =====================
  static Future<AuthResult> register({
    required String account,
    required String password,
  }) async {
    try {
      final endpoint = '$_basePath/register';

      final body = {'account': account, 'password': password};

      /// 🔥 LOG REQUEST
      debugPrint('👉 API CALL: ${DioClient.dio.options.baseUrl}$endpoint');
      debugPrint('👉 BODY: $body');

      final response = await DioClient.dio.post(endpoint, data: body);

      debugPrint('✅ STATUS: ${response.statusCode}');
      debugPrint('✅ RESPONSE: ${response.data}');

      if (response.statusCode == 200 && response.data is Map) {
        return AuthResult(
          success: response.data['success'] ?? false,
          message: response.data['message'] ?? 'Register failed',
        );
      }

      return AuthResult(success: false, message: 'Invalid response format');
    } on DioException catch (e) {
      debugPrint('❌ REGISTER ERROR: ${e.message}');
      debugPrint('❌ RESPONSE: ${e.response?.data}');

      return AuthResult(
        success: false,
        message:
            e.response?.data?['message'] ??
            'Unable to register. Please try again',
      );
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }
}

/// ===================== RESULT MODEL =====================
class AuthResult {
  final bool success;
  final String message;

  AuthResult({required this.success, required this.message});
}
