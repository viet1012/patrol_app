class FixedAssetMachine {
  final String machineCode;
  final String faName;

  const FixedAssetMachine({required this.machineCode, required this.faName});

  factory FixedAssetMachine.fromJson(Map<String, dynamic> json) {
    return FixedAssetMachine(
      machineCode: (json['machineCode'] ?? '').toString().trim(),
      faName: (json['faName'] ?? '').toString().trim(),
    );
  }
}
