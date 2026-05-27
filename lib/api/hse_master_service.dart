import 'package:dio/dio.dart';

import '../homeScreen/patrol_home_screen.dart';
import '../model/hse_patrol_team_model.dart';
import '../model/machine_model.dart';
import '../network/dio_error_handler.dart';
import 'dio_client.dart';

class HseMasterService {
  static Future<List<MachineModel>> fetchMachines() async {
    try {
      final res = await DioClient.get('/api/hse_master');

      if (res.statusCode == 200 && res.data is List) {
        final List data = res.data as List;
        return data
            .map((e) => MachineModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      throw Exception(
        'Invalid machine response | status=${res.statusCode} | data=${res.data}',
      );
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.handle(e));
    }
  }

  static Future<List<HsePatrolTeamModel>> fetchAll() async {
    try {
      final res = await DioClient.get('/api/patrol_teams');

      if (res.statusCode == 200 && res.data is List) {
        final List data = res.data as List;
        return data
            .map(
              (e) => HsePatrolTeamModel.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList();
      }

      throw Exception(
        'Invalid patrol team response | status=${res.statusCode} | data=${res.data}',
      );
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.handle(e));
    }
  }

  static HsePatrolTeamModel? findTeamByEmp(
    String empCode,
    PatrolGroup groupType,
    List<HsePatrolTeamModel> teams,
  ) {
    final code = empCode.trim();
    if (code.isEmpty) return null;

    final typeStr = groupType.name;

    for (final t in teams) {
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

      if (pics.any((p) => p != null && p.trim() == code)) {
        return t;
      }
    }

    return null;
  }

  static Future<String?> fetchEmployeeName(String code) async {
    final empCode = code.trim();
    if (empCode.isEmpty) return null;

    try {
      final res = await DioClient.get(
        '/api/hr/name',
        queryParameters: {'code': empCode},
      );

      if (res.statusCode == 200) {
        final name = res.data?.toString().trim();
        return (name == null || name.isEmpty) ? null : name;
      }

      return null;
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.handle(e));
    }
  }
}
