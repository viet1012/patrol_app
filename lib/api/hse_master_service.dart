import 'package:dio/dio.dart';

import '../homeScreen/patrol_home_screen.dart';
import '../model/hse_patrol_team_model.dart';
import '../model/machine_model.dart';
import '../network/dio_error_handler.dart';
import 'dio_client.dart';

class HseMasterService {
  static Future<List<MachineModel>> fetchMachines() async {
    try {
      final res = await DioClient.dio.get('/api/hse_master');
      final List data = res.data;
      return data.map((e) => MachineModel.fromJson(e)).toList();
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.handle(e));
    }
  }

  static Future<List<HsePatrolTeamModel>> fetchAll() async {
    try {
      final res = await DioClient.dio.get('/api/patrol_teams');
      final List data = res.data;
      return data.map((e) => HsePatrolTeamModel.fromJson(e)).toList();
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.handle(e));
    }
  }

  static HsePatrolTeamModel? findTeamByEmp(
    String empCode,
    PatrolGroup groupType,
    List<HsePatrolTeamModel> teams,
  ) {
    if (empCode.trim().isEmpty) return null;

    final typeStr = groupType.name;
    // PatrolGroup.Patrol → "Patrol"

    for (final t in teams) {
      // 🔹 filter theo type trước
      if (t.type != typeStr) continue;

      final pics = [
        t.pic1,
        t.pic2,
        t.pic3,
        t.pic4,
        t.pic5,
        t.pic6,
        t.pic7,
        t.pic8,
        t.pic9,
        t.pic10,
      ];

      if (pics.any((p) => p != null && p.trim() == empCode)) {
        return t;
      }
    }
    return null;
  }
}
