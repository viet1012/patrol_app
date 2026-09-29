/// GET /api/fixed-assets/zone-progress?fac=&floor= (kỳ kiểm kê 3 tháng hiện
/// tại, cùng logic /audit-summary). Một dòng = một vùng có total > 0.
///
/// Vùng cha không có vùng con: positionAA == positionA (ví dụ A30/A30).
class FixedAssetZoneProgressRow {
  final String positionA;
  final String positionAA;
  final int total;
  final int audited;

  const FixedAssetZoneProgressRow({
    required this.positionA,
    required this.positionAA,
    required this.total,
    required this.audited,
  });

  factory FixedAssetZoneProgressRow.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString().trim() ?? '') ?? 0;

    return FixedAssetZoneProgressRow(
      positionA: (json['positionA'] ?? '').toString().trim(),
      positionAA: (json['positionAA'] ?? '').toString().trim(),
      total: toInt(json['total']),
      audited: toInt(json['audited']),
    );
  }
}

/// Số máy đã kiểm kê / tổng số máy của một vùng.
class ZoneProgress {
  final int audited;
  final int total;

  const ZoneProgress({required this.audited, required this.total});

  static const ZoneProgress empty = ZoneProgress(audited: 0, total: 0);

  int get remaining => total - audited < 0 ? 0 : total - audited;

  /// 0–1; 0 khi total = 0.
  double get ratio => total <= 0 ? 0 : (audited / total).clamp(0.0, 1.0);

  /// Phần trăm làm tròn (0–100).
  int get percent => (ratio * 100).round();

  bool get isDone => total > 0 && audited >= total;

  ZoneProgress operator +(ZoneProgress other) =>
      ZoneProgress(audited: audited + other.audited, total: total + other.total);

  @override
  bool operator ==(Object other) =>
      other is ZoneProgress && other.audited == audited && other.total == total;

  @override
  int get hashCode => Object.hash(audited, total);

  @override
  String toString() => '$audited/$total';
}

/// Map mã vùng → tiến độ:
/// - key positionA: cộng dồn mọi dòng cùng positionA (vùng cha, kể cả vùng
///   cha không có con, khi positionAA == positionA);
/// - key positionAA (khi khác rỗng và khác positionA): vùng con.
///
/// Bỏ dòng positionA rỗng hoặc total <= 0; audited được kẹp trong 0..total.
Map<String, ZoneProgress> buildZoneProgressMap(
  Iterable<FixedAssetZoneProgressRow> rows,
) {
  final map = <String, ZoneProgress>{};
  for (final row in rows) {
    final positionA = row.positionA.trim();
    final positionAA = row.positionAA.trim();
    if (positionA.isEmpty || row.total <= 0) continue;

    final audited = row.audited.clamp(0, row.total);
    final progress = ZoneProgress(audited: audited, total: row.total);

    map[positionA] = (map[positionA] ?? ZoneProgress.empty) + progress;
    if (positionAA.isNotEmpty && positionAA != positionA) {
      map[positionAA] = (map[positionAA] ?? ZoneProgress.empty) + progress;
    }
  }
  return Map<String, ZoneProgress>.unmodifiable(map);
}
