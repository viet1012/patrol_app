import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/auto_cmp.dart';

class AutoCmpApi {
  static const String baseUrl =
      "http://127.0.0.1:9299/api/suggest";

  static Future<List<AutoCmp>> search(String keyword) async {
    if (keyword.isEmpty) return [];

    final uri = Uri.parse("$baseUrl/search?q=$keyword");
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((e) => AutoCmp.fromJson(e)).toList();
    } else {
      throw Exception("API error");
    }
  }
}
