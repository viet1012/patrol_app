/// Location dùng để POST audit, không phụ thuộc nguồn (AUTO/MANUAL).
///
/// Strict: khi tạo qua [fixedAssetStrictLocation] thì đủ 4 field. Riêng MASTER
/// hiển thị ([fixedAssetMasterDisplay]) có thể thiếu field.
class FixedAssetAuditLocation {
  final String fac;
  final String floor;
  final String positionA;
  final String positionAA;

  const FixedAssetAuditLocation({
    required this.fac,
    required this.floor,
    required this.positionA,
    required this.positionAA,
  });

  @override
  bool operator ==(Object other) =>
      other is FixedAssetAuditLocation &&
      other.fac == fac &&
      other.floor == floor &&
      other.positionA == positionA &&
      other.positionAA == positionAA;

  @override
  int get hashCode => Object.hash(fac, floor, positionA, positionAA);
}

/// Vị trí đang quét KHÔNG có trong MAP (known machine): chỉ có raw Floor +
/// PositionAA từ backend. Không có Fac/PositionA và không được suy ra
/// (ví dụ KHÔNG đổi A35-1 thành A35).
class FixedAssetUnmappedActual {
  final String floor;
  final String positionAA;

  const FixedAssetUnmappedActual({
    required this.floor,
    required this.positionAA,
  });
}

/// Nơi DUY NHẤT dựng các field location cho POST /audit.
///
/// - [FixedAssetSaveTarget.mapped]: location đầy đủ (match / mismatch / manual).
/// - [FixedAssetSaveTarget.unmapped]: vị trí không có trong MAP -> fac và
///   positionA = null, backend lưu A_Act = null, AA_Act = raw.
class FixedAssetSaveTarget {
  final FixedAssetAuditLocation? location;
  final FixedAssetUnmappedActual? unmapped;

  const FixedAssetSaveTarget.mapped(FixedAssetAuditLocation this.location)
    : unmapped = null;

  const FixedAssetSaveTarget.unmapped(FixedAssetUnmappedActual this.unmapped)
    : location = null;

  String? get fac => location?.fac;
  String get floor => location?.floor ?? unmapped?.floor ?? '';
  String? get positionA => location?.positionA;
  String get positionAA => location?.positionAA ?? unmapped?.positionAA ?? '';
}

/// Location strict: null nếu thiếu bất kỳ field nào.
FixedAssetAuditLocation? fixedAssetStrictLocation(
  String fac,
  String floor,
  String positionA,
  String positionAA,
) {
  if (fac.isEmpty ||
      floor.isEmpty ||
      positionA.isEmpty ||
      positionAA.isEmpty) {
    return null;
  }

  return FixedAssetAuditLocation(
    fac: fac,
    floor: floor,
    positionA: positionA,
    positionAA: positionAA,
  );
}

/// MASTER chỉ để HIỂN THỊ: giữ các field có giá trị, field rỗng hiện "-".
/// null chỉ khi backend không trả field MASTER nào. Không dùng cho POST
/// hay machine list (các chỗ đó vẫn dùng [fixedAssetStrictLocation]).
FixedAssetAuditLocation? fixedAssetMasterDisplay(
  String fac,
  String floor,
  String positionA,
  String positionAA,
) {
  if (fac.isEmpty &&
      floor.isEmpty &&
      positionA.isEmpty &&
      positionAA.isEmpty) {
    return null;
  }

  return FixedAssetAuditLocation(
    fac: fac,
    floor: floor,
    positionA: positionA,
    positionAA: positionAA,
  );
}

/// Giá trị rỗng (ví dụ MASTER Fac chưa map) hiển thị là "-" (chỉ UI).
String fixedAssetDash(String value) => value.trim().isEmpty ? '-' : value;
