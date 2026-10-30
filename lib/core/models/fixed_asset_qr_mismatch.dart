import 'package:chuphinh/core/models/fixed_asset_scan_info.dart'
    show parseBool, parseDateTime;

/// Một dòng GET /api/fixed-assets/qr-mismatch (FixedAssetQrMismatchDto):
/// lần quét mới nhất trong kỳ của máy có QR lệch vị trí đang chọn.
///
/// [facAct] / [floorAct] / [facQr] null khi API cũ chưa trả (hoặc bản ghi cũ
/// chưa lưu Fac_Act / Floor_Act / Fac_Qr).
class FixedAssetQrMismatch {
  final String machineCode;
  final String faName;

  /// Vị trí đang chọn lúc kiểm kê (Fac_Act / Floor_Act / A_Act / AA_Act).
  final String? facAct;
  final String? floorAct;
  final String positionA;
  final String positionAA;

  /// Vị trí in trên QR cũ (Fac_Qr / Floor_Qr / A_Qr / AA_Qr).
  final String? facQr;
  final String qrFloor;
  final String qrPositionA;
  final String qrPositionAA;

  /// Mode lúc lưu ("AUTO" / "MANUAL" / "NO_QR"); null khi API cũ chưa trả.
  final String? auditMode;

  final String userName;
  final DateTime? updatedAt;

  /// Ngày tài sản từ MASTER (F2_FIXED_ASSET.DateStart); null = không có.
  final DateTime? assetDate;

  /// Đang chờ thay QR (QrMismatch = 1 AND ReprintSts = 0): field
  /// needsQrReprint của backend; DTO không có field này thì = !reprintSts
  /// (mọi dòng của endpoint đã là QrMismatch = 1).
  final bool needsQrReprint;

  /// Đã thay QR (ReprintSts = 1) + lúc thay; *_Qr vẫn là QR cũ.
  final bool reprintSts;
  final DateTime? reprintAt;

  const FixedAssetQrMismatch({
    required this.machineCode,
    required this.faName,
    this.facAct,
    this.floorAct,
    required this.positionA,
    required this.positionAA,
    this.facQr,
    required this.qrFloor,
    required this.qrPositionA,
    required this.qrPositionAA,
    this.auditMode,
    required this.userName,
    this.updatedAt,
    this.assetDate,
    this.needsQrReprint = true,
    this.reprintSts = false,
    this.reprintAt,
  });

  factory FixedAssetQrMismatch.fromJson(Map<String, dynamic> json) {
    String str(String key) => (json[key] ?? '').toString().trim();
    // Key thiếu / null / rỗng -> null.
    String? opt(String key) {
      final value = str(key);
      return value.isEmpty ? null : value;
    }

    final reprintSts = parseBool(json['reprintSts']);
    return FixedAssetQrMismatch(
      machineCode: str('machineCode'),
      faName: str('faName'),
      facAct: opt('facAct') ?? opt('fac'),
      floorAct: opt('floorAct'),
      positionA: str('positionAAct'),
      positionAA: str('positionAAAct'),
      // DTO: qrFac (facQr giữ cho tương thích).
      facQr: opt('qrFac') ?? opt('facQr'),
      qrFloor: str('qrFloor'),
      qrPositionA: str('qrPositionA'),
      qrPositionAA: str('qrPositionAA'),
      auditMode: opt('auditMode')?.toUpperCase(),
      userName: str('userName'),
      updatedAt: parseDateTime(json['updatedAt']),
      assetDate: DateTime.tryParse(json['assetDate']?.toString() ?? ''),
      needsQrReprint: json.containsKey('needsQrReprint')
          ? parseBool(json['needsQrReprint'])
          : !reprintSts,
      reprintSts: reprintSts,
      reprintAt: parseDateTime(json['reprintAt']),
    );
  }

  /// Ghi nhận "máy không có tem" (không có QR cũ).
  bool get isNoQr => auditMode == 'NO_QR';

  /// Có QR cũ lúc kiểm kê (Floor_Qr / AA_Qr); false = chưa có QR. Chỉ dùng
  /// để phân loại việc (Mất QR / Sai QR), không quyết định "chờ thay QR".
  bool get hasQrLabel => qrFloor.isNotEmpty || qrPositionAA.isNotEmpty;
}
