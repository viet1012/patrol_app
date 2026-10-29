/// Dòng audit trong kỳ đang cần in lại tem (QrMismatch = 1), từ
/// reprintAct* / reprintQr* của scan-info và audit-check.
///
/// act* = vị trí thực tế đã ghi nhận (*_Act); qr* = vị trí trên tem hiện tại
/// (*_Qr). Field null = backend không trả / cột NULL.
class FixedAssetReprintInfo {
  final String? actFac;
  final String? actFloor;
  final String? actPositionA;
  final String? actPositionAA;

  final String? qrFac;
  final String? qrFloor;
  final String? qrPositionA;
  final String? qrPositionAA;

  /// Không tra được reprintQr* từ backend (scan-info lỗi): không hiển thị
  /// "Tem hiện tại" (khác NO_QR, nơi qr* null nghĩa là chưa có tem).
  final bool labelUnknown;

  const FixedAssetReprintInfo({
    this.actFac,
    this.actFloor,
    this.actPositionA,
    this.actPositionAA,
    this.qrFac,
    this.qrFloor,
    this.qrPositionA,
    this.qrPositionAA,
    this.labelUnknown = false,
  });

  /// null khi không có field reprint* nào (máy không cần in lại / API cũ).
  static FixedAssetReprintInfo? fromJson(Map<String, dynamic> json) {
    String? opt(String key) {
      final value = (json[key] ?? '').toString().trim();
      return value.isEmpty ? null : value;
    }

    final info = FixedAssetReprintInfo(
      actFac: opt('reprintActFac'),
      actFloor: opt('reprintActFloor'),
      actPositionA: opt('reprintActPositionA'),
      actPositionAA: opt('reprintActPositionAA'),
      qrFac: opt('reprintQrFac'),
      qrFloor: opt('reprintQrFloor'),
      qrPositionA: opt('reprintQrPositionA'),
      qrPositionAA: opt('reprintQrPositionAA'),
    );
    return info.hasAct || info.hasLabel ? info : null;
  }

  bool get hasAct =>
      actFac != null ||
      actFloor != null ||
      actPositionA != null ||
      actPositionAA != null;

  /// false = dòng NO_QR (máy chưa có tem): không có Floor_Qr / AA_Qr.
  bool get hasLabel => qrFloor != null || qrPositionAA != null;

  /// "Fac/Floor/A/AA", field thiếu là "-".
  String get actLabel =>
      fixedAssetLocationLabel(actFac, actFloor, actPositionA, actPositionAA);

  String get qrLabel =>
      fixedAssetLocationLabel(qrFac, qrFloor, qrPositionA, qrPositionAA);

  /// act* = vị trí thực tế [act*] (bỏ trống thì giữ của mình), qr* giữ nguyên.
  FixedAssetReprintInfo withAct({
    String? fac,
    String? floor,
    String? positionA,
    String? positionAA,
  }) => FixedAssetReprintInfo(
    actFac: fac ?? actFac,
    actFloor: floor ?? actFloor,
    actPositionA: positionA ?? actPositionA,
    actPositionAA: positionAA ?? actPositionAA,
    qrFac: qrFac,
    qrFloor: qrFloor,
    qrPositionA: qrPositionA,
    qrPositionAA: qrPositionAA,
    labelUnknown: labelUnknown,
  );
}

/// "Fac/Floor/A/AA" cho UI; null / rỗng hiển thị "-".
String fixedAssetLocationLabel(
  String? fac,
  String? floor,
  String? positionA,
  String? positionAA,
) => [fac, floor, positionA, positionAA]
    .map((v) => (v ?? '').trim().isEmpty ? '-' : v!.trim())
    .join('/');
