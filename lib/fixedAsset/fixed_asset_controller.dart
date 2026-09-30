import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';

import '../api/fixed_asset_backend.dart';
import '../model/fixed_asset_audit_check_response.dart';
import '../model/fixed_asset_audit_save_response.dart';
import '../model/fixed_asset_audit_summary.dart';
import '../model/fixed_asset_machine.dart';
import '../model/fixed_asset_zone_lock.dart';
import '../model/fixed_asset_zone_progress.dart';
import 'fixed_asset_audit_flow.dart';
import 'fixed_asset_features.dart';
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
/// - [onZoneUnlocked]: snackbar "Hoàn thành {AA} ✓" (khu vực khóa đã xong)
class FixedAssetController extends ChangeNotifier {
  FixedAssetController({
    required this.accountCode,
    required this.userName,
    required this.confirmMismatch,
    required this.showError,
    required this.resetQr,
    this.onScanAccepted,
    this.onZoneUnlocked,
    this.api = const FixedAssetBackend(),
    this.zoneLockEnabled = FixedAssetFeatures.zoneLock,
  }) {
    manual = FixedAssetManualCascade(
      onChanged: _notify,
      onError: showError,
      isDisposed: () => _disposed,
      api: api,
    );
  }

  final String accountCode;
  final String userName;
  final FixedAssetConfirmMismatch confirmMismatch;
  final ValueChanged<String> showError;
  final VoidCallback resetQr;
  final void Function(String rawQr, String machineCode)? onScanAccepted;

  /// Khu vực AUTO đang khóa vừa audit xong (PositionAA): báo đúng một lần.
  final ValueChanged<String>? onZoneUnlocked;

  /// Endpoint Fixed Asset (thay được trong test).
  final FixedAssetBackend api;

  /// Chế độ khóa khu vực AUTO ([FixedAssetFeatures.zoneLock]; test ghi đè
  /// được). false: không zone-lock, không chặn, không tự hiện khu vực dang
  /// dở. saveAudit vẫn gửi mode.
  final bool zoneLockEnabled;

  late final FixedAssetManualCascade manual;

  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _zoneRefreshTimer?.cancel();
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

  /// Pipeline (check -> confirm -> save) đang chạy: scan generation của nó
  /// và mode generation lúc bắt đầu. Chỉ một pipeline của MODE HIỆN TẠI chặn
  /// scan mới; pipeline của mode cũ bị bỏ (kết quả đã bị generation chặn),
  /// nên đổi mode không bao giờ để cờ "đang xử lý" kẹt sang mode mới.
  int? _activeScan;
  int _activeScanMode = -1;
  String? _processingRawQr;

  /// Tăng mỗi lần đổi mode.
  int _modeGeneration = 0;

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

  /// "AUTO" / "MANUAL" của từng pipeline (theo mode lúc bắt đầu), dùng cho
  /// mọi POST /audit của pipeline đó, kể cả re-POST sau xác nhận.
  final Map<int, String> _auditModeByScan = <int, String>{};

  bool get _pipelineBusy =>
      _activeScan != null && _activeScanMode == _modeGeneration;

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

  /// Log tạm cho luồng scan (chỉ debug).
  void _scanLog(String message) {
    if (!kDebugMode) return;
    debugPrint(
      '[FA-SCAN] $message | mode=${_locationMode.name} '
      'modeGen=$_modeGeneration scanGen=$_scanGeneration '
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
  final TextEditingController machineSearchController =
      TextEditingController();
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
      final result = await api.fetchAuditSummary();
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

  /// CURRENT LOCATION: số theo kỳ từ zone-progress; chưa tải / lỗi thì dùng
  /// số cũ (machine list + audited trong phiên).
  int get displayMachineCount => activeZoneProgress?.total ?? machineCount;
  int get displayAuditedCount =>
      activeZoneProgress?.audited ?? auditedMachineCount;

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
      final rows = await api.fetchZoneProgress(fac: f, floor: fl);
      if (_disposed || _zoneReqByKey[key] != req) return;
      _zoneProgressCache[key] = buildZoneProgressMap(rows);
      _staleZoneKeys.remove(key);
      _zoneLog('loaded $key: ${rows.length} rows');
      // The locked zone may just have reached 100% (anyone's audits):
      // unlock now, then let the server confirm.
      if (_checkLockTransition()) loadZoneLock();
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

  /// Sau save: máy được đếm theo vị trí MASTER (có thể ở floor khác), nên
  /// đánh dấu cũ mọi key đã cache; reload floor hiện tại sau debounce.
  void _scheduleZoneProgressRefresh() {
    _staleZoneKeys.addAll(_zoneProgressCache.keys);
    _zoneRefreshTimer?.cancel();
    _zoneRefreshTimer = Timer(_zoneRefreshDelay, () {
      if (_disposed) return;
      refreshZoneProgress();
      loadZoneLock();
    });
  }

  // ============================================================
  // ZONE LOCK (AUTO khóa ở một khu vực tới khi audit xong)
  // ============================================================

  /// Kết quả zone-lock thành công gần nhất (null = chưa tải được lần nào).
  FixedAssetZoneLock? _serverLock;

  /// Lần tải zone-lock gần nhất bị lỗi: chỉ [_optimisticLock] còn chặn.
  bool _zoneLockFailed = false;

  /// Khóa đặt ngay sau lần lưu AUTO, trước khi server xác nhận.
  FixedAssetAuditLocation? _optimisticLock;

  int _zoneLockReq = 0;

  /// [lockedZone] ở lần kiểm tra chuyển trạng thái trước (null lúc mở màn
  /// hình, nên lần tải đầu đã COMPLETED / NO_AUTO_AUDIT không báo gì).
  FixedAssetAuditLocation? _lastLockedZone;

  void _lockLog(String message) {
    if (kDebugMode) debugPrint('[FA-LOCK] $message');
  }

  /// Mã vùng của [location]: vùng cha không con (PositionAA rỗng hoặc =
  /// PositionA) dùng PositionA.
  static String _zoneCodeOf(FixedAssetAuditLocation location) {
    final positionA = location.positionA.trim();
    final positionAA = location.positionAA.trim();
    return positionAA.isEmpty || positionAA == positionA
        ? positionA
        : positionAA;
  }

  ZoneProgress? _zoneProgressOf(FixedAssetAuditLocation location) =>
      zoneProgressFor(location.fac, location.floor)?[_zoneCodeOf(location)];

  static bool _qrInZone(FixedAssetQrData qr, FixedAssetAuditLocation zone) {
    String norm(String v) => v.trim().toLowerCase();
    return norm(qr.floor) == norm(zone.floor) &&
        norm(qr.positionAA) == norm(zone.positionAA);
  }

  FixedAssetAuditLocation? get _serverLockedZone {
    final lock = _serverLock;
    if (_zoneLockFailed ||
        lock == null ||
        !lock.locked ||
        lock.reason == FixedAssetZoneLockReason.unresolved ||
        !lock.hasLocation) {
      return null;
    }
    return FixedAssetAuditLocation(
      fac: lock.fac!,
      floor: lock.floor!,
      positionA: lock.positionA!,
      positionAA: lock.positionAA!,
    );
  }

  /// Khu vực AUTO đang khóa: khóa lạc quan của phiên, hoặc khóa server (khi
  /// lần tải gần nhất thành công). Zone-progress báo đã xong -> không khóa.
  FixedAssetAuditLocation? get lockedZone {
    if (!zoneLockEnabled) return null;
    final candidate = _optimisticLock ?? _serverLockedZone;
    if (candidate == null) return null;
    if (_zoneProgressOf(candidate)?.isDone ?? false) return null;
    return candidate;
  }

  /// Tiến độ khu vực khóa (mọi user): zone-progress trước, không có thì số
  /// của zone-lock.
  ZoneProgress? get lockedZoneProgress {
    final zone = lockedZone;
    if (zone == null) return null;
    final fromZones = _zoneProgressOf(zone);
    if (fromZones != null) return fromZones;
    final lock = _serverLock;
    final total = lock?.total;
    if (lock == null || total == null || _serverLockedZone != zone) {
      return null;
    }
    return ZoneProgress(
      audited: (lock.audited ?? 0).clamp(0, total < 0 ? 0 : total),
      total: total,
    );
  }

  /// Không kiểm tra được khóa: lần tải gần nhất lỗi, hoặc UNRESOLVED.
  /// (NO_AUTO_AUDIT không phải lỗi.)
  bool get isZoneLockUnverified =>
      zoneLockEnabled &&
      (_zoneLockFailed ||
      _serverLock?.reason == FixedAssetZoneLockReason.unresolved);

  /// Khóa lạc quan sau lần lưu AUTO ở [location] (mapped), nếu zone-progress
  /// của nó có và chưa xong. Server xác nhận ở lần tải kế tiếp.
  void _setOptimisticLock(FixedAssetAuditLocation? location) {
    if (!zoneLockEnabled || location == null) return;
    final progress = _zoneProgressOf(location);
    if (progress == null || progress.isDone) return;
    _optimisticLock = location;
    _lockLog('optimistic lock ${location.floor}/${location.positionAA}');
    _checkLockTransition();
    _notify();
  }

  /// Tải khóa của user từ server. Kết quả cũ trả về muộn bị bỏ. Lỗi: giữ
  /// khóa lạc quan, bỏ khóa server, đánh dấu "không kiểm tra được".
  Future<void> loadZoneLock() async {
    if (!zoneLockEnabled || _disposed) return;
    final userId = accountCode.trim();
    if (userId.isEmpty) {
      _lockLog('skip: empty accountCode');
      return;
    }
    final req = ++_zoneLockReq;
    // A scan or a mode switch after this point wins over this result.
    final scanGeneration = _scanGeneration;
    final modeGeneration = _modeGeneration;
    try {
      final lock = await api.fetchZoneLock(userId: userId);
      if (_disposed || req != _zoneLockReq) return;
      _serverLock = lock;
      _zoneLockFailed = false;
      // Server is authoritative: it confirms or replaces the optimistic lock.
      _optimisticLock = null;
      _lockLog(
        'loaded: locked=${lock.locked} reason=${lock.reason.name} '
        '${lock.floor}/${lock.positionAA} ${lock.audited}/${lock.total}',
      );
      if (lock.reason == FixedAssetZoneLockReason.unresolved) {
        _lockLog('unresolved: not blocking scans');
      }
      if (scanGeneration == _scanGeneration &&
          modeGeneration == _modeGeneration) {
        _resumeLockedZone(lock);
      }
    } catch (error) {
      if (_disposed || req != _zoneLockReq) return;
      _zoneLockFailed = true;
      _lockLog('load failed: ${fixedAssetErrorText(error)}');
    }
    _checkLockTransition();
    _notify();
  }

  /// AUTO location restored from the unfinished zone (no scan yet): the
  /// location card shows "Tiếp tục khu vực đang kiểm kê dở" until the first
  /// scan.
  bool _isResumedFromLock = false;
  bool get isResumedFromLock => _isResumedFromLock;

  /// Opening AUTO with an unfinished zone (INCOMPLETE with a full location)
  /// and nothing scanned yet in this session: show that zone right away —
  /// location card, map, machine list — as after a scan, without check/save
  /// and without touching the scan status.
  void _resumeLockedZone(FixedAssetZoneLock lock) {
    if (!isAutoMode ||
        _autoLocation != null ||
        _autoUnmappedActual != null ||
        !lock.locked ||
        lock.reason != FixedAssetZoneLockReason.incomplete ||
        !lock.hasLocation) {
      return;
    }
    final location = FixedAssetAuditLocation(
      fac: lock.fac!,
      floor: lock.floor!,
      positionA: lock.positionA!,
      positionAA: lock.positionAA!,
    );
    _lockLog('resume ${location.floor}/${location.positionAA}');
    _autoLocation = location;
    _autoUnmappedActual = null;
    _autoLocationMismatch = false;
    _isResumedFromLock = true;

    _machineReq++;
    _machines = const <FixedAssetMachine>[];
    _machinesLocation = null;
    _machineError = null;
    _clearMachineSearch();
    // Also loads zone-progress for this floor (cached).
    _loadMachines(
      location.fac,
      location.floor,
      location.positionA,
      location.positionAA,
    );
  }

  /// So [lockedZone] với lần trước. Khi khu vực đang khóa được thả vì đã
  /// xong (zone-progress isDone, hoặc server COMPLETED cho cùng khu vực):
  /// báo [onZoneUnlocked] đúng một lần. true = vừa thả do đã xong.
  bool _checkLockTransition() {
    if (!zoneLockEnabled) return false;
    final previous = _lastLockedZone;
    final current = lockedZone;
    _lastLockedZone = current;
    if (previous == null || current == previous) return false;

    final server = _serverLock;
    final done =
        (_zoneProgressOf(previous)?.isDone ?? false) ||
        (server != null &&
            server.reason == FixedAssetZoneLockReason.completed &&
            server.floor == previous.floor &&
            server.positionAA == previous.positionAA);
    if (!done) return false;

    if (_optimisticLock == previous) _optimisticLock = null;
    _lockLog('unlocked ${previous.floor}/${previous.positionAA} (done)');
    onZoneUnlocked?.call(previous.positionAA);
    return true;
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
    _scanChipText = null;
    _pendingLocationQr = null;
    _qrLocationUnresolved = false;
    resetQr();
  }

  // ============================================================
  // SCAN FEEDBACK: camera chip + MANUAL without location
  // ============================================================

  /// Parsed text of the last received scan ("{code} · {floor}/{AA}") for
  /// the chip over the camera; null = hidden (mode / location change).
  String? _scanChipText;
  String? get scanChipText => _scanChipText;

  /// Bumped on every received scan (also ignored repeats): the chip shows /
  /// flashes again, so no scan goes without visible feedback.
  int _scanChipTick = 0;
  int get scanChipTick => _scanChipTick;

  /// The chip may fade out: the scan has a final result (not processing,
  /// no dialog open, not resolving a location).
  bool get isScanSettled =>
      _scanStatus != FixedAssetScanStatus.checking &&
      _scanStatus != FixedAssetScanStatus.saving &&
      !_confirmOpen &&
      !_resolvingQrLocation;

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

  /// Bumped on entering MANUAL: empty dropdowns pulse once.
  int _manualPromptTick = 0;
  int get manualPromptTick => _manualPromptTick;

  /// First empty dropdown after a scan without location (red + shake);
  /// [manualMissingTick] re-triggers the shake.
  FixedAssetManualField? _manualMissingField;
  int _manualMissingTick = 0;
  FixedAssetManualField? get manualMissingField =>
      _scanStatus == FixedAssetScanStatus.needsLocation
      ? _manualMissingField
      : null;
  int get manualMissingTick => _manualMissingTick;

  FixedAssetManualField? get _firstMissingManualField {
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

  /// Raw QR of the last scan without location that carries Floor +
  /// PositionAA ("Dùng vị trí từ QR").
  String? _pendingLocationQr;
  bool _qrLocationUnresolved = false;
  bool _resolvingQrLocation = false;
  bool get isResolvingQrLocation => _resolvingQrLocation;

  /// "{floor} / {positionAA}" for the "Dùng vị trí …" button; null when not
  /// offered (no QR location, or it could not be resolved).
  String? get pendingQrLocationLabel {
    final raw = _pendingLocationQr;
    if (raw == null ||
        _qrLocationUnresolved ||
        _scanStatus != FixedAssetScanStatus.needsLocation) {
      return null;
    }
    final data = parseFixedAssetQr(raw);
    return '${data.floor} / ${data.positionAA}';
  }

  /// Awaited by [useLocationFromQr] before re-processing the QR.
  Future<void>? _manualMachineLoad;

  /// MANUAL scan while the location is incomplete: no API, amber status,
  /// first empty dropdown marked. Repeated detections of the same code
  /// only flash the chip (no re-shake).
  void _handleScanWithoutLocation(String qr, DateTime now) {
    final data = parseFixedAssetQr(qr);
    if (data.machineCode.isEmpty) {
      _setScanChip(qr);
      _scanStatus = FixedAssetScanStatus.failed;
      _scannedCode = '';
      _statusMessage = 'Invalid machine QR';
      _notify();
      return;
    }
    final same =
        _scanStatus == FixedAssetScanStatus.needsLocation &&
        _scannedCode == data.machineCode &&
        _lastSeenQr == qr;
    // Keep the repeat window running: once a location is chosen, the QR
    // still in frame is not saved there by itself.
    _lastSeenQr = qr;
    _lastSeenAt = now;
    _isResumedFromLock = false;
    _setScanChip(qr);
    if (same) return;

    _scanGeneration++;
    _scannedCode = data.machineCode;
    _scannedFaName = data.displayName;
    _mismatchMaster = null;
    _lastAuditedAt = null;
    _lastAuditedUserId = null;
    _lastAuditedUserName = null;
    _pendingLocationQr = data.hasLocation ? qr : null;
    _qrLocationUnresolved = false;
    _scanStatus = FixedAssetScanStatus.needsLocation;
    _statusMessage = data.hasLocation
        ? 'Chưa chọn vị trí. Máy ${data.machineCode} · '
              'QR: ${data.floor}/${data.positionAA}'
        : 'Chưa chọn vị trí. Máy ${data.machineCode}';
    _manualMissingField = _firstMissingManualField;
    _manualMissingTick++;
    _scanLog('no location: ${data.machineCode} (missing $_manualMissingField)');
    _notify();
  }

  /// "Dùng vị trí từ QR": resolve Fac + PositionA from the QR's Floor +
  /// PositionAA through the MAP endpoints, fill the cascade, load the
  /// machines, then process that same QR again (no re-scan). Exactly one
  /// match is required; otherwise the user picks by hand.
  Future<void> useLocationFromQr() async {
    final raw = _pendingLocationQr;
    if (raw == null || isAutoMode || _resolvingQrLocation || _disposed) return;
    final data = parseFixedAssetQr(raw);
    final modeGeneration = _modeGeneration;

    _resolvingQrLocation = true;
    _scanStatus = FixedAssetScanStatus.checking;
    _statusMessage = 'Đang tìm vị trí ${data.floor}/${data.positionAA}…';
    _notify();

    bool stillHere() =>
        !_disposed && !isAutoMode && modeGeneration == _modeGeneration;

    try {
      final matches = await _resolveLocationFromMap(data.floor, data.positionAA);
      if (!stillHere()) return;
      if (matches.length != 1) {
        _scanLog('QR location ${data.floor}/${data.positionAA}: '
            '${matches.length} matches');
        _showQrLocationUnresolved(raw, data);
        return;
      }
      final target = matches.single;
      await onFacChanged(target.fac);
      if (stillHere() && manual.selectedFloor != target.floor) {
        await onFloorChanged(target.floor);
      }
      if (stillHere() && manual.selectedPositionA != target.positionA) {
        await onPositionAChanged(target.positionA);
      }
      if (stillHere() && manual.selectedPositionAA != target.positionAA) {
        await onPositionAAChanged(target.positionAA);
      }
      if (!stillHere()) return;
      if (manual.selectedLocation != target) {
        _showQrLocationUnresolved(raw, data);
        return;
      }
      await _manualMachineLoad;
      if (!stillHere() || manual.selectedLocation != target) return;

      // Same QR again, straight away: the cascade refreshed its repeat
      // window, which must not swallow this deliberate retry.
      _resolvingQrLocation = false;
      _lastSeenQr = null;
      _lastSeenAt = null;
      await processScannedQr(raw);
    } catch (error) {
      if (!stillHere()) return;
      _scanLog('QR location lookup failed: ${fixedAssetErrorText(error)}');
      _showQrLocationUnresolved(raw, data);
    } finally {
      _resolvingQrLocation = false;
    }
  }

  void _showQrLocationUnresolved(String raw, FixedAssetQrData data) {
    _pendingLocationQr = raw;
    _qrLocationUnresolved = true;
    _scannedCode = data.machineCode;
    _scanStatus = FixedAssetScanStatus.needsLocation;
    _statusMessage = 'Không xác định được vị trí từ QR';
    _manualMissingField = _firstMissingManualField;
    _manualMissingTick++;
    _notify();
  }

  /// Every MAP location whose Floor + PositionAA equal the QR's (trimmed,
  /// case-insensitive). Candidate PositionAs are those the code belongs to
  /// ("A35" for "A35-1", or itself); all PositionAs if none fits.
  Future<List<FixedAssetAuditLocation>> _resolveLocationFromMap(
    String floor,
    String positionAA,
  ) async {
    String norm(String v) => v.trim().toLowerCase();
    final wantFloor = norm(floor);
    final wantAA = norm(positionAA);
    final facs = manual.facs.isNotEmpty ? manual.facs : await api.fetchFacs();
    final found = <FixedAssetAuditLocation>[];

    await Future.wait(
      facs.map((fac) async {
        final floors = await api.fetchFloors(fac: fac);
        for (final f in floors.where((f) => norm(f) == wantFloor)) {
          final positionAs = await api.fetchPositionA(fac: fac, floor: f);
          final likely = positionAs.where((a) {
            final pa = norm(a);
            return wantAA == pa || wantAA.startsWith('$pa-');
          }).toList();
          await Future.wait(
            (likely.isNotEmpty ? likely : positionAs).map((pa) async {
              final aas = await api.fetchPositionAA(
                fac: fac,
                floor: f,
                positionA: pa,
              );
              for (final aa in aas.where((aa) => norm(aa) == wantAA)) {
                found.add(
                  FixedAssetAuditLocation(
                    fac: fac,
                    floor: f,
                    positionA: pa,
                    positionAA: aa,
                  ),
                );
              }
            }),
          );
        }
      }),
    );
    return found;
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

    // MANUAL without a full location: never saved, so no repeat window
    // applies — every scan shows "choose a location" (and can offer the
    // QR's own location).
    if (!isAutoMode && manual.selectedLocation == null) {
      _handleScanWithoutLocation(qr, now);
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
        qr == _lastSeenQr && lastAt != null && now.difference(lastAt) < repeatWindow;

    _lastSeenQr = qr;
    _lastSeenAt = now;

    if (isRepeat) {
      _scanLog('skip: repeat within ${_repeatScanWindow.inSeconds}s');
      // Status kept; the chip flashes so the user sees it was received.
      _setScanChip(qr);
      return;
    }

    final generation = ++_scanGeneration;
    _isResumedFromLock = false;
    _shortRepeatQr = null;
    _uxScanStart = _uxClock.elapsed;
    uxLog('received "$qr" (${_locationMode.name}) #$generation');
    _setScanChip(qr);
    final qrData = parseFixedAssetQr(qr);
    final machineCode = qrData.machineCode;

    // AUTO cần Floor + PositionAA từ QR để backend resolve vị trí thật.
    final String? invalidMessage = machineCode.isEmpty
        ? 'Invalid machine QR'
        : (isAutoMode && !qrData.hasLocation)
        ? 'Invalid Fixed Asset QR location'
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

    // AUTO đang khóa một khu vực: QR của khu vực khác không được check/lưu.
    final lock = isAutoMode && qrData.hasLocation ? lockedZone : null;
    if (lock != null && !_qrInZone(qrData, lock)) {
      final progress = lockedZoneProgress;
      final counts = progress == null
          ? ''
          : ' (${progress.audited}/${progress.total})';
      _scanLog(
        'skip: zone locked to ${lock.floor}/${lock.positionAA}, '
        'QR is ${qrData.floor}/${qrData.positionAA}',
      );
      _scannedCode = machineCode;
      _scannedFaName = qrData.displayName;
      _mismatchMaster = null;
      _lastAuditedAt = null;
      _lastAuditedUserId = null;
      _lastAuditedUserName = null;
      _scanStatus = FixedAssetScanStatus.zoneLocked;
      _statusMessage =
          'Khu vực ${lock.positionAA} chưa hoàn thành$counts. '
          'Hoàn thành khu vực này hoặc chuyển sang Manual.';
      _notify();
      resetQr();
      return;
    }

    // Một pipeline duy nhất cho toàn bộ CHECK -> (CONFIRM) -> SAVE.
    _auditModeByScan[generation] = isAutoMode ? 'AUTO' : 'MANUAL';
    _activeScan = generation;
    _activeScanMode = _modeGeneration;
    _processingRawQr = qr;
    _scanLog('start pipeline #$generation for $machineCode');

    _scannedCode = machineCode;
    _scannedFaName = qrData.displayName;
    _statusMessage = null;
    _lastAuditedAt = null;
    _lastAuditedUserId = null;
    _lastAuditedUserName = null;
    _mismatchMaster = null;
    // Immediate feedback in both modes; MANUAL shows its own text.
    _scanStatus = FixedAssetScanStatus.checking;
    if (!isAutoMode) _statusMessage = 'Đang kiểm tra $machineCode…';
    _notify();
    uxLog('accepted (start pipeline) $machineCode');

    try {
      if (isAutoMode) {
        _notifyScanAccepted(qr, machineCode);
        await _runAutoScan(qrData, generation);
      } else {
        await _runManualScan(machineCode, generation, rawQr: qr);
      }
    } finally {
      // Chỉ pipeline này tự trả cờ: pipeline cũ (mode trước) kết thúc muộn
      // không được xóa cờ của pipeline mới.
      _auditModeByScan.remove(generation);
      if (_activeScan == generation) {
        _activeScan = null;
        _processingRawQr = null;
      }
      _scanLog('end pipeline #$generation (current=${_isCurrentScan(generation)})');

      if (_isCurrentScan(generation)) {
        // Cửa sổ chống lặp tính từ lúc pipeline xong.
        _lastSeenQr = qr;
        _lastSeenAt = DateTime.now();
        resetQr();
      }
    }
  }

  /// MANUAL: location lấy từ dropdown. Mismatch (nếu có) do POST báo về.
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
      // Normally handled before the pipeline (_handleScanWithoutLocation).
      _failScan(generation, 'Chưa chọn vị trí');
      return;
    }

    _notifyScanAccepted(rawQr, machineCode);

    // Local check first when the selected location's list is loaded: a
    // machine that is not in it is asked about right away (no POST first).
    if (_machinesReadyFor(location)) {
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
      uxLog('local check skipped: list not ready (server check)');
    }

    await _saveAudit(
      machineCode,
      FixedAssetSaveTarget.mapped(location),
      generation,
    );
  }

  bool _machinesReadyFor(FixedAssetAuditLocation location) =>
      !_loadingMachines && _machineError == null && _machinesLocation == location;

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

    final confirmed = await _confirmLocationMismatch(
      generation,
      FixedAssetMismatchPrompt(
        machineCode: machineCode,
        faName: _scannedFaName,
        master: null,
        actual: location,
        masterUpdates: master,
        manual: true,
      ),
    );

    if (!_isCurrentScan(generation)) {
      _reportDropped(machineCode, 'đã đổi khu vực/chế độ');
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

  // ------------------------------------------------------------
  // AUTO FLOW: một POST /audit-check quyết định toàn bộ
  // ------------------------------------------------------------

  /// AUTO: check -> phân loại -> handler tương ứng. Không gọi scan-info /
  /// machine-location cho cùng scan.
  Future<void> _runAutoScan(FixedAssetQrData qrData, int generation) async {
    final machineCode = qrData.machineCode;

    final FixedAssetAuditCheckResponse check;

    _scanLog('checkAudit → $machineCode ${qrData.floor}/${qrData.positionAA}');
    try {
      check = await api.checkAudit(
        machineCode: machineCode,
        floor: qrData.floor,
        positionAA: qrData.positionAA,
      );
    } catch (error) {
      _scanLog('checkAudit error #$generation: $error');
      _failScan(
        generation,
        fixedAssetCheckErrorMessage(
          fixedAssetErrorText(error),
          'Unable to check audit status',
        ),
      );
      return;
    }

    if (!_isCurrentScan(generation) || !isAutoMode) {
      _scanLog('checkAudit result dropped: stale #$generation');
      return;
    }

    final actual = fixedAssetActualOf(check);
    final faName = check.faName.isNotEmpty ? check.faName : qrData.displayName;
    final outcome = classifyFixedAssetAutoCheck(check, actual);
    _scanLog('checkAudit #$generation → ${outcome.name}, actual=$actual');

    switch (outcome) {
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
    _scanLog('apply auto: status=${status.name} location=$location');

    if (reloadMachines) {
      _machines = const <FixedAssetMachine>[];
    _machinesLocation = null;
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
    _machinesLocation = null;
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
    // Only one dialog at a time (a pipeline of the previous mode may still
    // be waiting on one).
    if (_confirmOpen) return false;

    _confirmOpen = true;
    _confirmCode = prompt.machineCode;
    if (prompt.manual) {
      _statusMessage = 'Xác nhận máy ${prompt.machineCode} trước';
      _notify();
    }
    uxLog('confirmMismatch called');
    bool confirmed;
    try {
      confirmed = await confirmMismatch(prompt);
    } finally {
      _confirmOpen = false;
      _confirmCode = null;
    }
    uxLog('user chose ${confirmed ? 'SAVE' : 'SKIP'}');

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
    final mode = _auditModeByScan[generation] ?? (isAutoMode ? 'AUTO' : 'MANUAL');

    if (_scanStatus != FixedAssetScanStatus.saving) {
      _scanStatus = FixedAssetScanStatus.saving;
      _statusMessage = null;
      _notify();
    }

    FixedAssetAuditSaveResponse? response;
    Object? saveError;

    uxLog('POST /audit start (confirm=$confirmLocationMismatch)');
    final postStart = _uxClock.elapsed;
    _scanLog('saveAudit → $machineCode #$generation '
        '(confirm=$confirmLocationMismatch)');
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
        mode: mode,
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
    _scanLog('saveAudit #$generation → '
        '${result == null ? 'error: $errorText' : 'saved=${result.saved} '
            'alreadyAudited=${result.alreadyAudited}'}');

    // Tiến độ MASTER đổi khi có insert mới cho machine MASTER (kể cả
    // mismatch đã xác nhận). Vẫn refresh khi scan đã stale vì record đã
    // vào backend.
    if (isNewFixedAssetMasterAudit(result)) loadAuditSummary();
    if (result != null && result.saved) {
      if (mode == 'AUTO') _setOptimisticLock(target.location);
      // Zone progress + zone lock reload (shared 800 ms debounce).
      _scheduleZoneProgressRefresh();
    }

    // Location/mode đã đổi trong lúc save: không cập nhật status card /
    // audited set của màn hình hiện tại (nhưng báo lý do, không im lặng).
    if (!_isCurrentScan(generation)) {
      _reportDropped(machineCode, 'đã đổi khu vực/chế độ trong lúc lưu');
      return;
    }
    if (result != null && fixedAssetSaveNeedsConfirmation(
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
        manual: _auditModeByScan[generation] == 'MANUAL',
      ),
    );

    if (!_isCurrentScan(generation)) {
      _reportDropped(machineCode, 'đã đổi khu vực/chế độ');
      return;
    }

    if (!confirmed) {
      _markMismatchCancelled(generation);
      if (_auditModeByScan[generation] == 'MANUAL') {
        _shortRepeatQr = _processingRawQr;
      }
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
    _modeGeneration++;
    _isResumedFromLock = false;
    _autoLocation = null;
    _autoUnmappedActual = null;
    _autoLocationMismatch = false;

    _machines = const <FixedAssetMachine>[];
    _machinesLocation = null;
    _loadingMachines = false;
    _machineError = null;
    _clearMachineSearch();
    _clearScanState();

    // Pipeline của mode cũ không còn chặn scan mới (kết quả của nó đã bị
    // scan generation chặn), dù request của nó chưa trả về.
    _activeScan = null;
    _processingRawQr = null;

    // AUTO resolve vị trí từ chính QR: QR đang nằm trong khung phải được
    // xử lý ngay, không bị coi là "lặp" của lần detect ở MANUAL / trước đó.
    // (Sang MANUAL vẫn giữ cửa sổ chống lặp: QR trong khung không được tự
    // lưu vào location manual vừa chọn.)
    if (mode == FixedAssetLocationMode.auto) {
      _lastSeenQr = null;
      _lastSeenAt = null;
    }
    _scanLog('mode switched');
    _notify();

    // The lock is kept across modes (MANUAL ignores it); refresh it on the
    // way back to AUTO.
    if (mode == FixedAssetLocationMode.auto) loadZoneLock();

    // Lazy-load Fac lần đầu vào MANUAL, sau đó dùng lại cache.
    if (mode == FixedAssetLocationMode.manual) _manualPromptTick++;
    if (mode == FixedAssetLocationMode.manual && manual.needsFacs) {
      _loadManualFacs();
    } else if (mode == FixedAssetLocationMode.manual &&
        manual.facs.length == 1) {
      onFacChanged(manual.facs.first);
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
    final options = await manual.loadFacs();
    if (_disposed || isAutoMode || options?.length != 1) return;

    await onFacChanged(options!.first);
  }

  Future<void> onFacChanged(String? value) async {
    if (!manual.selectFac(value)) return;
    _resetForManualSelection();

    if (value == null) return;

    final options = await manual.loadFloors(value);
    if (_disposed || isAutoMode || manual.selectedFac != value) return;
    if (options?.length == 1) await onFloorChanged(options!.first);
  }

  Future<void> onFloorChanged(String? value) async {
    if (!manual.selectFloor(value)) return;
    _resetForManualSelection();

    final fac = manual.selectedFac;
    if (fac == null || value == null) return;

    final options = await manual.loadPositionA(fac, value);
    if (_disposed ||
        isAutoMode ||
        manual.selectedFac != fac ||
        manual.selectedFloor != value) {
      return;
    }
    if (options?.length == 1) await onPositionAChanged(options!.first);
  }

  Future<void> onPositionAChanged(String? value) async {
    if (!manual.selectPositionA(value)) return;
    _resetForManualSelection();

    final fac = manual.selectedFac;
    final floor = manual.selectedFloor;
    if (fac == null || floor == null || value == null) return;

    final options = await manual.loadPositionAA(fac, floor, value);
    if (_disposed ||
        isAutoMode ||
        manual.selectedFac != fac ||
        manual.selectedFloor != floor ||
        manual.selectedPositionA != value) {
      return;
    }
    if (options?.length == 1) await onPositionAAChanged(options!.first);
  }

  Future<void> onPositionAAChanged(String? value) async {
    if (!manual.selectPositionAA(value)) return;
    _resetForManualSelection();

    final fac = manual.selectedFac;
    final floor = manual.selectedFloor;
    final positionA = manual.selectedPositionA;
    if (fac != null && floor != null && positionA != null && value != null) {
      _manualMachineLoad = _loadMachines(fac, floor, positionA, value);
    }
  }

  // ============================================================
  // MACHINE LIST LOADING (AUTO + MANUAL)
  // ============================================================

  /// Gộp `auditedInPeriod` của [machines] vào [_auditedMachineCodes] (chỉ
  /// thêm). true nếu tập thay đổi.
  bool _mergeAuditedInPeriod(List<FixedAssetMachine> machines) {
    var changed = false;
    for (final machine in machines) {
      if (!machine.auditedInPeriod) continue;
      final code = machine.machineCode.trim().toLowerCase();
      if (code.isNotEmpty && _auditedMachineCodes.add(code)) changed = true;
    }
    return changed;
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
          x.auditedInPeriod != y.auditedInPeriod) {
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
    // Location mới (AUTO hoặc MANUAL): tiến độ theo vùng của floor này.
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
