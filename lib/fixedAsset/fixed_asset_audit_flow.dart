import '../model/fixed_asset_audit_check_response.dart';
import '../model/fixed_asset_audit_save_response.dart';
import 'fixed_asset_location.dart';

// Quy tắc nghiệp vụ thuần (không state, không UI) của luồng kiểm kê.

/// AUTO: QR -> MachineCode + Floor + PositionAA -> audit-check
///       -> (đã kiểm kê: dừng | sai vị trí: hỏi | khớp/ngoài master: save).
/// MANUAL: chọn location bằng cascade -> QR -> save (backend vẫn có thể
///         yêu cầu xác nhận sai vị trí).
enum FixedAssetLocationMode { auto, manual }

/// saved (insert mới) và alreadyAudited (đã có trong kỳ) là hai kết quả
/// nghiệp vụ khác nhau, không gộp chung.
enum FixedAssetScanStatus {
  idle,
  checking,
  saving,
  saved,
  alreadyAudited,

  /// Sai vị trí so với MASTER: đang chờ xác nhận hoặc operator đã Hủy.
  locationMismatch,

  /// Đã lưu sau khi operator xác nhận "Vẫn lưu".
  mismatchSaved,
  unknownSaved,
  failed,
}

/// Phân loại kết quả /audit-check trong AUTO.
enum FixedAssetAutoCheckOutcome {
  alreadyAudited,
  unmappedActual,
  unresolvedActual,
  mappedMismatch,
  directSave,
}

/// Dữ liệu cho dialog xác nhận sai vị trí (UI tự quyết cách hiển thị).
///
/// - [actual] có: mapped mismatch.
/// - [actual] null + [unmappedActual] có: vị trí đang quét không có trong MAP.
class FixedAssetMismatchPrompt {
  final String machineCode;
  final String faName;
  final FixedAssetAuditLocation? master;
  final FixedAssetAuditLocation? actual;
  final FixedAssetUnmappedActual? unmappedActual;

  const FixedAssetMismatchPrompt({
    required this.machineCode,
    required this.faName,
    required this.master,
    required this.actual,
    this.unmappedActual,
  });
}

/// UI trả true = "Vẫn lưu", false = "Hủy".
typedef FixedAssetConfirmMismatch =
    Future<bool> Function(FixedAssetMismatchPrompt prompt);

/// Thứ tự ưu tiên (không đổi):
/// 1. đã kiểm kê trong kỳ -> không POST, không hỏi mismatch
/// 2. known machine + vị trí đang quét không có trong MAP + cho xác nhận
/// 3. vị trí đang quét không resolve được (không xác nhận được) -> lỗi
/// 4. known machine + khác MASTER -> hỏi trước khi save
/// 5. khớp vị trí, hoặc machine ngoài MASTER -> save thẳng
FixedAssetAutoCheckOutcome classifyFixedAssetAutoCheck(
  FixedAssetAuditCheckResponse check,
  FixedAssetAuditLocation? actual,
) {
  if (check.alreadyAudited) return FixedAssetAutoCheckOutcome.alreadyAudited;

  if (check.existsInMaster &&
      !check.actualLocationResolved &&
      check.requiresConfirmation) {
    return FixedAssetAutoCheckOutcome.unmappedActual;
  }

  if (!check.actualLocationResolved || actual == null) {
    return FixedAssetAutoCheckOutcome.unresolvedActual;
  }

  if (check.existsInMaster &&
      (!check.locationMatch || check.requiresConfirmation)) {
    return FixedAssetAutoCheckOutcome.mappedMismatch;
  }

  return FixedAssetAutoCheckOutcome.directSave;
}

/// ACTUAL strict (đủ 4 field) từ audit-check.
FixedAssetAuditLocation? fixedAssetActualOf(FixedAssetAuditCheckResponse check) {
  return fixedAssetStrictLocation(
    check.actualFac,
    check.actualFloor,
    check.actualPositionA,
    check.actualPositionAA,
  );
}

/// MASTER strict (đủ 4 field) từ audit-check.
FixedAssetAuditLocation? fixedAssetStrictMasterOf(
  FixedAssetAuditCheckResponse check,
) {
  return fixedAssetStrictLocation(
    check.masterFac,
    check.masterFloor,
    check.masterPositionA,
    check.masterPositionAA,
  );
}

/// MASTER hiển thị từ response backend (không suy từ QR); field thiếu
/// hiện "-" thay vì ẩn toàn bộ MASTER.
FixedAssetAuditLocation? fixedAssetMasterDisplayOf(
  FixedAssetAuditCheckResponse check,
) {
  return fixedAssetMasterDisplay(
    check.masterFac,
    check.masterFloor,
    check.masterPositionA,
    check.masterPositionAA,
  );
}

/// Message lỗi thân thiện cho audit-check / ACTUAL location.
String fixedAssetCheckErrorMessage(String raw, String fallback) {
  final lower = raw.toLowerCase();
  if (lower.contains('ambiguous') || lower.contains('multiple')) {
    return 'QR location is ambiguous';
  }
  if (lower.contains('not found')) {
    return lower.contains('location') ? 'QR location not found' : raw;
  }
  return fallback;
}

/// Insert mới cho machine MASTER (kể cả mismatch đã xác nhận) -> tiến độ đổi.
bool isNewFixedAssetMasterAudit(FixedAssetAuditSaveResponse? result) {
  return result != null &&
      result.saved &&
      !result.alreadyAudited &&
      !result.unknownMachine;
}

/// Backend yêu cầu xác nhận sai vị trí khi POST (chủ yếu MANUAL).
bool fixedAssetSaveNeedsConfirmation(
  FixedAssetAuditSaveResponse? result, {
  required bool confirmLocationMismatch,
}) {
  return result != null &&
      !confirmLocationMismatch &&
      !result.saved &&
      !result.alreadyAudited &&
      result.requiresConfirmation;
}

String fixedAssetErrorText(Object error) {
  return error.toString().replaceFirst('Exception: ', '');
}
