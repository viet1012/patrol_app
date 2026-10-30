import 'package:chuphinh/core/models/fixed_asset_reprint_info.dart';
import 'package:chuphinh/core/models/fixed_asset_scan_info.dart' show parseBool, parseDate, parseDateTime;

/// Response của POST /api/fixed-assets/audit-check.
///
/// MASTER = vị trí đăng ký của machine. ACTUAL = vị trí đang quét, backend
/// resolve Fac/PositionA từ Floor + PositionAA của QR qua MASTER MAP.
class FixedAssetAuditCheckResponse {
  final String machineCode;

  final bool alreadyAudited;
  final DateTime? lastAuditedAt;

  /// Người kiểm kê gần nhất trong kỳ (null nếu backend không trả).
  final String? lastAuditedUserId;
  final String? lastAuditedUserName;

  final bool existsInMaster;
  final bool actualLocationResolved;

  final bool locationMatch;
  final bool requiresConfirmation;

  final String masterFac;
  final String masterFloor;
  final String masterPositionA;
  final String masterPositionAA;
  final String faName;

  final String actualFac;
  final String actualFloor;
  final String actualPositionA;
  final String actualPositionAA;

  final String message;

  /// Đang chờ thay QR (backend: QrMismatch = 1 AND ReprintSts = 0). Nguồn
  /// duy nhất cho "chờ thay QR".
  final bool needsQrReprint;

  /// Đã thay QR (ReprintSts = 1) + lúc thay; *_Qr vẫn là QR cũ.
  final bool reprintSts;
  final DateTime? reprintAt;

  /// reprintAct* / reprintQr* (QR cũ = *_Qr); chỉ dùng khi [needsQrReprint].
  final FixedAssetReprintInfo? reprint;

  const FixedAssetAuditCheckResponse({
    required this.machineCode,
    required this.alreadyAudited,
    this.needsQrReprint = false,
    this.reprintSts = false,
    this.reprintAt,
    this.reprint,
    this.lastAuditedAt,
    this.lastAuditedUserId,
    this.lastAuditedUserName,
    required this.existsInMaster,
    required this.actualLocationResolved,
    required this.locationMatch,
    required this.requiresConfirmation,
    required this.masterFac,
    required this.masterFloor,
    required this.masterPositionA,
    required this.masterPositionAA,
    required this.faName,
    required this.actualFac,
    required this.actualFloor,
    required this.actualPositionA,
    required this.actualPositionAA,
    required this.message,
  });

  factory FixedAssetAuditCheckResponse.fromJson(Map<String, dynamic> json) {
    String str(String key) => (json[key] ?? '').toString().trim();

    return FixedAssetAuditCheckResponse(
      machineCode: str('machineCode'),
      alreadyAudited: parseBool(json['alreadyAudited']),
      needsQrReprint: parseBool(json['needsQrReprint']),
      reprintSts: parseBool(json['reprintSts']),
      reprintAt: parseDateTime(json['reprintAt']),
      reprint: FixedAssetReprintInfo.fromJson(json),
      lastAuditedAt: parseDate(json['lastAuditedAt']),
      lastAuditedUserId: json['lastAuditedUserId']?.toString(),
      lastAuditedUserName: json['lastAuditedUserName']?.toString(),
      existsInMaster: parseBool(json['existsInMaster']),
      actualLocationResolved: parseBool(json['actualLocationResolved']),
      locationMatch: parseBool(json['locationMatch']),
      requiresConfirmation: parseBool(json['requiresConfirmation']),
      masterFac: str('masterFac'),
      masterFloor: str('masterFloor'),
      masterPositionA: str('masterPositionA'),
      masterPositionAA: str('masterPositionAA'),
      faName: str('faName'),
      actualFac: str('actualFac'),
      actualFloor: str('actualFloor'),
      actualPositionA: str('actualPositionA'),
      actualPositionAA: str('actualPositionAA'),
      message: str('message'),
    );
  }
}
