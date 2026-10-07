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
}
