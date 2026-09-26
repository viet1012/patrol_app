/// GET /api/fixed-assets/scan-info?machineCode=...
class FixedAssetScanInfo {
  final String machineCode;
  final bool existsInMaster;
  final String fac;
  final String floor;
  final String positionA;
  final String positionAA;
  final String faName;
  final bool auditedInCurrentPeriod;
  final DateTime? lastAuditedAt;

  /// Người kiểm kê gần nhất trong kỳ (null nếu backend không trả).
  final String? lastAuditedUserId;
  final String? lastAuditedUserName;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  const FixedAssetScanInfo({
    required this.machineCode,
    required this.existsInMaster,
    required this.fac,
    required this.floor,
    required this.positionA,
    required this.positionAA,
    required this.faName,
    required this.auditedInCurrentPeriod,
    this.lastAuditedAt,
    this.lastAuditedUserId,
    this.lastAuditedUserName,
    this.periodStart,
    this.periodEnd,
  });

  factory FixedAssetScanInfo.fromJson(Map<String, dynamic> json) {
    String str(String key) => (json[key] ?? '').toString().trim();

    return FixedAssetScanInfo(
      machineCode: str('machineCode'),
      existsInMaster: parseBool(json['existsInMaster']),
      fac: str('fac'),
      floor: str('floor'),
      positionA: str('positionA'),
      positionAA: str('positionAA'),
      faName: str('faName'),
      auditedInCurrentPeriod: parseBool(json['auditedInCurrentPeriod']),
      lastAuditedAt: parseDate(json['lastAuditedAt']),
      lastAuditedUserId: json['lastAuditedUserId']?.toString(),
      lastAuditedUserName: json['lastAuditedUserName']?.toString(),
      periodStart: parseDate(json['periodStart']),
      periodEnd: parseDate(json['periodEnd']),
    );
  }

  bool get hasFullLocation =>
      fac.isNotEmpty &&
      floor.isNotEmpty &&
      positionA.isNotEmpty &&
      positionAA.isNotEmpty;
}

bool parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.trim().toLowerCase() == 'true';
  return false;
}

DateTime? parseDate(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}
