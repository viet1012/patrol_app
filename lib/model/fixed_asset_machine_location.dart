/// Location MASTER của một machine (GET /api/fixed-assets/machine-location).
class FixedAssetMachineLocation {
  final String fac;
  final String floor;
  final String positionA;
  final String positionAA;
  final String machineCode;
  final String faName;

  const FixedAssetMachineLocation({
    required this.fac,
    required this.floor,
    required this.positionA,
    required this.positionAA,
    required this.machineCode,
    required this.faName,
  });

  factory FixedAssetMachineLocation.fromJson(Map<String, dynamic> json) {
    String read(String key) => (json[key] ?? '').toString().trim();

    return FixedAssetMachineLocation(
      fac: read('fac'),
      floor: read('floor'),
      positionA: read('positionA'),
      positionAA: read('positionAA'),
      machineCode: read('machineCode'),
      faName: read('faName'),
    );
  }

  bool get hasFullLocation =>
      fac.isNotEmpty &&
      floor.isNotEmpty &&
      positionA.isNotEmpty &&
      positionAA.isNotEmpty;
}
