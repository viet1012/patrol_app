import 'package:dio/dio.dart';

import '../model/auto_cmp.dart';
import '../network/dio_error_handler.dart';
import 'dio_client.dart';

class AutoCmpApi {
  /// GET /api/suggest/search
  static Future<List<AutoCmp>> search(String lang, String keyword) async {
    if (keyword.trim().isEmpty) return [];

    try {
      final Response res = await DioClient.dio.get(
        '/api/suggest/search',
        queryParameters: {'l': lang, 'q': keyword},
      );

      return _parseList(res.data);
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.handle(e));
    }
  }

  /// GET /api/suggest/searchCounter
  static Future<List<AutoCmp>> searchCounter(
    String lang,
    String keyword,
  ) async {
    if (keyword.trim().isEmpty) return [];

    try {
      final Response res = await DioClient.dio.get(
        '/api/suggest/searchCounter',
        queryParameters: {'l': lang, 'q': keyword},
      );

      return _parseList(res.data);
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.handle(e));
    }
  }

  // =======================
  // Helpers
  // =======================

  static List<AutoCmp> _parseList(dynamic data) {
    if (data is List) {
      return data.map((e) => AutoCmp.fromJson(e)).toList();
    }
    throw Exception('Unexpected response format');
  }
}
