import 'fixed_asset_scan_info.dart' show parseBool, parseDate;

/// Response của POST /api/fixed-assets/audit.
///
/// HTTP 2xx KHÔNG có nghĩa là đã insert: phải xét [saved] / [alreadyAudited].
class FixedAssetAuditSaveResponse {
  final bool success;
  final bool saved;
  final bool alreadyAudited;
  final bool unknownMachine;
  final String machineCode;
  final DateTime? updatedAt;
  final DateTime? lastAuditedAt;
  final String message;

  const FixedAssetAuditSaveResponse({
    required this.success,
    required this.saved,
    required this.alreadyAudited,
    required this.unknownMachine,
    required this.machineCode,
    this.updatedAt,
    this.lastAuditedAt,
    required this.message,
  });

  factory FixedAssetAuditSaveResponse.fromJson(Map<String, dynamic> json) {
    return FixedAssetAuditSaveResponse(
      success: parseBool(json['success']),
      saved: parseBool(json['saved']),
      alreadyAudited: parseBool(json['alreadyAudited']),
      unknownMachine: parseBool(json['unknownMachine']),
      machineCode: (json['machineCode'] ?? '').toString().trim(),
      updatedAt: parseDate(json['updatedAt']),
      lastAuditedAt: parseDate(json['lastAuditedAt']),
      message: (json['message'] ?? '').toString().trim(),
    );
  }
}
