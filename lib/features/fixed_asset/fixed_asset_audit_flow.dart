import 'package:flutter/foundation.dart' show ValueListenable;

import 'package:chuphinh/core/models/fixed_asset_audit_check_response.dart';
import 'package:chuphinh/core/models/fixed_asset_audit_save_response.dart';
import 'package:chuphinh/core/models/fixed_asset_reprint_info.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_location.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_qr_parser.dart';

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

  /// AUTO đang khóa một khu vực chưa xong: QR khu vực khác bị chặn (không
  /// check / không lưu).
  zoneLocked,
  /// MANUAL: quét khi chưa chọn đủ Fac/Floor/PositionA/PositionAA (không
  /// gọi API; có thể đề nghị dùng vị trí trong QR).
  needsLocation,

  /// MANUAL: vị trí in trên QR khác vị trí đang chọn: đang chờ xác nhận
  /// hoặc operator đã "Bỏ qua".
  qrLocationMismatch,

  /// Đã lưu với QR lệch vị trí: đã kiểm kê, cần in lại QR
  /// (backend không đếm vào tiến độ).
  qrReprintSaved,

  /// Máy đang chờ in lại được quét bằng tem cũ: không đổi gì, vẫn cần in tem
  /// (không hiện "Đã kiểm kê").
  qrLabelNotReplaced,

  /// Tem mới khớp vị trí thực tế: backend đã gỡ đánh dấu in lại.
  qrReprintCleared,
}

/// Dropdown của cascade MANUAL (đánh dấu ô còn trống đầu tiên).
enum FixedAssetManualField { fac, floor, positionA, positionAA }

/// Phân loại kết quả /audit-check trong AUTO.
enum FixedAssetAutoCheckOutcome {
  alreadyAudited,

  /// Đang chờ in lại QR (needsQrReprint): QR cũ / gỡ cờ / máy đã dời theo
  /// [classifyFixedAssetReprintRescan].
  reprintRescan,
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

  /// MASTER looked up while the dialog is already open (MANUAL local
  /// check); overrides [master] once it has a value.
  final ValueListenable<FixedAssetAuditLocation?>? masterUpdates;

  /// MANUAL flow: large "Vẫn lưu" / "Bỏ qua" buttons.
  final bool manual;

  const FixedAssetMismatchPrompt({
    required this.machineCode,
    required this.faName,
    required this.master,
    required this.actual,
    this.unmappedActual,
    this.masterUpdates,
    this.manual = false,
  });
}

/// UI trả true = "Vẫn lưu", false = "Hủy".
typedef FixedAssetConfirmMismatch =
    Future<bool> Function(FixedAssetMismatchPrompt prompt);

/// Vị trí in trên QR, gửi kèm mọi POST /audit của scan (qrFloor /
/// qrPositionA / qrPositionAA; MANUAL thêm qrLocationMismatch).
/// Field null = QR không có thông tin đó (layout KVH_{mã máy}_{floor}_{AA}
/// không in PositionA: backend tự tra A_Qr từ MAP).
class FixedAssetQrLocationCheck {
  final String? floor;
  final String? positionA;
  final String? positionAA;
  final bool mismatch;

  const FixedAssetQrLocationCheck({
    this.floor,
    this.positionA,
    this.positionAA,
    required this.mismatch,
  });
}

/// So vị trí dropdown với các field vị trí QR có (bỏ mọi khoảng trắng, không
/// phân biệt hoa thường). Field QR rỗng -> bỏ qua; QR không có vị trí ->
/// không lệch. Fac không so (QR không in Fac, chưa có bảng alias).
FixedAssetQrLocationCheck fixedAssetManualQrCheck(
  FixedAssetQrData qr,
  FixedAssetAuditLocation selected,
) {
  String norm(String v) => v.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  String? valueOf(String v) => v.trim().isEmpty ? null : v.trim();
  bool differs(String? qrValue, String selectedValue) =>
      qrValue != null && norm(qrValue) != norm(selectedValue);

  final floor = valueOf(qr.floor);
  final positionA = valueOf(qr.positionA);
  final positionAA = valueOf(qr.positionAA);
  final mismatch =
      differs(floor, selected.floor) ||
      differs(positionA, selected.positionA) ||
      differs(positionAA, selected.positionAA);

  return FixedAssetQrLocationCheck(
    floor: floor,
    positionA: positionA,
    positionAA: positionAA,
    mismatch: mismatch,
  );
}

/// AUTO: vị trí in trên QR gửi kèm POST /audit. Không so lệch vì ACTUAL
/// được resolve từ chính QR.
FixedAssetQrLocationCheck fixedAssetAutoQrLocation(FixedAssetQrData qr) {
  String? valueOf(String v) => v.trim().isEmpty ? null : v.trim();

  return FixedAssetQrLocationCheck(
    floor: valueOf(qr.floor),
    positionA: valueOf(qr.positionA),
    positionAA: valueOf(qr.positionAA),
    mismatch: false,
  );
}

/// Dữ liệu cho dialog "QR không khớp vị trí đang chọn" (MANUAL).
class FixedAssetQrMismatchPrompt {
  final String machineCode;
  final String faName;
  final FixedAssetAuditLocation selected;
  final FixedAssetQrLocationCheck qr;

  const FixedAssetQrMismatchPrompt({
    required this.machineCode,
    required this.faName,
    required this.selected,
    required this.qr,
  });
}

/// UI trả true = "Vẫn lưu (đánh dấu in lại QR)", false = "Bỏ qua".
typedef FixedAssetConfirmQrMismatch =
    Future<bool> Function(FixedAssetQrMismatchPrompt prompt);

/// Máy đang chờ in lại tem, vị trí tem / vị trí chọn khác vị trí thực tế đã
/// ghi nhận: hỏi "máy đã dời?" (labels dạng "Fac/Floor/A/AA").
class FixedAssetReprintMovePrompt {
  final String machineCode;
  final String faName;

  /// Vị trí thực tế đang ghi nhận (reprintAct*); null = không tra được.
  final String? recordedLabel;
  final String selectedLabel;

  const FixedAssetReprintMovePrompt({
    required this.machineCode,
    required this.faName,
    required this.recordedLabel,
    required this.selectedLabel,
  });
}

/// UI trả true = "Xác nhận đã dời", false = "Hủy".
typedef FixedAssetConfirmReprintMove =
    Future<bool> Function(FixedAssetReprintMovePrompt prompt);

/// Popup "QR chưa được thay" (save trả qrLabelNotReplaced).
class FixedAssetLabelNotReplacedPrompt {
  final String machineCode;
  final String faName;

  /// reprintAct* / reprintQr* từ backend; null = không tra được.
  final FixedAssetReprintInfo? reprint;

  const FixedAssetLabelNotReplacedPrompt({
    required this.machineCode,
    required this.faName,
    required this.reprint,
  });
}

enum FixedAssetLabelNotReplacedAction {
  /// "Quét QR mới": vào chế độ chờ QR mới.
  scanNewLabel,

  /// "Để sau": giữ card "QR chưa được thay", không chờ.
  later,
}

typedef FixedAssetShowLabelNotReplaced =
    Future<FixedAssetLabelNotReplacedAction> Function(
      FixedAssetLabelNotReplacedPrompt prompt,
    );

/// Chế độ chờ tem mới: máy [machineCode] vừa quét bằng tem cũ, đang chờ quét
/// tem in lại.
class FixedAssetAwaitingLabel {
  final String machineCode;
  final String faName;

  /// Vị trí thực tế + tem cũ (reprintQr*); null = không tra được (tem cũ khi
  /// đó do backend nhận ra qua qrLabelNotReplaced).
  final FixedAssetReprintInfo? reprint;

  const FixedAssetAwaitingLabel({
    required this.machineCode,
    required this.faName,
    required this.reprint,
  });

  /// PositionAA thực tế cho banner ("-" khi không rõ).
  String get actualPositionAA {
    final aa = reprint?.actPositionAA?.trim() ?? '';
    return aa.isEmpty ? '-' : aa;
  }

  bool isMachine(String code) =>
      code.trim().toLowerCase() == machineCode.trim().toLowerCase();
}

/// Quét lại máy needsQrReprint (theo audit-check, trước mọi dialog / save).
enum FixedAssetReprintRescan {
  /// QR = reprintQr*: popup "QR chưa được thay" (chờ QR mới: toast), không save.
  oldLabel,

  /// Save (kèm qr*), backend quyết định: QR = reprintAct* và vị trí chọn =
  /// reprintAct* (gỡ cờ), hoặc dòng NO_QR / không rõ tem hiện tại.
  save,

  /// Còn lại: dialog "Máy đã dời?", xác nhận thì save với
  /// confirmLocationMismatch.
  moved,
}

/// [selectedFac]... = vị trí đang chọn (MANUAL: dropdown; AUTO: ACTUAL
/// resolve từ QR). Cùng quy tắc với backend: Fac chỉ so khi cả hai có. QR
/// không in A thì không so A (backend tự tra; lệch thì POST trả
/// requiresConfirmation -> dialog dời).
///
/// Dòng NO_QR (reprintQr* null) hoặc không có reprint*: không có "QR cũ" để
/// so -> luôn save, backend gỡ cờ hoặc yêu cầu xác nhận dời.
FixedAssetReprintRescan classifyFixedAssetReprintRescan(
  FixedAssetQrData qr,
  FixedAssetReprintInfo? reprint, {
  required String? selectedFac,
  required String selectedFloor,
  required String? selectedPositionA,
  required String selectedPositionAA,
}) {
  if (reprint == null || reprint.labelUnknown || !reprint.hasLabel) {
    return FixedAssetReprintRescan.save;
  }
  if (fixedAssetQrIsOldLabel(qr, reprint)) {
    return FixedAssetReprintRescan.oldLabel;
  }
  if (!reprint.hasAct) return FixedAssetReprintRescan.moved;

  String norm(String? v) => (v ?? '').trim().toUpperCase();
  bool same(String? a, String? b) =>
      norm(a).isNotEmpty && norm(a) == norm(b);
  bool sameIfBoth(String? a, String? b) =>
      norm(a).isEmpty || norm(b).isEmpty || norm(a) == norm(b);

  final qrIsActual =
      same(qr.floor, reprint.actFloor) &&
      same(qr.positionAA, reprint.actPositionAA) &&
      sameIfBoth(qr.positionA, reprint.actPositionA);
  final selectedIsActual =
      sameIfBoth(selectedFac, reprint.actFac) &&
      same(selectedFloor, reprint.actFloor) &&
      same(selectedPositionA, reprint.actPositionA) &&
      same(selectedPositionAA, reprint.actPositionAA);

  return qrIsActual && selectedIsActual
      ? FixedAssetReprintRescan.save
      : FixedAssetReprintRescan.moved;
}

/// QR vừa quét vẫn là tem cũ ([label].qr*), cùng quy tắc với backend: Floor
/// + AA phải trùng; A chỉ so khi cả hai có. Tem cũ không rõ / NO_QR -> false.
bool fixedAssetQrIsOldLabel(FixedAssetQrData qr, FixedAssetReprintInfo? label) {
  if (label == null || label.labelUnknown || !label.hasLabel) return false;
  String norm(String? v) =>
      (v ?? '').replaceAll(RegExp(r'\s+'), '').toUpperCase();
  bool same(String qrValue, String? labelValue) =>
      norm(qrValue) == norm(labelValue);

  if (qr.floor.trim().isEmpty || qr.positionAA.trim().isEmpty) return false;
  if (!same(qr.floor, label.qrFloor)) return false;
  if (!same(qr.positionAA, label.qrPositionAA)) return false;
  final labelA = label.qrPositionA;
  if (qr.positionA.trim().isNotEmpty &&
      labelA != null &&
      labelA.trim().isNotEmpty &&
      !same(qr.positionA, labelA)) {
    return false;
  }
  return true;
}

/// Thứ tự ưu tiên (không đổi):
/// 0. đang chờ in lại QR -> [classifyFixedAssetReprintRescan] (QR cũ / gỡ cờ
///    / máy đã dời), không qua dialog sai vị trí
/// 1. đã kiểm kê trong kỳ -> không POST, không hỏi mismatch
/// 2. known machine + vị trí đang quét không có trong MAP + cho xác nhận
/// 3. vị trí đang quét không resolve được (không xác nhận được) -> lỗi
/// 4. known machine + khác MASTER -> hỏi trước khi save
/// 5. khớp vị trí, hoặc machine ngoài MASTER -> save thẳng
FixedAssetAutoCheckOutcome classifyFixedAssetAutoCheck(
  FixedAssetAuditCheckResponse check,
  FixedAssetAuditLocation? actual,
) {
  if (check.needsQrReprint) return FixedAssetAutoCheckOutcome.reprintRescan;
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

/// Backend yêu cầu xác nhận sai vị trí khi POST (chủ yếu MANUAL), hoặc máy
/// đang chờ in lại tem có vị trí khác vị trí thực tế đã ghi nhận
/// ([fixedAssetSaveIsReprintMove], response có alreadyAudited = true).
bool fixedAssetSaveNeedsConfirmation(
  FixedAssetAuditSaveResponse? result, {
  required bool confirmLocationMismatch,
}) {
  return result != null &&
      !confirmLocationMismatch &&
      !result.saved &&
      result.requiresConfirmation &&
      (!result.alreadyAudited || result.needsQrReprint);
}

/// requiresConfirmation của nhánh quét lại máy đang chờ in lại tem.
bool fixedAssetSaveIsReprintMove(FixedAssetAuditSaveResponse result) =>
    result.alreadyAudited && result.needsQrReprint;

/// Lỗi 400 khi máy chờ in lại mà request thiếu qrFloor / qrPositionAA.
bool fixedAssetIsMissingQrLocationError(String message) {
  final lower = message.toLowerCase();
  return lower.contains('qrfloor') && lower.contains('required');
}

String fixedAssetErrorText(Object error) {
  return error.toString().replaceFirst('Exception: ', '');
}
