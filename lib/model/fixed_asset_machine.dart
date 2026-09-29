class FixedAssetMachine {
  final String machineCode;
  final String faName;

  /// Đã kiểm kê trong kỳ 3 tháng hiện tại (GET /machines). Backend cũ không
  /// có field này -> false.
  final bool auditedInPeriod;

  const FixedAssetMachine({
    required this.machineCode,
    required this.faName,
    this.auditedInPeriod = false,
  });

  factory FixedAssetMachine.fromJson(Map<String, dynamic> json) {
    final audited = json['auditedInPeriod'];
    return FixedAssetMachine(
      machineCode: (json['machineCode'] ?? '').toString().trim(),
      faName: (json['faName'] ?? '').toString().trim(),
      auditedInPeriod:
          audited == true ||
          (audited is num && audited != 0) ||
          (audited is String &&
              const {'true', '1'}.contains(audited.trim().toLowerCase())),
    );
  }
}
