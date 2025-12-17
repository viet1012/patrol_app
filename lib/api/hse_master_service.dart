import 'package:dio/dio.dart';

import '../model/hse_patrol_team_model.dart';
import '../model/machine_model.dart';
import 'dio_client.dart';

class HseMasterService {
  /// GET /api/hse_master
  static Future<List<MachineModel>> fetchMachines() async {
    try {
      final Response res = await DioClient.dio.get('/api/hse_master');

      final List data = res.data;
      return data.map((e) => MachineModel.fromJson(e)).toList();
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  /// GET /api/hse/patrol-teams
  static Future<List<HsePatrolTeamModel>> fetchAll() async {
    try {
      final Response res = await DioClient.dio.get('/api/hse/patrol-teams');

      final List data = res.data;
      return data.map((e) => HsePatrolTeamModel.fromJson(e)).toList();
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  /// X? lý l?i Dio chu?n
  static String _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection to server timed out';
    }

    if (e.type == DioExceptionType.connectionError) {
      return 'Unable to connect to the server';
    }

    if (e.response != null) {
      return 'Server error ${e.response?.statusCode}: '
          '${e.response?.data ?? 'Unknown error'}';
    }

    return 'Unknown error occurred';
  }
}
