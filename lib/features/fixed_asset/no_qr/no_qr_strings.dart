/// Chuỗi hiển thị "Máy không có / không quét được QR" (cùng cách với các màn
/// Fixed Asset khác: tiếng Việt cố định, gom một chỗ để dễ chuyển sang i18n
/// sau này).
abstract final class NoQrStrings {
  // Điểm vào
  static const entryTitle = 'Máy không có QR';
  static const entrySubtitle = 'Bấm để ghi nhận máy không quét được';
  static const entryAction = 'Ghi nhận';
  static const cameraLink = 'Không quét được? Ghi máy thiếu QR';
  static const rowAction = 'Ghi máy thiếu QR';
  static const tag = 'Thiếu QR';
  static const openFailed = 'Không mở được form ghi nhận máy thiếu QR';

  // Form
  static const sheetTitle = 'Ghi nhận máy thiếu QR';
  static const change = 'Đổi';
  static const done = 'Xong';

  static const location = 'Vị trí';
  static const locationRequired = 'Chọn đủ Fac / Floor / PositionA / PositionAA';

  static const machineCode = 'Mã máy';
  static const machineSearchHint = 'Tìm mã / tên máy...';
  static const machineManualHint = 'Nhập mã máy';
  static const notInList = 'Máy không có trong danh sách';
  static const noMachines = 'Vị trí này chưa có danh sách máy';
  static const noMachineMatch = 'Không có máy phù hợp';
  static const machinesNeedLocation = 'Chọn vị trí để hiện danh sách máy';
  static const machinesFailed = 'Không tải được danh sách máy';
  static const machineRequired = 'Chọn máy hoặc nhập mã máy';

  static const note = 'Ghi chú';
  static const noteHint = 'Mô tả thêm (không bắt buộc)';

  static const cancel = 'Hủy';
  static const save = 'Lưu';
  static const saved = 'Đã ghi nhận máy thiếu QR';
  static const saveFailed = 'Không lưu được, vui lòng thử lại';
}
