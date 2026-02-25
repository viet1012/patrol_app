import 'package:dio/dio.dart';

import 'api_config.dart';

// class DioClient {
//   static final Dio dio = Dio(
//     BaseOptions(
//       baseUrl: ApiConfig.baseUrl,
//       connectTimeout: const Duration(seconds: 10),
//       receiveTimeout: const Duration(seconds: 10),
//       headers: {'ngrok-skip-browser-warning': 'true'},
//     ),
//   );
// }
class DioClient {
  static Dio? _dio;

  static Dio get dio => _dio ??= _create();

  static Dio _create() {
    return Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'ngrok-skip-browser-warning': 'true'},
      ),
    );
  }

  static void reset() {
    try {
      _dio?.close(force: true);
    } catch (_) {}
    _dio = null;
  }
}
