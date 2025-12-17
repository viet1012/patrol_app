import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/hse_patrol_team_model.dart';
import '../model/machine_model.dart';
import 'api_config.dart';

class HseMasterService {
  static String baseUrl = ApiConfig.baseUrl;

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

  static Future<List<HsePatrolTeamModel>> fetchAll() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/hse/patrol-teams'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => HsePatrolTeamModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load patrol teams');
    }
  }
}
