/// GET /api/fixed-assets/pics: một PIC (người phụ trách máy).
class FixedAssetPic {
  final String email;

  /// Phần trước @ của [email] (backend trả sẵn; thiếu thì tự tách).
  final String name;
  final int machineCount;
  final int zoneCount;

  const FixedAssetPic({
    required this.email,
    required this.name,
    this.machineCount = 0,
    this.zoneCount = 0,
  });

  factory FixedAssetPic.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString().trim() ?? '') ?? 0;

    final email = (json['email'] ?? '').toString().trim();
    final name = (json['name'] ?? '').toString().trim();
    return FixedAssetPic(
      email: email,
      name: name.isNotEmpty ? name : nameOf(email),
      machineCount: toInt(json['machineCount']),
      zoneCount: toInt(json['zoneCount']),
    );
  }

  /// "viet.ta@x.com" -> "viet.ta".
  static String nameOf(String email) {
    final at = email.indexOf('@');
    return at > 0 ? email.substring(0, at) : email;
  }

  /// So email không phân biệt hoa thường; rỗng/null không bằng gì.
  static bool sameEmail(String? a, String? b) {
    final x = a?.trim().toLowerCase() ?? '';
    final y = b?.trim().toLowerCase() ?? '';
    return x.isNotEmpty && x == y;
  }
}
