import 'package:chuphinh/core/models/fixed_asset_scan_info.dart' show parseDate;

/// Lý do khóa khu vực (GET /api/fixed-assets/zone-lock).
enum FixedAssetZoneLockReason {
  /// Khu vực AUTO gần nhất của user chưa audit xong: đang khóa.
  incomplete,

  /// Khu vực đã xong (total có thể = 0): không khóa.
  completed,

  /// User chưa có bản ghi AUTO trong kỳ: không khóa, không phải lỗi.
  noAutoAudit,

  /// Không xác định được khu vực (hoặc reason lạ): không kiểm tra được.
  unresolved,
}

/// Trạng thái khóa khu vực AUTO của một user, tính từ bản ghi AUTO mới
/// nhất trong kỳ hiện tại. Field thiếu -> null.
class FixedAssetZoneLock {
  final bool locked;
  final FixedAssetZoneLockReason reason;
  final String? fac;
  final String? floor;
  final String? positionA;
  final String? positionAA;
  final int? total;
  final int? audited;
  final DateTime? lastAuditedAt;

  const FixedAssetZoneLock({
    required this.locked,
    required this.reason,
    this.fac,
    this.floor,
    this.positionA,
    this.positionAA,
    this.total,
    this.audited,
    this.lastAuditedAt,
  });

  /// Đủ Fac/Floor/PositionA/PositionAA để xác định khu vực.
  bool get hasLocation =>
      [fac, floor, positionA, positionAA].every((v) => v != null);

  factory FixedAssetZoneLock.fromJson(Map<String, dynamic> json) {
    String? text(dynamic v) {
      final s = v?.toString().trim() ?? '';
      return s.isEmpty ? null : s;
    }

    int? count(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString().trim());
    }

    final locked = json['locked'];
    return FixedAssetZoneLock(
      locked:
          locked == true ||
          (locked is String && locked.trim().toLowerCase() == 'true'),
      reason: switch (json['reason']?.toString().trim().toUpperCase()) {
        'INCOMPLETE' => FixedAssetZoneLockReason.incomplete,
        'COMPLETED' => FixedAssetZoneLockReason.completed,
        'NO_AUTO_AUDIT' => FixedAssetZoneLockReason.noAutoAudit,
        _ => FixedAssetZoneLockReason.unresolved,
      },
      fac: text(json['fac']),
      floor: text(json['floor']),
      positionA: text(json['positionA']),
      positionAA: text(json['positionAA']),
      total: count(json['total']),
      audited: count(json['audited']),
      lastAuditedAt: parseDate(json['lastAuditedAt']),
    );
  }
}
