import 'package:dio/dio.dart';

import 'package:chuphinh/core/models/auto_cmp.dart';
import 'package:chuphinh/core/network/dio_error_handler.dart';
import 'package:chuphinh/core/network/dio_client.dart';

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
