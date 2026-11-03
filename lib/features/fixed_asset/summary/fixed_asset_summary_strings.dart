/// Chuỗi hiển thị mục "Tổng quan" (summary) Fixed Asset (tiếng Việt cố định, gom một
/// chỗ như các màn Fixed Asset khác).
abstract final class FixedAssetSummaryStrings {
  static const menuTitle = 'Tổng hợp';

  // Tổng hợp (B)
  static const overviewTitle = 'Tổng hợp kiểm kê';

  /// "Quý 4/2026 · tháng 2/3"; ngoài quý chỉ tên quý.
  static String periodMonth(String period, int month) =>
      month > 0 ? '$period · tháng $month/3' : period;
  static const refresh = 'Làm mới';

  // Hàng KPI
  static const quarterProgress = 'Tiến độ quý';
  static String auditedOfSuffix(int total) => ' / $total máy';

  /// "Kế hoạch đến hôm nay: 329 (37%)".
  static String planToday(int machines, double planPct) =>
      'Kế hoạch đến hôm nay: $machines (${formatNumber(planPct)}%)';
  static String behindChip(int count) => 'Chậm $count máy';
  static String aheadChip(int count) => 'Vượt $count máy';
  static const onSchedule = 'Đúng tiến độ';
  static const donutTooltip =
      'Cung mờ: kế hoạch đến hôm nay\nCung màu: đã kiểm kê';

  /// "Mục tiêu tháng 11"; ngoài quý không có số tháng.
  static String monthTarget(int? month) =>
      month == null ? 'Mục tiêu tháng' : 'Mục tiêu tháng $month';
  static String monthNeedSuffix(String date) => ' máy cần kiểm trước $date';
  static const monthReached = 'Đã đạt chỉ tiêu tháng';

  static const quarterRemaining = 'Còn lại cả quý';
  static const unauditedSuffix = ' máy chưa kiểm';

  /// "≈ 20 máy/ngày · còn 28 ngày".
  static String perDay(int perDay, int days) =>
      '≈ $perDay máy/ngày · còn $days ngày';

  /// "≈ 15 máy/ngày đến 31/12 · còn 59 ngày".
  static String perDayUntil(int perDay, String date, int days) =>
      '≈ $perDay máy/ngày đến $date · còn $days ngày';

  static const pendingQr = 'Chờ thay QR';
  static const pendingQrHint = 'Bấm để xem danh sách';

  /// Hàng gọn mobile: "{n} máy chờ thay QR".
  static const pendingQrSuffix = ' máy chờ thay QR';
  static const noValue = '—';

  /// "30/11".
  static String dayMonth(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  /// "Tiến độ theo PIC · Quý 4/2026".
  static String picProgressTitle(String period) => 'Tiến độ theo PIC · $period';

  /// Mobile: app bar đã có tên quý.
  static const picProgressTitleShort = 'Tiến độ theo PIC';
  static const sortTooltip = 'Sắp xếp';

  /// Chú thích vạch kế hoạch (mobile): "Hôm nay 03/11 · KH 36.7%".
  static String todayLegend(String date, double planPct) =>
      'Hôm nay $date · KH ${percent(planPct)}';

  /// "9/251 · 3.6%" (phần sau số đã kiểm).
  static String picOfPct(int total, double pct) =>
      '/$total · ${percent1(pct)}';
  static const picProgressUnassigned = 'Chưa có PIC';

  /// Tooltip vạch hôm nay: "Hôm nay 03/11 · kế hoạch 45.2%".
  static String todayTooltip(String date, double planPct) =>
      'Hôm nay $date · kế hoạch ${percent(planPct)}';

  static const sortMachines = 'Số máy';
  static const sortBehindPlan = 'Thiếu so KH';

  static const colPic = 'PIC';
  static const colMachines = 'Máy';
  static String colMonth(int month) => 'Tháng $month';
  static String colMonthCurrent(int month) => 'Tháng $month · tháng này';

  static const noData = 'Chưa có dữ liệu kỳ này';

  // Chi tiết PIC (C)
  static const statAudited = 'Đã kiểm';
  static const statPendingQr = 'Chờ thay QR';
  static const machineUnit = 'máy';
  static const tabZones = 'Theo khu';
  static String tabZonesCount(int count) => 'Theo khu ($count)';
  static String tabMachines(int count) => 'Danh sách máy ($count)';
  static const noZones = 'Không có khu nào';
  static const close = 'Đóng';

  // Bảng "Theo khu"
  static const onlyUnfinishedZones = 'Chỉ khu chưa xong';
  static const noZoneMatch = 'Không có khu phù hợp';
  static const searchZone = 'Tìm khu…';
  static String zoneCount(int count) => '$count khu';

  /// Dòng tên header PIC: " · {email} · {n} khu" (chưa có số khu thì bỏ).
  static String picMeta(String email, int? zones) =>
      ' · $email${zones == null ? '' : ' · ${zoneCount(zones)}'}';
  static const colZone = 'Khu';
  static const colProgress = 'Tiến độ';
  static const colPercent = '%';
  static const colRemaining = 'Còn lại';
  static const colMoved = 'Lệch vị trí';

  /// Header nhóm: "{Fac} · {Tầng}".
  static String groupTitle(String fac, String floor) => '$fac · $floor';

  // Bảng máy (khu / toàn bộ PIC)
  static const colMachineCode = 'Mã máy';
  static const colMachineName = 'Tên máy';
  static const colStatus = 'Trạng thái';
  static const colAuditor = 'Người kiểm';
  static const colTime = 'Thời gian';
  static const colQrMaster = 'Vị trí QR/Master';
  static const colNote = 'Ghi chú';
  static String qrAt(String location) => 'QR: $location';
  static String masterAt(String location) => 'Master: $location';

  static const filterAll = 'Tất cả';
  static const filterUnaudited = 'Chưa kiểm';
  static const filterAudited = 'Đã kiểm';
  static const filterAbnormal = 'Bất thường';
  static String filterCount(String label, int count) => '$label ($count)';

  static const chipUnaudited = 'Chưa kiểm';
  static const chipAudited = 'Đã kiểm';
  static const chipMoved = 'Lệch vị trí';
  static const chipPendingQr = 'Chờ thay QR';

  static const searchMachine = 'Tìm mã / tên máy…';
  static const allZones = 'Tất cả khu';
  static const noMachine = 'Không có máy phù hợp';

  static const loadFailed = 'Không tải được dữ liệu';
  static const retry = 'Thử lại';

  /// 64.0 -> "64", 64.5 -> "64.5", 64.27 -> "64.3".
  static String formatNumber(double value) {
    final rounded = (value * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toStringAsFixed(1);
  }

  static String percent(double value) => '${formatNumber(value)}%';

  /// Luôn 1 số lẻ: 64 -> "64.0%".
  static String percent1(double value) => '${value.toStringAsFixed(1)}%';
}
