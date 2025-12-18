import 'package:dio/dio.dart';

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
}
