import 'fixed_asset_scan_info.dart' show parseBool, parseDate;

/// Response của POST /api/fixed-assets/audit-check.
///
/// MASTER = vị trí đăng ký của machine. ACTUAL = vị trí đang quét, backend
/// resolve Fac/PositionA từ Floor + PositionAA của QR qua MASTER MAP.
class FixedAssetAuditCheckResponse {
  final String machineCode;

  final bool alreadyAudited;
  final DateTime? lastAuditedAt;

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

  const FixedAssetAuditCheckResponse({
    required this.machineCode,
    required this.alreadyAudited,
    this.lastAuditedAt,
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
      lastAuditedAt: parseDate(json['lastAuditedAt']),
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
