/// Chuỗi hiển thị luồng "Thay QR" (cùng cách với [FixedAssetReprintStrings]:
/// tiếng Việt cố định, gom một chỗ).
abstract final class FixedAssetReplaceStrings {
  static const menuTitle = 'Thay QR';
  static const title = 'Thay QR';
  static String subtitle(int count) => '$count máy còn chờ thay QR';
  static const refresh = 'Làm mới';

  static const fac = 'Xưởng';
  static const allFacs = 'Tất cả xưởng';
  static const unknownLocation = 'Chưa rõ vị trí';
  static String waiting(int count) => '$count máy chờ';

  static const kindMissing = 'Mất QR';
  static const kindWrongShort = 'Sai QR';
  static String kindWrong(String label) => 'Sai QR – đang dán $label';
  static const stepMissing = 'Quét 1 lần: QR mới';
  static const stepWrong = 'Quét 2 lần: QR cũ → QR mới';
  static const oldScanned = 'Đã quét QR cũ → quét QR mới';
  static const done = 'Đã xong';

  static const empty = 'Không còn máy nào chờ thay QR ✓';
  static const zoneEmpty = 'Khu này đã thay xong QR ✓';
  static const loadFailed = 'Không tải được danh sách';
  static const retry = 'Thử lại';

  // Màn "Việc cần làm".
  static const tasksTitle = 'Việc cần làm';
  static String actual(String label) => 'Vị trí thực tế: $label';
  static String stepOld(String oldQr) => 'Quét QR cũ – đang dán $oldQr';
  static String stepNew(String act) => 'Quét QR mới – $act';
  static String doneAt(String time) => 'Xong lúc $time';
  static const tapToScan = 'Bấm để mở camera';
  static const unknownAct =
      'Chưa rõ vị trí thực tế – chưa quét QR mới được ở đây';
  static const allDone = 'Đã thay QR xong';
  static const nextMachine = 'Máy tiếp theo';
  static const backToList = 'Về danh sách';
  static String zoneDone(String positionAA) =>
      'Khu $positionAA đã thay xong QR';

  // Camera.
  // Header: "Quét" + badge loại QR.
  static const scan = 'Quét';
  static const qrNew = 'QR MỚI';
  static const qrOld = 'QR CŨ';

  // Thẻ thông tin dưới khung quét.
  static String placeOld(String oldQr) => '· đang dán tại $oldQr';
  static String placeNew(String act) => '· vị trí thực tế $act';
  static const oldQrGuide = 'Tìm tem QR đang dán trên máy và đưa vào khung.';
  static const newQrGuide =
      'Dùng tem QR mới chưa dán, quét trước khi dán lên máy.';
  static String oldQrScanned(String oldQr) => 'Đã quét QR cũ: $oldQr';

  // Hướng dẫn: "Đưa " + loại QR (tô màu) + " vào giữa khung".
  static const scanHintPrefix = 'Đưa ';
  static const scanHintSuffix = ' vào giữa khung';
  static const saving = 'Đang lưu…';
  static const flashUnsupported = 'Máy này không bật được đèn flash';
  static const invalidQr = 'QR không hợp lệ (không đọc được mã máy)';
  static String mismatch(String scanned, String expected) =>
      'QR không khớp: đang quét $scanned, cần $expected';

  // Lỗi lưu bước 2: camera đóng, báo ở màn "Việc cần làm".
  static String saveFailed(String error) =>
      'Lưu không thành công: $error. Bấm bước 2 để quét lại';
  static String notCleared(String message) =>
      'Chưa gỡ được cờ QR${message.isEmpty ? '' : ': $message'}. '
      'Bấm bước 2 để quét lại';
  static String replaced(String code) => 'Đã thay QR $code';
  static String replacedNext(String code, String next) =>
      'Đã thay QR $code · tiếp $next';
  static String zoneFinished(String zone) => 'Đã xong khu $zone';
  static const noneLeft = 'Không còn máy chờ thay QR';
}
