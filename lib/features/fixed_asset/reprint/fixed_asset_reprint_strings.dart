/// Chuỗi hiển thị màn "In lại QR" (cùng cách với các màn Fixed Asset khác:
/// tiếng Việt cố định, gom một chỗ để dễ chuyển sang i18n sau này).
abstract final class FixedAssetReprintStrings {
  static const menuTitle = 'In lại QR';
  static const title = 'In lại QR';
  static String subtitle(int count) => '$count máy cần in lại';
  static const refresh = 'Làm mới';

  static String allFacs(int count) => 'Tất cả ($count)';
  static String facChip(String fac, int count) => '$fac ($count)';
  static String facGroup(String fac, int count) => '$fac · $count máy';
  static const unknownFac = 'Chưa rõ xưởng';

  static const searchHint = 'Tìm mã / tên máy...';
  static const allAreas = 'Tất cả khu vực';
  static const selectAll = 'Chọn tất cả';
  static const deselectAll = 'Bỏ chọn';

  static const oldQr = 'QR cũ';
  static const newQr = 'QR mới';
  static const missingLocation = 'Thiếu dữ liệu vị trí';
  static const resolvingLocation = 'Đang tra vị trí…';

  static String selected(int count) => 'Đã chọn $count';
  static const downloadPng = 'Tải PNG';
  static const printLabels = 'In tem (PDF)';
  static const print = 'In';

  static const empty = 'Không có QR nào cần in lại ✓';
  static const loadFailed = 'Không tải được danh sách';
  static const retry = 'Thử lại';
  static const noMatch = 'Không có máy phù hợp';

  static const exportFailed = 'Không tạo được file';
  static String downloaded(int count) =>
      count == 1 ? 'Đã tải 1 file PNG' : 'Đã tải $count file PNG';
}
