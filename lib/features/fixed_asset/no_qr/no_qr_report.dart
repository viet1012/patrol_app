import 'package:chuphinh/features/fixed_asset/fixed_asset_location.dart';

/// Một case "máy thiếu QR" ghi tại vị trí đang kiểm kê.
class NoQrReport {
  /// Vị trí đang dùng lúc ghi (AUTO: vị trí đang quét, MANUAL: 4 dropdown).
  final FixedAssetAuditLocation location;
  final String machineCode;

  /// true = nhập tay (máy không có trong danh sách của vị trí).
  final bool isManualCode;
  final String note;
  final DateTime createdAt;

  const NoQrReport({
    required this.location,
    required this.machineCode,
    required this.isManualCode,
    required this.note,
    required this.createdAt,
  });
}
