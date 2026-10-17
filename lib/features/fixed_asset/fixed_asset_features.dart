/// Cờ tính năng của màn hình Fixed Asset (đổi ở đây, hoặc ghi đè khi build
/// bằng `--dart-define`).
abstract final class FixedAssetFeatures {
  /// Chế độ Auto khóa user ở một khu vực (PositionAA) cho tới khi audit 100%.
  /// false: tắt hoàn toàn (không gọi zone-lock, không chặn scan, không dải khóa,
  /// không cảnh báo, không SnackBar mở khóa, không tự hiện khu vực dang dở).
  static const bool zoneLock = bool.fromEnvironment(
    'FA_ZONE_LOCK',
    defaultValue: true,
  );

  /// TẠM THỜI: false = màn hình chỉ dùng MANUAL (vào thẳng MANUAL, ẩn toggle
  /// Auto/Manual, chặn mọi đường chuyển sang AUTO). Code AUTO vẫn giữ nguyên;
  /// bật lại bằng `defaultValue: true` hoặc `--dart-define=FA_AUTO_MODE=true`.
  static const bool autoMode = bool.fromEnvironment(
    'FA_AUTO_MODE',
    defaultValue: false,
  );

  /// TẠM THỜI: false = MANUAL không hiện dialog "Sai vị trí máy" (MASTER),
  /// xử lý như "Vẫn lưu" (POST confirmLocationMismatch = true). Status card
  /// vẫn hiện sai vị trí. Dialog QR không bị ảnh hưởng; AUTO giữ nguyên.
  /// Bật lại bằng `defaultValue: true` hoặc
  /// `--dart-define=FA_MASTER_MISMATCH_DIALOG=true`.
  static const bool masterMismatchDialog = bool.fromEnvironment(
    'FA_MASTER_MISMATCH_DIALOG',
    defaultValue: false,
  );
}
