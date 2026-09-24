import 'package:dio/dio.dart';

import '../model/fixed_asset_audit_save_response.dart';
import '../model/fixed_asset_audit_summary.dart';
import '../model/fixed_asset_machine.dart';
import '../model/fixed_asset_machine_location.dart';
import '../model/fixed_asset_scan_info.dart';
import '../network/dio_error_handler.dart';
import 'dio_client.dart';

enum FixedAssetLookupError { notFound, ambiguous, failed }

/// Lỗi khi tra MASTER location, đã phân loại để UI hiển thị đúng.
class FixedAssetLookupException implements Exception {
  final FixedAssetLookupError kind;
  final String message;

  const FixedAssetLookupException(this.kind, [this.message = '']);

  @override
  String toString() => message;
}

class FixedAssetApi {
  static const String _base = '/api/fixed-assets';

  static Future<List<String>> fetchFacs() {
    return _getStrings('$_base/facs');
  }

  static Future<List<String>> fetchFloors(String fac) {
    return _getStrings('$_base/floors', {'fac': fac});
  }

  static Future<List<String>> fetchPositionA({
    required String fac,
    required String floor,
  }) {
    return _getStrings('$_base/position-a', {'fac': fac, 'floor': floor});
  }

  static Future<List<String>> fetchPositionAA({
    required String fac,
    required String floor,
    required String positionA,
  }) {
    return _getStrings('$_base/position-aa', {
      'fac': fac,
      'floor': floor,
      'positionA': positionA,
    });
  }

  /// MachineCode đã có ít nhất một record audit (global, không lọc location).
  static Future<List<String>> fetchAuditedMachineCodes() async {
    final codes = await _getStrings('$_base/audited-machine-codes');
    return codes.toSet().toList();
  }

  /// Thông tin quyết định cho một scan: MASTER location + trạng thái kiểm kê
  /// trong kỳ hiện tại. Không retry (mỗi scan chỉ gọi một lần).
  static Future<FixedAssetScanInfo> fetchScanInfo(String machineCode) async {
    final data = await _getMapOnce(
      '$_base/scan-info',
      queryParameters: {'machineCode': machineCode},
    );
    return FixedAssetScanInfo.fromJson(data);
  }

  /// Tiến độ kiểm kê của kỳ 3 tháng hiện tại.
  static Future<FixedAssetAuditSummary> fetchAuditSummary() async {
    final data = await _getMapOnce('$_base/audit-summary');
    return FixedAssetAuditSummary.fromJson(data);
  }

  /// GET một object JSON, không qua _retry. Lỗi 4xx/5xx/format -> Exception
  /// với message server nếu có.
  static Future<Map<String, dynamic>> _getMapOnce(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    Response res;

    try {
      res = await DioClient.dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw Exception(
        _serverMessage(e.response?.data) ?? DioErrorHandler.handle(e),
      );
    }

    final status = res.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw Exception(_serverMessage(res.data) ?? 'Server error $status');
    }

    return _extractMap(res.data);
  }

  static Map<String, dynamic> _extractMap(dynamic data) {
    final map = data is Map && data['data'] is Map ? data['data'] : data;

    if (map is! Map) {
      throw Exception('Unexpected response format: ${data.runtimeType}');
    }

    return Map<String, dynamic>.from(map);
  }

  /// Tra location MASTER theo MachineCode.
  ///
  /// Không còn dùng cho AUTO scan (đã thay bằng [fetchScanInfo]); giữ lại
  /// để không phá caller khác.
  ///
  /// Gọi DioClient.dio trực tiếp (không qua _retry): mỗi scan chỉ tra
  /// đúng một lần. Lỗi được phân loại thành [FixedAssetLookupException].
  static Future<FixedAssetMachineLocation> fetchMachineLocation(
    String machineCode,
  ) async {
    Response res;

    try {
      res = await DioClient.dio.get(
        '$_base/machine-location',
        queryParameters: {'machineCode': machineCode},
      );
    } on DioException catch (e) {
      final response = e.response;
      if (response == null) {
        throw FixedAssetLookupException(
          FixedAssetLookupError.failed,
          DioErrorHandler.handle(e),
        );
      }
      res = response;
    }

    final status = res.statusCode ?? 0;
    final message = _serverMessage(res.data) ?? '';
    final lower = message.toLowerCase();

    if (status >= 200 && status < 300) {
      final data = res.data;
      final map = data is Map && data['data'] is Map ? data['data'] : data;

      if (map is! Map) {
        throw const FixedAssetLookupException(FixedAssetLookupError.notFound);
      }

      return FixedAssetMachineLocation.fromJson(
        Map<String, dynamic>.from(map),
      );
    }

    if (status == 409 || lower.contains('multiple')) {
      throw FixedAssetLookupException(FixedAssetLookupError.ambiguous, message);
    }

    if (status == 404 || lower.contains('not found')) {
      throw FixedAssetLookupException(FixedAssetLookupError.notFound, message);
    }

    throw FixedAssetLookupException(
      FixedAssetLookupError.failed,
      message.isEmpty ? 'Server error $status' : message,
    );
  }

  static Future<List<FixedAssetMachine>> fetchMachines({
    required String fac,
    required String floor,
    required String positionA,
    required String positionAA,
  }) async {
    try {
      final Response res = await DioClient.get(
        '$_base/machines',
        queryParameters: {
          'fac': fac,
          'floor': floor,
          'positionA': positionA,
          'positionAA': positionAA,
        },
      );

      return _extractList(res.data)
          .whereType<Map>()
          .map((e) => FixedAssetMachine.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.handle(e));
    }
  }

  /// UpdatedAt do backend tự set, không gửi từ frontend.
  ///
  /// HTTP 2xx không đồng nghĩa với insert mới: caller phải xét
  /// saved / alreadyAudited / unknownMachine trong response.
  static Future<FixedAssetAuditSaveResponse> saveAudit({
    required String fac,
    required String floor,
    required String positionA,
    required String positionAA,
    required String machineCode,
    required String userId,
    required String userName,
    String note = '',
  }) async {
    try {
      // Dùng DioClient.dio trực tiếp (không qua _retry): POST này INSERT
      // record, retry khi receiveTimeout có thể tạo record trùng.
      final Response res = await DioClient.dio.post(
        '$_base/audit',
        data: {
          'fac': fac,
          'floor': floor,
          'positionA': positionA,
          'positionAA': positionAA,
          'machineCode': machineCode,
          'userId': userId,
          'userName': userName,
          'note': note,
        },
      );

      // DioClient chỉ throw khi status >= 500, nên tự kiểm tra 4xx.
      final status = res.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw Exception(_serverMessage(res.data) ?? 'Server error $status');
      }

      return FixedAssetAuditSaveResponse.fromJson(_extractMap(res.data));
    } on DioException catch (e) {
      throw Exception(
        _serverMessage(e.response?.data) ?? DioErrorHandler.handle(e),
      );
    }
  }

  static String? _serverMessage(dynamic data) {
    if (data is Map) {
      final message = (data['message'] ?? data['error'])?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    }

    if (data is String && data.trim().isNotEmpty) return data.trim();

    return null;
  }

  static Future<List<String>> _getStrings(
    String path, [
    Map<String, dynamic>? queryParameters,
  ]) async {
    try {
      final Response res = await DioClient.get(
        path,
        queryParameters: queryParameters,
      );

      return _extractList(res.data)
          .where((e) => e != null)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.handle(e));
    }
  }

  /// Supports both a bare list and `{ "data": [...] }`.
  static List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;

    if (data is Map && data['data'] is List) {
      return data['data'] as List;
    }

    throw Exception('Unexpected response format: ${data.runtimeType}');
  }
}
