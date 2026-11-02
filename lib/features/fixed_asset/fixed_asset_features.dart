/// Cờ tính năng của màn hình Fixed Asset (đổi ở đây, hoặc ghi đè khi build
/// bằng `--dart-define`).
abstract final class FixedAssetFeatures {
  /// TẠM THỜI: false = không hiện dialog "Sai vị trí máy" (MASTER), xử lý
  /// như "Vẫn lưu" (POST confirmLocationMismatch = true). Status card vẫn
  /// hiện sai vị trí. Dialog QR không bị ảnh hưởng.
  /// Bật lại bằng `defaultValue: true` hoặc
  /// `--dart-define=FA_MASTER_MISMATCH_DIALOG=true`.
  static const bool masterMismatchDialog = bool.fromEnvironment(
    'FA_MASTER_MISMATCH_DIALOG',
    defaultValue: false,
  );
}
