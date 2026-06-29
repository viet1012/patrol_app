import 'package:dio/dio.dart';

class ApiErrorMessage {
  static String fromDio(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (e.type == DioExceptionType.connectionTimeout) {
      return "Connection Timeout: Không k?t n?i du?c t?i server.";
    }

    if (e.type == DioExceptionType.sendTimeout) {
      return "Send Timeout: G?i d? li?u/?nh lên server quá lâu.";
    }

    if (e.type == DioExceptionType.receiveTimeout) {
      return "Receive Timeout: Server x? lý quá lâu, chua tr? k?t qu?.";
    }

    if (e.type == DioExceptionType.connectionError) {
      return "Connection Error: Không k?t n?i du?c BE. Ki?m tra BE có ch?y không, IP/port dúng không.";
    }

    if (e.type == DioExceptionType.badResponse) {
      if (status != null && status >= 500) {
        return "BE Error $status: Server b? l?i khi x? lý request.";
      }

      if (status != null && status >= 400) {
        return "Request Error $status: D? li?u g?i lên không h?p l?.";
      }
    }

    if (e.type == DioExceptionType.unknown) {
      return "Unknown Network Error: Không g?i du?c API. Ki?m tra baseUrl, m?ng, ho?c server.";
    }

    return "Dio Error: ${e.type}";
  }

  static String fromFlutter(Object e) {
    return "FE Error: $e";
  }
}
