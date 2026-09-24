import 'fixed_asset_scan_info.dart' show parseDate;

/// GET /api/fixed-assets/audit-summary (kỳ kiểm kê 3 tháng hiện tại).
class FixedAssetAuditSummary {
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final int totalMachines;
  final int auditedMachines;
  final int remainingMachines;
  final double completionPercent;

  const FixedAssetAuditSummary({
    this.periodStart,
    this.periodEnd,
    required this.totalMachines,
    required this.auditedMachines,
    required this.remainingMachines,
    required this.completionPercent,
  });

  factory FixedAssetAuditSummary.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

    final percent = json['completionPercent'];

    return FixedAssetAuditSummary(
      periodStart: parseDate(json['periodStart']),
      periodEnd: parseDate(json['periodEnd']),
      totalMachines: toInt(json['totalMachines']),
      auditedMachines: toInt(json['auditedMachines']),
      remainingMachines: toInt(json['remainingMachines']),
      completionPercent: percent is num
          ? percent.toDouble()
          : double.tryParse(percent?.toString() ?? '') ?? 0,
    );
  }
}
