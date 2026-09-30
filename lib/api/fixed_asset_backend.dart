import '../model/fixed_asset_audit_check_response.dart';
import '../model/fixed_asset_audit_save_response.dart';
import '../model/fixed_asset_audit_summary.dart';
import '../model/fixed_asset_machine.dart';
import '../model/fixed_asset_zone_lock.dart';
import '../model/fixed_asset_zone_progress.dart';
import 'fixed_asset_api.dart';

/// Các endpoint Fixed Asset mà FixedAssetController dùng, dạng instance để
/// test có thể thay bằng bản giả. Bản mặc định gọi thẳng [FixedAssetApi].
class FixedAssetBackend {
  const FixedAssetBackend();

  Future<FixedAssetAuditSummary> fetchAuditSummary() =>
      FixedAssetApi.fetchAuditSummary();

  Future<List<FixedAssetZoneProgressRow>> fetchZoneProgress({
    required String fac,
    required String floor,
  }) => FixedAssetApi.fetchZoneProgress(fac: fac, floor: floor);

  Future<FixedAssetZoneLock> fetchZoneLock({required String userId}) =>
      FixedAssetApi.fetchZoneLock(userId: userId);

  Future<FixedAssetAuditCheckResponse> checkAudit({
    required String machineCode,
    required String floor,
    required String positionAA,
  }) => FixedAssetApi.checkAudit(
    machineCode: machineCode,
    floor: floor,
    positionAA: positionAA,
  );

  Future<FixedAssetAuditSaveResponse> saveAudit({
    required String? fac,
    required String floor,
    required String? positionA,
    required String positionAA,
    required String machineCode,
    required String userId,
    required String userName,
    bool confirmLocationMismatch = false,
    String? mode,
  }) => FixedAssetApi.saveAudit(
    fac: fac,
    floor: floor,
    positionA: positionA,
    positionAA: positionAA,
    machineCode: machineCode,
    userId: userId,
    userName: userName,
    confirmLocationMismatch: confirmLocationMismatch,
    mode: mode,
  );

  Future<List<FixedAssetMachine>> fetchMachines({
    required String fac,
    required String floor,
    required String positionA,
    required String positionAA,
  }) => FixedAssetApi.fetchMachines(
    fac: fac,
    floor: floor,
    positionA: positionA,
    positionAA: positionAA,
  );
}
