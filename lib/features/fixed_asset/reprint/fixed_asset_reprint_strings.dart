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
  static const filter = 'Lọc';
  static const filterTitle = 'Bộ lọc';
  static const fac = 'Xưởng';
  static const area = 'Khu vực';
  static const search = 'Tìm kiếm';
  static const clearFilters = 'Xoá bộ lọc';
  static const applyFilters = 'Xong';
  static String picChip(String name) => 'PIC: $name';
  static String searchChip(String q) => '"$q"';
  static String listCount(int count) => '$count máy';
  static const selectAll = 'Chọn tất cả';
  static const deselectAll = 'Bỏ chọn';

  static const reasonNoQr = 'Mất QR';
  static const reasonWrongLocation = 'Sai vị trí';

  static const printFor = 'In cho vị trí';
  static const currentQr = 'QR đang dán';
  static const noQrYet = 'Chưa có QR';
  static const missingLocation = 'Thiếu dữ liệu vị trí';
  static const resolvingLocation = 'Đang tra vị trí…';

  static String selected(int count) => 'Đã chọn $count máy';
  static const selectToPrint = 'Chọn máy để in';
  static const downloadPng = 'Tải PNG';
  static const printLabels = 'In QR (PDF)';
  static const print = 'In';

  static const empty = 'Không có máy cần in lại QR';
  static String emptyForPic(String name) =>
      'PIC $name không có máy cần in lại QR';
  static const loadFailed = 'Không tải được danh sách';
  static const retry = 'Thử lại';
  static const noMatch = 'Không có máy phù hợp';

  static const exportFailed = 'Không tạo được file';
  static String printed(int count) =>
      'Đã tạo file $count QR. In xong thì dán và quét tại 3) Thay QR';
  static const openReplace = 'Mở Thay QR';
  static const close = 'Đóng';
  static String downloaded(int count) =>
      count == 1 ? 'Đã tải 1 file PNG' : 'Đã tải $count file PNG';
}
