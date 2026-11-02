class FixedAssetMachine {
  final String machineCode;
  final String faName;

  /// Đã kiểm kê trong kỳ 3 tháng hiện tại (GET /machines). Backend cũ không
  /// có field này -> false.
  final bool auditedInPeriod;

  /// Lần quét mới nhất có QR lệch vị trí (QrMismatch = 1): cần in lại QR,
  /// KHÔNG tính là đã kiểm kê. Backend cũ không có field này -> false.
  final bool needsQrReprint;

  /// Vị trí MASTER "Fac/Floor/A/AA" (list tính theo vị trí hiệu lực). Backend
  /// cũ không có -> rỗng.
  final String masterLocation;

  /// Vị trí hiệu lực (actual mới nhất trong quý) khác MASTER. Backend cũ
  /// không có -> false.
  final bool isMoved;

  const FixedAssetMachine({
    required this.machineCode,
    required this.faName,
    this.auditedInPeriod = false,
    this.needsQrReprint = false,
    this.masterLocation = '',
    this.isMoved = false,
  });

  factory FixedAssetMachine.fromJson(Map<String, dynamic> json) {
    return FixedAssetMachine(
      machineCode: (json['machineCode'] ?? '').toString().trim(),
      faName: (json['faName'] ?? '').toString().trim(),
      auditedInPeriod: _flag(json['auditedInPeriod']),
      needsQrReprint: _flag(json['needsQrReprint']),
      masterLocation: (json['masterLocation'] ?? '').toString().trim(),
      isMoved: _flag(json['isMoved']),
    );
  }

  static bool _flag(dynamic value) =>
      value == true ||
      (value is num && value != 0) ||
      (value is String &&
          const {'true', '1'}.contains(value.trim().toLowerCase()));
}
