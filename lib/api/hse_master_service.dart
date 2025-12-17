import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/machine_model.dart';

class HseMasterService {
  static const String baseUrl = 'http://localhost:9299';

  static Future<List<MachineModel>> fetchMachines() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/hse_master'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => MachineModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load HSE master');
    }
  }
}
