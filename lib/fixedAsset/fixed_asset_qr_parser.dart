/// Dữ liệu tách từ QR Fixed Asset.
/// KVH_A-593_1F_A12-2_Fine Bush -> A-593 / 1F / A12-2 / Fine Bush.
/// Không suy PositionA/Fac từ QR: backend resolve qua MASTER MAP.
/// MachineCode = định danh MASTER; Floor + PositionAA = input vị trí ACTUAL.
class FixedAssetQrData {
  final String machineCode;
  final String floor;
  final String positionAA;
  final String displayName;

  const FixedAssetQrData({
    required this.machineCode,
    this.floor = '',
    this.positionAA = '',
    this.displayName = '',
  });

  bool get hasLocation => floor.isNotEmpty && positionAA.isNotEmpty;
}

/// KVH_A-1456_1F_A34-2_Sprue Bush -> A-1456
/// A-2331 -> A-2331
String extractFixedAssetMachineCode(String rawQr) {
  final qr = rawQr.trim();
  if (qr.isEmpty) return '';

  if (qr.startsWith('KVH_')) {
    final segments = qr.split('_');
    return segments.length >= 2 ? segments[1].trim() : '';
  }

  return qr;
}

/// Tách thêm Floor + PositionAA (+ tên hiển thị) từ QR KVH_ cho AUTO.
/// Chỉ nhận khi đủ segment; không suy đoán giá trị.
FixedAssetQrData parseFixedAssetQr(String rawQr) {
  final qr = rawQr.trim();
  final machineCode = extractFixedAssetMachineCode(qr);

  if (!qr.startsWith('KVH_')) {
    return FixedAssetQrData(machineCode: machineCode);
  }

  final segments = qr.split('_');
  if (segments.length < 4) {
    return FixedAssetQrData(machineCode: machineCode);
  }

  return FixedAssetQrData(
    machineCode: machineCode,
    floor: segments[2].trim(),
    positionAA: segments[3].trim(),
    displayName: segments.length > 4
        ? segments.sublist(4).join('_').trim()
        : '',
  );
}
