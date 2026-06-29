import 'package:dio/dio.dart';

class ApiErrorMessage {
  static String fromDio(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return "Connection Timeout: Unable to connect to the server.";

      case DioExceptionType.sendTimeout:
        return "Send Timeout: Uploading data or images took too long.";

      case DioExceptionType.receiveTimeout:
        return "Receive Timeout: The server took too long to respond.";

      case DioExceptionType.connectionError:
        return "Connection Error: Unable to reach the backend server. Please check your network connection or verify that the server is running.";

      case DioExceptionType.badResponse:
        if (status != null && status >= 500) {
          return "Server Error ($status): The server encountered an internal error while processing your request.";
        }

        if (status != null && status >= 400) {
          if (data is Map && data['message'] != null) {
            return "Request Error ($status): ${data['message']}";
          }

          return "Request Error ($status): The request is invalid or contains incorrect data.";
        }

        break;

      case DioExceptionType.cancel:
        return "Request Cancelled: The request was cancelled before completion.";

      case DioExceptionType.badCertificate:
        return "SSL Certificate Error: The server's security certificate could not be verified.";

      case DioExceptionType.unknown:
        return "Unknown Network Error: Unable to communicate with the server. Please check your network connection and try again.";
    }

    return "Unexpected Error: ${e.message ?? 'An unknown error occurred.'}";
  }

  static String fromFlutter(Object e) {
    return "Application Error: $e";
  }
}
