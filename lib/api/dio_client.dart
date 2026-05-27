// import 'package:dio/dio.dart';
// import 'package:flutter/foundation.dart';
//
// import 'api_config.dart';
//
// class DioClient {
//   static Dio? _dio;
//
//   static Dio get dio => _dio ??= _create();
//
//   static Dio _create() {
//     final dio = Dio(
//       BaseOptions(
//         baseUrl: ApiConfig.baseUrl,
//
//         //////////////////////////////////////////////////////
//         /// TIMEOUT
//         //////////////////////////////////////////////////////
//         connectTimeout: const Duration(seconds: 30),
//         receiveTimeout: const Duration(seconds: 60),
//
//         //////////////////////////////////////////////////////
//         /// HEADERS
//         //////////////////////////////////////////////////////
//         headers: {'ngrok-skip-browser-warning': 'true'},
//
//         //////////////////////////////////////////////////////
//         /// STATUS
//         //////////////////////////////////////////////////////
//         validateStatus: (status) {
//           return status != null && status < 500;
//         },
//       ),
//     );
//
//     ////////////////////////////////////////////////////////////
//     /// LOG INTERCEPTOR
//     ////////////////////////////////////////////////////////////
//     dio.interceptors.add(
//       InterceptorsWrapper(
//         onRequest: (options, handler) {
//           debugPrint('');
//           debugPrint('=========== API REQUEST ===========');
//           debugPrint('METHOD : ${options.method}');
//           debugPrint('URL    : ${options.uri}');
//           debugPrint('HEADERS: ${options.headers}');
//           debugPrint('===================================');
//
//           handler.next(options);
//         },
//
//         onResponse: (response, handler) {
//           debugPrint('');
//           debugPrint('=========== API RESPONSE ==========');
//           debugPrint('STATUS : ${response.statusCode}');
//           debugPrint('URL    : ${response.requestOptions.uri}');
//           debugPrint('DATA   : ${response.data}');
//           debugPrint('===================================');
//
//           handler.next(response);
//         },
//
//         onError: (e, handler) {
//           debugPrint('');
//           debugPrint('============= DIO ERROR ===========');
//           debugPrint('TYPE    : ${e.type}');
//           debugPrint('MESSAGE : ${e.message}');
//           debugPrint('STATUS  : ${e.response?.statusCode}');
//           debugPrint('URL     : ${e.requestOptions.uri}');
//           debugPrint('DATA    : ${e.response?.data}');
//           debugPrint('===================================');
//
//           handler.next(e);
//         },
//       ),
//     );
//
//     return dio;
//   }
//
//   ////////////////////////////////////////////////////////////
//   /// RESET
//   ////////////////////////////////////////////////////////////
//   static void reset() {
//     try {
//       _dio?.close(force: true);
//     } catch (_) {}
//
//     _dio = null;
//   }
// }
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_config.dart';

class DioClient {
  static Dio? _dio;

  static Dio get dio => _dio ??= _create();

  static Dio _create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          debugPrint('=========== API REQUEST ===========');
          debugPrint('METHOD : ${options.method}');
          debugPrint('URL    : ${options.uri}');
          debugPrint('===================================');
          handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint('=========== API RESPONSE ==========');
          debugPrint('STATUS : ${response.statusCode}');
          debugPrint('URL    : ${response.requestOptions.uri}');
          debugPrint('===================================');
          handler.next(response);
        },
        onError: (e, handler) {
          debugPrint('============= DIO ERROR ===========');
          debugPrint('TYPE    : ${e.type}');
          debugPrint('MESSAGE : ${e.message}');
          debugPrint('STATUS  : ${e.response?.statusCode}');
          debugPrint('URL     : ${e.requestOptions.uri}');
          debugPrint('DATA    : ${e.response?.data}');
          debugPrint('===================================');
          handler.next(e);
        },
      ),
    );

    return dio;
  }

  static Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _retry(() => dio.get<T>(path, queryParameters: queryParameters));
  }

  static Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _retry(
      () => dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  static Future<Response<T>> postUpload<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _retry(
      () => dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          sendTimeout: const Duration(seconds: 180),
          receiveTimeout: const Duration(seconds: 180),
        ),
      ),
    );
  }

  static Future<Response<T>> putUpload<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _retry(
      () => dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 180),
          receiveTimeout: const Duration(seconds: 180),
        ),
      ),
    );
  }

  static Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _retry(
      () => dio.delete<T>(path, data: data, queryParameters: queryParameters),
    );
  }

  static Future<Response<T>> _retry<T>(
    Future<Response<T>> Function() request, {
    int maxRetry = 2,
  }) async {
    int attempt = 0;

    while (true) {
      try {
        return await request();
      } on DioException catch (e) {
        attempt++;

        final canRetry =
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionError;

        if (!canRetry || attempt > maxRetry) {
          rethrow;
        }

        await Future.delayed(Duration(milliseconds: 700 * attempt));
      }
    }
  }

  static void reset() {
    try {
      _dio?.close(force: true);
    } catch (_) {}
    _dio = null;
  }
}
