import 'package:chuphinh/camera_preview_box.dart';
import 'package:chuphinh/widget/glass_action_button.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/fixed_asset_api.dart';
import '../common/common_searchable_dropdown.dart';
import '../common/common_ui_helper.dart';
import '../homeScreen/patrol_home_screen.dart';
import '../model/fixed_asset_audit_save_response.dart';
import '../model/fixed_asset_audit_summary.dart';
import '../model/fixed_asset_machine.dart';
import '../model/fixed_asset_scan_info.dart';

/// AUTO: QR -> MachineCode -> scan-info -> (đã kiểm kê: dừng | save).
/// MANUAL: chọn location bằng cascade -> QR -> save.
enum FixedAssetLocationMode { auto, manual }

/// saved (insert mới) và alreadyAudited (đã có trong kỳ) là hai kết quả
/// nghiệp vụ khác nhau, không gộp chung.
enum _ScanStatus {
  idle,
  checking,
  saving,
  saved,
  alreadyAudited,
  unknownSaved,
  failed,
}

/// Location dùng để POST audit, không phụ thuộc nguồn (AUTO/MANUAL).
class _AuditLocation {
  final String fac;
  final String floor;
  final String positionA;
  final String positionAA;

  const _AuditLocation({
    required this.fac,
    required this.floor,
    required this.positionA,
    required this.positionAA,
  });

  @override
  bool operator ==(Object other) =>
      other is _AuditLocation &&
      other.fac == fac &&
      other.floor == floor &&
      other.positionA == positionA &&
      other.positionAA == positionAA;

  @override
  int get hashCode => Object.hash(fac, floor, positionA, positionAA);
}

class FixedAssetScreen extends StatefulWidget {
  final String accountCode;
  final String? selectedPlant;
  final String userName;

  const FixedAssetScreen({
    super.key,
    required this.accountCode,
    this.selectedPlant,
    this.userName = '',
  });

  @override
  State<FixedAssetScreen> createState() => _FixedAssetScreenState();
}

class _FixedAssetScreenState extends State<FixedAssetScreen> {
  final GlobalKey<CameraPreviewBoxState> _cameraKey =
      GlobalKey<CameraPreviewBoxState>();

  // cyan = đang xử lý, green = save mới, amber = đã kiểm kê / ngoài master,
  // red = lỗi thật.
  static const Color _accent = Color(0xFF4DD0E1);
  static const Color _success = Color(0xFF22C55E);
  static const Color _amber = Color(0xFFF59E0B);

  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _monthFormat = DateFormat('MMM');

  // ============================================================
  // MODE
  // ============================================================

  FixedAssetLocationMode _locationMode = FixedAssetLocationMode.auto;

  bool get _isAutoMode => _locationMode == FixedAssetLocationMode.auto;

  /// Location AUTO lấy từ MASTER (chỉ hiển thị, không phải control).
  _AuditLocation? _masterLocation;

  // ============================================================
  // SCAN STATE
  // ============================================================

  _ScanStatus _scanStatus = _ScanStatus.idle;

  /// MachineCode đã extract từ QR gần nhất (không phải raw QR).
  String _scannedCode = '';

  /// FAName từ MASTER (chỉ có ở AUTO).
  String _scannedFaName = '';

  /// Message lỗi hiển thị trên status card.
  String? _statusMessage;

  /// Lần kiểm kê gần nhất (khi machine đã kiểm kê trong kỳ).
  DateTime? _lastAuditedAt;

  /// Chỉ một scan pipeline (lookup -> save) chạy tại một thời điểm.
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

  // ============================================================
  // MANUAL CASCADE STATE
  // ============================================================

  String? selectedFac;
  String? selectedFloor;
  String? selectedPositionA;
  String? selectedPositionAA;

  /// Fac được cache: chỉ load lần đầu vào MANUAL, tái sử dụng khi toggle.
  List<String> facs = const <String>[];
  List<String> floors = const <String>[];
  List<String> positionAs = const <String>[];
  List<String> positionAAs = const <String>[];

  bool _loadingFacs = false;
  bool _loadingFloors = false;
  bool _loadingPositionA = false;
  bool _loadingPositionAA = false;

  // Request tokens: mỗi lần parent đổi thì tăng token của các level con,
  // response cũ có token khác sẽ bị bỏ qua.
  int _facReq = 0;
  int _floorReq = 0;
  int _positionAReq = 0;
  int _positionAAReq = 0;
  int _machineReq = 0;

  // ============================================================
  // MACHINE LIST STATE
  // ============================================================

  List<FixedAssetMachine> machines = const <FixedAssetMachine>[];
  bool _loadingMachines = false;
  String? _machineError;

  // Search cục bộ, không gọi API.
  final TextEditingController _machineSearchController =
      TextEditingController();
  String _machineSearch = '';

  /// MachineCode ĐÃ KIỂM KÊ TRONG KỲ HIỆN TẠI, lưu dạng trim().toLowerCase().
  ///
  /// Chỉ thêm từ bằng chứng trong session này (scan-info
  /// auditedInCurrentPeriod, POST saved/alreadyAudited). KHÔNG dùng
  /// /audited-machine-codes vì endpoint đó là lịch sử trọn đời, không lọc
  /// theo kỳ 3 tháng. Không reset khi location/mode đổi.
  final Set<String> _auditedMachineCodes = <String>{};

  // ============================================================
  // AUDIT SUMMARY STATE
  // ============================================================

  FixedAssetAuditSummary? _auditSummary;
  bool _loadingAuditSummary = false;
  String? _auditSummaryError;
  int _summaryReq = 0;

  /// Camera chỉ build một lần: setState của màn hình (search, check,
  /// status...) không rebuild CameraPreviewBox.
  late final Widget _cameraSection = _buildCameraSection();

  @override
  void initState() {
    super.initState();
    // AUTO là mặc định: Fac chỉ load khi chuyển sang MANUAL.
    // Summary chạy độc lập, không chặn camera.
    _loadAuditSummary();
  }

  @override
  void dispose() {
    _machineSearchController.dispose();
    super.dispose();
  }

  /// Gọi bên trong setState khi danh sách machine bị clear.
  void _clearMachineSearch() {
    _machineSearch = '';
    _machineSearchController.clear();
  }

  _AuditLocation? get _selectedManualLocation {
    final fac = selectedFac;
    final floor = selectedFloor;
    final positionA = selectedPositionA;
    final positionAA = selectedPositionAA;

    if (fac == null ||
        floor == null ||
        positionA == null ||
        positionAA == null) {
      return null;
    }

    return _AuditLocation(
      fac: fac,
      floor: floor,
      positionA: positionA,
      positionAA: positionAA,
    );
  }

  /// Location đang dùng cho machine list, theo mode hiện tại.
  _AuditLocation? get _activeLocation =>
      _isAutoMode ? _masterLocation : _selectedManualLocation;

  bool _isCurrentScan(int generation) =>
      mounted && generation == _scanGeneration;

  // ============================================================
  // QR
  // ============================================================

  void _onQrDetected(String qr) {
    _processScannedQr(qr);
  }

  /// KVH_A-1456_1F_A34-2_Sprue Bush -> A-1456
  /// A-2331 -> A-2331
  ///
  /// Chỉ lấy MachineCode. Location nhúng trong QR KHÔNG được dùng:
  /// AUTO lấy từ MASTER, MANUAL lấy từ dropdown.
  String _extractMachineCode(String rawQr) {
    final qr = rawQr.trim();
    if (qr.isEmpty) return '';

    if (qr.startsWith('KVH_')) {
      final segments = qr.split('_');
      return segments.length >= 2 ? segments[1].trim() : '';
    }

    return qr;
  }

  /// Gọi bên trong setState khi location/mode đổi.
  ///
  /// KHÔNG xóa _lastSeenQr: QR vẫn đang nằm trong khung camera phải
  /// rời khung (quá _repeatScanWindow) rồi scan lại mới được save.
  void _clearScanState() {
    _scanGeneration++;
    _scanStatus = _ScanStatus.idle;
    _scannedCode = '';
    _scannedFaName = '';
    _statusMessage = null;
    _lastAuditedAt = null;
    if (_lastSeenQr != null) _lastSeenAt = DateTime.now();
    _cameraKey.currentState?.resetQr();
  }

  void _failScan(int generation, String message) {
    if (!_isCurrentScan(generation)) return;
    setState(() {
      _scanStatus = _ScanStatus.failed;
      _statusMessage = message;
    });
  }

  Future<void> _processScannedQr(String rawQr) async {
    final qr = rawQr.trim();
    if (qr.isEmpty || !mounted) return;

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
    final machineCode = _extractMachineCode(qr);

    if (machineCode.isEmpty) {
      setState(() {
        _scannedCode = '';
        _scannedFaName = '';
        _scanStatus = _ScanStatus.failed;
        _statusMessage = 'Invalid machine QR';
      });
      _cameraKey.currentState?.resetQr();
      return;
    }

    _processingScan = true;
    _processingRawQr = qr;

    setState(() {
      _scannedCode = machineCode;
      _scannedFaName = '';
      _statusMessage = null;
      _lastAuditedAt = null;
      _scanStatus = _isAutoMode ? _ScanStatus.checking : _ScanStatus.saving;
    });

    try {
      final location = await _resolveAuditLocation(machineCode, generation);
      if (location == null || !_isCurrentScan(generation)) return;

      await _saveAudit(machineCode, location, generation);
    } finally {
      _processingScan = false;
      _processingRawQr = null;

      if (_isCurrentScan(generation)) {
        // Cửa sổ chống lặp tính từ lúc pipeline xong.
        _lastSeenQr = qr;
        _lastSeenAt = DateTime.now();
        _cameraKey.currentState?.resetQr();
      }
    }
  }

  /// AUTO: scan-info quyết định (đã kiểm kê -> dừng, chưa -> location MASTER).
  /// MANUAL: location đang chọn.
  /// Trả null nếu không POST (đã set trạng thái) hoặc scan đã stale.
  Future<_AuditLocation?> _resolveAuditLocation(
    String machineCode,
    int generation,
  ) async {
    if (!_isAutoMode) {
      final location = _selectedManualLocation;
      if (location == null) {
        _failScan(
          generation,
          'Select Fac, Floor, PositionA and PositionAA first',
        );
      }
      return location;
    }

    final FixedAssetScanInfo info;

    try {
      info = await FixedAssetApi.fetchScanInfo(machineCode);
    } catch (_) {
      _failScan(generation, 'Unable to check audit status');
      return null;
    }

    if (!_isCurrentScan(generation) || !_isAutoMode) return null;

    // Case A / D: đã kiểm kê trong kỳ -> không POST.
    if (info.auditedInCurrentPeriod) {
      _applyScanInfo(machineCode, info, _ScanStatus.alreadyAudited);
      return null;
    }

    // Case C: không có trong MASTER và chưa kiểm kê. Chưa có nguồn location
    // vật lý hợp lệ cho machine lạ -> không POST, không tự suy location.
    if (!info.existsInMaster) {
      _applyScanInfo(
        machineCode,
        info,
        _ScanStatus.failed,
        message: 'Machine not found in master',
      );
      return null;
    }

    if (!info.hasFullLocation) {
      _applyScanInfo(
        machineCode,
        info,
        _ScanStatus.failed,
        message: 'Master location is incomplete',
      );
      return null;
    }

    // Case B: MASTER + chưa kiểm kê -> hiển thị location rồi POST.
    return _applyScanInfo(machineCode, info, _ScanStatus.saving);
  }

  /// Áp kết quả scan-info trong MỘT setState: status, FAName, lastAuditedAt,
  /// location MASTER (nếu có), audited set. Không đi qua handler cascade
  /// manual. Machine list chỉ reload khi location đổi hoặc lần trước lỗi.
  ///
  /// Trả về location MASTER đã áp (null nếu machine không có trong MASTER).
  _AuditLocation? _applyScanInfo(
    String machineCode,
    FixedAssetScanInfo info,
    _ScanStatus status, {
    String? message,
  }) {
    final location = info.existsInMaster && info.hasFullLocation
        ? _AuditLocation(
            fac: info.fac,
            floor: info.floor,
            positionA: info.positionA,
            positionAA: info.positionAA,
          )
        : null;

    final sameLocation = location == _masterLocation;
    final reloadMachines =
        location != null && (!sameLocation || _machineError != null);

    if (reloadMachines) _machineReq++;

    setState(() {
      _scannedFaName = info.faName;
      _lastAuditedAt = info.lastAuditedAt;
      _scanStatus = status;
      _statusMessage = message;

      if (status == _ScanStatus.alreadyAudited) {
        _auditedMachineCodes.add(machineCode.trim().toLowerCase());
      }

      // Machine không có trong MASTER: giữ nguyên location đang hiển thị,
      // không điền location từ QR.
      if (location != null) _masterLocation = location;

      if (reloadMachines) {
        machines = const <FixedAssetMachine>[];
        _machineError = null;
        if (!sameLocation) _clearMachineSearch();
      }
    });

    if (reloadMachines) {
      // Chạy song song với POST audit, không chặn save.
      _loadMachines(
        location.fac,
        location.floor,
        location.positionA,
        location.positionAA,
      );
    }

    return location;
  }

  /// Đường save chung cho AUTO và MANUAL. Request body không đổi.
  Future<void> _saveAudit(
    String machineCode,
    _AuditLocation location,
    int generation,
  ) async {
    final userId = widget.accountCode.trim();
    final name = widget.userName.trim();
    final userName = name.isEmpty ? userId : name;

    if (_scanStatus != _ScanStatus.saving) {
      setState(() => _scanStatus = _ScanStatus.saving);
    }

    FixedAssetAuditSaveResponse? response;
    Object? saveError;

    try {
      response = await FixedAssetApi.saveAudit(
        fac: location.fac,
        floor: location.floor,
        positionA: location.positionA,
        positionAA: location.positionAA,
        machineCode: machineCode,
        userId: userId,
        userName: userName,
      );
    } catch (error) {
      saveError = error;
    }

    if (!mounted) return;

    final result = response;
    final errorText = saveError == null ? '' : _errorText(saveError);

    final newlySavedMaster =
        result != null &&
        result.saved &&
        !result.alreadyAudited &&
        !result.unknownMachine;

    // Tiến độ MASTER chỉ đổi khi có insert mới cho machine MASTER.
    // Vẫn refresh kể cả khi scan đã stale vì record đã vào backend.
    if (newlySavedMaster) _loadAuditSummary();

    // Location/mode đã đổi trong lúc save: không cập nhật status card /
    // audited set của màn hình hiện tại.
    if (!_isCurrentScan(generation)) return;

    setState(() {
      if (result == null) {
        _scanStatus = _ScanStatus.failed;
        _statusMessage = 'Save failed: $errorText';
      } else if (result.alreadyAudited) {
        _scanStatus = _ScanStatus.alreadyAudited;
        _lastAuditedAt = result.lastAuditedAt;
        _auditedMachineCodes.add(machineCode.trim().toLowerCase());
      } else if (result.saved && result.unknownMachine) {
        // Hợp lệ về nghiệp vụ, không phải lỗi; không tính vào tiến độ.
        _scanStatus = _ScanStatus.unknownSaved;
      } else if (result.saved) {
        _scanStatus = _ScanStatus.saved;
        _auditedMachineCodes.add(machineCode.trim().toLowerCase());
      } else {
        _scanStatus = _ScanStatus.failed;
        _statusMessage = result.message.isNotEmpty
            ? result.message
            : 'Audit was not saved';
      }
    });
  }

  // ============================================================
  // MODE SWITCH
  // ============================================================

  void _setLocationMode(FixedAssetLocationMode mode) {
    if (mode == _locationMode) return;

    // Vô hiệu hóa lookup/cascade/machine request đang chạy.
    _floorReq++;
    _positionAReq++;
    _positionAAReq++;
    _machineReq++;

    setState(() {
      _locationMode = mode;

      // Không để location của mode cũ bị dùng lại ở mode mới.
      _masterLocation = null;
      selectedFac = null;
      selectedFloor = null;
      selectedPositionA = null;
      selectedPositionAA = null;
      floors = const <String>[];
      positionAs = const <String>[];
      positionAAs = const <String>[];

      _loadingFloors = false;
      _loadingPositionA = false;
      _loadingPositionAA = false;

      machines = const <FixedAssetMachine>[];
      _loadingMachines = false;
      _machineError = null;
      _clearMachineSearch();
      _clearScanState();
    });

    // Lazy-load Fac lần đầu vào MANUAL, sau đó dùng lại cache.
    if (mode == FixedAssetLocationMode.manual &&
        facs.isEmpty &&
        !_loadingFacs) {
      _loadFacs();
    }
  }

  // ============================================================
  // LOADING
  // ============================================================

  String _errorText(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _showError(String message) {
    if (!mounted) return;
    CommonUI.showSnackBar(
      context: context,
      message: message,
      color: Colors.redAccent,
    );
  }

  Future<void> _loadFacs() async {
    final req = ++_facReq;
    setState(() => _loadingFacs = true);

    try {
      final result = await FixedAssetApi.fetchFacs();
      if (!mounted || req != _facReq) return;
      setState(() => facs = result);
    } catch (error) {
      if (!mounted || req != _facReq) return;
      setState(() => facs = const <String>[]);
      _showError('Load Fac failed: ${_errorText(error)}');
    } finally {
      if (mounted && req == _facReq) {
        setState(() => _loadingFacs = false);
      }
    }
  }

  /// Gọi lúc mở màn hình và sau POST saved=true cho machine MASTER.
  /// Lỗi chỉ hiện trên progress card, không ảnh hưởng scan workflow.
  Future<void> _loadAuditSummary() async {
    final req = ++_summaryReq;
    setState(() {
      _loadingAuditSummary = true;
      _auditSummaryError = null;
    });

    try {
      final result = await FixedAssetApi.fetchAuditSummary();
      if (!mounted || req != _summaryReq) return;
      setState(() {
        _auditSummary = result;
        _loadingAuditSummary = false;
      });
    } catch (error) {
      if (!mounted || req != _summaryReq) return;
      setState(() {
        _auditSummaryError = _errorText(error);
        _loadingAuditSummary = false;
      });
    }
  }

  Future<void> _loadFloors(String fac) async {
    final req = _floorReq;
    setState(() => _loadingFloors = true);

    try {
      final result = await FixedAssetApi.fetchFloors(fac);
      if (!mounted || req != _floorReq) return;
      setState(() => floors = result);
    } catch (error) {
      if (!mounted || req != _floorReq) return;
      setState(() => floors = const <String>[]);
      _showError('Load Floor failed: ${_errorText(error)}');
    } finally {
      if (mounted && req == _floorReq) {
        setState(() => _loadingFloors = false);
      }
    }
  }

  Future<void> _loadPositionA(String fac, String floor) async {
    final req = _positionAReq;
    setState(() => _loadingPositionA = true);

    try {
      final result = await FixedAssetApi.fetchPositionA(
        fac: fac,
        floor: floor,
      );
      if (!mounted || req != _positionAReq) return;
      setState(() => positionAs = result);
    } catch (error) {
      if (!mounted || req != _positionAReq) return;
      setState(() => positionAs = const <String>[]);
      _showError('Load PositionA failed: ${_errorText(error)}');
    } finally {
      if (mounted && req == _positionAReq) {
        setState(() => _loadingPositionA = false);
      }
    }
  }

  Future<void> _loadPositionAA(
    String fac,
    String floor,
    String positionA,
  ) async {
    final req = _positionAAReq;
    setState(() => _loadingPositionAA = true);

    try {
      final result = await FixedAssetApi.fetchPositionAA(
        fac: fac,
        floor: floor,
        positionA: positionA,
      );
      if (!mounted || req != _positionAAReq) return;
      setState(() => positionAAs = result);
    } catch (error) {
      if (!mounted || req != _positionAAReq) return;
      setState(() => positionAAs = const <String>[]);
      _showError('Load PositionAA failed: ${_errorText(error)}');
    } finally {
      if (mounted && req == _positionAAReq) {
        setState(() => _loadingPositionAA = false);
      }
    }
  }

  Future<void> _loadMachines(
    String fac,
    String floor,
    String positionA,
    String positionAA,
  ) async {
    final req = _machineReq;
    setState(() {
      _loadingMachines = true;
      _machineError = null;
    });

    try {
      final result = await FixedAssetApi.fetchMachines(
        fac: fac,
        floor: floor,
        positionA: positionA,
        positionAA: positionAA,
      );
      if (!mounted || req != _machineReq) return;
      setState(() => machines = result);
    } catch (error) {
      if (!mounted || req != _machineReq) return;
      setState(() {
        machines = const <FixedAssetMachine>[];
        _machineError = _errorText(error);
      });
    } finally {
      if (mounted && req == _machineReq) {
        setState(() => _loadingMachines = false);
      }
    }
  }

  // ============================================================
  // MANUAL CASCADE
  // ============================================================

  void _onFacChanged(String? value) {
    if (value == selectedFac) return;

    // Vô hiệu hóa mọi request con đang chạy.
    _floorReq++;
    _positionAReq++;
    _positionAAReq++;
    _machineReq++;

    setState(() {
      selectedFac = value;
      selectedFloor = null;
      selectedPositionA = null;
      selectedPositionAA = null;

      floors = const <String>[];
      positionAs = const <String>[];
      positionAAs = const <String>[];
      machines = const <FixedAssetMachine>[];

      _loadingFloors = false;
      _loadingPositionA = false;
      _loadingPositionAA = false;
      _loadingMachines = false;
      _machineError = null;
      _clearMachineSearch();
      _clearScanState();
    });

    if (value != null) _loadFloors(value);
  }

  void _onFloorChanged(String? value) {
    if (value == selectedFloor) return;

    _positionAReq++;
    _positionAAReq++;
    _machineReq++;

    setState(() {
      selectedFloor = value;
      selectedPositionA = null;
      selectedPositionAA = null;

      positionAs = const <String>[];
      positionAAs = const <String>[];
      machines = const <FixedAssetMachine>[];

      _loadingPositionA = false;
      _loadingPositionAA = false;
      _loadingMachines = false;
      _machineError = null;
      _clearMachineSearch();
      _clearScanState();
    });

    final fac = selectedFac;
    if (fac != null && value != null) _loadPositionA(fac, value);
  }

  void _onPositionAChanged(String? value) {
    if (value == selectedPositionA) return;

    _positionAAReq++;
    _machineReq++;

    setState(() {
      selectedPositionA = value;
      selectedPositionAA = null;

      positionAAs = const <String>[];
      machines = const <FixedAssetMachine>[];

      _loadingPositionAA = false;
      _loadingMachines = false;
      _machineError = null;
      _clearMachineSearch();
      _clearScanState();
    });

    final fac = selectedFac;
    final floor = selectedFloor;
    if (fac != null && floor != null && value != null) {
      _loadPositionAA(fac, floor, value);
    }
  }

  void _onPositionAAChanged(String? value) {
    if (value == selectedPositionAA) return;

    _machineReq++;

    setState(() {
      selectedPositionAA = value;
      machines = const <FixedAssetMachine>[];
      _loadingMachines = false;
      _machineError = null;
      _clearMachineSearch();
      _clearScanState();
    });

    final fac = selectedFac;
    final floor = selectedFloor;
    final positionA = selectedPositionA;
    if (fac != null && floor != null && positionA != null && value != null) {
      _loadMachines(fac, floor, positionA, value);
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121826),
        centerTitle: false,
        titleSpacing: 4,
        leading: GlassActionButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fixed Asset',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
            if ((widget.selectedPlant ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.selectedPlant!,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF121826), Color(0xFF1F2937), Color(0xFF374151)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              _cameraSection,
              const SizedBox(height: 6),
              _buildStatusCard(),
              const SizedBox(height: 6),
              _buildProgressCard(),
              const SizedBox(height: 8),
              _buildLocationCard(),
              const SizedBox(height: 8),
              _buildMachineSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraSection() {
    return SizedBox(
      width: 340,
      height: 340,
      child: RepaintBoundary(
        child: CameraPreviewBox(
          key: _cameraKey,
          size: 340,
          plant: widget.selectedPlant,
          type: PatrolGroup.AssetUpdate.name,
          patrolGroup: PatrolGroup.AssetUpdate,
          onQrDetected: _onQrDetected,
          qrOnly: true,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // STATUS CARD
  // ------------------------------------------------------------

  Widget _buildStatusCard() {
    final hasCode = _scannedCode.isNotEmpty;
    final lastAudited = _lastAuditedAt;

    final String primary;
    final List<String> details = <String>[];
    String? label;
    Color color;
    Widget? indicator;

    switch (_scanStatus) {
      case _ScanStatus.idle:
        primary = 'Scan machine QR';
        color = Colors.white54;
      case _ScanStatus.checking:
        primary = _scannedCode;
        details.add('Checking audit status...');
        color = _accent;
        indicator = _spinner();
      case _ScanStatus.saving:
        primary = _scannedCode;
        if (_scannedFaName.isNotEmpty) details.add(_scannedFaName);
        label = 'Saving...';
        color = _accent;
        indicator = _spinner();
      case _ScanStatus.saved:
        primary = _scannedCode;
        if (_scannedFaName.isNotEmpty) details.add(_scannedFaName);
        label = 'Saved';
        color = _success;
        indicator = const Icon(
          Icons.check_circle_rounded,
          color: _success,
          size: 20,
        );
      case _ScanStatus.alreadyAudited:
        primary = _scannedCode;
        if (_scannedFaName.isNotEmpty) details.add(_scannedFaName);
        if (lastAudited != null) {
          details.add('Last: ${_dateTimeFormat.format(lastAudited)}');
        }
        label = 'Đã kiểm kê';
        color = _amber;
        indicator = const Icon(Icons.task_alt_rounded, color: _amber, size: 20);
      case _ScanStatus.unknownSaved:
        primary = _scannedCode;
        details.add('Saved outside master');
        label = 'Not in master';
        color = _amber;
        indicator = const Icon(
          Icons.warning_amber_rounded,
          color: _amber,
          size: 20,
        );
      case _ScanStatus.failed:
        // Invalid QR: không có MachineCode, message là dòng chính.
        primary = hasCode ? _scannedCode : (_statusMessage ?? 'Scan failed');
        if (hasCode && (_statusMessage ?? '').isNotEmpty) {
          details.add(_statusMessage!);
        }
        color = Colors.redAccent;
        indicator = const Icon(
          Icons.error_rounded,
          color: Colors.redAccent,
          size: 20,
        );
    }

    final idle = _scanStatus == _ScanStatus.idle;
    final failed = _scanStatus == _ScanStatus.failed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: idle ? Colors.white.withOpacity(.06) : color.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: idle ? Colors.white.withOpacity(.14) : color.withOpacity(.45),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.qr_code_2_rounded, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  primary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: idle ? Colors.white.withOpacity(.6) : Colors.white,
                    fontSize: idle ? 13.5 : 15.5,
                    fontWeight: idle ? FontWeight.w500 : FontWeight.w800,
                  ),
                ),
                for (final detail in details)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      detail,
                      maxLines: failed ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: failed
                            ? Colors.redAccent.shade100
                            : Colors.white.withOpacity(.65),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (indicator != null) ...[const SizedBox(width: 6), indicator],
        ],
      ),
    );
  }

  Widget _spinner() {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
    );
  }

  // ------------------------------------------------------------
  // AUDIT PROGRESS CARD (kỳ 3 tháng, số liệu từ backend)
  // ------------------------------------------------------------

  /// 64.0 -> "64", 64.5 -> "64.5", 64.27 -> "64.27".
  String _formatPercent(double value) {
    var text = value.toStringAsFixed(2);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return text;
  }

  /// Nhãn kỳ từ periodStart/periodEnd của backend, ví dụ "Jul–Sep 2026".
  String _formatPeriod(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '';

    final startMonth = _monthFormat.format(start);
    final endMonth = _monthFormat.format(end);

    if (start.year == end.year) {
      return '$startMonth–$endMonth ${end.year}';
    }
    return '$startMonth ${start.year}–$endMonth ${end.year}';
  }

  Widget _buildProgressCard() {
    final summary = _auditSummary;
    final error = _auditSummaryError;

    final period = summary == null
        ? ''
        : _formatPeriod(summary.periodStart, summary.periodEnd);

    final Widget body;

    if (summary != null) {
      final percent = summary.completionPercent;
      final done = percent >= 100;

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text:
                            '${summary.auditedMachines} / '
                            '${summary.totalMachines}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: '  ·  ${summary.remainingMachines} remaining',
                        style: TextStyle(
                          color: Colors.white.withOpacity(.55),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_formatPercent(percent)}%',
                style: TextStyle(
                  color: done ? _success : _accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (percent / 100.0).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(.10),
              valueColor: AlwaysStoppedAnimation<Color>(
                done ? _success : _accent,
              ),
            ),
          ),
        ],
      );
    } else if (error != null) {
      body = Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Unable to load progress',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(.65),
                fontSize: 12,
              ),
            ),
          ),
          _retrySummaryButton(),
        ],
      );
    } else {
      // Loading lần đầu: skeleton gọn.
      body = ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          minHeight: 6,
          backgroundColor: Colors.white.withOpacity(.08),
          valueColor: AlwaysStoppedAnimation<Color>(_accent.withOpacity(.5)),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'AUDIT PROGRESS',
                style: TextStyle(
                  color: Colors.white.withOpacity(.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                ),
              ),
              const Spacer(),
              // Refresh chạy nền khi đã có số liệu cũ.
              if (_loadingAuditSummary && summary != null) ...[
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: _accent,
                  ),
                ),
                const SizedBox(width: 6),
              ] else if (error != null && summary != null) ...[
                _retrySummaryButton(),
                const SizedBox(width: 4),
              ],
              if (period.isNotEmpty)
                Text(
                  period,
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          body,
        ],
      ),
    );
  }

  Widget _retrySummaryButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: _loadingAuditSummary ? null : _loadAuditSummary,
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(Icons.refresh_rounded, size: 16, color: _accent),
      ),
    );
  }

  // ------------------------------------------------------------
  // LOCATION CARD
  // ------------------------------------------------------------

  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  _isAutoMode ? 'MASTER LOCATION' : 'LOCATION',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
              ),
              const Spacer(),
              _buildModeToggle(),
            ],
          ),
          const SizedBox(height: 8),
          if (_isAutoMode)
            _buildMasterLocation()
          else
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _buildSelectors(),
            ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeChip(
            FixedAssetLocationMode.auto,
            'Auto',
            Icons.qr_code_scanner_rounded,
          ),
          _modeChip(
            FixedAssetLocationMode.manual,
            'Manual',
            Icons.tune_rounded,
          ),
        ],
      ),
    );
  }

  Widget _modeChip(FixedAssetLocationMode mode, String label, IconData icon) {
    final selected = _locationMode == mode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: selected ? null : () => _setLocationMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? _accent.withOpacity(.20) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? _accent : Colors.white.withOpacity(.55),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white.withOpacity(.6),
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMasterLocation() {
    final location = _masterLocation;

    if (location == null) {
      return Text(
        'Scan a machine to resolve location',
        style: TextStyle(color: Colors.white.withOpacity(.5), fontSize: 12.5),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _locationValue('Fac', location.fac)),
            const SizedBox(width: 12),
            Expanded(child: _locationValue('Floor', location.floor)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _locationValue('Position A', location.positionA)),
            const SizedBox(width: 12),
            Expanded(child: _locationValue('Position AA', location.positionAA)),
          ],
        ),
      ],
    );
  }

  Widget _locationValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          style: TextStyle(color: Colors.white.withOpacity(.5), fontSize: 11),
        ),
        Text(
          value.isEmpty ? '-' : value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectors() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _selector(
                label: 'Fac',
                value: selectedFac,
                items: facs,
                enabled: true,
                loading: _loadingFacs,
                onChanged: _onFacChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _selector(
                label: 'Floor',
                value: selectedFloor,
                items: floors,
                enabled: selectedFac != null,
                loading: _loadingFloors,
                onChanged: _onFloorChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _selector(
                label: 'PositionA',
                value: selectedPositionA,
                items: positionAs,
                enabled: selectedFloor != null,
                loading: _loadingPositionA,
                onChanged: _onPositionAChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _selector(
                label: 'PositionAA',
                value: selectedPositionAA,
                items: positionAAs,
                enabled: selectedPositionA != null,
                loading: _loadingPositionAA,
                onChanged: _onPositionAAChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _selector({
    required String label,
    required String? value,
    required List<String> items,
    required bool enabled,
    required bool loading,
    required ValueChanged<String?> onChanged,
  }) {
    final active = enabled && !loading;

    return Stack(
      alignment: Alignment.centerRight,
      children: [
        IgnorePointer(
          ignoring: !active,
          child: Opacity(
            opacity: enabled ? 1 : .45,
            child: CommonSearchableDropdown(
              label: label,
              selectedValue: value,
              items: items,
              allowAddNew: false,
              onChanged: onChanged,
            ),
          ),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(right: 36),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------
  // MACHINE LIST
  // ------------------------------------------------------------

  Widget _buildMachineSection() {
    if (_activeLocation == null) {
      return const SizedBox.shrink();
    }

    if (_loadingMachines) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
          ),
        ),
      );
    }

    if (_machineError != null) {
      return _compactMessage(
        _machineError!,
        icon: Icons.error_outline_rounded,
        iconColor: Colors.redAccent,
      );
    }

    if (machines.isEmpty) {
      return _compactMessage('No machines found.');
    }

    final query = _machineSearch.trim().toLowerCase();
    final filtered = query.isEmpty
        ? machines
        : machines
              .where(
                (m) =>
                    m.machineCode.toLowerCase().contains(query) ||
                    m.faName.toLowerCase().contains(query),
              )
              .toList(growable: false);

    // Machine đã audit lên đầu. Chia nhóm (stable) để giữ nguyên thứ tự
    // gốc trong từng nhóm; không mutate `machines`.
    final audited = <FixedAssetMachine>[];
    final notAudited = <FixedAssetMachine>[];
    for (final machine in filtered) {
      (_isAuditedMachine(machine) ? audited : notAudited).add(machine);
    }
    final displayMachines = [...audited, ...notAudited];

    // Chiều cao list có giới hạn, list tự cuộn bên trong.
    final maxListHeight = (MediaQuery.of(context).size.height * 0.38).clamp(
      160.0,
      300.0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMachineHeader(filtered.length),
        const SizedBox(height: 6),
        if (filtered.isEmpty)
          _compactMessage('No matching machines.')
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxListHeight),
            child: ListView.separated(
              primary: false,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: displayMachines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) =>
                  _buildMachineRow(displayMachines[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildMachineHeader(int visibleCount) {
    final total = machines.length;
    final countText = _machineSearch.trim().isEmpty
        ? '$total'
        : '$visibleCount / $total';

    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Machines',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          countText,
          style: const TextStyle(
            color: _accent,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    return Row(
      children: [
        Padding(padding: const EdgeInsets.only(left: 4), child: title),
        const SizedBox(width: 8),
        Expanded(child: _buildMachineSearchField()),
      ],
    );
  }

  Widget _buildMachineSearchField() {
    final hasText = _machineSearch.isNotEmpty;

    return SizedBox(
      height: 38,
      child: TextField(
        controller: _machineSearchController,
        onChanged: (value) => setState(() => _machineSearch = value),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        cursorColor: _accent,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search machine...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(.5),
            fontSize: 13,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(.08),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: Colors.white.withOpacity(.6),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 34,
            minHeight: 34,
          ),
          suffixIcon: hasText
              ? InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => setState(() {
                    _machineSearch = '';
                    _machineSearchController.clear();
                  }),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white.withOpacity(.7),
                  ),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _accent.withOpacity(.35)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _accent, width: 1.2),
          ),
        ),
      ),
    );
  }

  /// MachineCode đã có trong audit history (exact, không phân biệt hoa
  /// thường). Chỉ là feedback hiển thị, không phải selection.
  bool _isAuditedMachine(FixedAssetMachine machine) {
    final code = machine.machineCode.trim().toLowerCase();
    return code.isNotEmpty && _auditedMachineCodes.contains(code);
  }

  Widget _buildMachineRow(FixedAssetMachine machine) {
    final audited = _isAuditedMachine(machine);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  machine.machineCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (machine.faName.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    machine.faName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.62),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (audited) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle_rounded, size: 18, color: _success),
          ],
        ],
      ),
    );
  }

  Widget _compactMessage(
    String message, {
    IconData? icon,
    Color? iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white.withOpacity(.65),
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
