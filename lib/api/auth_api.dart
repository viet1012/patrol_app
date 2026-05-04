import 'package:dio/dio.dart';

import '../model/auth_result.dart';
import 'dio_client.dart';

////////////////////////////////////////////////////////////
/// MESSAGE SYSTEM
////////////////////////////////////////////////////////////

class AppMessage {
  /// ===== USER ERRORS =====
  static const accountNotFound = "Account not found.";
  static const wrongPassword = "Incorrect password.";
  static const accountExists = "Account already exists.";
  static const invalidData = "Invalid input data.";

  /// ===== SUCCESS =====
  static const loginSuccess = "Login successful.";
  static const registerSuccess = "Registration successful.";
  static const changePasswordSuccess = "Password changed successfully.";

  /// ===== SERVER / NETWORK =====
  static const serverError = "Server error. Please contact KVH_IT support";
  static const cannotConnect =
      "Cannot connect to server.\nPlease contact KVH_IT support";
  static const timeout =
      "Server timeout. Please try again later.\nPlease contact KVH_IT support";
  static const networkError = "Network error.\nPlease contact KVH_IT support";

  /// ===== FALLBACK =====
  static const unknownError = "Something went wrong. Please try again.";
}

////////////////////////////////////////////////////////////
/// API
////////////////////////////////////////////////////////////

class AuthApi {
  static const String _basePath = '/api/auth';

  ////////////////////////////////////////////////////////////
  /// LOGIN
  ////////////////////////////////////////////////////////////
  static Future<AuthResult> login({
    required String account,
    required String password,
  }) async {
    try {
      final response = await DioClient.dio.post(
        '$_basePath/login',
        data: {'account': account, 'password': password},
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200) {
        return AuthResult(
          success: true,
          message: AppMessage.loginSuccess,
          code: response.data?['code'],
        );
      }

      return AuthResult(
        success: false,
        isServerError: true,
        message: AppMessage.serverError,
      );
    }
    ////////////////////////////////////////////////////////////
    /// ERROR HANDLE
    ////////////////////////////////////////////////////////////
    on DioException catch (e) {
      if (e.response == null) {
        return AuthResult(
          success: false,
          isServerError: true,
          message: _mapDioError(e),
        );
      }

      final data = e.response?.data;
      final code = data?['code'];
      final msg = data?['message'];

      return AuthResult(
        success: false,
        code: code,
        message: _mapErrorCode(code, msg),
      );
    } catch (_) {
      return AuthResult(
        success: false,
        isServerError: true,
        message: AppMessage.unknownError,
      );
    }
  }

  ////////////////////////////////////////////////////////////
  /// REGISTER
  ////////////////////////////////////////////////////////////
  static Future<AuthResult> register({
    required String account,
    required String password,
  }) async {
    try {
      final response = await DioClient.dio.post(
        '$_basePath/register',
        data: {'account': account, 'password': password},
      );

      if (response.statusCode == 200) {
        return AuthResult(
          success: true,
          message: AppMessage.registerSuccess,
          code: response.data?['code'],
        );
      }

      return AuthResult(
        success: false,
        isServerError: true,
        message: AppMessage.serverError,
      );
    } on DioException catch (e) {
      if (e.response == null) {
        return AuthResult(
          success: false,
          isServerError: true,
          message: _mapDioError(e),
        );
      }

      final data = e.response?.data;
      final code = data?['code'];
      final msg = data?['message'];

      return AuthResult(
        success: false,
        code: code,
        message: _mapErrorCode(code, msg),
      );
    } catch (_) {
      return AuthResult(
        success: false,
        isServerError: true,
        message: AppMessage.unknownError,
      );
    }
  }

  ////////////////////////////////////////////////////////////
  /// CHANGE PASSWORD
  ////////////////////////////////////////////////////////////
  static Future<AuthResult> changePassword({
    required String account,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await DioClient.dio.post(
        '$_basePath/change_password',
        data: {
          'account': account,
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        },
      );

      if (response.statusCode == 200) {
        return AuthResult(
          success: true,
          message: AppMessage.changePasswordSuccess,
          code: response.data?['code'],
        );
      }

      return AuthResult(
        success: false,
        isServerError: true,
        message: AppMessage.serverError,
      );
    } on DioException catch (e) {
      if (e.response == null) {
        return AuthResult(
          success: false,
          isServerError: true,
          message: _mapDioError(e),
        );
      }

      final data = e.response?.data;
      final code = data?['code'];
      final msg = data?['message'];

      return AuthResult(
        success: false,
        code: code,
        message: _mapErrorCode(code, msg),
      );
    } catch (_) {
      return AuthResult(
        success: false,
        isServerError: true,
        message: AppMessage.unknownError,
      );
    }
  }

  ////////////////////////////////////////////////////////////
  /// CHECK ACCOUNT
  ////////////////////////////////////////////////////////////
  static Future<bool> checkAccountExists(String account) async {
    try {
      final response = await DioClient.dio.get(
        '$_basePath/check-account-exists',
        queryParameters: {'account': account},
      );

      if (response.statusCode == 200 && response.data is bool) {
        return response.data as bool;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<AuthResult> forgotPassword({
    required String account,
    required String email,
  }) async {
    try {
      final res = await DioClient.dio.get(
        '/api/auth/export-password',
        queryParameters: {'account': account, 'email': email},
      );

      return AuthResult(success: true, message: res.data ?? "File created");
    } on DioException catch (e) {
      if (e.response == null) {
        return AuthResult(
          success: false,
          isServerError: true,
          message: "Cannot connect to server",
        );
      }

      return AuthResult(
        success: false,
        message: e.response?.data?['message'] ?? "Failed",
      );
    }
  }

  ////////////////////////////////////////////////////////////
  /// MAP ERROR CODE
  ////////////////////////////////////////////////////////////
  static String _mapErrorCode(String? code, String? msg) {
    switch (code) {
      case "AUTH_001":
        return AppMessage.accountNotFound;

      case "AUTH_002":
        return AppMessage.wrongPassword;

      case "AUTH_003":
        return AppMessage.accountExists;

      case "AUTH_004":
        return AppMessage.invalidData;

      default:
        return msg ?? AppMessage.unknownError;
    }
  }

  ////////////////////////////////////////////////////////////
  /// MAP NETWORK ERROR
  ////////////////////////////////////////////////////////////
  static String _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return AppMessage.timeout;

      case DioExceptionType.connectionError:
        return AppMessage.cannotConnect;

      case DioExceptionType.badResponse:
        return AppMessage.serverError;

      default:
        return AppMessage.networkError;
    }
  }
}
