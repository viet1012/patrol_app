import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';

import 'package:chuphinh/core/api/fixed_asset_backend.dart';
import 'package:chuphinh/core/models/fixed_asset_audit_check_response.dart';
import 'package:chuphinh/core/models/fixed_asset_audit_save_response.dart';
import 'package:chuphinh/core/models/fixed_asset_audit_summary.dart';
import 'package:chuphinh/core/models/fixed_asset_machine.dart';
import 'package:chuphinh/core/models/fixed_asset_pic.dart';
import 'package:chuphinh/core/models/fixed_asset_reprint_info.dart';
import 'package:chuphinh/core/models/fixed_asset_zone_progress.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_audit_flow.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_features.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_location.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_manual_cascade.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_pic_filter.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_qr_parser.dart';

/// State + điều phối nghiệp vụ của màn hình Fixed Asset (scan, audit, save,
/// machine list, summary; cascade MANUAL ở [FixedAssetManualCascade]).
///
/// Không giữ BuildContext. Những việc cần UI được đưa vào qua callback:
/// - [confirmMismatch]: dialog "Vẫn lưu / Hủy"
/// - [showError]: snackbar lỗi load dropdown
/// - [resetQr]: re-arm QR scanner của CameraPreviewBox
///
/// Chỉ có MANUAL: vị trí luôn lấy từ 4 dropdown; chưa chọn đủ thì không quét
/// ([canScan]), mọi POST /audit gửi mode "MANUAL".
class FixedAssetController extends ChangeNotifier {
  FixedAssetController({
    required this.accountCode,
    required this.userName,
    required this.confirmMismatch,
    this.confirmQrMismatch,
    this.confirmReprintMove,
    required this.showError,
    this.showNotice,
    required this.resetQr,
    this.onScanAccepted,
    this.api = const FixedAssetBackend(),
    this.masterMismatchDialogEnabled = FixedAssetFeatures.masterMismatchDialog,
  }) {
    manual = FixedAssetManualCascade(
      onChanged: _notify,
      onError: showError,
      isDisposed: () => _disposed,
      api: api,
    )..pic = _pic;
  }

  final String accountCode;
  final String userName;
  final FixedAssetConfirmMismatch confirmMismatch;

  /// MANUAL: dialog "QR không khớp vị trí đang chọn". null (không có UI)
  /// = đi tiếp như "Vẫn lưu" (vẫn đánh dấu qrLocationMismatch).
  final FixedAssetConfirmQrMismatch? confirmQrMismatch;

  /// Máy chờ in lại tem, vị trí khác vị trí thực tế đã ghi nhận: dialog
  /// "Xác nhận máy đã dời?". null (không có UI) = coi như "Hủy" (không dời).
  final FixedAssetConfirmReprintMove? confirmReprintMove;
  final ValueChanged<String> showError;

  /// Snackbar thông tin (vd. máy được ghi nhận ở vùng khác). null = bỏ qua.
  final ValueChanged<String>? showNotice;
  final VoidCallback resetQr;
  final void Function(String rawQr, String machineCode)? onScanAccepted;

  /// Endpoint Fixed Asset (thay được trong test).
  final FixedAssetBackend api;

  /// MANUAL hiện dialog "Sai vị trí máy" ([FixedAssetFeatures
  /// .masterMismatchDialog]; test ghi đè được). false: coi như "Vẫn lưu".
  final bool masterMismatchDialogEnabled;

  late final FixedAssetManualCascade manual;

  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    picFilter.dispose();
    _zoneRefreshTimer?.cancel();
    machineSearchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOCATION
  // ============================================================

  /// Location đang dùng (audit + machine list) = 4 dropdown; null khi chưa
  /// chọn đủ.
  FixedAssetAuditLocation? get activeLocation => manual.selectedLocation;

  /// Đã chọn đủ Fac / Floor / PositionA / PositionAA: camera được bật, QR
  /// được xử lý. Chưa đủ thì mọi QR bị bỏ qua ([processScannedQr]). Phải
  /// chọn PIC trước mới chọn được vị trí.
  bool get canScan => manual.selectedLocation != null;

  // ============================================================
  // PIC (lọc dropdown vị trí, machine list, zone-progress, audit-summary)
  // ============================================================

  /// Danh sách PIC + PIC chọn chung các màn trong phiên
  /// ([FixedAssetPicSession]).
  late final FixedAssetPicFilter picFilter = FixedAssetPicFilter(api: api)
    ..addListener(_onPicFilterChanged);

  /// PIC đã áp dụng cho dữ liệu màn này; null = chưa chọn PIC (kể cả
  /// "Tất cả PIC" nhớ từ màn khác): không tải vị trí / máy / tiến độ.
  String? _pic = FixedAssetPicSession.selected.value;
  String? get selectedPicEmail => _pic;
  bool get hasPic => _pic != null;

  List<FixedAssetPic> get pics => picFilter.pics;
  bool get loadingPics => picFilter.loading;

  /// Tên hiển thị của [email]: theo danh sách PIC, không có thì phần trước @.
  String picNameOf(String email) => picFilter.nameOf(email);

  /// Chưa chọn PIC mà danh sách đúng 1 người: tự chọn người đó.
  Future<void> loadPics({bool silent = false}) async {
    await picFilter.load(onError: showError, silent: silent);
    if (_disposed) return;
    final pick = fixedAssetAutoPick(pics, hasValue: _pic != null);
    if (pick != null) await onPicChanged(pick.email);
  }

  /// Danh sách tải xong (rebuild), hoặc PIC đổi ở màn khác (áp dụng).
  void _onPicFilterChanged() {
    final selected = picFilter.selectedEmail;
    if (selected != _pic) {
      onPicChanged(selected);
    } else {
      _notify();
    }
  }

  /// Đổi PIC: xoá 4 dropdown vị trí + search, rồi tải lại audit-summary và
  /// Fac theo PIC mới. null = chưa chọn PIC: dừng ở trạng thái trống.
  Future<void> onPicChanged(String? email) async {
    final value = (email?.trim().isEmpty ?? true) ? null : email!.trim();
    if (_disposed || value == _pic) return;
    _pic = value;
    picFilter.select(value);
    manual.pic = value;

    // Số liệu theo PIC cũ không dùng lại.
    _zoneProgressCache.clear();
    _staleZoneKeys.clear();
    // Request đang chạy (PIC cũ) không còn khớp số thứ tự -> bị bỏ.
    _zoneReqByKey.updateAll((_, req) => req + 1);
    _auditSummary = null;
    _auditSummaryError = null;
    _loadingAuditSummary = false;
    _summaryReq++;
    manual.clear();
    _resetForManualSelection();

    if (value == null) return;
    loadAuditSummary();
    await _loadManualFacs();
  }

  // ============================================================
  // SCAN STATE
  // ============================================================

  FixedAssetScanStatus _scanStatus = FixedAssetScanStatus.idle;
  FixedAssetScanStatus get scanStatus => _scanStatus;

  /// MachineCode đã extract từ QR gần nhất (không phải raw QR).
  String _scannedCode = '';
  String get scannedCode => _scannedCode;

  /// FAName của máy vừa quét (audit-check / tên trên QR).
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

  /// Pipeline (check -> confirm -> save) đang chạy (scan generation của nó):
  /// chặn scan mới tới khi xong.
  int? _activeScan;
  String? _processingRawQr;

  /// A mismatch dialog is open: other scans are ignored (not queued).
  bool _confirmOpen = false;
  String? _confirmCode;

  /// QR the user just dismissed in a MANUAL mismatch dialog: its repeat
  /// window is [_cancelRepeatWindow] instead of [_repeatScanWindow], so
  /// scanning it again (after it left the frame) asks again quickly.
  String? _shortRepeatQr;
  static const Duration _cancelRepeatWindow = Duration(milliseconds: 1200);

  /// Location [_machines] was loaded for (null while loading / on error /
  /// cleared): the MANUAL local check only trusts a list of this location.
  FixedAssetAuditLocation? _machinesLocation;

  /// [FA-UX] timing log (debug only): ms since the scan was received.
  final Stopwatch _uxClock = Stopwatch()..start();
  Duration _uxScanStart = Duration.zero;

  /// Debug timing log for the MANUAL scan UX (also used by the screen for
  /// camera / dialog events).
  void uxLog(String event) {
    if (!kDebugMode) return;
    final ms = (_uxClock.elapsed - _uxScanStart).inMilliseconds;
    debugPrint('[FA-UX] +${ms}ms $event');
  }

  /// Mode gửi kèm mọi POST /audit của màn này.
  static const String _auditMode = 'MANUAL';

  /// Vị trí in trên QR của từng pipeline (so với vị trí đang chọn), gửi kèm
  /// mọi POST /audit của pipeline đó (kể cả re-POST sau xác nhận).
  final Map<int, FixedAssetQrLocationCheck> _qrCheckByScan =
      <int, FixedAssetQrLocationCheck>{};

  /// reprintAct* / reprintQr* từ audit-check hoặc scan-info của từng
  /// pipeline: vị trí thực tế đang ghi nhận + tem hiện tại của máy chờ in lại.
  final Map<int, FixedAssetReprintInfo> _reprintByScan =
      <int, FixedAssetReprintInfo>{};

  /// Scan hiện tại đã lưu với qrLocationMismatch = true.
  bool _qrReprintSaved = false;

  /// Email PIC của máy vừa quét (audit-check / scan-info); null = chưa biết
  /// hoặc máy không có PIC.
  String? _scannedPic;

  /// Tên PIC của máy vừa quét khi khác PIC đang chọn ("Máy thuộc PIC …").
  /// null: "Tất cả PIC", máy không có PIC, hoặc cùng PIC.
  String? get scannedOtherPicName {
    final machinePic = _scannedPic;
    final pic = _pic;
    if (_scanStatus == FixedAssetScanStatus.idle ||
        machinePic == null ||
        pic == null ||
        FixedAssetPic.sameEmail(machinePic, pic)) {
      return null;
    }
    return picNameOf(machinePic);
  }

  /// Badge "Cần in lại QR" trên status card.
  bool get needsQrReprint =>
      _qrReprintSaved &&
      (_scanStatus == FixedAssetScanStatus.qrReprintSaved ||
          _scanStatus == FixedAssetScanStatus.qrLabelNotReplaced ||
          _scanStatus == FixedAssetScanStatus.qrReplacePending ||
          _scanStatus == FixedAssetScanStatus.unknownSaved);

  /// Vị trí thực tế + tem hiện tại hiển thị khi [needsQrReprint].
  FixedAssetReprintInfo? _reprintInfo;
  FixedAssetReprintInfo? get reprintInfo => needsQrReprint ? _reprintInfo : null;

  /// Máy đã thay QR (reprintSts): lúc thay (reprintAt), cho card xanh.
  DateTime? _qrReplacedAt;
  DateTime? get qrReplacedAt =>
      _scanStatus == FixedAssetScanStatus.qrReplaced ? _qrReplacedAt : null;

  bool get _pipelineBusy => _activeScan != null;

  /// QR camera nhìn thấy gần nhất + thời điểm. Cập nhật ở mỗi lần detect
  /// lặp, nên QR còn nằm trong khung camera luôn bị coi là "cũ".
  String? _lastSeenQr;
  DateTime? _lastSeenAt;

  /// Tăng khi: nhận scan mới, đổi location.
  /// Mọi bước async của pipeline kiểm tra lại token này trước khi
  /// đụng tới UI / gọi API tiếp theo.
  int _scanGeneration = 0;

  /// Cùng một QR được detect lại liên tục (vẫn nằm trong khung camera)
  /// sẽ bị bỏ qua cho tới khi vắng mặt quá khoảng này.
  static const Duration _repeatScanWindow = Duration(seconds: 3);

  bool _isCurrentScan(int generation) =>
      !_disposed && generation == _scanGeneration;

  /// Lý do đang tạm dừng quét (vd 'no_qr_sheet' khi form máy thiếu QR mở).
  /// Khác rỗng: mọi QR nhận được đều bị bỏ qua (không check / lưu).
  final Set<String> _qrScanPauseReasons = <String>{};
  bool get isQrScanPaused => _qrScanPauseReasons.isNotEmpty;

  void pauseQrScan(String reason) {
    if (_disposed) return;
    if (_qrScanPauseReasons.add(reason)) _scanLog('pause ($reason)');
  }

  void resumeQrScan(String reason) {
    if (_disposed) return;
    if (_qrScanPauseReasons.remove(reason)) _scanLog('resume ($reason)');
  }

  /// Log tạm cho luồng scan (chỉ debug).
  void _scanLog(String message) {
    if (!kDebugMode) return;
    debugPrint(
      '[FA-SCAN] $message | scanGen=$_scanGeneration '
      'busy=$_pipelineBusy lastSeen=$_lastSeenQr',
    );
  }

  // ============================================================
  // MACHINE LIST STATE
  // ============================================================

  List<FixedAssetMachine> _machines = const <FixedAssetMachine>[];
  List<FixedAssetMachine> get machines => _machines;
  int get machineCount => _machines.length;
  int get auditedMachineCount => _machines.where((machine) {
    final code = machine.machineCode.trim().toLowerCase();
    return code.isNotEmpty && _auditedMachineCodes.contains(code);
  }).length;

  bool _loadingMachines = false;
  bool get loadingMachines => _loadingMachines;

  String? _machineError;
  String? get machineError => _machineError;

  int _machineReq = 0;

  // Search cục bộ, không gọi API.
  final TextEditingController machineSearchController = TextEditingController();
  String _machineSearch = '';
  String get machineSearch => _machineSearch;

  /// MachineCode ĐÃ KIỂM KÊ TRONG KỲ HIỆN TẠI, lưu dạng trim().toLowerCase().
  ///
  /// Hai nguồn, chỉ thêm: bằng chứng trong session này (audit-check
  /// alreadyAudited, POST saved/alreadyAudited) và `auditedInPeriod` của
  /// GET /machines. KHÔNG dùng /audited-machine-codes vì endpoint đó là lịch
  /// sử trọn đời, không lọc theo kỳ 3 tháng. Không reset khi location/mode
  /// đổi; chỉ xóa khi kỳ kiểm kê đổi (period của audit-summary).
  final Set<String> _auditedMachineCodes = <String>{};
  Set<String> get auditedMachineCodes => _auditedMachineCodes;

  /// MachineCode có lần quét mới nhất QR lệch vị trí (đã kiểm kê, cần in lại
  /// QR), dạng trim().toLowerCase(). Nguồn: POST lưu với
  /// qrLocationMismatch / needsQrReprint và `needsQrReprint` của GET
  /// /machines. Rời tập khi lưu lại đúng vị trí. Là tập con của
  /// [_auditedMachineCodes].
  final Set<String> _qrReprintMachineCodes = <String>{};
  Set<String> get qrReprintMachineCodes => _qrReprintMachineCodes;

  /// Tăng mỗi khi hai tập trên đổi (có thể bớt phần tử, nên length không
  /// còn là version).
  int _auditedVersion = 0;
  int get auditedVersion => _auditedVersion;

  /// Lưu được tính kiểm kê: ✓, bỏ dấu in lại QR.
  void _markAudited(String machineCode) {
    final code = machineCode.trim().toLowerCase();
    if (code.isEmpty) return;
    final changed =
        _auditedMachineCodes.add(code) | _qrReprintMachineCodes.remove(code);
    if (changed) _auditedVersion++;
  }

  /// Lưu với QR lệch vị trí: vẫn tính kiểm kê, thêm dấu in lại QR.
  void _markQrReprint(String machineCode) {
    final code = machineCode.trim().toLowerCase();
    if (code.isEmpty) return;
    final changed =
        _qrReprintMachineCodes.add(code) | _auditedMachineCodes.add(code);
    if (changed) _auditedVersion++;
  }

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
    if (_disposed || _pic == null) return;
    final req = ++_summaryReq;
    _loadingAuditSummary = true;
    _auditSummaryError = null;
    _notify();

    try {
      final result = await api.fetchAuditSummary(pic: _pic);
      if (_disposed || req != _summaryReq) return;
      final previous = _auditSummary;
      final periodChanged =
          previous != null &&
          (previous.periodStart != result.periodStart ||
              previous.periodEnd != result.periodEnd);
      _auditSummary = result;
      _loadingAuditSummary = false;
      if (periodChanged) {
        _onAuditPeriodChanged();
      } else {
        _notify();
      }
    } catch (error) {
      if (_disposed || req != _summaryReq) return;
      _auditSummaryError = fixedAssetErrorText(error);
      _loadingAuditSummary = false;
      _notify();
    }
  }

  /// Kỳ kiểm kê đổi (ví dụ sang quý mới): bỏ dấu ✓ của kỳ cũ và tải lại
  /// machine list của location hiện tại (auditedInPeriod theo kỳ mới).
  void _onAuditPeriodChanged() {
    _auditedMachineCodes.clear();
    _qrReprintMachineCodes.clear();
    _auditedVersion++;
    final location = activeLocation;
    if (location == null) {
      _notify();
      return;
    }
    _machineReq++;
    _machines = const <FixedAssetMachine>[];
    _machinesLocation = null;
    _machineError = null;
    _loadMachines(
      location.fac,
      location.floor,
      location.positionA,
      location.positionAA,
    );
  }

  // ============================================================
  // ZONE PROGRESS (số máy đã kiểm kê / tổng theo vùng, theo kỳ)
  // ============================================================

  /// "fac|floor" -> mã vùng -> tiến độ. Cache trong phiên.
  final Map<String, Map<String, ZoneProgress>> _zoneProgressCache =
      <String, Map<String, ZoneProgress>>{};

  /// Key có dữ liệu có thể đã cũ (sau save): lần load kế tiếp gọi lại API.
  final Set<String> _staleZoneKeys = <String>{};

  /// Số thứ tự request theo key: kết quả không còn mới nhất thì bỏ.
  final Map<String, int> _zoneReqByKey = <String, int>{};

  /// Debounce reload sau save khi quét liên tục.
  Timer? _zoneRefreshTimer;
  static const Duration _zoneRefreshDelay = Duration(milliseconds: 800);

  static String _zoneKey(String fac, String floor) =>
      '${fac.trim()}|${floor.trim()}';

  void _zoneLog(String message) {
    if (kDebugMode) debugPrint('[FA-ZONE] $message');
  }

  Map<String, ZoneProgress>? zoneProgressFor(String fac, String floor) =>
      _zoneProgressCache[_zoneKey(fac, floor)];

  /// Tiến độ theo vùng của floor chứa [activeLocation]; null khi chưa có
  /// location hoặc chưa tải được.
  Map<String, ZoneProgress>? get zoneProgress {
    final location = activeLocation;
    if (location == null) return null;
    return zoneProgressFor(location.fac, location.floor);
  }

  /// Tiến độ của đúng vị trí đang dùng: vùng cha không con (PositionAA rỗng
  /// hoặc = PositionA) tra theo PositionA, còn lại theo PositionAA. Map đã
  /// tải nhưng vùng không có dòng nào -> [ZoneProgress.empty] (hiển thị 0).
  ZoneProgress? get activeZoneProgress {
    final location = activeLocation;
    final map = zoneProgress;
    if (location == null || map == null) return null;
    final positionA = location.positionA.trim();
    final positionAA = location.positionAA.trim();
    final key = positionAA.isEmpty || positionAA == positionA
        ? positionA
        : positionAA;
    return map[key] ?? ZoneProgress.empty;
  }

  /// [checkMachines]: after a successful load, if the active zone reports
  /// more audited machines than the list shows ✓ (audited elsewhere, e.g.
  /// another device), refresh the list silently — at most once per load.
  Future<void> loadZoneProgress(
    String fac,
    String floor, {
    bool force = false,
    bool checkMachines = true,
  }) async {
    if (_disposed) return;
    final f = fac.trim();
    final fl = floor.trim();
    if (f.isEmpty || fl.isEmpty) return;

    final key = _zoneKey(f, fl);
    if (!force &&
        _zoneProgressCache.containsKey(key) &&
        !_staleZoneKeys.contains(key)) {
      return;
    }

    final req = (_zoneReqByKey[key] ?? 0) + 1;
    _zoneReqByKey[key] = req;

    try {
      final rows = await api.fetchZoneProgress(
        fac: f,
        floor: fl,
        pic: _pic,
      );
      if (_disposed || _zoneReqByKey[key] != req) return;
      _zoneProgressCache[key] = buildZoneProgressMap(rows);
      _staleZoneKeys.remove(key);
      _zoneLog('loaded $key: ${rows.length} rows');
      _notify();
      if (checkMachines) _refreshMachinesIfBehind(key);
    } catch (error) {
      if (_disposed || _zoneReqByKey[key] != req) return;
      // Giữ dữ liệu cũ (nếu có); không báo lỗi cho người dùng.
      _zoneLog('load $key failed: ${fixedAssetErrorText(error)}');
    }
  }

  /// Force tải lại (fac, floor) của [activeLocation], kèm machine list
  /// (tải ngầm): app resume, mở dialog map, sau save (debounce).
  Future<void> refreshZoneProgress() async {
    if (_disposed) return;
    final location = activeLocation;
    if (location == null) return;
    _refreshMachinesSilently();
    // The list is already being refreshed: no extra mismatch refresh.
    await loadZoneProgress(
      location.fac,
      location.floor,
      force: true,
      checkMachines: false,
    );
  }

  /// Machines of the active list that currently show ✓.
  int get _checkedMachineCount => _machines.where((machine) {
    final code = machine.machineCode.trim().toLowerCase();
    return code.isNotEmpty && _auditedMachineCodes.contains(code);
  }).length;

  /// Zone-progress [key] just loaded: if it belongs to the active location
  /// and reports more audited machines than the list shows ✓, reload the
  /// list silently once. No loop: a silent refresh never reloads zones.
  void _refreshMachinesIfBehind(String key) {
    final location = activeLocation;
    if (location == null || _zoneKey(location.fac, location.floor) != key) {
      return;
    }
    final audited = activeZoneProgress?.audited ?? 0;
    final checked = _checkedMachineCount;
    if (audited <= checked) return;
    _zoneLog('zone audited $audited > list ✓ $checked: refresh machines');
    _refreshMachinesSilently();
  }

  /// Sau save: máy được đếm theo vị trí hiệu lực (có thể ở floor khác), nên
  /// đánh dấu cũ mọi key đã cache; sau debounce reload floor hiện tại +
  /// machine list, dropdown vị trí và danh sách PIC (zoneCount).
  void _scheduleZoneProgressRefresh() {
    _staleZoneKeys.addAll(_zoneProgressCache.keys);
    _zoneRefreshTimer?.cancel();
    _zoneRefreshTimer = Timer(_zoneRefreshDelay, () {
      if (_disposed) return;
      refreshZoneProgress();
      _refreshLocationOptions();
      loadPics(silent: true);
    });
  }

  /// Tải lại 4 danh sách dropdown theo PIC hiện tại: cấp đang chọn còn trong
  /// danh sách mới thì giữ, không còn thì xoá cấp đó (và các cấp sau). Tải
  /// ngầm: không hiện loading, giữ danh sách cũ tới khi có danh sách mới.
  Future<void> _refreshLocationOptions() async {
    final pic = _pic;
    if (pic == null) return;
    final fac = manual.selectedFac;
    final floor = manual.selectedFloor;
    final positionA = manual.selectedPositionA;
    final positionAA = manual.selectedPositionAA;
    bool stale() =>
        _disposed ||
        pic != _pic ||
        manual.selectedFac != fac ||
        manual.selectedFloor != floor ||
        manual.selectedPositionA != positionA ||
        manual.selectedPositionAA != positionAA;

    final facs = await manual.loadFacs(silent: true);
    if (stale() || facs == null || fac == null) return;
    if (!facs.contains(fac)) {
      await onFacChanged(null);
      return;
    }

    final floors = await manual.loadFloors(fac, silent: true);
    if (stale() || floors == null || floor == null) return;
    if (!floors.contains(floor)) {
      await onFloorChanged(null);
      return;
    }

    final positionAs = await manual.loadPositionA(fac, floor, silent: true);
    if (stale() || positionAs == null || positionA == null) return;
    if (!positionAs.contains(positionA)) {
      await onPositionAChanged(null);
      return;
    }

    final positionAAs = await manual.loadPositionAA(
      fac,
      floor,
      positionA,
      silent: true,
    );
    if (stale() || positionAAs == null || positionAA == null) return;
    if (!positionAAs.contains(positionAA)) {
      await onPositionAAChanged(null);
    }
  }

  // ============================================================
  // SCAN PIPELINE
  // ============================================================

  /// Gọi trong lúc mutate state khi location đổi.
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
    _qrReprintSaved = false;
    _reprintInfo = null;
    _scannedPic = null;
    if (_lastSeenQr != null) _lastSeenAt = DateTime.now();
    _scanChipText = null;
    resetQr();
  }

  // ============================================================
  // SCAN FEEDBACK: camera chip + dropdown còn trống
  // ============================================================

  /// Parsed text of the last received scan ("{code} · {floor}/{AA}") for
  /// the chip over the camera; null = hidden (location change).
  String? _scanChipText;
  String? get scanChipText => _scanChipText;

  /// Bumped on every received scan (also ignored repeats): the chip shows /
  /// flashes again, so no scan goes without visible feedback.
  int _scanChipTick = 0;
  int get scanChipTick => _scanChipTick;

  /// The chip may fade out: the scan has a final result (not processing,
  /// no dialog open).
  bool get isScanSettled =>
      _scanStatus != FixedAssetScanStatus.checking &&
      _scanStatus != FixedAssetScanStatus.saving &&
      !_confirmOpen;

  static String scanChipLabel(String rawQr) {
    final data = parseFixedAssetQr(rawQr);
    final code = data.machineCode.isNotEmpty ? data.machineCode : rawQr.trim();
    return data.hasLocation ? '$code · ${data.floor}/${data.positionAA}' : code;
  }

  void _setScanChip(String rawQr) {
    _scanChipText = scanChipLabel(rawQr);
    _scanChipTick++;
    _notify();
  }

  void _flashScanChip() {
    if (_scanChipText == null) return;
    _scanChipTick++;
    _notify();
  }

  /// Dropdown còn trống đầu tiên (Fac → Floor → PositionA → PositionAA),
  /// được làm nổi bật khi chưa đủ vị trí; null = đã chọn đủ ([canScan])
  /// hoặc chưa chọn PIC (dropdown bị khoá).
  FixedAssetManualField? get firstMissingManualField {
    if (_pic == null) return null;
    if (manual.selectedFac == null) return FixedAssetManualField.fac;
    if (manual.selectedFloor == null) return FixedAssetManualField.floor;
    if (manual.selectedPositionA == null) {
      return FixedAssetManualField.positionA;
    }
    if (manual.selectedPositionAA == null) {
      return FixedAssetManualField.positionAA;
    }
    return null;
  }

  void _failScan(int generation, String message) {
    if (!_isCurrentScan(generation)) return;
    _scanStatus = FixedAssetScanStatus.failed;
    _statusMessage = message;
    _notify();
  }

  Future<void> processScannedQr(String rawQr) async {
    final qr = rawQr.trim();
    _scanLog('received "$qr"');
    if (qr.isEmpty || _disposed) {
      _scanLog('skip: empty or disposed');
      return;
    }

    // Chốt chặn chung (camera + nhập tay): chưa chọn đủ 4 ô vị trí thì bỏ
    // qua, không audit-check / save / scan-info.
    if (!canScan) {
      _scanLog('skip: location not selected');
      return;
    }

    if (isQrScanPaused) {
      _scanLog('skip: paused (${_qrScanPauseReasons.join(', ')})');
      return;
    }

    final now = DateTime.now();

    // A confirmation dialog is open: ignore other scans (no queue) and the
    // camera's repeated detections of the same code (the chip still
    // flashes: the scan was received).
    if (_confirmOpen) {
      uxLog('skip "$qr": waiting confirmation of $_confirmCode');
      _flashScanChip();
      return;
    }

    if (_pipelineBusy) {
      // Giữ QR đang xử lý ở trạng thái "cũ" để không xử lý lại sau khi xong.
      // QR khác không được ghi nhận, để lần detect sau vẫn là scan mới.
      if (qr == _processingRawQr) {
        _lastSeenQr = qr;
        _lastSeenAt = now;
      }
      _scanLog('skip: pipeline busy (processing "$_processingRawQr")');
      _flashScanChip();
      return;
    }

    // Chặn detect lặp của cùng một QR đang nằm trong khung camera.
    // Mỗi lần detect lặp sẽ gia hạn cửa sổ, nên chỉ khi QR rời khung
    // quá _repeatScanWindow mới được scan lại (không blacklist vĩnh viễn).
    final lastAt = _lastSeenAt;
    final repeatWindow = qr == _shortRepeatQr
        ? _cancelRepeatWindow
        : _repeatScanWindow;
    final isRepeat =
        qr == _lastSeenQr &&
        lastAt != null &&
        now.difference(lastAt) < repeatWindow;

    _lastSeenQr = qr;
    _lastSeenAt = now;

    if (isRepeat) {
      _scanLog('skip: repeat within ${_repeatScanWindow.inSeconds}s');
      // Status kept; the chip flashes so the user sees it was received.
      _setScanChip(qr);
      return;
    }

    final generation = ++_scanGeneration;
    _shortRepeatQr = null;
    _uxScanStart = _uxClock.elapsed;
    uxLog('received "$qr" #$generation');
    _setScanChip(qr);
    final qrData = parseFixedAssetQr(qr);
    final machineCode = qrData.machineCode;

    final String? invalidMessage = machineCode.isEmpty
        ? 'Invalid machine QR'
        : null;

    if (invalidMessage != null) {
      _scanLog('skip: invalid ($invalidMessage)');
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
    _activeScan = generation;
    _processingRawQr = qr;
    _scanLog('start pipeline #$generation for $machineCode');

    _scannedCode = machineCode;
    _scannedFaName = qrData.displayName;
    _statusMessage = null;
    _lastAuditedAt = null;
    _lastAuditedUserId = null;
    _lastAuditedUserName = null;
    _mismatchMaster = null;
    _qrReprintSaved = false;
    _reprintInfo = null;
    _scannedPic = null;
    // Immediate feedback.
    _scanStatus = FixedAssetScanStatus.checking;
    _statusMessage = 'Đang kiểm tra $machineCode…';
    _notify();
    uxLog('accepted (start pipeline) $machineCode');

    try {
      await _runManualScan(machineCode, generation, rawQr: qr);
    } finally {
      // Chỉ pipeline này tự trả cờ.
      _qrCheckByScan.remove(generation);
      _reprintByScan.remove(generation);
      if (_activeScan == generation) {
        _activeScan = null;
        _processingRawQr = null;
      }
      _scanLog(
        'end pipeline #$generation (current=${_isCurrentScan(generation)})',
      );

      if (_isCurrentScan(generation)) {
        // Cửa sổ chống lặp tính từ lúc pipeline xong.
        _lastSeenQr = qr;
        _lastSeenAt = DateTime.now();
        resetQr();
      }
    }
  }

  void _notifyScanAccepted(String rawQr, String machineCode) {
    try {
      onScanAccepted?.call(rawQr, machineCode);
    } catch (_) {
      // Visual feedback must never interrupt the audit/save pipeline.
    }
  }

  Future<void> _runManualScan(
    String machineCode,
    int generation, {
    required String rawQr,
  }) async {
    final location = manual.selectedLocation;
    if (location == null) {
      // Normally blocked before the pipeline ([canScan]).
      _failScan(generation, 'Chưa chọn vị trí');
      return;
    }

    _notifyScanAccepted(rawQr, machineCode);

    // Vị trí in trên QR phải trùng vị trí đang chọn (trước bước MASTER).
    // Lệch: hỏi; "Vẫn lưu" thì đi tiếp và mọi POST mang qrLocationMismatch.
    // qr* luôn được gửi (kể cả khi khớp).
    final qrData = parseFixedAssetQr(rawQr);
    final qrCheck = fixedAssetManualQrCheck(qrData, location);
    _qrCheckByScan[generation] = qrCheck;

    // audit-check trước: máy needsQrReprint đi luồng in lại QR (QR cũ /
    // gỡ cờ / máy đã dời), không qua dialog QR lệch / sai vị trí / list.
    FixedAssetAuditCheckResponse? check;
    try {
      check = await api.checkAudit(
        machineCode: machineCode,
        floor: location.floor,
        positionAA: location.positionAA,
      );
    } catch (error) {
      uxLog('audit-check failed: ${fixedAssetErrorText(error)}');
    }
    if (!_isCurrentScan(generation)) {
      _reportDropped(machineCode, 'đã đổi khu vực');
      return;
    }
    if (check != null && check.pic != null) {
      _scannedPic = check.pic;
      _notify();
    }

    if (check != null && check.needsQrReprint) {
      if (check.faName.isNotEmpty) _scannedFaName = check.faName;
      await _runReprintRescan(
        machineCode: machineCode,
        generation: generation,
        qrData: qrData,
        check: check,
        target: FixedAssetSaveTarget.mapped(location),
      );
      return;
    }

    // audit-check lỗi mà FE đã biết máy chờ in lại: POST thẳng, backend
    // quyết định (QR cũ / gỡ cờ / hỏi máy đã dời).
    if (check == null &&
        _qrReprintMachineCodes.contains(machineCode.trim().toLowerCase())) {
      uxLog('reprint rescan (no audit-check): POST directly');
      await _saveAudit(
        machineCode,
        FixedAssetSaveTarget.mapped(location),
        generation,
      );
      return;
    }

    if (qrCheck.mismatch) {
      uxLog('QR location ${qrCheck.floor}/${qrCheck.positionAA} != selected');
      final confirmed = await _confirmQrLocationMismatch(
        generation,
        FixedAssetQrMismatchPrompt(
          machineCode: machineCode,
          faName: _scannedFaName,
          selected: location,
          qr: qrCheck,
        ),
      );
      if (!_isCurrentScan(generation)) {
        _reportDropped(machineCode, 'đã đổi khu vực');
        return;
      }
      if (!confirmed) {
        _markMismatchCancelled(generation, qrLocation: true);
        _shortRepeatQr = _processingRawQr;
        return;
      }
    }

    // Local check first when the selected location's list is loaded: a
    // machine that is not in it is asked about right away (no POST first).
    // List lọc theo PIC chỉ chứa máy của PIC đó: máy PIC khác / chưa biết
    // PIC không bị coi là sai vị trí, để server kiểm tra (lưu bình thường).
    final listCoversMachine =
        _pic == null || FixedAssetPic.sameEmail(_scannedPic, _pic);
    if (_machinesReadyFor(location) && listCoversMachine) {
      final code = machineCode.trim().toLowerCase();
      final inList = _machines.any(
        (machine) => machine.machineCode.trim().toLowerCase() == code,
      );
      uxLog('local check: ${inList ? 'in list' : 'NOT in list'}');
      if (!inList) {
        await _confirmManualLocalMismatch(machineCode, location, generation);
        return;
      }
    } else {
      uxLog('local check skipped: list not ready / other PIC (server check)');
    }

    await _saveAudit(
      machineCode,
      FixedAssetSaveTarget.mapped(location),
      generation,
    );
  }

  bool _machinesReadyFor(FixedAssetAuditLocation location) =>
      !_loadingMachines &&
      _machineError == null &&
      _machinesLocation == location;

  /// MANUAL: machine not in the selected location's list. The dialog opens
  /// at once; MASTER is looked up in parallel and filled in when it
  /// arrives. "Vẫn lưu" -> one POST with confirmLocationMismatch = true.
  Future<void> _confirmManualLocalMismatch(
    String machineCode,
    FixedAssetAuditLocation location,
    int generation,
  ) async {
    final master = ValueNotifier<FixedAssetAuditLocation?>(null);
    _scanStatus = FixedAssetScanStatus.locationMismatch;
    _mismatchMaster = null;
    _notify();

    uxLog('scan-info lookup start');
    api
        .fetchScanInfo(machineCode)
        .then((info) {
          uxLog('scan-info done (existsInMaster=${info.existsInMaster})');
          if (info.pic != null && _isCurrentScan(generation)) {
            _scannedPic ??= info.pic;
            _notify();
          }
          if (!info.hasFullLocation) return;
          final value = FixedAssetAuditLocation(
            fac: info.fac,
            floor: info.floor,
            positionA: info.positionA,
            positionAA: info.positionAA,
          );
          master.value = value;
          if (_isCurrentScan(generation)) {
            _mismatchMaster = value;
            _notify();
          }
        })
        .catchError((Object error) {
          uxLog('scan-info failed: ${fixedAssetErrorText(error)}');
        });

    // Dialog MASTER tắt: như "Vẫn lưu" (MASTER vẫn tra để hiện trên card).
    final confirmed = masterMismatchDialogEnabled
        ? await _confirmLocationMismatch(
            generation,
            FixedAssetMismatchPrompt(
              machineCode: machineCode,
              faName: _scannedFaName,
              master: null,
              actual: location,
              masterUpdates: master,
              manual: true,
            ),
          )
        : _isCurrentScan(generation);
    if (!masterMismatchDialogEnabled) uxLog('master dialog off: auto SAVE');

    if (!_isCurrentScan(generation)) {
      _reportDropped(machineCode, 'đã đổi khu vực');
      return;
    }
    if (!confirmed) {
      _markMismatchCancelled(generation);
      _shortRepeatQr = _processingRawQr;
      return;
    }
    await _saveAudit(
      machineCode,
      FixedAssetSaveTarget.mapped(location),
      generation,
      confirmLocationMismatch: true,
    );
  }

  /// A scan dropped because location/mode changed meanwhile: never silent.
  /// Shown only if nothing newer is on the status card.
  void _reportDropped(String machineCode, String reason) {
    uxLog('dropped $machineCode: $reason');
    if (_disposed || _scanStatus != FixedAssetScanStatus.idle) return;
    _scannedCode = machineCode;
    _scannedFaName = '';
    _mismatchMaster = null;
    _scanStatus = FixedAssetScanStatus.failed;
    _statusMessage = 'Đã bỏ qua $machineCode: $reason';
    _notify();
  }

  void _markMismatchCancelled(int generation, {bool qrLocation = false}) {
    if (!_isCurrentScan(generation)) return;
    if (qrLocation) {
      _scanStatus = FixedAssetScanStatus.qrLocationMismatch;
      _statusMessage = 'QR khác vị trí đang chọn - chưa lưu';
    } else {
      _scanStatus = FixedAssetScanStatus.locationMismatch;
      _statusMessage = 'Sai vị trí - chưa lưu';
    }
    _notify();
  }

  /// Hỏi UI xác nhận sai vị trí. Scan đã stale (trước hoặc sau dialog)
  /// -> false: kết quả dialog cũ không được save vào context mới.
  Future<bool> _confirmLocationMismatch(
    int generation,
    FixedAssetMismatchPrompt prompt,
  ) {
    return _runConfirm(
      generation,
      prompt.machineCode,
      manual: prompt.manual,
      show: () => confirmMismatch(prompt),
    );
  }

  /// MANUAL: dialog "QR không khớp vị trí đang chọn" (cùng cơ chế chặn scan
  /// như dialog sai vị trí). Không có UI -> coi như "Vẫn lưu".
  Future<bool> _confirmQrLocationMismatch(
    int generation,
    FixedAssetQrMismatchPrompt prompt,
  ) {
    final show = confirmQrMismatch;
    if (show == null) return Future.value(_isCurrentScan(generation));
    _scanStatus = FixedAssetScanStatus.qrLocationMismatch;
    _notify();
    return _runConfirm(
      generation,
      prompt.machineCode,
      manual: true,
      show: () => show(prompt),
    );
  }

  Future<bool> _runConfirm(
    int generation,
    String machineCode, {
    required bool manual,
    required Future<bool> Function() show,
  }) async {
    if (!_isCurrentScan(generation)) return false;
    // Only one dialog at a time (a pipeline of the previous mode may still
    // be waiting on one).
    if (_confirmOpen) return false;

    _confirmOpen = true;
    _confirmCode = machineCode;
    if (manual) {
      _statusMessage = 'Xác nhận máy $machineCode trước';
      _notify();
    }
    uxLog('confirmMismatch called');
    bool confirmed;
    try {
      confirmed = await show();
    } finally {
      _confirmOpen = false;
      _confirmCode = null;
    }
    uxLog('user chose ${confirmed ? 'SAVE' : 'SKIP'}');

    return confirmed && _isCurrentScan(generation);
  }

  // ------------------------------------------------------------
  // SAVE: đường duy nhất gọi POST /audit
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
    final qrCheck = _qrCheckByScan[generation];

    if (_scanStatus != FixedAssetScanStatus.saving) {
      _scanStatus = FixedAssetScanStatus.saving;
      _statusMessage = null;
      _notify();
    }

    FixedAssetAuditSaveResponse? response;
    Object? saveError;

    uxLog('POST /audit start (confirm=$confirmLocationMismatch)');
    final postStart = _uxClock.elapsed;
    _scanLog(
      'saveAudit → $machineCode #$generation '
      '(confirm=$confirmLocationMismatch)',
    );
    try {
      response = await api.saveAudit(
        fac: target.fac,
        floor: target.floor,
        positionA: target.positionA,
        positionAA: target.positionAA,
        machineCode: machineCode,
        userId: userId,
        userName: saveUserName,
        confirmLocationMismatch: confirmLocationMismatch,
        mode: _auditMode,
        qrFloor: qrCheck?.floor,
        qrPositionA: qrCheck?.positionA,
        qrPositionAA: qrCheck?.positionAA,
        qrLocationMismatch: qrCheck?.mismatch,
      );
    } catch (error) {
      saveError = error;
    }

    if (_disposed) return;

    final result = response;
    final errorText = saveError == null ? '' : fixedAssetErrorText(saveError);
    uxLog(
      'POST /audit end in ${(_uxClock.elapsed - postStart).inMilliseconds}ms '
      '(saved=${result?.saved} requiresConfirmation=${result?.requiresConfirmation})',
    );
    _scanLog(
      'saveAudit #$generation → '
      '${result == null ? 'error: $errorText' : 'saved=${result.saved} '
                'alreadyAudited=${result.alreadyAudited}'}',
    );

    // Tiến độ MASTER đổi khi có insert mới cho machine MASTER (kể cả
    // mismatch đã xác nhận). Vẫn refresh khi scan đã stale vì record đã
    // vào backend.
    if (isNewFixedAssetMasterAudit(result)) loadAuditSummary();
    // Máy đang chờ in lại tem (FE biết qua list / audit-check / scan-info).
    final wasFlagged =
        _reprintByScan.containsKey(generation) ||
        _qrReprintMachineCodes.contains(machineCode.trim().toLowerCase());
    // Bản ghi in lại QR được gỡ cờ (alreadyAudited, hết needsQrReprint) hoặc
    // dời sang vị trí mới sau xác nhận: progress / list theo vị trí đổi.
    final reprintCleared =
        result != null &&
        result.alreadyAudited &&
        !result.needsQrReprint &&
        wasFlagged;
    final reprintMoved =
        result != null &&
        confirmLocationMismatch &&
        fixedAssetSaveIsReprintMove(result);
    if (result != null && (result.saved || reprintCleared || reprintMoved)) {
      // Zone progress reload (800 ms debounce).
      _scheduleZoneProgressRefresh();
    }

    // Location/mode đã đổi trong lúc save: không cập nhật status card /
    // audited set của màn hình hiện tại (nhưng báo lý do, không im lặng).
    if (!_isCurrentScan(generation)) {
      _reportDropped(machineCode, 'đã đổi khu vực trong lúc lưu');
      return;
    }
    if (result != null &&
        fixedAssetSaveNeedsConfirmation(
          result,
          confirmLocationMismatch: confirmLocationMismatch,
        )) {
      uxLog('response requiresConfirmation');
    }

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

    if (result != null && (result.saved || reprintMoved)) {
      _noticeIfRecordedElsewhere(machineCode, result);
    }

    _applySaveResult(
      machineCode,
      result,
      errorText,
      qrLocationMismatch: qrCheck?.mismatch ?? false,
      wasFlagged: wasFlagged,
    );
  }

  /// Máy vừa lưu có vị trí actual khác vùng đang chọn: báo nơi đã ghi nhận.
  void _noticeIfRecordedElsewhere(
    String machineCode,
    FixedAssetAuditSaveResponse result,
  ) {
    final notice = showNotice;
    if (notice == null) return;
    final actual = fixedAssetStrictLocation(
      result.actualFac.trim(),
      result.actualFloor.trim(),
      result.actualPositionA.trim(),
      result.actualPositionAA.trim(),
    );
    if (actual == null || actual == activeLocation) return;
    final label = fixedAssetLocationLabel(
      actual.fac,
      actual.floor,
      actual.positionA,
      actual.positionAA,
    );
    notice('Đã ghi nhận $machineCode tại $label');
  }

  /// act* = actual* của response (*_Act của dòng); qr* = reprintQr* của
  /// response (không có = dòng NO_QR, chưa có tem).
  static FixedAssetReprintInfo _reprintFromResponse(
    FixedAssetAuditSaveResponse result,
  ) {
    String? opt(String v) => v.trim().isEmpty ? null : v.trim();
    return (result.reprint ?? const FixedAssetReprintInfo())
        .withAct(
          fac: opt(result.actualFac),
          floor: opt(result.actualFloor),
          positionA: opt(result.actualPositionA),
          positionAA: opt(result.actualPositionAA),
        );
  }

  /// Fallback: POST trả requiresConfirmation -> cùng dialog, rồi re-POST
  /// đúng [target] đã gửi với confirmLocationMismatch = true.
  Future<void> _confirmFromSaveResponse(
    String machineCode,
    FixedAssetSaveTarget target,
    FixedAssetAuditSaveResponse result,
    int generation,
  ) async {
    if (fixedAssetSaveIsReprintMove(result)) {
      await _confirmReprintMove(
        machineCode,
        target,
        generation,
        result: result,
      );
      return;
    }

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
                fac: result.actualFac.isNotEmpty ? result.actualFac : null,
                floor: result.actualFloor,
                positionAA: result.actualPositionAA,
              ));

    _scanStatus = FixedAssetScanStatus.locationMismatch;
    _statusMessage = null;
    _mismatchMaster = master;
    _notify();

    // Dialog MASTER tắt: như "Vẫn lưu".
    final skipDialog = !masterMismatchDialogEnabled;
    if (skipDialog) uxLog('master dialog off: auto SAVE');
    final confirmed = skipDialog
        ? _isCurrentScan(generation)
        : await _confirmLocationMismatch(
            generation,
            FixedAssetMismatchPrompt(
              machineCode: machineCode,
              faName: _scannedFaName,
              master: master,
              actual: actual,
              unmappedActual: rawActual,
              manual: true,
            ),
          );

    if (!_isCurrentScan(generation)) {
      _reportDropped(machineCode, 'đã đổi khu vực');
      return;
    }

    if (!confirmed) {
      _markMismatchCancelled(generation);
      _shortRepeatQr = _processingRawQr;
      return;
    }

    await _saveAudit(
      machineCode,
      target,
      generation,
      confirmLocationMismatch: true,
    );
  }

  /// Máy needsQrReprint (audit-check), không qua dialog QR
  /// lệch / sai vị trí:
  /// - QR = reprintQr*: card "QR chưa được thay" (thay QR ở tab "3) Thay
  ///   QR"), không gọi save;
  /// - QR = reprintAct* và vị trí chọn = reprintAct*: save (gỡ cờ);
  /// - còn lại: dialog "Máy đã dời?" rồi save với confirmLocationMismatch.
  Future<void> _runReprintRescan({
    required String machineCode,
    required int generation,
    required FixedAssetQrData qrData,
    required FixedAssetAuditCheckResponse check,
    required FixedAssetSaveTarget target,
  }) async {
    final reprint = check.reprint;
    if (reprint != null) _reprintByScan[generation] = reprint;

    final decision = classifyFixedAssetReprintRescan(
      qrData,
      reprint,
      selectedFac: target.fac,
      selectedFloor: target.floor,
      selectedPositionA: target.positionA,
      selectedPositionAA: target.positionAA,
    );
    uxLog('reprint rescan: ${decision.name}');

    switch (decision) {
      case FixedAssetReprintRescan.oldLabel:
        _qrReprintSaved = true;
        _reprintInfo = reprint;
        _scanStatus = FixedAssetScanStatus.qrLabelNotReplaced;
        _statusMessage = null;
        _mismatchMaster = null;
        _lastAuditedAt = check.lastAuditedAt;
        _lastAuditedUserId = check.lastAuditedUserId;
        _lastAuditedUserName = check.lastAuditedUserName;
        _markQrReprint(machineCode);
        _notify();
      case FixedAssetReprintRescan.save:
        await _saveAudit(machineCode, target, generation);
      case FixedAssetReprintRescan.moved:
        await _confirmReprintMove(machineCode, target, generation);
    }
  }

  /// Máy chờ in lại QR, QR / vị trí chọn khác vị trí thực tế đã ghi nhận:
  /// hỏi "máy đã dời?" -> POST [target] với confirmLocationMismatch = true
  /// (backend ghi đè *_Act / *_Qr). Gọi trước POST (từ audit-check, [result]
  /// null) hoặc khi POST trả requiresConfirmation.
  Future<void> _confirmReprintMove(
    String machineCode,
    FixedAssetSaveTarget target,
    int generation, {
    FixedAssetAuditSaveResponse? result,
  }) async {
    _scanStatus = FixedAssetScanStatus.locationMismatch;
    _statusMessage = null;
    _mismatchMaster = null;
    _notify();

    // Response này không có reprintAct*: lấy từ audit-check, thiếu thì
    // scan-info.
    var recorded = _reprintByScan[generation];
    if (recorded == null || !recorded.hasAct) {
      try {
        final info = await api.fetchScanInfo(machineCode);
        if (info.needsQrReprint) recorded = info.reprint ?? recorded;
      } catch (error) {
        uxLog('scan-info failed: ${fixedAssetErrorText(error)}');
      }
      if (!_isCurrentScan(generation)) {
        _reportDropped(machineCode, 'đã đổi khu vực');
        return;
      }
      if (recorded != null) _reprintByScan[generation] = recorded;
    }

    // actual* của response = vị trí đang chọn (Fac / A backend điền từ MAP).
    String pick(String? fromResponse, String? fromTarget) =>
        (fromResponse ?? '').isNotEmpty ? fromResponse! : (fromTarget ?? '');
    final prompt = FixedAssetReprintMovePrompt(
      machineCode: machineCode,
      faName: _scannedFaName,
      recordedLabel: recorded != null && recorded.hasAct
          ? recorded.actLabel
          : null,
      selectedLabel: fixedAssetLocationLabel(
        pick(result?.actualFac, target.fac),
        pick(result?.actualFloor, target.floor),
        pick(result?.actualPositionA, target.positionA),
        pick(result?.actualPositionAA, target.positionAA),
      ),
    );

    final show = confirmReprintMove;
    final confirmed = show != null &&
        await _runConfirm(
          generation,
          machineCode,
          manual: true,
          show: () => show(prompt),
        );

    if (!_isCurrentScan(generation)) {
      _reportDropped(machineCode, 'đã đổi khu vực');
      return;
    }
    if (!confirmed) {
      _scanStatus = FixedAssetScanStatus.locationMismatch;
      _statusMessage = 'Chưa xác nhận máy đã dời - chưa lưu';
      _notify();
      _shortRepeatQr = _processingRawQr;
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
  ///
  /// [wasFlagged] = máy đang chờ in lại.
  void _applySaveResult(
    String machineCode,
    FixedAssetAuditSaveResponse? result,
    String errorText, {
    bool qrLocationMismatch = false,
    bool wasFlagged = false,
  }) {
    // Lưu thành công với QR lệch vị trí -> "Đã kiểm kê" + "Cần in lại QR"
    // (tính vào tiến độ). Bản ghi trong kỳ backend còn báo needsQrReprint
    // cũng vậy. alreadyAudited mà hết needsQrReprint: backend đã sửa bản ghi
    // -> bỏ dấu in lại QR (_markAudited), dù FE còn giữ trong set.
    final reprintRecord =
        result != null && result.alreadyAudited && result.needsQrReprint;
    _qrReprintSaved =
        reprintRecord ||
        ((qrLocationMismatch || (result?.needsQrReprint ?? false)) &&
            result != null &&
            result.saved &&
            !result.alreadyAudited);
    // Vị trí thực tế = actual* của response (*_Act của dòng khi quét lại);
    // tem hiện tại = reprintQr* của response, không lấy từ tem vừa quét.
    _reprintInfo = result == null || !_qrReprintSaved
        ? null
        : _reprintFromResponse(result);
    if (result == null) {
      _scanStatus = FixedAssetScanStatus.failed;
      _statusMessage = fixedAssetIsMissingQrLocationError(errorText)
          ? 'Không đọc được vị trí trên QR, quét lại'
          : 'Save failed: $errorText';
    } else if (result.pendingQrReplace) {
      // Máy chờ thay QR, quét ngoài tab "3) Thay QR": backend không gỡ cờ.
      _qrReprintSaved = true;
      _reprintInfo = _reprintFromResponse(result);
      _scanStatus = FixedAssetScanStatus.qrReplacePending;
      _lastAuditedAt = result.lastAuditedAt;
      _lastAuditedUserId = result.lastAuditedUserId;
      _lastAuditedUserName = result.lastAuditedUserName;
      _markQrReprint(machineCode);
    } else if (result.qrLabelNotReplaced) {
      // Tem cũ: không đổi gì, không hiện "Đã kiểm kê".
      _scanStatus = FixedAssetScanStatus.qrLabelNotReplaced;
      _lastAuditedAt = result.lastAuditedAt;
      _lastAuditedUserId = result.lastAuditedUserId;
      _lastAuditedUserName = result.lastAuditedUserName;
      _markQrReprint(machineCode);
    } else if (reprintRecord) {
      _scanStatus = FixedAssetScanStatus.qrReprintSaved;
      _lastAuditedAt = result.lastAuditedAt;
      _lastAuditedUserId = result.lastAuditedUserId;
      _lastAuditedUserName = result.lastAuditedUserName;
      _markAudited(machineCode);
      _markQrReprint(machineCode);
    } else if (result.alreadyAudited &&
        result.reprintSts &&
        !result.needsQrReprint) {
      // Máy đã thay QR (backend ReprintSts = 1): kiểm kê bình thường, không
      // coi là sai QR (*_Qr vẫn là QR cũ lúc kiểm kê).
      _scanStatus = FixedAssetScanStatus.qrReplaced;
      _qrReplacedAt = result.reprintAt;
      _lastAuditedAt = result.lastAuditedAt;
      _lastAuditedUserId = result.lastAuditedUserId;
      _lastAuditedUserName = result.lastAuditedUserName;
      _markAudited(machineCode);
    } else if (result.alreadyAudited && wasFlagged) {
      // Tem mới khớp vị trí thực tế: backend đã gỡ cờ in lại.
      _scanStatus = FixedAssetScanStatus.qrReprintCleared;
      _lastAuditedAt = result.lastAuditedAt;
      _lastAuditedUserId = result.lastAuditedUserId;
      _lastAuditedUserName = result.lastAuditedUserName;
      _markAudited(machineCode);
    } else if (result.alreadyAudited) {
      _scanStatus = FixedAssetScanStatus.alreadyAudited;
      _statusMessage = result.message.isNotEmpty ? result.message : null;
      _lastAuditedAt = result.lastAuditedAt;
      _lastAuditedUserId = result.lastAuditedUserId;
      _lastAuditedUserName = result.lastAuditedUserName;
      _markAudited(machineCode);
    } else if (result.saved && result.unknownMachine) {
      // Hợp lệ về nghiệp vụ, không phải lỗi; không tính vào tiến độ.
      _scanStatus = FixedAssetScanStatus.unknownSaved;
    } else if (_qrReprintSaved) {
      // MASTER (nếu sai) vẫn hiện qua [mismatchMaster].
      _scanStatus = FixedAssetScanStatus.qrReprintSaved;
      _markAudited(machineCode);
      _markQrReprint(machineCode);
    } else if (result.saved && result.locationMismatch) {
      _scanStatus = FixedAssetScanStatus.mismatchSaved;
      _markAudited(machineCode);
    } else if (result.saved) {
      _scanStatus = FixedAssetScanStatus.saved;
      _markAudited(machineCode);
    } else {
      _scanStatus = FixedAssetScanStatus.failed;
      _statusMessage = result.message.isNotEmpty
          ? result.message
          : 'Audit was not saved';
    }
    _notify();
  }

  // ============================================================
  // START
  // ============================================================

  /// Gọi một lần khi mở màn hình: tải danh sách PIC + Fac (theo PIC đã
  /// chọn trong phiên; tự chọn nếu chỉ có 1 Fac). Chưa chọn PIC: chỉ tải
  /// danh sách PIC.
  ///
  /// [initialLocation]: mở sẵn tại vị trí này (vd. từ Summary → khu của
  /// PIC): chọn lần lượt 4 dropdown, không tự chọn Fac duy nhất.
  void start({FixedAssetAuditLocation? initialLocation}) {
    if (_disposed) return;
    loadPics();
    if (_pic == null) return;
    if (initialLocation != null) {
      if (manual.needsFacs) manual.loadFacs();
      applyLocation(initialLocation);
      return;
    }
    if (manual.needsFacs) {
      _loadManualFacs();
    } else {
      final pick = manual.singleOption(
        FixedAssetManualField.fac,
        manual.facs,
      );
      if (pick != null) onFacChanged(pick);
    }
  }

  // ============================================================
  // MANUAL CASCADE (điều phối machine list + scan state)
  // ============================================================

  /// Reset machine list + scan state khi lựa chọn manual đổi.
  void _resetForManualSelection() {
    _machineReq++;
    _machines = const <FixedAssetMachine>[];
    _machinesLocation = null;
    _loadingMachines = false;
    _machineError = null;
    _clearMachineSearch();
    _clearScanState();
    _notify();
  }

  Future<void> _loadManualFacs() async {
    if (_disposed) return;
    final options = await manual.loadFacs();
    if (_disposed) return;
    final pick = manual.singleOption(FixedAssetManualField.fac, options);
    if (pick != null) await onFacChanged(pick);
  }

  Future<void> onFacChanged(String? value) async {
    if (_disposed) return;
    if (!manual.selectFac(value)) return;
    _resetForManualSelection();

    if (value == null) return;

    final options = await manual.loadFloors(value);
    if (_disposed || manual.selectedFac != value) return;
    final pick = manual.singleOption(FixedAssetManualField.floor, options);
    if (pick != null) await onFloorChanged(pick);
  }

  Future<void> onFloorChanged(String? value) async {
    if (_disposed) return;
    if (!manual.selectFloor(value)) return;
    _resetForManualSelection();

    final fac = manual.selectedFac;
    if (fac == null || value == null) return;

    final options = await manual.loadPositionA(fac, value);
    if (_disposed ||
        manual.selectedFac != fac ||
        manual.selectedFloor != value) {
      return;
    }
    final pick = manual.singleOption(FixedAssetManualField.positionA, options);
    if (pick != null) await onPositionAChanged(pick);
  }

  Future<void> onPositionAChanged(String? value) async {
    if (_disposed) return;
    if (!manual.selectPositionA(value)) return;
    _resetForManualSelection();

    final fac = manual.selectedFac;
    final floor = manual.selectedFloor;
    if (fac == null || floor == null || value == null) return;

    final options = await manual.loadPositionAA(fac, floor, value);
    if (_disposed ||
        manual.selectedFac != fac ||
        manual.selectedFloor != floor ||
        manual.selectedPositionA != value) {
      return;
    }
    final pick = manual.singleOption(
      FixedAssetManualField.positionAA,
      options,
    );
    if (pick != null) await onPositionAAChanged(pick);
  }

  Future<void> onPositionAAChanged(String? value) async {
    if (_disposed) return;
    if (!manual.selectPositionAA(value)) return;
    _resetForManualSelection();

    final fac = manual.selectedFac;
    final floor = manual.selectedFloor;
    final positionA = manual.selectedPositionA;
    if (fac != null && floor != null && positionA != null && value != null) {
      _loadMachines(fac, floor, positionA, value);
    }
  }

  /// Đưa location màn hình về [location] (vị trí vừa dùng ở form máy thiếu
  /// QR): chọn lần lượt 4 dropdown như user chọn tay (tải list + machines,
  /// reset scan state như mọi lần đổi vị trí).
  Future<void> applyLocation(FixedAssetAuditLocation location) async {
    if (_disposed || activeLocation == location) return;

    bool stillHere() => !_disposed;

    await onFacChanged(location.fac);
    if (stillHere() && manual.selectedFloor != location.floor) {
      await onFloorChanged(location.floor);
    }
    if (stillHere() && manual.selectedPositionA != location.positionA) {
      await onPositionAChanged(location.positionA);
    }
    if (stillHere() && manual.selectedPositionAA != location.positionAA) {
      await onPositionAAChanged(location.positionAA);
    }
  }

  // ============================================================
  // MACHINE LIST LOADING
  // ============================================================

  /// Gộp `auditedInPeriod` / `needsQrReprint` của [machines] vào hai tập
  /// (backend là nguồn đúng cho máy trong list). true nếu tập thay đổi.
  bool _mergeAuditedInPeriod(List<FixedAssetMachine> machines) {
    final before = _auditedVersion;
    for (final machine in machines) {
      final code = machine.machineCode.trim().toLowerCase();
      if (code.isEmpty) continue;
      if (machine.needsQrReprint) {
        _markQrReprint(code);
      } else if (machine.auditedInPeriod) {
        _markAudited(code);
      } else if (_qrReprintMachineCodes.remove(code)) {
        _auditedVersion++;
      }
    }
    return _auditedVersion != before;
  }

  static bool _sameMachines(
    List<FixedAssetMachine> a,
    List<FixedAssetMachine> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.machineCode != y.machineCode ||
          x.faName != y.faName ||
          x.auditedInPeriod != y.auditedInPeriod ||
          x.masterLocation != y.masterLocation ||
          x.isMoved != y.isMoved) {
        return false;
      }
    }
    return true;
  }

  bool _silentMachineRefreshInFlight = false;

  /// Reload GET /machines for [activeLocation] without UI churn: the list
  /// is not cleared, no loading state, search kept. Notifies only when the
  /// list or the audited set actually changed. Errors keep the old list.
  /// Dropped when the location changed meanwhile ([_machineReq]).
  Future<void> _refreshMachinesSilently() async {
    final location = activeLocation;
    // A normal load (location change) or another silent one is running.
    if (_disposed ||
        location == null ||
        _loadingMachines ||
        _silentMachineRefreshInFlight) {
      return;
    }
    final req = _machineReq;
    _silentMachineRefreshInFlight = true;
    try {
      final result = await api.fetchMachines(
        fac: location.fac,
        floor: location.floor,
        positionA: location.positionA,
        positionAA: location.positionAA,
        pic: _pic,
      );
      if (_disposed || req != _machineReq) return;
      final listChanged = !_sameMachines(_machines, result);
      if (listChanged) _machines = result;
      final auditedChanged = _mergeAuditedInPeriod(result);
      final errorCleared = _machineError != null;
      if (errorCleared) _machineError = null;
      if (listChanged || auditedChanged || errorCleared) _notify();
      _zoneLog(
        'silent machines refresh: list=$listChanged audited=$auditedChanged',
      );
    } catch (error) {
      if (_disposed || req != _machineReq) return;
      _zoneLog('silent machines refresh failed: ${fixedAssetErrorText(error)}');
    } finally {
      _silentMachineRefreshInFlight = false;
    }
  }

  Future<void> _loadMachines(
    String fac,
    String floor,
    String positionA,
    String positionAA,
  ) async {
    if (_disposed) return;
    // Location mới: tiến độ theo vùng của floor này.
    // Có cache nên không gọi dư.
    loadZoneProgress(fac, floor);

    final req = _machineReq;
    _loadingMachines = true;
    _machineError = null;
    _notify();

    try {
      final result = await api.fetchMachines(
        fac: fac,
        floor: floor,
        positionA: positionA,
        positionAA: positionAA,
        pic: _pic,
      );
      if (_disposed || req != _machineReq) return;
      _machines = result;
      _machinesLocation = FixedAssetAuditLocation(
        fac: fac,
        floor: floor,
        positionA: positionA,
        positionAA: positionAA,
      );
      // Gộp nguồn theo kỳ (backend) với mã đã audit trong phiên; không xóa
      // mã nào đã có.
      _mergeAuditedInPeriod(result);
      _notify();
    } catch (error) {
      if (_disposed || req != _machineReq) return;
      _machines = const <FixedAssetMachine>[];
      _machinesLocation = null;
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
