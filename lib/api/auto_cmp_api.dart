import 'dart:convert';

import 'package:dio/dio.dart';

import '../model/auto_cmp.dart';
import 'api_config.dart';

class AutoCmpApi {
  static final Dio _dio = Dio()
    ..options.headers['ngrok-skip-browser-warning'] =
        'true'; // thêm header vào dây

  static final String baseUrl = "${ApiConfig.baseUrl}/api/suggest";

  static Future<List<AutoCmp>> search(String lang, String keyword) async {
    print('lang: $lang');
    if (keyword.isEmpty) return [];

    final url = "$baseUrl/search";
    try {
      final response = await _dio.get(url, queryParameters: {'q': keyword});

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data.map((e) => AutoCmp.fromJson(e)).toList();
        } else if (data is String) {
          final List<dynamic> decoded = json.decode(data);
          return decoded.map((e) => AutoCmp.fromJson(e)).toList();
        } else {
          throw Exception("Unexpected data format");
        }
      } else {
        throw Exception("API error, status code: ${response.statusCode}");
      }
    } on DioError catch (e) {
      throw Exception("Dio error: ${e.message}");
    }
  }

  static Future<List<AutoCmp>> searchCounter(String lang, String keyword) async {
    if (keyword.isEmpty) return [];

    final url = "$baseUrl/searchCounter";
    try {
      final response = await _dio.get(url, queryParameters: {'q': keyword});

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data.map((e) => AutoCmp.fromJson(e)).toList();
        } else if (data is String) {
          final List<dynamic> decoded = json.decode(data);
          return decoded.map((e) => AutoCmp.fromJson(e)).toList();
        } else {
          throw Exception("Unexpected data format");
        }
      } else {
        throw Exception("API error, status code: ${response.statusCode}");
      }
    } on DioError catch (e) {
      throw Exception("Dio error: ${e.message}");
    }
  }
}
