import 'package:chuphinh/core/models/fixed_asset_scan_info.dart' show parseDate;

/// Một dòng GET /api/fixed-assets/qr-mismatch (FixedAssetQrMismatchDto):
/// lần quét mới nhất trong kỳ của máy có QR lệch vị trí đang chọn.
///
/// Vị trí đang chọn chỉ có A_Act / AA_Act (bảng audit không lưu Floor);
/// [floor] chỉ có khi backend trả thêm `floorAct`.
class FixedAssetQrMismatch {
  final String machineCode;
  final String faName;

  /// Vị trí đang chọn lúc kiểm kê (A_Act / AA_Act).
  final String positionA;
  final String positionAA;
  final String floor;

  /// Xưởng; backend hiện không trả (chỉ có khi trả thêm `fac`).
  final String fac;

  /// Vị trí in trên QR cũ (Floor_Qr / A_Qr / AA_Qr).
  final String qrFloor;
  final String qrPositionA;
  final String qrPositionAA;

  final String userName;
  final DateTime? updatedAt;

  /// Ngày tài sản từ MASTER (F2_FIXED_ASSET.DateStart); null = không có.
  final DateTime? assetDate;

  const FixedAssetQrMismatch({
    required this.machineCode,
    required this.faName,
    required this.positionA,
    required this.positionAA,
    this.floor = '',
    this.fac = '',
    required this.qrFloor,
    required this.qrPositionA,
    required this.qrPositionAA,
    required this.userName,
    this.updatedAt,
    this.assetDate,
  });

  factory FixedAssetQrMismatch.fromJson(Map<String, dynamic> json) {
    String str(String key) => (json[key] ?? '').toString().trim();

    return FixedAssetQrMismatch(
      machineCode: str('machineCode'),
      faName: str('faName'),
      positionA: str('positionAAct'),
      positionAA: str('positionAAAct'),
      floor: str('floorAct'),
      fac: str('fac'),
      qrFloor: str('qrFloor'),
      qrPositionA: str('qrPositionA'),
      qrPositionAA: str('qrPositionAA'),
      userName: str('userName'),
      updatedAt: _parseDateTime(json['updatedAt']),
      assetDate: DateTime.tryParse(json['assetDate']?.toString() ?? ''),
    );
  }

  /// LocalDateTime: chuỗi ISO, hoặc mảng [y, M, d, h, m, s] (Jackson).
  static DateTime? _parseDateTime(dynamic value) {
    if (value is List && value.length >= 3) {
      int at(int i) => i < value.length ? (value[i] as num).toInt() : 0;
      return DateTime(at(0), at(1), at(2), at(3), at(4), at(5));
    }
    return parseDate(value);
  }
}
