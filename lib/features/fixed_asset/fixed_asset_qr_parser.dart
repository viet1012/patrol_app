/// Dữ liệu tách từ QR Fixed Asset. Hai layout KVH_:
/// - KVH_A-593_1F_A12-2_Fine Bush -> A-593 / 1F / A12-2 / Fine Bush.
/// - KVH_1F_A1_A1-1_A-1564-1_Cutting 2-2 -> A-1564-1 / 1F / A1 / A1-1 /
///   Cutting 2-2 (vị trí đứng trước mã máy).
/// Không suy PositionA/Fac khi QR không có: backend resolve qua MASTER MAP.
/// MachineCode = định danh MASTER; Floor + PositionAA = input vị trí ACTUAL.
class FixedAssetQrData {
  final String machineCode;
  final String floor;

  /// Rỗng khi QR không in PositionA (layout mã máy đứng đầu).
  final String positionA;
  final String positionAA;
  final String displayName;

  const FixedAssetQrData({
    required this.machineCode,
    this.floor = '',
    this.positionA = '',
    this.positionAA = '',
    this.displayName = '',
  });

  bool get hasLocation => floor.isNotEmpty && positionAA.isNotEmpty;
}

/// Mã máy: chữ + "-" + số (A-593, A-1564-1). PositionAA (A12-2) không khớp.
final RegExp _machineCodePattern = RegExp(r'^[A-Za-z]+-\d+(?:-\d+)*$');

/// Bỏ BOM, zero-width và ký tự điều khiển (\r\n...) scanner có thể chèn.
String _cleanQr(String rawQr) => rawQr
    .replaceAll(RegExp(r'[\u0000-\u001F\u007F​-‍⁠﻿]'), '')
    .trim();

/// KVH_A-1456_1F_A34-2_Sprue Bush -> A-1456
/// KVH_1F_A1_A1-1_A-1564-1_Cutting 2-2 -> A-1564-1
/// A-2331 -> A-2331
String extractFixedAssetMachineCode(String rawQr) =>
    parseFixedAssetQr(rawQr).machineCode;

/// Nội dung QR KVH_ mới: KVH_{machineCode}_{floor}_{positionAA}[_{tên}].
///
/// Chỉ trả nội dung khi [parseFixedAssetQr] đọc lại ra ĐÚNG machineCode,
/// Floor, PositionAA (ví dụ field chứa "_" hoặc rỗng -> null): QR in ra
/// luôn quét được bằng chính parser này.
String? buildFixedAssetQr({
  required String machineCode,
  required String floor,
  required String positionAA,
  String displayName = '',
}) {
  final code = machineCode.trim();
  final f = floor.trim();
  final aa = positionAA.trim();
  final name = displayName.trim();
  if (code.isEmpty || f.isEmpty || aa.isEmpty) return null;

  final content = name.isEmpty ? 'KVH_${code}_${f}_$aa' : 'KVH_${code}_${f}_${aa}_$name';
  final parsed = parseFixedAssetQr(content);
  if (parsed.machineCode != code ||
      parsed.floor != f ||
      parsed.positionAA != aa) {
    return null;
  }
  return content;
}

/// Tách thêm Floor (+ PositionA) + PositionAA (+ tên hiển thị) từ QR KVH_.
/// Chỉ nhận khi đủ segment; không suy đoán giá trị.
FixedAssetQrData parseFixedAssetQr(String rawQr) {
  final qr = _cleanQr(rawQr);
  if (qr.isEmpty) return const FixedAssetQrData(machineCode: '');

  if (!qr.startsWith('KVH_')) {
    return FixedAssetQrData(machineCode: qr);
  }

  final s = qr.substring(4).split('_').map((v) => v.trim()).toList();
  String nameFrom(int i) => s.length > i ? s.sublist(i).join('_').trim() : '';

  // Layout vị trí trước: mã máy là segment sau ...{floor}_{A}_{AA}.
  if (!_machineCodePattern.hasMatch(s[0])) {
    final i = s.indexWhere(_machineCodePattern.hasMatch);
    if (i >= 2) {
      return FixedAssetQrData(
        machineCode: s[i],
        floor: i >= 3 ? s[i - 3] : s[i - 2],
        positionA: i >= 3 ? s[i - 2] : '',
        positionAA: s[i - 1],
        displayName: nameFrom(i + 1),
      );
    }
  }

  // Layout mã máy trước: KVH_{code}_{floor}_{AA}[_{tên}].
  if (s.length < 3) return FixedAssetQrData(machineCode: s[0]);
  return FixedAssetQrData(
    machineCode: s[0],
    floor: s[1],
    positionAA: s[2],
    displayName: nameFrom(3),
  );
}
