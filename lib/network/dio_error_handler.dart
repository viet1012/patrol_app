import 'package:dio/dio.dart';

class DioErrorHandler {
  static String handle(DioException e) {
    // Timeout
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Connection to server timed out';
    }

    // No internet / server unreachable
    if (e.type == DioExceptionType.connectionError) {
      return 'Unable to connect to the server';
    }

    // Server responded with error
    if (e.response != null) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      if (status == 401) return 'Unauthorized. Please login again.';
      if (status == 403) return 'Access denied';
      if (status == 404) return 'API not found';
      if (status == 500) return 'Internal server error';

      return 'Server error $status: ${data ?? 'Unknown error'}';
    }

    // Unknown
    return 'Unexpected error occurred';
  }
}
