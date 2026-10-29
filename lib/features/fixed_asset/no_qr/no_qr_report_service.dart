import 'package:flutter/foundation.dart';

import 'package:chuphinh/features/fixed_asset/no_qr/no_qr_report.dart';

/// Case "máy thiếu QR" của phiên (một màn Fixed Asset). Chưa có BE: chỉ giữ
/// trong bộ nhớ, mất khi rời màn hình.
class NoQrReportService extends ChangeNotifier {
  final List<NoQrReport> _reports = <NoQrReport>[];
  List<NoQrReport> get reports => List<NoQrReport>.unmodifiable(_reports);

  /// Số case đã ghi; chỉ tăng nên dùng được làm version cho [machineCodes].
  int get count => _reports.length;

  /// MachineCode đã ghi thiếu QR, dạng trim().toLowerCase() (như tập
  /// audited của controller). Mutate tại chỗ: so [count] để biết đổi.
  final Set<String> _machineCodes = <String>{};
  Set<String> get machineCodes => _machineCodes;

  bool _disposed = false;

  Future<void> submit(NoQrReport report) async {
    // TODO: gửi API khi BE sẵn sàng
    if (_disposed) return;
    _reports.add(report);
    final code = report.machineCode.trim().toLowerCase();
    if (code.isNotEmpty) _machineCodes.add(code);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
