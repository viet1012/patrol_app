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

/// Token có thể là mã máy trong URL / nội dung nhiều trường.
final RegExp _tokenPattern = RegExp(r'[A-Za-z0-9-]+');

/// Bỏ BOM, zero-width và ký tự điều khiển (\r\n...) scanner có thể chèn.
String _cleanQr(String rawQr) => rawQr
    .replaceAll(RegExp(r'[\u0000-\u001F\u007F​-‍⁠﻿]'), '')
    .trim();

/// Mã máy hợp lệ (upper-case) hoặc '' nếu không khớp mẫu.
String _validCode(String value) {
  final code = value.trim().toUpperCase();
  return _machineCodePattern.hasMatch(code) ? code : '';
}

/// Nội dung không phải KVH_ (mã trần, URL, nhiều trường): đúng một mã máy
/// khớp mẫu; không có / nhiều mã khác nhau -> ''.
String _machineCodeInText(String qr) {
  final whole = _validCode(qr);
  if (whole.isNotEmpty) return whole;
  final codes = <String>{
    for (final m in _tokenPattern.allMatches(qr))
      if (_validCode(m[0]!).isNotEmpty) _validCode(m[0]!),
  };
  return codes.length == 1 ? codes.first : '';
}

/// KVH_A-1456_1F_A34-2_Sprue Bush -> A-1456
/// KVH_1F_A1_A1-1_A-1564-1_Cutting 2-2 -> A-1564-1
/// A-2331 -> A-2331
String extractFixedAssetMachineCode(String rawQr) =>
    parseFixedAssetQr(rawQr).machineCode;

/// Mã máy chuẩn hoá để so với danh sách máy (bỏ ký tự điều khiển, trim,
/// upper-case); '' = không phải mã máy.
String normalizeMachineCode(String value) => _validCode(_cleanQr(value));

/// Hai mã cách tâm chênh nhau dưới mức này (theo nửa đường chéo) = "gần
/// tâm như nhau".
const double _sameDistance = 0.08;

/// Frame có nhiều mã ([candidates]: text + khoảng cách tới tâm, rỗng = 1
/// mã): ưu tiên mã gần tâm nhất có trong danh sách tải sẵn ([isKnown],
/// nhận mã đã chuẩn hoá). Không mã nào trong danh sách: giữ [rawQr] (gần
/// tâm nhất). [ambiguous] = ≥ 2 mã khác nhau trong danh sách, gần tâm như
/// nhau.
({String rawQr, bool ambiguous}) fixedAssetPickFrameQr(
  String rawQr,
  List<({String text, double distance})> candidates,
  bool Function(String machineCode) isKnown,
) {
  if (candidates.length < 2) return (rawQr: rawQr, ambiguous: false);
  final known = [
    for (final c in candidates)
      if (isKnown(parseFixedAssetQr(c.text).machineCode)) c,
  ]..sort((a, b) => a.distance.compareTo(b.distance));
  if (known.isEmpty) return (rawQr: rawQr, ambiguous: false);
  final best = known.first;
  final bestCode = parseFixedAssetQr(best.text).machineCode;
  final ambiguous = known.skip(1).any(
    (c) =>
        parseFixedAssetQr(c.text).machineCode != bestCode &&
        c.distance - best.distance < _sameDistance,
  );
  return (rawQr: best.text, ambiguous: ambiguous);
}

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
  if (parsed.machineCode != code.toUpperCase() ||
      parsed.floor != f ||
      parsed.positionAA != aa) {
    return null;
  }
  return content;
}

/// Tách thêm Floor (+ PositionA) + PositionAA (+ tên hiển thị) từ QR KVH_.
/// Chỉ nhận khi đủ segment; không suy đoán giá trị.
///
/// machineCode luôn upper-case và khớp mẫu mã máy; '' = QR không phải mã
/// máy (caller bỏ qua, báo "QR không phải mã máy").
FixedAssetQrData parseFixedAssetQr(String rawQr) {
  final data = _parseFixedAssetQr(rawQr);
  final code = _validCode(data.machineCode);
  if (code == data.machineCode) return data;
  if (code.isEmpty) return const FixedAssetQrData(machineCode: '');
  return FixedAssetQrData(
    machineCode: code,
    floor: data.floor,
    positionA: data.positionA,
    positionAA: data.positionAA,
    displayName: data.displayName,
  );
}

/// KVH_{MachineCode}_{Floor}_{PositionAA}_{Tên máy}, vd
/// "KVH_A-1208_1F_A5-2_DP Fine": khớp đầy đủ thì lấy thẳng các group.
final RegExp _kvhFullPattern = RegExp(
  r'^KVH_([A-Za-z]+-\d+(?:-\d+)*)_([^_]+)_([^_]+)_(.*)$',
);

FixedAssetQrData _parseFixedAssetQr(String rawQr) {
  final qr = _cleanQr(rawQr);
  if (qr.isEmpty) return const FixedAssetQrData(machineCode: '');

  final full = _kvhFullPattern.firstMatch(qr);
  if (full != null) {
    return FixedAssetQrData(
      machineCode: full[1]!.toUpperCase(),
      floor: full[2]!.trim(),
      positionAA: full[3]!.trim(),
      displayName: full[4]!.trim(),
    );
  }

  if (!qr.startsWith('KVH_')) {
    return FixedAssetQrData(machineCode: _machineCodeInText(qr));
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
