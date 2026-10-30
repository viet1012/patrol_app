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
  static String scanOldTitle(String code, String oldQr) =>
      'Quét QR CŨ của $code (đang dán $oldQr)';
  static String scanNewTitle(String code, String act) =>
      'Quét QR MỚI của $code ($act)';
  static const scanHint = 'Đưa QR vào giữa khung';
  static const saving = 'Đang lưu…';
  static const flashUnsupported = 'Máy này không bật được đèn flash';
  static const invalidQr = 'QR không hợp lệ (không đọc được mã máy)';
  static String otherMachine(String other, String code) =>
      'QR này của máy $other, không phải $code';
  static String notOldQr(String oldQr) => 'Đây không phải QR cũ ($oldQr)';
  static const stillOldQr = 'Vẫn là QR cũ, hãy quét QR mới';
  static String newQrWrongLocation(String onQr, String act) =>
      'QR mới in sai vị trí ($onQr), cần in lại QR $act';
  static String newQrNoLocation(String act) =>
      'QR không có vị trí, cần in lại QR $act';
  static String saveFailed(String error) =>
      'Lưu không thành công: $error. Đưa QR ra rồi quét lại';
  static String notCleared(String message) =>
      'Chưa gỡ được cờ QR${message.isEmpty ? '' : ': $message'}. '
      'Đưa QR ra rồi quét lại';
}
