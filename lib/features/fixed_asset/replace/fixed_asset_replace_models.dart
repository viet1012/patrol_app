import 'package:chuphinh/core/models/fixed_asset_qr_mismatch.dart';
import 'package:chuphinh/core/models/fixed_asset_reprint_info.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_audit_flow.dart'
    show fixedAssetQrIsOldLabel;
import 'package:chuphinh/features/fixed_asset/fixed_asset_location.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_qr_parser.dart';

/// Loại việc thay QR của một máy.
enum FixedAssetReplaceKind {
  /// NO_QR / chưa có QR (*_Qr null): quét 1 lần QR mới.
  missingQr,

  /// Đang dán QR sai vị trí: quét QR cũ (xác nhận gỡ) rồi QR mới.
  wrongQr,
}

/// Một máy còn chờ thay QR (một dòng GET /qr-mismatch).
class FixedAssetReplaceTask {
  final FixedAssetQrMismatch row;

  const FixedAssetReplaceTask(this.row);

  String get machineCode => row.machineCode;
  String get faName => row.faName;

  /// Khóa so sánh (trim, không phân biệt hoa thường).
  String get code => fixedAssetReplaceCode(machineCode);

  FixedAssetReplaceKind get kind => row.isNoQr || !row.hasQrLabel
      ? FixedAssetReplaceKind.missingQr
      : FixedAssetReplaceKind.wrongQr;

  /// Vị trí thực tế đầy đủ (*_Act); thiếu cấp nào -> null.
  FixedAssetAuditLocation? get location => fixedAssetReplaceLocationOf(row);

  /// Vị trí thực tế "Fac/Floor/A/AA".
  String get actLabel => fixedAssetLocationLabel(
    row.facAct,
    row.floorAct,
    row.positionA,
    row.positionAA,
  );

  /// QR đang dán: "Fac/Floor/A/AA" (*_Qr).
  String get oldQrLabel => fixedAssetLocationLabel(
    row.facQr,
    row.qrFloor,
    row.qrPositionA,
    row.qrPositionAA,
  );

  /// Dạng ngắn cho checklist / camera: AA (thiếu thì nhãn đầy đủ).
  String get actShort =>
      row.positionAA.trim().isNotEmpty ? row.positionAA.trim() : actLabel;
  String get oldQrShort =>
      row.qrPositionAA.trim().isNotEmpty ? row.qrPositionAA.trim() : oldQrLabel;

  /// *_Act / *_Qr của dòng, dạng dùng chung với luồng in lại QR.
  FixedAssetReprintInfo get reprint => FixedAssetReprintInfo(
    actFac: row.facAct,
    actFloor: row.floorAct,
    actPositionA: _opt(row.positionA),
    actPositionAA: _opt(row.positionAA),
    qrFac: row.facQr,
    qrFloor: _opt(row.qrFloor),
    qrPositionA: _opt(row.qrPositionA),
    qrPositionAA: _opt(row.qrPositionAA),
  );

  bool isMachine(String machineCode) =>
      fixedAssetReplaceCode(machineCode) == code;

  /// QR quét là QR cũ đang dán (mã máy đã khớp; vị trí = *_Qr). Không có QR
  /// cũ (Mất QR) -> false.
  bool isOldQr(FixedAssetQrData qr) => fixedAssetQrIsOldLabel(qr, reprint);

  /// Vị trí in trên QR = vị trí thực tế: Floor + AA trùng, A chỉ so khi cả
  /// hai có (cùng quy tắc với QR cũ).
  bool qrMatchesAct(FixedAssetQrData qr) {
    String norm(String? v) =>
        (v ?? '').replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (!qr.hasLocation) return false;
    if (norm(qr.floor) != norm(row.floorAct)) return false;
    if (norm(qr.positionAA) != norm(row.positionAA)) return false;
    final a = norm(qr.positionA);
    final actA = norm(row.positionA);
    return a.isEmpty || actA.isEmpty || a == actA;
  }

  static String? _opt(String v) => v.trim().isEmpty ? null : v.trim();
}

String fixedAssetReplaceCode(String code) => code.trim().toLowerCase();

/// Một khu (Fac / Floor / A / AA thực tế) và các máy còn chờ thay QR.
/// [location] null = nhóm "Chưa rõ vị trí" (*_Act thiếu).
class FixedAssetReplaceZone {
  final FixedAssetAuditLocation? location;
  final List<FixedAssetReplaceTask> tasks;

  const FixedAssetReplaceZone(this.location, this.tasks);

  bool get isKnown => location != null;

  /// Khóa ổn định giữa các lần tải lại (tra lại khu sau khi quét xong).
  String get key => fixedAssetReplaceZoneKey(location);
}

String fixedAssetReplaceZoneKey(FixedAssetAuditLocation? location) =>
    location == null
    ? ''
    : [
        location.fac,
        location.floor,
        location.positionA,
        location.positionAA,
      ].map(fixedAssetReplaceCode).join('|');

/// Vị trí thực tế đầy đủ của dòng; thiếu Fac / Floor / A / AA -> null.
FixedAssetAuditLocation? fixedAssetReplaceLocationOf(FixedAssetQrMismatch row) {
  final fac = row.facAct?.trim() ?? '';
  final floor = row.floorAct?.trim() ?? '';
  final positionA = row.positionA.trim();
  final positionAA = row.positionAA.trim();
  if (fac.isEmpty || floor.isEmpty || positionA.isEmpty || positionAA.isEmpty) {
    return null;
  }
  return FixedAssetAuditLocation(
    fac: fac,
    floor: floor,
    positionA: positionA,
    positionAA: positionAA,
  );
}
