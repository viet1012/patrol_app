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

  /// ===== SUPPORT =====
  static const support = "IT Support (via Microsoft Teams)";

  /// ===== SERVER / NETWORK =====
  static const serverError = "Server error. Please contact IT Support.";

  static const cannotConnect =
      "Unable to connect to the server.\nPlease contact IT Support.";

  static const timeout =
      "The request timed out.\nPlease try again later or contact IT Support.";

  static const networkError =
      "Network error occurred.\nPlease contact IT Support.";

  /// ===== FALLBACK =====
  static const unknownError = "Something went wrong. Please try again.";
}
////////////////////////////////////////////////////////////
/// API
////////////////////////////////////////////////////////////

class AuthApi {
  static const String _basePath = '/api/auth';

  ////////////////////////////////////////////////////////////
  /// COMMON ERROR HANDLER (CORE)
  ////////////////////////////////////////////////////////////
  static AuthResult _handleDioError(DioException e) {
    // 👉 NETWORK / NO RESPONSE
    if (e.response == null) {
      return AuthResult(
        success: false,
        isServerError: true,
        message: _mapDioError(e),
      );
    }

    final status = e.response?.statusCode;

    // 👉 SERVER ERROR (5xx: 500, 502,...)
    if (status != null && status >= 500) {
      return AuthResult(
        success: false,
        isServerError: true,
        message: AppMessage.serverError,
      );
    }

    // 👉 BUSINESS ERROR (4xx)
    final data = e.response?.data;
    final code = data?['code'];
    final msg = data?['message'];

    return AuthResult(
      success: false,
      code: code,
      message: _mapErrorCode(code, msg),
    );
  }

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

      return AuthResult(
        success: true,
        message: AppMessage.loginSuccess,
        code: response.data?['code'],
      );
    } on DioException catch (e) {
      return _handleDioError(e);
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

      return AuthResult(
        success: true,
        message: AppMessage.registerSuccess,
        code: response.data?['code'],
      );
    } on DioException catch (e) {
      return _handleDioError(e);
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

      return AuthResult(
        success: true,
        message: AppMessage.changePasswordSuccess,
        code: response.data?['code'],
      );
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (_) {
      return AuthResult(
        success: false,
        isServerError: true,
        message: AppMessage.unknownError,
      );
    }
  }

  ////////////////////////////////////////////////////////////
  /// FORGOT PASSWORD (FIX LUÔN)
  ////////////////////////////////////////////////////////////
  static Future<AuthResult> forgotPassword({
    required String account,
    required String email,
  }) async {
    try {
      final res = await DioClient.dio.get(
        '/api/auth/export-password',
        queryParameters: {'account': account, 'email': email},
      );

      return AuthResult(success: true, message: res.data ?? "Request sent");
    } on DioException catch (e) {
      return _handleDioError(e); // 👈 QUAN TRỌNG
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
  static Future<AuthResult> checkAccountExists(String account) async {
    try {
      final response = await DioClient.dio.get(
        '$_basePath/check-account-exists',
        queryParameters: {'account': account},
      );

      return AuthResult(
        success: true,
        message: "",
        code: null,
        isServerError: false,
        data: response.data,
      ); // 👈 nếu bạn có field data
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (_) {
      return AuthResult(
        success: false,
        message: AppMessage.unknownError,
        isServerError: true,
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
