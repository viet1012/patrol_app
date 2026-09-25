import 'fixed_asset_scan_info.dart' show parseBool, parseDate;

/// Response của POST /api/fixed-assets/audit.
///
/// HTTP 2xx KHÔNG có nghĩa là đã insert: phải xét [saved] / [alreadyAudited]
/// / [requiresConfirmation].
class FixedAssetAuditSaveResponse {
  final bool success;
  final bool saved;
  final bool alreadyAudited;
  final bool unknownMachine;
  final String machineCode;
  final DateTime? updatedAt;
  final DateTime? lastAuditedAt;
  final String message;

  /// Vị trí audit khác MASTER. Khi [requiresConfirmation] = true và
  /// [saved] = false: phải hỏi operator rồi POST lại với
  /// confirmLocationMismatch = true.
  final bool locationMismatch;
  final bool requiresConfirmation;

  final String masterFac;
  final String masterFloor;
  final String masterPositionA;
  final String masterPositionAA;

  final String actualFac;
  final String actualFloor;
  final String actualPositionA;
  final String actualPositionAA;

  const FixedAssetAuditSaveResponse({
    required this.success,
    required this.saved,
    required this.alreadyAudited,
    required this.unknownMachine,
    required this.machineCode,
    this.updatedAt,
    this.lastAuditedAt,
    required this.message,
    this.locationMismatch = false,
    this.requiresConfirmation = false,
    this.masterFac = '',
    this.masterFloor = '',
    this.masterPositionA = '',
    this.masterPositionAA = '',
    this.actualFac = '',
    this.actualFloor = '',
    this.actualPositionA = '',
    this.actualPositionAA = '',
  });

  factory FixedAssetAuditSaveResponse.fromJson(Map<String, dynamic> json) {
    String str(String key) => (json[key] ?? '').toString().trim();

    return FixedAssetAuditSaveResponse(
      success: parseBool(json['success']),
      saved: parseBool(json['saved']),
      alreadyAudited: parseBool(json['alreadyAudited']),
      unknownMachine: parseBool(json['unknownMachine']),
      machineCode: str('machineCode'),
      updatedAt: parseDate(json['updatedAt']),
      lastAuditedAt: parseDate(json['lastAuditedAt']),
      message: str('message'),
      locationMismatch: parseBool(json['locationMismatch']),
      requiresConfirmation: parseBool(json['requiresConfirmation']),
      masterFac: str('masterFac'),
      masterFloor: str('masterFloor'),
      masterPositionA: str('masterPositionA'),
      masterPositionAA: str('masterPositionAA'),
      actualFac: str('actualFac'),
      actualFloor: str('actualFloor'),
      actualPositionA: str('actualPositionA'),
      actualPositionAA: str('actualPositionAA'),
    );
  }
}
