import 'package:flutter/widgets.dart';

import '../api/fixed_asset_api.dart';
import '../model/fixed_asset_audit_check_response.dart';
import '../model/fixed_asset_audit_save_response.dart';
import '../model/fixed_asset_audit_summary.dart';
import '../model/fixed_asset_machine.dart';
import 'fixed_asset_audit_flow.dart';
import 'fixed_asset_location.dart';
import 'fixed_asset_manual_cascade.dart';
import 'fixed_asset_qr_parser.dart';

/// State + điều phối nghiệp vụ của màn hình Fixed Asset (scan, audit, save,
/// machine list, summary; cascade MANUAL ở [FixedAssetManualCascade]).
///
/// Không giữ BuildContext. Những việc cần UI được đưa vào qua callback:
/// - [confirmMismatch]: dialog "Vẫn lưu / Hủy"
/// - [showError]: snackbar lỗi load dropdown
/// - [resetQr]: re-arm QR scanner của CameraPreviewBox
class FixedAssetController extends ChangeNotifier {
  FixedAssetController({
    required this.accountCode,
    required this.userName,
    required this.confirmMismatch,
    required this.showError,
    required this.resetQr,
  }) {
    manual = FixedAssetManualCascade(
      onChanged: _notify,
      onError: showError,
      isDisposed: () => _disposed,
    );
  }

  final String accountCode;
  final String userName;
  final FixedAssetConfirmMismatch confirmMismatch;
  final ValueChanged<String> showError;
  final VoidCallback resetQr;

  late final FixedAssetManualCascade manual;

  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    machineSearchController.dispose();
    super.dispose();
  }

  // ============================================================
  // MODE + AUTO LOCATION
  // ============================================================

  FixedAssetLocationMode _locationMode = FixedAssetLocationMode.auto;
  FixedAssetLocationMode get locationMode => _locationMode;

  bool get isAutoMode => _locationMode == FixedAssetLocationMode.auto;

  /// Location AUTO = vị trí ĐANG QUÉT (ACTUAL) do audit-check resolve.
  /// Đây là location audit + machine list, không phải location MASTER.
  FixedAssetAuditLocation? _autoLocation;
  FixedAssetAuditLocation? get autoLocation => _autoLocation;

  /// ACTUAL location hiện tại khác MASTER của machine vừa quét.
  bool _autoLocationMismatch = false;
  bool get autoLocationMismatch => _autoLocationMismatch;

  /// Vị trí đang quét không có trong MAP (AUTO). Khi có giá trị thì
  /// [autoLocation] = null: location card chỉ hiện Floor / PositionAA.
  FixedAssetUnmappedActual? _autoUnmappedActual;
  FixedAssetUnmappedActual? get autoUnmappedActual => _autoUnmappedActual;

  /// Location đang dùng cho machine list, theo mode hiện tại.
  FixedAssetAuditLocation? get activeLocation =>
      isAutoMode ? _autoLocation : manual.selectedLocation;

  // ============================================================
  // SCAN STATE
  // ============================================================

  FixedAssetScanStatus _scanStatus = FixedAssetScanStatus.idle;
  FixedAssetScanStatus get scanStatus => _scanStatus;

  /// MachineCode đã extract từ QR gần nhất (không phải raw QR).
  String _scannedCode = '';
  String get scannedCode => _scannedCode;

  /// FAName từ MASTER (chỉ có ở AUTO).
  String _scannedFaName = '';
  String get scannedFaName => _scannedFaName;

  /// Message lỗi hiển thị trên status card.
  String? _statusMessage;
  String? get statusMessage => _statusMessage;

  /// Lần kiểm kê gần nhất (khi machine đã kiểm kê trong kỳ).
  DateTime? _lastAuditedAt;
  DateTime? get lastAuditedAt => _lastAuditedAt;

  /// Người kiểm kê gần nhất (cùng nguồn với [lastAuditedAt]).
  String? _lastAuditedUserId;
  String? get lastAuditedUserId => _lastAuditedUserId;

  String? _lastAuditedUserName;
  String? get lastAuditedUserName => _lastAuditedUserName;

  /// MASTER location của machine sai vị trí (hiển thị trên status card).
  FixedAssetAuditLocation? _mismatchMaster;
  FixedAssetAuditLocation? get mismatchMaster => _mismatchMaster;

  /// Chỉ một scan pipeline (check -> confirm -> save) chạy tại một thời điểm.
  bool _processingScan = false;
  String? _processingRawQr;

  /// QR camera nhìn thấy gần nhất + thời điểm. Cập nhật ở mỗi lần detect
  /// lặp, nên QR còn nằm trong khung camera luôn bị coi là "cũ".
  String? _lastSeenQr;
  DateTime? _lastSeenAt;

  /// Tăng khi: nhận scan mới, đổi mode, đổi location manual.
  /// Mọi bước async của pipeline kiểm tra lại token này trước khi
  /// đụng tới UI / gọi API tiếp theo.
  int _scanGeneration = 0;

  /// Cùng một QR được detect lại liên tục (vẫn nằm trong khung camera)
  /// sẽ bị bỏ qua cho tới khi vắng mặt quá khoảng này.
  static const Duration _repeatScanWindow = Duration(seconds: 3);

  bool _isCurrentScan(int generation) =>
      !_disposed && generation == _scanGeneration;

  // ============================================================
  // MACHINE LIST STATE
  // ============================================================

  List<FixedAssetMachine> _machines = const <FixedAssetMachine>[];
  List<FixedAssetMachine> get machines => _machines;

  bool _loadingMachines = false;
  bool get loadingMachines => _loadingMachines;

  String? _machineError;
  String? get machineError => _machineError;

  int _machineReq = 0;

  // Search cục bộ, không gọi API.
  final TextEditingController machineSearchController =
      TextEditingController();
  String _machineSearch = '';
  String get machineSearch => _machineSearch;

  /// MachineCode ĐÃ KIỂM KÊ TRONG KỲ HIỆN TẠI, lưu dạng trim().toLowerCase().
  ///
  /// Chỉ thêm từ bằng chứng trong session này (audit-check alreadyAudited,
  /// POST saved/alreadyAudited). KHÔNG dùng
  /// /audited-machine-codes vì endpoint đó là lịch sử trọn đời, không lọc
  /// theo kỳ 3 tháng. Không reset khi location/mode đổi.
  final Set<String> _auditedMachineCodes = <String>{};
  Set<String> get auditedMachineCodes => _auditedMachineCodes;

  /// Gọi trong lúc mutate state khi danh sách machine bị clear.
  void _clearMachineSearch() {
    _machineSearch = '';
    machineSearchController.clear();
  }

  void setMachineSearch(String value) {
    _machineSearch = value;
    _notify();
  }

  void clearMachineSearch() {
    _clearMachineSearch();
    _notify();
  }

  // ============================================================
  // AUDIT SUMMARY STATE
  // ============================================================

  FixedAssetAuditSummary? _auditSummary;
  FixedAssetAuditSummary? get auditSummary => _auditSummary;

  bool _loadingAuditSummary = false;
  bool get loadingAuditSummary => _loadingAuditSummary;

  String? _auditSummaryError;
  String? get auditSummaryError => _auditSummaryError;

  int _summaryReq = 0;

  /// Gọi lúc mở màn hình và sau POST saved=true cho machine MASTER.
  /// Lỗi chỉ hiện trên progress card, không ảnh hưởng scan workflow.
  Future<void> loadAuditSummary() async {
    final req = ++_summaryReq;
    _loadingAuditSummary = true;
    _auditSummaryError = null;
    _notify();

    try {
      final result = await FixedAssetApi.fetchAuditSummary();
      if (_disposed || req != _summaryReq) return;
      _auditSummary = result;
      _loadingAuditSummary = false;
      _notify();
    } catch (error) {
      if (_disposed || req != _summaryReq) return;
      _auditSummaryError = fixedAssetErrorText(error);
      _loadingAuditSummary = false;
      _notify();
    }
  }

  // ============================================================
  // SCAN PIPELINE
  // ============================================================

  /// Gọi trong lúc mutate state khi location/mode đổi.
  ///
  /// KHÔNG xóa _lastSeenQr: QR vẫn đang nằm trong khung camera phải
  /// rời khung (quá _repeatScanWindow) rồi scan lại mới được save.
  void _clearScanState() {
    _scanGeneration++;
    _scanStatus = FixedAssetScanStatus.idle;
    _scannedCode = '';
    _scannedFaName = '';
    _statusMessage = null;
    _lastAuditedAt = null;
    _lastAuditedUserId = null;
    _lastAuditedUserName = null;
    _mismatchMaster = null;
    if (_lastSeenQr != null) _lastSeenAt = DateTime.now();
    resetQr();
  }

  void _failScan(int generation, String message) {
    if (!_isCurrentScan(generation)) return;
    _scanStatus = FixedAssetScanStatus.failed;
    _statusMessage = message;
    _notify();
  }

  Future<void> processScannedQr(String rawQr) async {
    final qr = rawQr.trim();
    if (qr.isEmpty || _disposed) return;

    final now = DateTime.now();

    if (_processingScan) {
      // Giữ QR đang xử lý ở trạng thái "cũ" để không xử lý lại sau khi xong.
      // QR khác không được ghi nhận, để lần detect sau vẫn là scan mới.
      if (qr == _processingRawQr) {
        _lastSeenQr = qr;
        _lastSeenAt = now;
      }
      return;
    }

    // Chặn detect lặp của cùng một QR đang nằm trong khung camera.
    // Mỗi lần detect lặp sẽ gia hạn cửa sổ, nên chỉ khi QR rời khung
    // quá _repeatScanWindow mới được scan lại (không blacklist vĩnh viễn).
    final lastAt = _lastSeenAt;
    final isRepeat =
        qr == _lastSeenQr &&
        lastAt != null &&
        now.difference(lastAt) < _repeatScanWindow;

    _lastSeenQr = qr;
    _lastSeenAt = now;

    if (isRepeat) return;

    final generation = ++_scanGeneration;
    final qrData = parseFixedAssetQr(qr);
    final machineCode = qrData.machineCode;

    // AUTO cần Floor + PositionAA từ QR để backend resolve vị trí thật.
    final String? invalidMessage = machineCode.isEmpty
        ? 'Invalid machine QR'
        : (isAutoMode && !qrData.hasLocation)
        ? 'Invalid Fixed Asset QR location'
        : null;

    if (invalidMessage != null) {
      _scannedCode = machineCode;
      _scannedFaName = '';
      _mismatchMaster = null;
      _scanStatus = FixedAssetScanStatus.failed;
      _statusMessage = invalidMessage;
      _notify();
      resetQr();
      return;
    }

    // Một pipeline duy nhất cho toàn bộ CHECK -> (CONFIRM) -> SAVE.
    _processingScan = true;
    _processingRawQr = qr;

    _scannedCode = machineCode;
    _scannedFaName = qrData.displayName;
    _statusMessage = null;
    _lastAuditedAt = null;
    _lastAuditedUserId = null;
    _lastAuditedUserName = null;
    _mismatchMaster = null;
    _scanStatus = isAutoMode
        ? FixedAssetScanStatus.checking
        : FixedAssetScanStatus.saving;
    _notify();

    try {
      if (isAutoMode) {
        await _runAutoScan(qrData, generation);
      } else {
        await _runManualScan(machineCode, generation);
      }
    } finally {
      _processingScan = false;
      _processingRawQr = null;

      if (_isCurrentScan(generation)) {
        // Cửa sổ chống lặp tính từ lúc pipeline xong.
        _lastSeenQr = qr;
        _lastSeenAt = DateTime.now();
        resetQr();
      }
    }
  }

  /// MANUAL: location lấy từ dropdown. Mismatch (nếu có) do POST báo về.
  Future<void> _runManualScan(String machineCode, int generation) async {
    final location = manual.selectedLocation;
    if (location == null) {
      _failScan(generation, 'Select Fac, Floor, PositionA and PositionAA first');
      return;
    }

    await _saveAudit(
      machineCode,
      FixedAssetSaveTarget.mapped(location),
      generation,
    );
  }

  // ------------------------------------------------------------
  // AUTO FLOW: một POST /audit-check quyết định toàn bộ
  // ------------------------------------------------------------

  /// AUTO: check -> phân loại -> handler tương ứng. Không gọi scan-info /
  /// machine-location cho cùng scan.
  Future<void> _runAutoScan(FixedAssetQrData qrData, int generation) async {
    final machineCode = qrData.machineCode;

    final FixedAssetAuditCheckResponse check;

    try {
      check = await FixedAssetApi.checkAudit(
        machineCode: machineCode,
        floor: qrData.floor,
        positionAA: qrData.positionAA,
      );
    } catch (error) {
      _failScan(
        generation,
        fixedAssetCheckErrorMessage(
          fixedAssetErrorText(error),
          'Unable to check audit status',
        ),
      );
      return;
    }

    if (!_isCurrentScan(generation) || !isAutoMode) return;

    final actual = fixedAssetActualOf(check);
    final faName = check.faName.isNotEmpty ? check.faName : qrData.displayName;

    switch (classifyFixedAssetAutoCheck(check, actual)) {
      case FixedAssetAutoCheckOutcome.alreadyAudited:
        // 1. Trùng trong kỳ: không POST. Location card ưu tiên ACTUAL,
        //    không có thì dùng MASTER (strict).
        _applyAutoCheck(
          machineCode,
          actual ?? fixedAssetStrictMasterOf(check),
          faName,
          FixedAssetScanStatus.alreadyAudited,
          lastAuditedAt: check.lastAuditedAt,
          lastAuditedUserId: check.lastAuditedUserId,
          lastAuditedUserName: check.lastAuditedUserName,
        );
      case FixedAssetAutoCheckOutcome.unmappedActual:
        await _handleUnmappedActual(
          machineCode,
          check,
          qrData,
          faName,
          generation,
        );
      case FixedAssetAutoCheckOutcome.unresolvedActual:
        _failScan(
          generation,
          fixedAssetCheckErrorMessage(check.message, 'QR location not found'),
        );
      case FixedAssetAutoCheckOutcome.mappedMismatch:
        // actual != null đã được đảm bảo bởi classifyFixedAssetAutoCheck.
        await _handleMappedMismatch(
          machineCode,
          check,
          actual!,
          faName,
          generation,
        );
      case FixedAssetAutoCheckOutcome.directSave:
        // 5. Khớp vị trí, hoặc machine ngoài MASTER: POST bằng ACTUAL.
        _applyAutoCheck(
          machineCode,
          actual!,
          faName,
          FixedAssetScanStatus.saving,
        );
        await _saveAudit(
          machineCode,
          FixedAssetSaveTarget.mapped(actual),
          generation,
        );
    }
  }

  /// 2. Known machine, vị trí đang quét KHÔNG có trong MAP: không phải lỗi.
  /// Hiện MASTER + raw Floor/PositionAA, hỏi rồi mới lưu (Fac/PositionA =
  /// null, không suy ra).
  Future<void> _handleUnmappedActual(
    String machineCode,
    FixedAssetAuditCheckResponse check,
    FixedAssetQrData qrData,
    String faName,
    int generation,
  ) async {
    final raw = FixedAssetUnmappedActual(
      floor: check.actualFloor.isNotEmpty ? check.actualFloor : qrData.floor,
      positionAA: check.actualPositionAA.isNotEmpty
          ? check.actualPositionAA
          : qrData.positionAA,
    );
    final masterDisplay = fixedAssetMasterDisplayOf(check);

    _applyUnmappedActual(raw, faName, masterDisplay);

    await _confirmThenSaveAuto(
      generation: generation,
      machineCode: machineCode,
      faName: faName,
      masterDisplay: masterDisplay,
      target: FixedAssetSaveTarget.unmapped(raw),
    );
  }

  /// 4. Machine có trong MASTER nhưng ở vị trí khác (đã map): hỏi trước khi
  /// save, save bằng ACTUAL location.
  Future<void> _handleMappedMismatch(
    String machineCode,
    FixedAssetAuditCheckResponse check,
    FixedAssetAuditLocation actual,
    String faName,
    int generation,
  ) async {
    final masterDisplay = fixedAssetMasterDisplayOf(check);

    _applyAutoCheck(
      machineCode,
      actual,
      faName,
      FixedAssetScanStatus.locationMismatch,
      mismatchMaster: masterDisplay,
    );

    await _confirmThenSaveAuto(
      generation: generation,
      machineCode: machineCode,
      faName: faName,
      masterDisplay: masterDisplay,
      target: FixedAssetSaveTarget.mapped(actual),
    );
  }

  /// Chung cho mapped mismatch và unmapped ACTUAL (AUTO): dialog -> Hủy thì
  /// không save; "Vẫn lưu" thì POST với confirmLocationMismatch = true.
  Future<void> _confirmThenSaveAuto({
    required int generation,
    required String machineCode,
    required String faName,
    required FixedAssetAuditLocation? masterDisplay,
    required FixedAssetSaveTarget target,
  }) async {
    final confirmed = await _confirmLocationMismatch(
      generation,
      FixedAssetMismatchPrompt(
        machineCode: machineCode,
        faName: faName,
        master: masterDisplay,
        actual: target.location,
        unmappedActual: target.unmapped,
      ),
    );

    if (!_isCurrentScan(generation) || !isAutoMode) return;

    if (!confirmed) {
      _markMismatchCancelled(generation);
      return;
    }

    await _saveAudit(
      machineCode,
      target,
      generation,
      confirmLocationMismatch: true,
    );
  }

  /// Áp kết quả audit-check trong MỘT lần notify. ACTUAL location là location
  /// audit + machine list. Không đi qua handler cascade manual; machine list
  /// chỉ reload khi location đổi hoặc lần trước lỗi.
  void _applyAutoCheck(
    String machineCode,
    FixedAssetAuditLocation? location,
    String faName,
    FixedAssetScanStatus status, {
    DateTime? lastAuditedAt,
    String? lastAuditedUserId,
    String? lastAuditedUserName,
    FixedAssetAuditLocation? mismatchMaster,
  }) {
    final sameLocation = location == _autoLocation;
    final reloadMachines =
        location != null && (!sameLocation || _machineError != null);

    if (reloadMachines) _machineReq++;

    _scannedFaName = faName;
    _lastAuditedAt = lastAuditedAt;
    _lastAuditedUserId = lastAuditedUserId;
    _lastAuditedUserName = lastAuditedUserName;
    _scanStatus = status;
    _statusMessage = null;
    _mismatchMaster = mismatchMaster;

    if (status == FixedAssetScanStatus.alreadyAudited) {
      _auditedMachineCodes.add(machineCode.trim().toLowerCase());
    }

    if (location != null) {
      _autoLocation = location;
      _autoUnmappedActual = null;
      _autoLocationMismatch = mismatchMaster != null;
    }

    if (reloadMachines) {
      _machines = const <FixedAssetMachine>[];
      _machineError = null;
      if (!sameLocation) _clearMachineSearch();
    }
    _notify();

    if (reloadMachines) {
      // Chạy song song với dialog / POST audit, không chặn save.
      _loadMachines(
        location.fac,
        location.floor,
        location.positionA,
        location.positionAA,
      );
    }
  }

  void _markMismatchCancelled(int generation) {
    if (!_isCurrentScan(generation)) return;
    _scanStatus = FixedAssetScanStatus.locationMismatch;
    _statusMessage = _autoUnmappedActual != null
        ? 'Không có trong MAP - chưa lưu'
        : 'Sai vị trí - chưa lưu';
    _notify();
  }

  /// AUTO: vị trí đang quét không có trong MAP (known machine). Một notify:
  /// status cảnh báo, MASTER hiển thị, raw ACTUAL. Không có location đầy đủ
  /// nên không load machine list (clear list cũ để không gây hiểu nhầm).
  void _applyUnmappedActual(
    FixedAssetUnmappedActual raw,
    String faName,
    FixedAssetAuditLocation? masterDisplay,
  ) {
    _machineReq++;

    _scannedFaName = faName;
    _lastAuditedAt = null;
    _lastAuditedUserId = null;
    _lastAuditedUserName = null;
    _scanStatus = FixedAssetScanStatus.locationMismatch;
    _statusMessage = null;
    _mismatchMaster = masterDisplay;

    _autoLocation = null;
    _autoUnmappedActual = raw;
    _autoLocationMismatch = true;

    _machines = const <FixedAssetMachine>[];
    _loadingMachines = false;
    _machineError = null;
    _clearMachineSearch();
    _notify();
  }

  /// Hỏi UI xác nhận sai vị trí. Scan đã stale (trước hoặc sau dialog)
  /// -> false: kết quả dialog cũ không được save vào context mới.
  Future<bool> _confirmLocationMismatch(
    int generation,
    FixedAssetMismatchPrompt prompt,
  ) async {
    if (!_isCurrentScan(generation)) return false;

    final confirmed = await confirmMismatch(prompt);

    return confirmed && _isCurrentScan(generation);
  }

  // ------------------------------------------------------------
  // SAVE: đường duy nhất gọi POST /audit (AUTO + MANUAL)
  // ------------------------------------------------------------

  /// Request body không đổi; field location lấy từ [target] (nơi duy nhất
  /// dựng fac/floor/positionA/positionAA).
  Future<void> _saveAudit(
    String machineCode,
    FixedAssetSaveTarget target,
    int generation, {
    bool confirmLocationMismatch = false,
  }) async {
    final userId = accountCode.trim();
    final name = userName.trim();
    final saveUserName = name.isEmpty ? userId : name;

    if (_scanStatus != FixedAssetScanStatus.saving) {
      _scanStatus = FixedAssetScanStatus.saving;
      _statusMessage = null;
      _notify();
    }

    FixedAssetAuditSaveResponse? response;
    Object? saveError;

    try {
      response = await FixedAssetApi.saveAudit(
        fac: target.fac,
        floor: target.floor,
        positionA: target.positionA,
        positionAA: target.positionAA,
        machineCode: machineCode,
        userId: userId,
        userName: saveUserName,
        confirmLocationMismatch: confirmLocationMismatch,
      );
    } catch (error) {
      saveError = error;
    }

    if (_disposed) return;

    final result = response;
    final errorText = saveError == null ? '' : fixedAssetErrorText(saveError);

    // Tiến độ MASTER đổi khi có insert mới cho machine MASTER (kể cả
    // mismatch đã xác nhận). Vẫn refresh khi scan đã stale vì record đã
    // vào backend.
    if (isNewFixedAssetMasterAudit(result)) loadAuditSummary();

    // Location/mode đã đổi trong lúc save: không cập nhật status card /
    // audited set của màn hình hiện tại.
    if (!_isCurrentScan(generation)) return;

    // Backend phát hiện sai vị trí (chủ yếu MANUAL): hỏi rồi POST lại cùng
    // target với confirmLocationMismatch = true.
    if (result != null &&
        fixedAssetSaveNeedsConfirmation(
          result,
          confirmLocationMismatch: confirmLocationMismatch,
        )) {
      await _confirmFromSaveResponse(machineCode, target, result, generation);
      return;
    }

    _applySaveResult(machineCode, result, errorText);
  }

  /// Fallback: POST trả requiresConfirmation -> cùng dialog, rồi re-POST
  /// đúng [target] đã gửi với confirmLocationMismatch = true.
  Future<void> _confirmFromSaveResponse(
    String machineCode,
    FixedAssetSaveTarget target,
    FixedAssetAuditSaveResponse result,
    int generation,
  ) async {
    final master = fixedAssetMasterDisplay(
      result.masterFac,
      result.masterFloor,
      result.masterPositionA,
      result.masterPositionAA,
    );
    final actual =
        fixedAssetStrictLocation(
          result.actualFac,
          result.actualFloor,
          result.actualPositionA,
          result.actualPositionAA,
        ) ??
        target.location;
    // Không có location đầy đủ -> hiển thị raw Floor/PositionAA.
    final rawActual = actual != null
        ? null
        : (target.unmapped ??
              FixedAssetUnmappedActual(
                floor: result.actualFloor,
                positionAA: result.actualPositionAA,
              ));

    _scanStatus = FixedAssetScanStatus.locationMismatch;
    _statusMessage = null;
    _mismatchMaster = master;
    _notify();

    final confirmed = await _confirmLocationMismatch(
      generation,
      FixedAssetMismatchPrompt(
        machineCode: machineCode,
        faName: _scannedFaName,
        master: master,
        actual: actual,
        unmappedActual: rawActual,
      ),
    );

    if (!_isCurrentScan(generation)) return;

    if (!confirmed) {
      _markMismatchCancelled(generation);
      return;
    }

    await _saveAudit(
      machineCode,
      target,
      generation,
      confirmLocationMismatch: true,
    );
  }

  /// Kết quả POST -> status card + audited set (một notify).
  void _applySaveResult(
    String machineCode,
    FixedAssetAuditSaveResponse? result,
    String errorText,
  ) {
    if (result == null) {
      _scanStatus = FixedAssetScanStatus.failed;
      _statusMessage = 'Save failed: $errorText';
    } else if (result.alreadyAudited) {
      _scanStatus = FixedAssetScanStatus.alreadyAudited;
      _lastAuditedAt = result.lastAuditedAt;
      _lastAuditedUserId = result.lastAuditedUserId;
      _lastAuditedUserName = result.lastAuditedUserName;
      _auditedMachineCodes.add(machineCode.trim().toLowerCase());
    } else if (result.saved && result.unknownMachine) {
      // Hợp lệ về nghiệp vụ, không phải lỗi; không tính vào tiến độ.
      _scanStatus = FixedAssetScanStatus.unknownSaved;
    } else if (result.saved && result.locationMismatch) {
      _scanStatus = FixedAssetScanStatus.mismatchSaved;
      _auditedMachineCodes.add(machineCode.trim().toLowerCase());
    } else if (result.saved) {
      _scanStatus = FixedAssetScanStatus.saved;
      _auditedMachineCodes.add(machineCode.trim().toLowerCase());
    } else {
      _scanStatus = FixedAssetScanStatus.failed;
      _statusMessage = result.message.isNotEmpty
          ? result.message
          : 'Audit was not saved';
    }
    _notify();
  }

  // ============================================================
  // MODE SWITCH
  // ============================================================

  void setLocationMode(FixedAssetLocationMode mode) {
    if (mode == _locationMode) return;

    // Vô hiệu hóa lookup/cascade/machine request đang chạy, và không để
    // location của mode cũ bị dùng lại ở mode mới.
    manual.resetForModeSwitch();
    _machineReq++;

    _locationMode = mode;
    _autoLocation = null;
    _autoUnmappedActual = null;
    _autoLocationMismatch = false;

    _machines = const <FixedAssetMachine>[];
    _loadingMachines = false;
    _machineError = null;
    _clearMachineSearch();
    _clearScanState();
    _notify();

    // Lazy-load Fac lần đầu vào MANUAL, sau đó dùng lại cache.
    if (mode == FixedAssetLocationMode.manual && manual.needsFacs) {
      manual.loadFacs();
    }
  }

  // ============================================================
  // MANUAL CASCADE (điều phối machine list + scan state)
  // ============================================================

  /// Reset machine list + scan state khi lựa chọn manual đổi.
  void _resetForManualSelection() {
    _machineReq++;
    _machines = const <FixedAssetMachine>[];
    _loadingMachines = false;
    _machineError = null;
    _clearMachineSearch();
    _clearScanState();
    _notify();
  }

  void onFacChanged(String? value) {
    if (!manual.selectFac(value)) return;
    _resetForManualSelection();

    if (value != null) manual.loadFloors(value);
  }

  void onFloorChanged(String? value) {
    if (!manual.selectFloor(value)) return;
    _resetForManualSelection();

    final fac = manual.selectedFac;
    if (fac != null && value != null) manual.loadPositionA(fac, value);
  }

  void onPositionAChanged(String? value) {
    if (!manual.selectPositionA(value)) return;
    _resetForManualSelection();

    final fac = manual.selectedFac;
    final floor = manual.selectedFloor;
    if (fac != null && floor != null && value != null) {
      manual.loadPositionAA(fac, floor, value);
    }
  }

  void onPositionAAChanged(String? value) {
    if (!manual.selectPositionAA(value)) return;
    _resetForManualSelection();

    final fac = manual.selectedFac;
    final floor = manual.selectedFloor;
    final positionA = manual.selectedPositionA;
    if (fac != null && floor != null && positionA != null && value != null) {
      _loadMachines(fac, floor, positionA, value);
    }
  }

  // ============================================================
  // MACHINE LIST LOADING (AUTO + MANUAL)
  // ============================================================

  Future<void> _loadMachines(
    String fac,
    String floor,
    String positionA,
    String positionAA,
  ) async {
    final req = _machineReq;
    _loadingMachines = true;
    _machineError = null;
    _notify();

    try {
      final result = await FixedAssetApi.fetchMachines(
        fac: fac,
        floor: floor,
        positionA: positionA,
        positionAA: positionAA,
      );
      if (_disposed || req != _machineReq) return;
      _machines = result;
      _notify();
    } catch (error) {
      if (_disposed || req != _machineReq) return;
      _machines = const <FixedAssetMachine>[];
      _machineError = fixedAssetErrorText(error);
      _notify();
    } finally {
      if (!_disposed && req == _machineReq) {
        _loadingMachines = false;
        _notify();
      }
    }
  }
}
