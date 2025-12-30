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

  /// ===================== CHANGE PASSWORD =====================
  static Future<AuthResult> changePassword({
    required String account,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final endpoint = '$_basePath/change_password';

      final body = {
        'account': account,
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      };

      /// 🔥 LOG REQUEST
      debugPrint('👉 API CALL: ${DioClient.dio.options.baseUrl}$endpoint');
      debugPrint('👉 BODY: $body');

      final response = await DioClient.dio.post(endpoint, data: body);

      debugPrint('✅ STATUS: ${response.statusCode}');
      debugPrint('✅ RESPONSE: ${response.data}');

      if (response.statusCode == 200 && response.data is Map) {
        return AuthResult(
          success: response.data['success'] ?? false,
          message: response.data['message'] ?? 'Change password failed',
        );
      }

      return AuthResult(success: false, message: 'Invalid response format');
    } on DioException catch (e) {
      debugPrint('❌ CHANGE PASSWORD ERROR: ${e.message}');
      debugPrint('❌ RESPONSE: ${e.response?.data}');

      return AuthResult(
        success: false,
        message:
            e.response?.data?['message'] ??
            'Unable to change password. Please try again',
      );
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }

  /// ===================== CHECK ACCOUNT EXISTS =====================
  static Future<bool> checkAccountExists(String account) async {
    try {
      final endpoint = '$_basePath/check-account-exists';

      /// 🔥 LOG REQUEST
      debugPrint('👉 API CALL: ${DioClient.dio.options.baseUrl}$endpoint');
      debugPrint('👉 PARAMS: account=$account');

      final response = await DioClient.dio.get(
        endpoint,
        queryParameters: {'account': account},
      );

      debugPrint('✅ STATUS: ${response.statusCode}');
      debugPrint('✅ RESPONSE: ${response.data}');

      if (response.statusCode == 200 && response.data is bool) {
        return response.data as bool;
      }

      // Nếu response không đúng kiểu bool thì trả về false
      return false;
    } on DioException catch (e) {
      debugPrint('❌ CHECK ACCOUNT ERROR: ${e.message}');
      debugPrint('❌ RESPONSE: ${e.response?.data}');
      return false;
    } catch (e) {
      debugPrint('❌ CHECK ACCOUNT ERROR: $e');
      return false;
    }
  }
}

/// ===================== RESULT MODEL =====================
class AuthResult {
  final bool success;
  final String message;

  AuthResult({required this.success, required this.message});
}
