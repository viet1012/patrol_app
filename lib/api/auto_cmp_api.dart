import 'package:dio/dio.dart';

import '../model/auto_cmp.dart';
import '../network/dio_error_handler.dart';
import 'dio_client.dart';

class AutoCmpApi {
  /// Get all comment suggestions by language
  static Future<List<AutoCmp>> getAllComment(String lang) async {
    try {
      final Response res = await DioClient.get(
        '/api/suggest/comment',
        queryParameters: {'l': lang},
      );

      return _parseList(res.data);
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.handle(e));
    }
  }

  /// Get all countermeasure suggestions by language
  static Future<List<AutoCmp>> getAllCounter(String lang) async {
    try {
      final Response res = await DioClient.get(
        '/api/suggest/counter',
        queryParameters: {'l': lang},
      );

      return _parseList(res.data);
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.handle(e));
    }
  }

  /// Search comment suggestions
  static Future<List<AutoCmp>> search(String lang, String keyword) async {
    final q = keyword.trim();
    if (q.isEmpty) return [];

    try {
      final Response res = await DioClient.get(
        '/api/suggest/search',
        queryParameters: {'l': lang, 'q': q},
      );

      return _parseList(res.data);
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.handle(e));
    }
  }

  /// Search countermeasure suggestions
  static Future<List<AutoCmp>> searchCounter(
    String lang,
    String keyword,
  ) async {
    final q = keyword.trim();
    if (q.isEmpty) return [];

    try {
      final Response res = await DioClient.get(
        '/api/suggest/searchCounter',
        queryParameters: {'l': lang, 'q': q},
      );

      return _parseList(res.data);
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.handle(e));
    }
  }

  static List<AutoCmp> _parseList(dynamic data) {
    if (data is List) {
      return data
          .map((e) => AutoCmp.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => AutoCmp.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    throw Exception('Unexpected response format: ${data.runtimeType}');
  }
}
