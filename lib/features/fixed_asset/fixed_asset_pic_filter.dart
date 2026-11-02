import 'package:flutter/foundation.dart';

import 'package:chuphinh/core/api/fixed_asset_backend.dart';
import 'package:chuphinh/core/models/fixed_asset_pic.dart';
import 'package:chuphinh/core/models/fixed_asset_qr_mismatch.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_audit_flow.dart'
    show fixedAssetErrorText;

/// PIC đang chọn, dùng chung mọi màn Fixed Asset ("Kiểm kê", "In lại QR",
/// "Thay QR") trong phiên chạy app (không lưu storage). null = "Tất cả PIC".
abstract final class FixedAssetPicSession {
  static final ValueNotifier<String?> selected = ValueNotifier<String?>(null);
}

/// Danh sách PIC + PIC đang chọn của một màn. Đổi PIC ở màn nào cũng ghi
/// vào [FixedAssetPicSession], các màn khác nhận qua listener.
///
/// Hai nguồn danh sách:
/// - mặc định: GET /pics ([load]) – màn "Kiểm kê";
/// - [localOnly]: PIC rút từ dữ liệu màn đã tải ([setFromRows]) – "In lại QR"
///   / "Thay QR". PIC ghi nhớ không có trong danh sách thì màn hiển thị
///   "Tất cả PIC" nhưng KHÔNG ghi đè PIC đã ghi nhớ.
class FixedAssetPicFilter extends ChangeNotifier {
  FixedAssetPicFilter({
    this.api = const FixedAssetBackend(),
    this.localOnly = false,
  }) {
    FixedAssetPicSession.selected.addListener(_notify);
  }

  final FixedAssetBackend api;
  final bool localOnly;

  /// [localOnly]: tổng số dòng (kể cả máy chưa có PIC) cho "Tất cả PIC (N)".
  int? _allCount;
  int? get allCount => _allCount;

  bool _disposed = false;

  List<FixedAssetPic> _pics = const <FixedAssetPic>[];
  List<FixedAssetPic> get pics => _pics;

  bool _loading = false;
  bool get loading => _loading;

  /// Email PIC đang áp dụng ở màn này; null = "Tất cả PIC".
  String? get selectedEmail {
    final remembered = FixedAssetPicSession.selected.value;
    if (!localOnly || remembered == null) return remembered;
    return picOf(remembered) != null ? remembered : null;
  }

  /// [localOnly]: danh sách PIC = các pic có trong [rows] (bỏ dòng không có
  /// PIC); machineCount = số máy, zoneCount = số khu theo vị trí thực tế
  /// (*_Act). Sắp theo số máy giảm dần, rồi theo tên.
  void setFromRows(Iterable<FixedAssetQrMismatch> rows) {
    String norm(String? v) => (v ?? '').trim().toLowerCase();
    final emailOf = <String, String>{};
    final machines = <String, Set<String>>{};
    final zones = <String, Set<String>>{};
    var total = 0;
    for (final row in rows) {
      total++;
      final email = row.pic?.trim() ?? '';
      if (email.isEmpty) continue;
      final key = norm(email);
      emailOf[key] ??= email;
      (machines[key] ??= <String>{}).add(norm(row.machineCode));
      (zones[key] ??= <String>{}).add(
        [row.facAct, row.floorAct, row.positionA, row.positionAA]
            .map(norm)
            .join('|'),
      );
    }
    final pics = [
      for (final key in emailOf.keys)
        FixedAssetPic(
          email: emailOf[key]!,
          name: FixedAssetPic.nameOf(emailOf[key]!),
          machineCount: machines[key]!.length,
          zoneCount: zones[key]!.length,
        ),
    ]..sort((a, b) {
        final byCount = b.machineCount.compareTo(a.machineCount);
        return byCount != 0 ? byCount : a.name.compareTo(b.name);
      });
    _pics = List<FixedAssetPic>.unmodifiable(pics);
    _allCount = total;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    FixedAssetPicSession.selected.removeListener(_notify);
    super.dispose();
  }

  /// Lỗi tải chỉ báo qua [onError] (dropdown vẫn có "Tất cả PIC").
  /// [silent]: tải ngầm (không hiện loading, lỗi bỏ qua), giữ danh sách cũ
  /// tới khi có danh sách mới.
  Future<void> load({ValueChanged<String>? onError, bool silent = false}) async {
    if (_disposed) return;
    if (!silent) {
      _loading = true;
      _notify();
    }
    try {
      final result = await api.fetchPics();
      if (_disposed) return;
      _pics = result;
    } catch (error) {
      if (_disposed || silent) return;
      onError?.call('Load PIC failed: ${fixedAssetErrorText(error)}');
    } finally {
      if (!_disposed) {
        _loading = false;
        _notify();
      }
    }
  }

  /// Chọn PIC (null / rỗng = "Tất cả PIC") cho mọi màn.
  void select(String? email) {
    final value = (email?.trim().isEmpty ?? true) ? null : email!.trim();
    FixedAssetPicSession.selected.value = value;
  }

  /// Dòng có PIC [pic] được hiện theo PIC đang chọn. Dòng không có PIC chỉ
  /// hiện khi "Tất cả PIC".
  bool matches(String? pic) {
    final selected = selectedEmail;
    return selected == null || FixedAssetPic.sameEmail(pic, selected);
  }

  FixedAssetPic? picOf(String? email) {
    for (final pic in _pics) {
      if (FixedAssetPic.sameEmail(pic.email, email)) return pic;
    }
    return null;
  }

  /// Tên hiển thị: theo danh sách PIC, không có thì phần trước @.
  String nameOf(String email) => picOf(email)?.name ?? FixedAssetPic.nameOf(email);
}
