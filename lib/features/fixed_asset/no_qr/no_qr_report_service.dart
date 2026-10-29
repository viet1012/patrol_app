import 'package:flutter/foundation.dart';

import 'package:chuphinh/core/api/fixed_asset_backend.dart';
import 'package:chuphinh/core/models/fixed_asset_audit_save_response.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_audit_flow.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_location.dart';
import 'package:chuphinh/features/fixed_asset/no_qr/no_qr_report.dart';

/// Kết quả gửi một case "máy thiếu QR".
enum NoQrSubmitOutcome {
  /// Insert mới (mode NO_QR, needsQrReprint).
  saved,

  /// Đã kiểm kê trong kỳ: backend đánh dấu in tem trên bản ghi đó.
  alreadyAudited,

  /// Backend yêu cầu xác nhận sai vị trí và operator chọn "Bỏ qua".
  cancelled,
}

/// Case "máy thiếu QR" của phiên (một màn Fixed Asset): lưu qua POST /audit
/// (mode NO_QR, needsQrReprint = true, không gửi qr*). Danh sách mã máy chỉ
/// giữ trong bộ nhớ để gắn tag, mất khi rời màn hình.
class NoQrReportService extends ChangeNotifier {
  NoQrReportService({
    required this.userId,
    required this.userName,
    this.api = const FixedAssetBackend(),
  });

  final String userId;
  final String userName;
  final FixedAssetBackend api;

  final List<NoQrReport> _reports = <NoQrReport>[];
  List<NoQrReport> get reports => List<NoQrReport>.unmodifiable(_reports);

  /// Số case đã ghi; chỉ tăng nên dùng được làm version cho [machineCodes].
  int get count => _reports.length;

  /// MachineCode đã ghi thiếu QR, dạng trim().toLowerCase() (như tập
  /// audited của controller). Mutate tại chỗ: so [count] để biết đổi.
  final Set<String> _machineCodes = <String>{};
  Set<String> get machineCodes => _machineCodes;

  bool _disposed = false;

  /// Lỗi mạng / backend không lưu -> throw (form hiện lỗi, giữ nguyên form).
  /// requiresConfirmation -> [confirmMismatch]; "Vẫn lưu" thì POST lại với
  /// confirmLocationMismatch = true (như luồng scan).
  Future<NoQrSubmitOutcome> submit(
    NoQrReport report, {
    required FixedAssetConfirmMismatch confirmMismatch,
  }) async {
    var result = await _post(report, confirmLocationMismatch: false);

    if (fixedAssetSaveNeedsConfirmation(
      result,
      confirmLocationMismatch: false,
    )) {
      final confirmed = await confirmMismatch(
        FixedAssetMismatchPrompt(
          machineCode: report.machineCode,
          faName: '',
          master: fixedAssetMasterDisplay(
            result.masterFac,
            result.masterFloor,
            result.masterPositionA,
            result.masterPositionAA,
          ),
          actual: report.location,
          manual: true,
        ),
      );
      if (!confirmed) return NoQrSubmitOutcome.cancelled;
      result = await _post(report, confirmLocationMismatch: true);
    }

    if (result.alreadyAudited) {
      _record(report);
      return NoQrSubmitOutcome.alreadyAudited;
    }
    if (result.saved) {
      _record(report);
      return NoQrSubmitOutcome.saved;
    }
    throw Exception(
      result.message.isNotEmpty ? result.message : 'Save failed',
    );
  }

  Future<FixedAssetAuditSaveResponse> _post(
    NoQrReport report, {
    required bool confirmLocationMismatch,
  }) {
    final id = userId.trim();
    final name = userName.trim();
    final location = report.location;
    return api.saveAudit(
      fac: location.fac,
      floor: location.floor,
      positionA: location.positionA,
      positionAA: location.positionAA,
      machineCode: report.machineCode,
      userId: id,
      userName: name.isEmpty ? id : name,
      note: report.note,
      confirmLocationMismatch: confirmLocationMismatch,
      mode: 'NO_QR',
      needsQrReprint: true,
    );
  }

  void _record(NoQrReport report) {
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
