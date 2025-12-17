import 'package:dio/dio.dart';
import 'api_config.dart';

class DioClient {
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'ngrok-skip-browser-warning': 'true'},
    ),
  );
}
