/// Chuỗi hiển thị màn "Kiểm kê" Fixed Asset (cùng cách với
/// [FixedAssetReprintStrings]: tiếng Việt cố định, gom một chỗ).
abstract final class FixedAssetStrings {
  static const menuTitle = 'Kiểm kê';
  static const notMachineQr = 'QR không phải mã máy';
  static const multipleQr = 'Đưa 1 mã vào giữa khung';
  static String alreadySavedAt(String machineCode, DateTime at) =>
      '$machineCode đã kiểm kê lúc '
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
  static String photoUploadFailed(String machineCode) =>
      'Chưa lưu được ảnh $machineCode';
}
