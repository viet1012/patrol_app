import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chuphinh/camera_preview_box.dart';
import 'package:chuphinh/translator.dart';
import 'package:chuphinh/widget/glass_action_button.dart';
import 'package:dio/dio.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'ai/machine_ai_alert_card.dart';
import 'api/api_error_message.dart';
import 'api/auto_cmp_api.dart';
import 'api/dio_client.dart';
import 'api/hse_master_service.dart';
import 'common/common_ui_helper.dart';
import 'edit/edit_before_screen.dart';
import 'homeScreen/patrol_home_screen.dart';
import 'login/login_page.dart';
import 'model/auto_cmp.dart';
import 'model/hse_patrol_team_model.dart';
import 'model/machine_model.dart';
import 'model/reason_model.dart';
import 'model/risk_score_calculator.dart';

class _ReportServerMessage {
  final String? code;
  final String? message;

  const _ReportServerMessage({this.code, this.message});
}

class HseMachineInfo {
  final String plant;
  final String fac;
  final String area;
  final String macId;

  const HseMachineInfo({
    required this.plant,
    required this.fac,
    required this.area,
    required this.macId,
  });

  factory HseMachineInfo.fromJson(Map<String, dynamic> json) {
    return HseMachineInfo(
      plant: (json['plant'] ?? '').toString().trim(),
      fac: (json['fac'] ?? '').toString().trim(),
      area: (json['area'] ?? '').toString().trim(),
      macId: (json['macId'] ?? '').toString().trim(),
    );
  }
}

class QrCheckResult {
  final String? qrKey;
  final bool valid;
  final bool available;
  final bool duplicate;
  final String message;

  const QrCheckResult({
    required this.qrKey,
    required this.valid,
    required this.available,
    required this.duplicate,
    required this.message,
  });

  factory QrCheckResult.fromJson(Map<String, dynamic> json) {
    return QrCheckResult(
      qrKey: json['qrKey']?.toString().trim(),
      valid: json['valid'] == true,
      available: json['available'] == true,
      duplicate: json['duplicate'] == true,
      message: json['message']?.toString().trim() ?? '',
    );
  }
}

class CameraScreen extends StatefulWidget {
  final List<MachineModel> machines;
  final List<HsePatrolTeamModel> patrolTeams;

  final String? selectedPlant;
  final String lang;

  final PatrolGroup patrolGroup;
  final String titleScreen;
  final String accountCode;
  final HsePatrolTeamModel? autoTeam;

  const CameraScreen({
    super.key,
    required this.machines,
    required this.patrolTeams,
    required this.selectedPlant,
    required this.titleScreen,
    required this.lang,
    required this.patrolGroup,
    required this.accountCode,
    this.autoTeam,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  String? _selectedPlant;
  String? _selectedFac;
  String? _selectedArea;
  String? _selectedMachine;
  String? _selectedGroup;
  int numbersGroup = 7;

  String _comment = '';
  String _counterMeasure = '';
  bool _needRecheck = false;
  String? _freq;
  String? _prob;
  String? _sev;

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  final TextEditingController _counterController = TextEditingController();
  final FocusNode _counterFocusNode = FocusNode();

  Timer? _commentDebounce;
  Timer? _counterDebounce;

  String? _employeeName;
  bool _isLoadingName = false;

  // ? QA states
  String? _qaFreq; // dùng chung key frequency_often...
  String? _qa5m; // 1 l?a ch?n
  String? _qaImpact; // 1 l?a ch?n

  bool _isLoadingMachineInfo = false;
  String? _loadingMacId;

  HseMachineInfo? _qrFallbackMachine;

  MachineAiSummary? _machineAiSummary;
  bool _isLoadingMachineAi = false;
  String? _machineAiError;
  String? _lastAiMachine;

  bool _isTranslatingAi = false;
  String? _summaryJp;

  String _qrKey = '';

  bool _isCheckingQr = false;

  /// QR dang du?c g?i API ki?m tra.
  /// Dùng d? tránh scanner g?i cùng QR nhi?u l?n.
  String? _checkingQrKey;

  // CameraPreviewBoxState là nguồn trạng thái camera thật duy nhất.
  // Hai biến dưới đây chỉ phục vụ render UI và khóa thao tác.
  bool _cameraUiSleeping = false;
  bool _cameraSwitching = false;
  bool _isSubmitting = false;

  // Chỉ phần AppBar ảnh/nút Send lắng nghe notifier này.
  // Thay đổi ảnh không còn rebuild toàn bộ CameraScreen.
  final ValueNotifier<List<Uint8List>> _imagesNotifier =
      ValueNotifier<List<Uint8List>>(const <Uint8List>[]);

  // Font size của hai ô text được cập nhật cục bộ.
  final ValueNotifier<double> _commentFontSizeNotifier = ValueNotifier<double>(
    14,
  );
  final ValueNotifier<double> _counterFontSizeNotifier = ValueNotifier<double>(
    14,
  );

  // Cache master data để không quét widget.machines trong mỗi build().
  final Map<String, List<String>> _facByPlantCache = <String, List<String>>{};
  final Map<String, List<String>> _areaByPlantFacCache =
      <String, List<String>>{};
  final Map<String, List<String>> _machineByPlantFacAreaCache =
      <String, List<String>>{};
  final Map<String, List<String>> _groupsByPlantCache =
      <String, List<String>>{};
  final Set<String> _localMachineKeys = <String>{};

  /// QR g?n nh?t dã ki?m tra thành công.
  String? _lastValidQrKey;

  @override
  void initState() {
    super.initState();

    final team = widget.autoTeam;

    // ? Patrol Before uu tiên nh?n Plant / Fac / Group t? _loadTeams
    if (team != null) {
      _selectedPlant = team.plant;
      _selectedFac = team.fac;
      _selectedGroup = team.grp;
    } else {
      _selectedPlant = widget.selectedPlant;
    }

    debugPrint('Camera selectedPlant = $_selectedPlant');
    debugPrint('Camera selectedFac = $_selectedFac');
    debugPrint('Camera selectedGroup = $_selectedGroup');

    _buildMasterIndexes();

    fetchEmployeeName(
      widget.accountCode,
    ).then((name) => debugPrint('EMPLOYEE NAME = $name'));

    _loadInitialDataComment();
    _loadInitialDataCounter();
  }

  @override
  void dispose() {
    _commentDebounce?.cancel();
    _counterDebounce?.cancel();
    _commentController.dispose();
    _counterController.dispose();
    _commentFocusNode.dispose();
    _counterFocusNode.dispose();
    _imagesNotifier.dispose();
    _commentFontSizeNotifier.dispose();
    _counterFontSizeNotifier.dispose();
    super.dispose();
  }

  Future<void> _translateAiSummaryToJp() async {
    final vi = _machineAiSummary?.summaryVi?.trim();

    if (vi == null || vi.isEmpty) return;
    if (_summaryJp != null && _summaryJp!.isNotEmpty) return;

    setState(() {
      _isTranslatingAi = true;
    });

    try {
      final response = await DioClient.post(
        '/api/patrol_report/translate-ai-summary',
        data: {'text': vi},
      );

      final data = response.data;

      if (!mounted) return;

      setState(() {
        _summaryJp = data['text']?.toString();
      });
    } catch (e) {
      debugPrint('Translate AI summary error: $e');
    } finally {
      if (!mounted) return;

      setState(() {
        _isTranslatingAi = false;
      });
    }
  }

  Future<void> _loadMachineAiSummary(
    String? machine, {
    bool force = false,
  }) async {
    final mac = machine?.trim();

    if (mac == null || mac.isEmpty) return;

    if (!force && _lastAiMachine == mac && _machineAiSummary != null) {
      return;
    }

    setState(() {
      _isLoadingMachineAi = true;
      _machineAiError = null;
      _machineAiSummary = null;
      _summaryJp = null;
      _lastAiMachine = mac;
    });
    try {
      final response = await DioClient.get(
        '/api/patrol_report/analyze-machine',
        queryParameters: {'machine': mac},
      );

      final data = response.data;

      if (!mounted) return;

      if (data is Map) {
        ;
        final summary = MachineAiSummary.fromJson(
          Map<String, dynamic>.from(data),
        );

        setState(() {
          _machineAiSummary = summary;
          _summaryJp = null;
        });

        if (widget.lang.toUpperCase() == 'JP') {
          await _translateAiSummaryToJp();
        }
      } else {
        setState(() {
          _machineAiError = 'Invalid AI response';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _machineAiError = 'Unable to load AI summary';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoadingMachineAi = false;
      });
    }
  }

  Future<String?> fetchEmployeeName(String code) async {
    final empCode = code.trim();
    if (empCode.isEmpty) return null;

    if (!mounted) return null;
    setState(() => _isLoadingName = true);

    try {
      final name = await HseMasterService.fetchEmployeeName(empCode);

      if (!mounted) return null;
      setState(() => _employeeName = name);
      return name;
    } catch (e) {
      debugPrint('Error fetching employee name: $e');

      if (!mounted) return null;
      setState(() => _employeeName = null);
      return null;
    } finally {
      if (!mounted) return null;
      setState(() => _isLoadingName = false);
    }
  }

  int get totalScore {
    int f = frequencyOptions
        .firstWhere(
          (e) => e.labelKey == _freq,
          orElse: () => const RiskOption(labelKey: "", score: 0),
        )
        .score;

    int p = probabilityOptions
        .firstWhere(
          (e) => e.labelKey == _prob,
          orElse: () => const RiskOption(labelKey: "", score: 0),
        )
        .score;

    int s = severityOptions
        .firstWhere(
          (e) => e.labelKey == _sev,
          orElse: () => const RiskOption(labelKey: "", score: 0),
        )
        .score;

    return f + p + s;
  }

  String getScoreSymbol() {
    // N?u chua ch?n d? 3 thì tr? v? r?ng
    if (_freq == null || _prob == null || _sev == null) {
      return "";
    }

    final score = totalScore;

    if (score >= 16) return "V";
    if (score >= 12) return "IV";
    if (score >= 9) return "III";
    if (score >= 6) return "II";
    if (score >= 3) return "I";
    return "-";
  }

  final GlobalKey<CameraPreviewBoxState> _cameraKey =
      GlobalKey<CameraPreviewBoxState>();

  List<String> get groupList =>
      List<String>.generate(numbersGroup, (index) => 'Group ${index + 1}');

  String _cacheKey2(String first, String second) {
    return '${_norm(first)}|${_norm(second)}';
  }

  String _cacheKey3(String first, String second, String third) {
    return '${_norm(first)}|${_norm(second)}|${_norm(third)}';
  }

  void _addUnique(Map<String, List<String>> target, String key, String value) {
    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) return;

    final values = target.putIfAbsent(key, () => <String>[]);

    final exists = values.any((item) => _norm(item) == _norm(normalizedValue));

    if (!exists) {
      values.add(normalizedValue);
    }
  }

  void _buildMasterIndexes() {
    _facByPlantCache.clear();
    _areaByPlantFacCache.clear();
    _machineByPlantFacAreaCache.clear();
    _groupsByPlantCache.clear();
    _localMachineKeys.clear();

    for (final team in widget.patrolTeams) {
      final plant = team.plant?.toString().trim() ?? '';
      final group = team.grp?.toString().trim() ?? '';

      if (plant.isEmpty || group.isEmpty) continue;

      _addUnique(_groupsByPlantCache, _norm(plant), group);
    }

    for (final item in widget.machines) {
      final plant = item.plant.toString().trim();
      final fac = item.fac.toString().trim();
      final area = item.area.toString().trim();
      final machine = item.macId.toString().trim();

      if (plant.isEmpty) continue;

      if (fac.isNotEmpty) {
        _addUnique(_facByPlantCache, _norm(plant), fac);
      }

      if (fac.isNotEmpty && area.isNotEmpty) {
        _addUnique(_areaByPlantFacCache, _cacheKey2(plant, fac), area);
      }

      if (fac.isNotEmpty && area.isNotEmpty && machine.isNotEmpty) {
        _addUnique(
          _machineByPlantFacAreaCache,
          _cacheKey3(plant, fac, area),
          machine,
        );

        _localMachineKeys.add(
          '${_cacheKey3(plant, fac, area)}|${_norm(machine)}',
        );
      }
    }

    for (final values in _facByPlantCache.values) {
      values.sort();
    }

    for (final values in _areaByPlantFacCache.values) {
      values.sort();
    }

    for (final values in _machineByPlantFacAreaCache.values) {
      values.sort();
    }

    for (final values in _groupsByPlantCache.values) {
      values.sort();
    }
  }

  List<String> getPlants() {
    final plants = _facByPlantCache.keys.toList(growable: false);
    plants.sort();
    return plants;
  }

  List<String> getGroupsByPlant() {
    final plant = _selectedPlant;
    if (plant == null || plant.trim().isEmpty) {
      return const <String>[];
    }

    return _groupsByPlantCache[_norm(plant)] ?? const <String>[];
  }

  List<String> getFacByPlant(String plant) {
    return _facByPlantCache[_norm(plant)] ?? const <String>[];
  }

  List<String> getAreaByFac(String plant, String fac) {
    return _areaByPlantFacCache[_cacheKey2(plant, fac)] ?? const <String>[];
  }

  List<String> getMachineByArea(String plant, String fac, String area) {
    return _machineByPlantFacAreaCache[_cacheKey3(plant, fac, area)] ??
        const <String>[];
  }

  String normalizeGroup(String? group) {
    return group == null ? '' : group.replaceAll(' ', '').trim();
  }

  String _extractMacIdFromQr(String qr) {
    final text = qr.trim();

    // KVH_A-2681_1F_A32-1_Retainer
    final match = RegExp(r'[A-Z]-\d+').firstMatch(text);

    if (match != null) {
      return match.group(0)!;
    }

    // A-769
    return text;
  }

  String? _extractAreaFromQr(String qr) {
    final parts = qr.trim().split('_');

    // KVH_A-2003_1F_A35-2_Ejector Pin
    if (parts.length >= 5) {
      final area = parts.sublist(4).join('_').trim();
      return area.isEmpty ? null : area;
    }

    return null;
  }

  HseMachineInfo _buildFallbackMachineInfoFromQr({
    required String rawQr,
    required String macId,
  }) {
    return HseMachineInfo(
      plant: _selectedPlant ?? widget.selectedPlant ?? '',
      fac: _selectedFac ?? '',
      area: _extractAreaFromQr(rawQr) ?? _selectedArea ?? '',
      macId: macId,
    );
  }

  Future<HseMachineInfo?> _fetchMachineInfoByMacId(String macId) async {
    try {
      final response = await DioClient.get(
        '/api/hse_master/by-macid',
        queryParameters: {'macId': macId},
      );

      final data = response.data;

      if (data == null) return null;

      if (data is List && data.isNotEmpty) {
        final first = data.first;

        if (first is Map) {
          return HseMachineInfo.fromJson(Map<String, dynamic>.from(first));
        }
      }

      if (data is Map) {
        return HseMachineInfo.fromJson(Map<String, dynamic>.from(data));
      }

      return null;
    } catch (e) {
      debugPrint('FETCH MACHINE INFO ERROR: $e');
      return null;
    }
  }

  bool _isBlank(String? value) {
    return value == null || value.trim().isEmpty;
  }

  String _norm(String? v) {
    return (v ?? '')
        .replaceAll(String.fromCharCode(160), ' ')
        .trim()
        .toLowerCase();
  }

  bool _existsInLocalMaster(HseMachineInfo info) {
    final key =
        '${_cacheKey3(info.plant, info.fac, info.area)}|${_norm(info.macId)}';

    return _localMachineKeys.contains(key);
  }

  Future<void> _handlePatrolQr(String rawQr) async {
    final qr = rawQr.trim();

    if (!RegExp(r'^\d{1,5}$').hasMatch(qr)) {
      if (!mounted) return;

      CommonUI.showWarning(
        context: context,
        title: 'Invalid QR Code',
        message:
            'QR code must contain only numbers and have a maximum of 5 digits.',
      );

      return;
    }

    // Ðã check thành công QR này r?i thì không g?i API l?i.
    if (_lastValidQrKey == qr && _qrKey == qr) {
      return;
    }

    // Scanner dang gi? camera trên cùng QR.
    // Không cho t?o thêm request trùng.
    if (_isCheckingQr && _checkingQrKey == qr) {
      return;
    }

    // Có request QR khác dang ch?y thì b? qua lu?t scan này.
    if (_isCheckingQr) {
      return;
    }

    setState(() {
      _isCheckingQr = true;
      _checkingQrKey = qr;
    });

    try {
      final result = await _checkQrDuplicate(qr);

      if (!mounted) return;

      if (!result.valid) {
        /*
       * Không gi? QR không h?p l? trên state cha.
       * Reset ph?n hi?n th? QR trong CameraPreviewBox.
       */
        _cameraKey.currentState?.resetQr();

        CommonUI.showWarning(
          context: context,
          title: 'Invalid QR Code',
          message: result.message.isNotEmpty
              ? result.message
              : 'Invalid QR code.',
        );

        return;
      }

      if (result.duplicate || !result.available) {
        /*
       * QR b? trùng thì không gán vào _qrKey.
       * UI camera cung xóa QR v?a quét d? ngu?i dùng quét mã khác.
       */
        _cameraKey.currentState?.resetQr();

        CommonUI.showWarning(
          context: context,
          title: 'Duplicate QR Code',
          message: result.message.isNotEmpty
              ? result.message
              : 'QR code $qr already exists and has not been closed.',
        );

        return;
      }

      final acceptedQr = result.qrKey == null || result.qrKey!.isEmpty
          ? qr
          : result.qrKey!;

      setState(() {
        _qrKey = acceptedQr;
        _lastValidQrKey = acceptedQr;
      });

      CommonUI.showSnackBar(
        context: context,
        message: 'QR code $acceptedQr is available.',
        color: Colors.green,
      );
    } on DioException catch (error) {
      if (!mounted) return;

      /*
     * API check l?i thì không nên ch?p nh?n QR,
     * vì chua xác d?nh du?c QR có trùng hay không.
     */
      _cameraKey.currentState?.resetQr();

      CommonUI.showWarning(
        context: context,
        title: 'QR Check Failed',
        message: error.type == DioExceptionType.connectionTimeout
            ? 'Connection timeout while checking QR code.'
            : error.type == DioExceptionType.receiveTimeout
            ? 'The server took too long to check the QR code.'
            : ApiErrorMessage.fromDio(error),
      );
    } catch (error) {
      if (!mounted) return;

      _cameraKey.currentState?.resetQr();

      CommonUI.showWarning(
        context: context,
        title: 'QR Check Failed',
        message: 'Unable to verify QR code. Please scan again.',
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isCheckingQr = false;
        _checkingQrKey = null;
      });
    }
  }

  Future<void> _handleQrDetected(String qr) async {
    final rawQr = qr.trim();

    if (rawQr.isEmpty) return;

    final isQrNumber = RegExp(r'^\d+$').hasMatch(rawQr);

    // ============================================================
    // QR NUMBER
    // ============================================================

    if (isQrNumber) {
      // Ch? Patrol m?i ki?m tra QR trùng.
      if (widget.patrolGroup == PatrolGroup.Patrol) {
        await _handlePatrolQr(rawQr);
        return;
      }

      // Audit / Quality Patrol / Asset Update:
      // ch? luu QR, không g?i API check trùng.
      if (!mounted) return;

      setState(() {
        _qrKey = rawQr;
      });

      return;
    }

    // ============================================================
    // QR MACHINE
    // ============================================================

    if (_isLoadingMachineInfo) return;

    final macId = _extractMacIdFromQr(rawQr);

    if (macId.trim().isEmpty) return;

    setState(() {
      _isLoadingMachineInfo = true;
      _loadingMacId = macId;
    });

    try {
      final apiInfo = await _fetchMachineInfoByMacId(macId);

      if (!mounted) return;

      final fallbackInfo = _buildFallbackMachineInfoFromQr(
        rawQr: rawQr,
        macId: macId,
      );

      final info = apiInfo ?? fallbackInfo;

      final validInMaster = _existsInLocalMaster(info);

      final samePlant = _norm(info.plant) == _norm(widget.selectedPlant);

      final shouldUseFallback = apiInfo == null || !validInMaster || !samePlant;

      final selectedInfo = shouldUseFallback ? fallbackInfo : info;

      setState(() {
        _qrFallbackMachine = shouldUseFallback ? fallbackInfo : null;

        _selectedPlant = selectedInfo.plant;
        _selectedFac = selectedInfo.fac;
        _selectedArea = selectedInfo.area;
        _selectedMachine = selectedInfo.macId;

        // Không thay d?i _qrKey.
        // Quét QR máy không du?c làm m?t QR Patrol.
      });

      if (_aiEnabled) {
        _loadMachineAiSummary(selectedInfo.macId);
      }

      CommonUI.showSnackBar(
        context: context,
        message: shouldUseFallback
            ? 'Machine added from QR: ${selectedInfo.macId}'
            : 'Machine detected: ${selectedInfo.macId}',
        color: shouldUseFallback ? Colors.orange : Colors.green,
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoadingMachineInfo = false;
        _loadingMacId = null;
      });
    }
  }

  Future<QrCheckResult> _checkQrDuplicate(String qrKey) async {
    final normalizedQr = qrKey.trim();

    final response = await DioClient.get(
      '/api/report/check-qr',
      queryParameters: {'qrKey': normalizedQr},
    );

    final data = response.data;

    if (data is! Map) {
      throw const FormatException('Invalid QR check response.');
    }

    return QrCheckResult.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> _sendReport() async {
    if (_isSubmitting) return;

    final isPatrol = widget.patrolGroup == PatrolGroup.Patrol;
    final isQA = widget.patrolGroup == PatrolGroup.QualityPatrol;
    final qrKey = _qrKey.trim();

    final images = List<Uint8List>.from(
      _cameraKey.currentState?.images ?? const <Uint8List>[],
    );

    if (images.isEmpty) {
      CommonUI.showWarning(
        context: context,
        title: 'Image Required',
        message: 'Please take at least one photo.',
      );
      return;
    }

    if (isPatrol && !RegExp(r'^\d{1,5}$').hasMatch(qrKey)) {
      CommonUI.showWarning(
        context: context,
        title: 'QR Required',
        message: 'Please scan a valid Patrol QR containing 1 to 5 digits.',
      );
      return;
    }

    if (isPatrol &&
        (_isBlank(_selectedPlant) ||
            _isBlank(_selectedFac) ||
            _isBlank(_selectedArea) ||
            _isBlank(_selectedMachine))) {
      CommonUI.showWarning(
        context: context,
        title: 'Information Required',
        message: 'Please select Plant, Fac, Area and Machine.',
      );
      return;
    }

    final latestComment = _commentController.text.trim();
    final latestCounterMeasure = _counterController.text.trim();

    if (latestComment.isEmpty) {
      CommonUI.showWarning(
        context: context,
        title: 'Comment Required',
        message: 'Please enter a comment.',
      );
      return;
    }

    final plant = _selectedPlant?.trim() ?? '';
    final division = _selectedFac?.trim() ?? '';
    final area = _selectedArea?.trim() ?? '';
    final machine = _selectedMachine?.trim() ?? '';

    final cameraState = _cameraKey.currentState;
    final cameraWasSleeping = cameraState?.isCameraSleeping ?? true;

    final totalWatch = Stopwatch()..start();
    var loadingVisible = false;

    void hideLoading() {
      if (!loadingVisible) return;
      loadingVisible = false;
      LoadingDialog.hide();
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isSubmitting = true;
    });

    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) return;

    unawaited(LoadingDialog.show(context, message: 'Sending report...'));
    loadingVisible = true;

    try {
      if (!cameraWasSleeping) {
        final cameraSleepWatch = Stopwatch()..start();
        await cameraState?.sleepCamera();
        cameraSleepWatch.stop();

        debugPrint(
          'REPORT CAMERA SLEEP TIME: '
          '${cameraSleepWatch.elapsedMilliseconds} ms',
        );
      }

      final prepareWatch = Stopwatch()..start();

      final imageFiles = List<MultipartFile>.generate(
        images.length,
        (index) => MultipartFile.fromBytes(
          images[index],
          filename: 'photo_${index + 1}.jpg',
          contentType: http.MediaType('image', 'jpeg'),
        ),
        growable: false,
      );

      final employeeName = _employeeName?.trim() ?? '';
      final accountCode = widget.accountCode.trim();

      final userCreate = employeeName.isEmpty
          ? accountCode
          : '${accountCode}_$employeeName';

      final latestComment = _commentController.text.trim();

      final latestCounterMeasure = _counterController.text.trim();

      if (latestComment.isEmpty) {
        CommonUI.showWarning(
          context: context,
          title: 'Comment Required',
          message: 'Please enter a comment.',
        );
        return;
      }

      final bool isJapaneseUser = widget.lang.trim().toUpperCase() == 'JP';

      final reportMap = <String, dynamic>{
        'userCreate': userCreate,
        'qr_key': qrKey,
        'qr_scan_sts': qrKey.isNotEmpty ? 'SUCCESS_1st' : '',
        'type': widget.patrolGroup.name,
        'group': _selectedGroup?.trim() ?? '',
        'plant': plant,
        'division': division,
        'area': area,
        'machine': machine,
        'check': _needRecheck
            ? (area.isNotEmpty
                  ? ''.combinedViJa(context, 'needRecheck')
                  : ''.combinedViJa(context, 'needSelectArea'))
            : '',
      };

      if (isJapaneseUser) {
        reportMap.addAll({
          // Không lưu tiếng Nhật nhầm vào cột tiếng Việt
          'comment': '',
          'countermeasure': '',

          // Nội dung do người Nhật nhập
          'comment_jp': latestComment,
          'countermeasure_jp': latestCounterMeasure,
        });
      } else {
        reportMap.addAll({
          // Nội dung do người Việt nhập
          'comment': latestComment,
          'countermeasure': latestCounterMeasure,

          // Python daemon sẽ dịch và cập nhật sau
          'comment_jp': '',
          'countermeasure_jp': '',
        });
      }

      if (isQA) {
        reportMap.addAll({
          'riskFreq': ''.combinedViJa(context, _qaFreq ?? ''),
          'riskProb': ''.combinedViJa(context, _qa5m ?? ''),
          'riskSev': ''.combinedViJa(context, _qaImpact ?? ''),
          'riskTotal': '',
        });
      } else {
        reportMap.addAll({
          'riskFreq': ''.combinedViJa(context, _freq ?? ''),
          'riskProb': ''.combinedViJa(context, _prob ?? ''),
          'riskSev': ''.combinedViJa(context, _sev ?? ''),
          'riskTotal': getScoreSymbol(),
        });
      }

      final formData = FormData.fromMap({
        'report': jsonEncode(reportMap),
        'images': imageFiles,
      });

      prepareWatch.stop();

      final totalImageBytes = images.fold<int>(
        0,
        (sum, image) => sum + image.lengthInBytes,
      );

      debugPrint('REPORT PREPARE TIME: ${prepareWatch.elapsedMilliseconds} ms');
      debugPrint('REPORT IMAGE COUNT: ${images.length}');
      debugPrint('REPORT IMAGE BYTES: $totalImageBytes');
      debugPrint(
        'REPORT IMAGE SIZE MB: '
        '${(totalImageBytes / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      final uploadWatch = Stopwatch()..start();

      final response = await DioClient.postUpload(
        '/api/report',
        data: formData,
      );

      uploadWatch.stop();

      debugPrint('REPORT UPLOAD TIME: ${uploadWatch.elapsedMilliseconds} ms');

      hideLoading();

      if (!mounted) return;

      final statusCode = response.statusCode ?? 0;
      final serverResult = _parseServerResponse(response.data);

      debugPrint('REPORT RESPONSE STATUS: $statusCode');
      debugPrint('REPORT RESPONSE CODE: ${serverResult.code}');
      debugPrint('REPORT RESPONSE MESSAGE: ${serverResult.message}');

      if (statusCode >= 200 && statusCode < 300) {
        CommonUI.showSnackBar(
          context: context,
          message: 'Successfully sent ${images.length} images!',
          color: Colors.green,
        );

        _resetForm();
        return;
      }

      _showReportServerError(
        statusCode: statusCode,
        serverCode: serverResult.code,
        serverMessage: serverResult.message,
        qrKey: qrKey,
      );
    } on DioException catch (error, stackTrace) {
      hideLoading();

      debugPrint('========== SEND REPORT DIO ERROR ==========');
      debugPrint('TYPE: ${error.type}');
      debugPrint('STATUS: ${error.response?.statusCode}');
      debugPrint('DATA: ${error.response?.data}');
      debugPrint('MESSAGE: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _handleReportDioError(error: error, qrKey: qrKey);
    } catch (error, stackTrace) {
      hideLoading();

      debugPrint('========== SEND REPORT FLUTTER ERROR ==========');
      debugPrint('ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      CommonUI.showSnackBar(
        context: context,
        message: ApiErrorMessage.fromFlutter(error),
        color: Colors.red,
      );
    } finally {
      hideLoading();

      totalWatch.stop();
      debugPrint('REPORT TOTAL TIME: ${totalWatch.elapsedMilliseconds} ms');

      if (!cameraWasSleeping && mounted) {
        final cameraWakeWatch = Stopwatch()..start();
        final started = await cameraState?.wakeCamera();
        cameraWakeWatch.stop();

        debugPrint(
          'REPORT CAMERA WAKE TIME: '
          '${cameraWakeWatch.elapsedMilliseconds} ms',
        );
        debugPrint('REPORT CAMERA WAKE RESULT: $started');
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  _ReportServerMessage _parseServerResponse(dynamic responseData) {
    if (responseData is Map) {
      return _ReportServerMessage(
        code: responseData['code']?.toString().trim(),
        message: responseData['message']?.toString().trim(),
      );
    }

    if (responseData is String && responseData.trim().isNotEmpty) {
      final raw = responseData.trim();

      try {
        final decoded = jsonDecode(raw);

        if (decoded is Map) {
          return _ReportServerMessage(
            code: decoded['code']?.toString().trim(),
            message: decoded['message']?.toString().trim(),
          );
        }
      } catch (_) {
        return _ReportServerMessage(message: raw);
      }

      return _ReportServerMessage(message: raw);
    }

    return const _ReportServerMessage();
  }

  void _showReportServerError({
    required int statusCode,
    required String? serverCode,
    required String? serverMessage,
    required String qrKey,
  }) {
    if (!mounted) return;

    final message = serverMessage?.trim() ?? '';

    if (statusCode == 409 || serverCode == 'DUPLICATE_QR') {
      CommonUI.showWarning(
        context: context,
        title: 'Duplicate QR Code',
        message: message.isNotEmpty
            ? message
            : 'QR code $qrKey already exists and has not been closed.',
      );
      return;
    }

    if (statusCode == 400 && serverCode == 'INVALID_QR') {
      CommonUI.showWarning(
        context: context,
        title: 'Invalid QR Code',
        message: message.isNotEmpty
            ? message
            : 'QR code must contain only numbers and have a maximum of 5 digits.',
      );
      return;
    }

    CommonUI.showSnackBar(
      context: context,
      message: message.isNotEmpty ? message : 'Unable to submit the report.',
      color: Colors.red,
    );
  }

  void _handleReportDioError({
    required DioException error,
    required String qrKey,
  }) {
    if (!mounted) return;

    final statusCode = error.response?.statusCode ?? 0;
    final serverResult = _parseServerResponse(error.response?.data);
    final serverCode = serverResult.code;
    final serverMessage = serverResult.message?.trim() ?? '';

    if (statusCode == 409 || serverCode == 'DUPLICATE_QR') {
      CommonUI.showWarning(
        context: context,
        title: 'Duplicate QR Code',
        message: serverMessage.isNotEmpty
            ? serverMessage
            : 'QR code $qrKey already exists and has not been closed.',
      );
      return;
    }

    if (statusCode == 400 && serverCode == 'INVALID_QR') {
      CommonUI.showWarning(
        context: context,
        title: 'Invalid QR Code',
        message: serverMessage.isNotEmpty
            ? serverMessage
            : 'QR code must contain only numbers and have a maximum of 5 digits.',
      );
      return;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        CommonUI.showWarning(
          context: context,
          title: 'Connection Timeout',
          message: 'The server took too long to connect. Please try again.',
        );
        return;

      case DioExceptionType.sendTimeout:
        CommonUI.showWarning(
          context: context,
          title: 'Upload Timeout',
          message:
              'The images took too long to upload. Please check the network and try again.',
        );
        return;

      case DioExceptionType.receiveTimeout:
        CommonUI.showWarning(
          context: context,
          title: 'Server Timeout',
          message:
              'The server is still processing the report. Please check the report before sending again.',
        );
        return;

      case DioExceptionType.connectionError:
        CommonUI.showWarning(
          context: context,
          title: 'Connection Error',
          message:
              'Unable to connect to the server. Please check the network connection.',
        );
        return;

      default:
        CommonUI.showSnackBar(
          context: context,
          message: serverMessage.isNotEmpty
              ? serverMessage
              : ApiErrorMessage.fromDio(error),
          color: Colors.red,
        );
    }
  }

  double _resolveFontSize(String text) {
    final length = text.length;

    if (length > 120) return 11;
    if (length > 80) return 12;
    if (length > 40) return 13;

    return 14;
  }

  void _resetForm() {
    setState(() {
      _selectedMachine = null;

      _comment = '';
      _counterMeasure = '';

      _commentController.clear();
      _counterController.clear();
      _commentFontSizeNotifier.value = 14;
      _counterFontSizeNotifier.value = 14;

      _freq = null;
      _prob = null;
      _sev = null;

      _qaFreq = null;
      _qa5m = null;
      _qaImpact = null;

      _needRecheck = false;

      _qrKey = '';
      _lastValidQrKey = null;
      _checkingQrKey = null;
      _isCheckingQr = false;
    });

    _cameraKey.currentState?.clearAll();
    _cameraKey.currentState?.resetQr();
    _imagesNotifier.value = const <Uint8List>[];
  }

  bool _aiEnabled = false;

  void _onMachineChanged(String? machine) {
    final mac = machine?.trim();

    setState(() {
      _selectedMachine = mac == null || mac.isEmpty ? null : mac;
      _machineAiSummary = null;
      _machineAiError = null;
      _lastAiMachine = null;
    });

    if (_aiEnabled && mac != null && mac.isNotEmpty) {
      _loadMachineAiSummary(mac);
    }
  }

  Future<void> _toggleCameraPower() async {
    if (_cameraSwitching) return;

    final camera = _cameraKey.currentState;
    if (camera == null) {
      if (!mounted) return;
      CommonUI.showWarning(
        context: context,
        title: 'Camera Error',
        message: 'Camera is not ready.',
      );
      return;
    }

    setState(() => _cameraSwitching = true);

    try {
      final success = camera.isCameraSleeping
          ? await camera.wakeCamera()
          : await _sleepCamera(camera);

      if (!mounted) return;

      _cameraUiSleeping = camera.isCameraSleeping;

      if (!success && !camera.isCameraSleeping) {
        CommonUI.showWarning(
          context: context,
          title: 'Camera Error',
          message: 'Unable to start camera. Please check camera permission.',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Toggle camera error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      CommonUI.showWarning(
        context: context,
        title: 'Camera Error',
        message: 'Unable to change camera state.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _cameraSwitching = false;
          _cameraUiSleeping = _cameraKey.currentState?.isCameraSleeping ?? true;
        });
      }
    }
  }

  Future<bool> _sleepCamera(CameraPreviewBoxState camera) async {
    await camera.sleepCamera();
    return camera.isCameraSleeping;
  }

  void _onCameraSleepingChanged(bool sleeping) {
    if (!mounted || _cameraUiSleeping == sleeping) return;
    setState(() => _cameraUiSleeping = sleeping);
  }

  Widget _buildBatterySavingTip() {
    final sleeping = _cameraUiSleeping;
    final color = sleeping ? const Color(0xFF22C55E) : Colors.amber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.32)),
      ),
      child: Row(
        children: [
          Icon(
            sleeping
                ? Icons.videocam_off_rounded
                : Icons.battery_saver_outlined,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Battery Saving',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sleeping
                      ? 'Camera and QR scanner are off.'
                      : 'Turn off camera while walking to save battery.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.68),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: _cameraSwitching ? null : _toggleCameraPower,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              constraints: const BoxConstraints(minWidth: 58, minHeight: 30),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _cameraSwitching
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      sleeping ? 'WAKE' : 'OFF',
                      style: TextStyle(
                        color: sleeping ? Colors.white : Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSection() {
    return SizedBox(
      width: 340,
      height: 340,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CameraPreviewBox(
              key: _cameraKey,
              size: 340,
              plant: _selectedPlant,
              type: widget.patrolGroup.name,
              group: _selectedGroup,
              patrolGroup: widget.patrolGroup,
              onImagesChanged: (images) {
                _imagesNotifier.value = List<Uint8List>.unmodifiable(images);
              },
              onQrDetected: _handleQrDetected,
              onCameraSleepingChanged: _onCameraSleepingChanged,
            ),
          ),
          if (_isCheckingQr && !_cameraUiSleeping)
            Positioned.fill(child: _buildCheckingQrOverlay()),
        ],
      ),
    );
  }

  Widget _buildCheckingQrOverlay() {
    return Container(
      alignment: Alignment.center,
      color: Colors.black.withOpacity(.20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF22C55E).withOpacity(.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF22C55E),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Checking QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((_checkingQrKey ?? '').isNotEmpty)
                  Text(
                    _checkingQrKey!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.65),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupList = getGroupsByPlant();

    final facList = <String>{
      if (_selectedPlant != null) ...getFacByPlant(_selectedPlant!),

      if (_qrFallbackMachine != null &&
          _norm(_qrFallbackMachine!.plant) == _norm(_selectedPlant) &&
          _qrFallbackMachine!.fac.isNotEmpty)
        _qrFallbackMachine!.fac,
    }.toList();

    final areaList = <String>{
      if (_selectedPlant != null && _selectedFac != null)
        ...getAreaByFac(_selectedPlant!, _selectedFac!),

      if (_qrFallbackMachine != null &&
          _norm(_qrFallbackMachine!.plant) == _norm(_selectedPlant) &&
          _norm(_qrFallbackMachine!.fac) == _norm(_selectedFac) &&
          _qrFallbackMachine!.area.isNotEmpty)
        _qrFallbackMachine!.area,
    }.toList();

    final machineList = <String>{
      if (_selectedPlant != null &&
          _selectedFac != null &&
          _selectedArea != null)
        ...getMachineByArea(_selectedPlant!, _selectedFac!, _selectedArea!),

      if (_qrFallbackMachine != null &&
          _norm(_qrFallbackMachine!.plant) == _norm(_selectedPlant) &&
          _norm(_qrFallbackMachine!.fac) == _norm(_selectedFac) &&
          _norm(_qrFallbackMachine!.area) == _norm(_selectedArea) &&
          _qrFallbackMachine!.macId.isNotEmpty)
        _qrFallbackMachine!.macId,
    }.toList();

    final minLength = (widget.lang == 'JP') ? 1 : 2;

    return Scaffold(
      // ? QUAN TR?NG: Giúp giao di?n t? co lên khi bàn phím hi?n
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Color(0xFF121826),
        // soft dark blue
        centerTitle: false,
        titleSpacing: 4,
        leading: GlassActionButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.titleScreen,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectedPlant ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ValueListenableBuilder<List<Uint8List>>(
            valueListenable: _imagesNotifier,
            builder: (context, images, _) {
              final hasImages = images.isNotEmpty;
              final canSubmit = hasImages && !_isSubmitting;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasImages)
                    SizedBox(
                      width: 168,
                      height: 52,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          final image = images[index];

                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    image,
                                    width: 50,
                                    height: 50,
                                    cacheWidth: 100,
                                    cacheHeight: 100,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    filterQuality: FilterQuality.low,
                                  ),
                                ),
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: GestureDetector(
                                    onTap: _isSubmitting
                                        ? null
                                        : () {
                                            _cameraKey.currentState
                                                ?.removeImage(index);
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  GlassActionButton(
                    icon: _isSubmitting
                        ? Icons.hourglass_top_rounded
                        : Icons.send_rounded,
                    enabled: canSubmit,
                    onTap: canSubmit ? _sendReport : null,
                    backgroundColor: canSubmit ? const Color(0xFF22C55E) : null,
                    iconColor: canSubmit ? Colors.black : Colors.white54,
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,

        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF121826), // soft dark blue
              Color(0xFF1F2937), // slate blue
              Color(0xFF374151), // soft steel
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              // CAMERA + QR CHECK OVERLAY
              _buildCameraSection(),
              const SizedBox(height: 8),

              _buildBatterySavingTip(),

              const SizedBox(height: 16),
              if (widget.patrolGroup != PatrolGroup.AssetUpdate) ...[
                // CÁC DROPDOWN PHÍA TRÊN
                Row(
                  children: [
                    Expanded(
                      child: _buildSearchableDropdown(
                        label: "group".tr(context),
                        selectedValue: _selectedGroup,
                        items: groupList,
                        onChanged: (v) {
                          setState(() {
                            _selectedGroup = v;
                          });
                        },
                        isRequired: true,
                      ),
                    ),

                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSearchableDropdown(
                        label: "fac".tr(context),
                        selectedValue: _selectedFac,
                        items: _selectedPlant == null
                            ? <String>[]
                            : facList.cast<String>(),
                        onChanged: (v) {
                          setState(() {
                            _selectedFac = v;
                            _selectedArea = null;

                            final isFallbackMachine =
                                _qrFallbackMachine != null &&
                                _norm(_qrFallbackMachine!.macId) ==
                                    _norm(_selectedMachine);

                            if (!isFallbackMachine) {
                              _selectedMachine = null;
                            }

                            if (isFallbackMachine) {
                              _qrFallbackMachine = HseMachineInfo(
                                plant:
                                    _selectedPlant ??
                                    widget.selectedPlant ??
                                    '',
                                fac: v ?? '',
                                area: _selectedArea ?? '',
                                macId:
                                    _selectedMachine ??
                                    _qrFallbackMachine!.macId,
                              );
                            }

                            final areas = getAreaByFac(_selectedPlant!, v!);
                            if (!isFallbackMachine && areas.length == 1) {
                              _selectedArea = areas.first;

                              final machines = getMachineByArea(
                                _selectedPlant!,
                                v,
                                areas.first,
                              );

                              if (machines.length == 1) {
                                _selectedMachine = machines.first;
                              }
                            }
                          });
                        },
                        isRequired: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    if (widget.patrolGroup != PatrolGroup.AssetUpdate)
                      Expanded(
                        child: _buildSearchableDropdown(
                          label: "area".tr(context),
                          selectedValue: _selectedArea,
                          items:
                              (_selectedPlant == null || _selectedFac == null)
                              ? <String>[]
                              : areaList.cast<String>(),
                          onChanged: (v) {
                            String? autoMachine;

                            setState(() {
                              _selectedArea = v;

                              final isFallbackMachine =
                                  _qrFallbackMachine != null &&
                                  _norm(_qrFallbackMachine!.macId) ==
                                      _norm(_selectedMachine);

                              if (!isFallbackMachine) {
                                _selectedMachine = null;
                              }

                              if (isFallbackMachine) {
                                _qrFallbackMachine = HseMachineInfo(
                                  plant:
                                      _selectedPlant ??
                                      widget.selectedPlant ??
                                      '',
                                  fac: _selectedFac ?? '',
                                  area: v ?? '',
                                  macId:
                                      _selectedMachine ??
                                      _qrFallbackMachine!.macId,
                                );
                              }

                              final machines = getMachineByArea(
                                _selectedPlant!,
                                _selectedFac!,
                                v!,
                              );

                              if (!isFallbackMachine && machines.length == 1) {
                                autoMachine = machines.first;
                                _selectedMachine = autoMachine;
                              }
                            });

                            if (_aiEnabled && autoMachine != null) {
                              _loadMachineAiSummary(autoMachine);
                            }
                          },
                          isRequired: true,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSearchableDropdown(
                        label: "machine".tr(context),
                        selectedValue: _selectedMachine,
                        items:
                            (_selectedPlant == null ||
                                _selectedFac == null ||
                                _selectedArea == null)
                            ? <String>[]
                            : machineList.cast<String>(),
                        onChanged: _onMachineChanged,
                        isRequired: true,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),

              MachineAiRiskHistoryPanel(
                lang: widget.lang,
                enabled: _aiEnabled,
                loading: _isLoadingMachineAi,
                hasMachine: (_selectedMachine?.isNotEmpty ?? false),
                machine: _selectedMachine,
                error: _machineAiError,
                summary: _machineAiSummary,
                summaryJp: _summaryJp,
                translatingJp: _isTranslatingAi,
                onTranslateJp: _translateAiSummaryToJp,
                onRetry: () =>
                    _loadMachineAiSummary(_selectedMachine, force: true),
                onToggle: () {
                  final mac = _selectedMachine ?? '';

                  setState(() {
                    _aiEnabled = !_aiEnabled;
                  });

                  if (_aiEnabled) {
                    _loadMachineAiSummary(mac);
                  } else {
                    setState(() {
                      _machineAiSummary = null;
                      _machineAiError = null;
                      _lastAiMachine = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              // CÁC DROPDOWN RISK
              if (widget.patrolGroup != PatrolGroup.AssetUpdate)
                _buildRiskSection(),

              const SizedBox(height: 8),

              // ---------------------------------------------------------
              // PH?N AUTO COMPLETE ÐÃ T?I UU CHO MOBILE
              // ---------------------------------------------------------
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ô 1: COMMENT
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return RawAutocomplete<AutoCmp>(
                          textEditingController: _commentController,
                          focusNode: _commentFocusNode,
                          optionsViewOpenDirection: OptionsViewOpenDirection.up,
                          displayStringForOption: (option) => option.inputText,

                          optionsBuilder: (TextEditingValue value) {
                            final keyword = value.text.trim().toLowerCase();

                            if (keyword.length < minLength || isLoading) {
                              return const Iterable<AutoCmp>.empty();
                            }

                            return allOptionsComment
                                .where(
                                  (option) => option.inputText
                                      .toLowerCase()
                                      .contains(keyword),
                                )
                                .take(5);
                          },

                          onSelected: (AutoCmp selection) {
                            final comment = selection.inputText.trim();

                            _commentController.value = TextEditingValue(
                              text: comment,
                              selection: TextSelection.collapsed(
                                offset: comment.length,
                              ),
                            );

                            final countermeasure = selection.countermeasure
                                .trim();

                            _counterController.value = TextEditingValue(
                              text: countermeasure,
                              selection: TextSelection.collapsed(
                                offset: countermeasure.length,
                              ),
                            );

                            setState(() {
                              _comment = comment;
                              _counterMeasure = countermeasure;
                              _commentFontSizeNotifier.value = _resolveFontSize(
                                comment,
                              );
                              _counterFontSizeNotifier.value = _resolveFontSize(
                                countermeasure,
                              );
                            });
                          },

                          fieldViewBuilder:
                              (
                                context,
                                controller,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                // Không gán lại _commentController = controller.
                                // RawAutocomplete đang dùng chính _commentController.
                                return ValueListenableBuilder<double>(
                                  valueListenable: _commentFontSizeNotifier,
                                  builder: (context, fontSize, _) {
                                    return TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      enabled: !_isSubmitting,
                                      maxLines: 3,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: fontSize,
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        hint: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'commentHint'.tr(context),
                                              style: TextStyle(
                                                color: Colors.red.withOpacity(
                                                  .6,
                                                ),
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.star_rounded,
                                              size: 14,
                                              color: Colors.red.withOpacity(.6),
                                            ),
                                          ],
                                        ),
                                        fillColor: Colors.green.withOpacity(
                                          .08,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.white.withOpacity(
                                              .35,
                                            ),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: BorderSide(
                                            color: const Color(
                                              0xFF90E14D,
                                            ).withOpacity(.25),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: BorderSide(
                                            color: const Color(
                                              0xFF90E14D,
                                            ).withOpacity(.45),
                                          ),
                                        ),
                                        contentPadding: const EdgeInsets.all(
                                          12,
                                        ),
                                      ),
                                      onChanged: (value) {
                                        _commentFontSizeNotifier.value =
                                            _resolveFontSize(value);

                                        if (value.trim().isEmpty) {
                                          _counterController.clear();
                                          _counterFontSizeNotifier.value = 14;
                                        }

                                        _commentDebounce?.cancel();
                                        _commentDebounce = Timer(
                                          const Duration(milliseconds: 250),
                                          () {
                                            _comment = value;

                                            if (value.trim().isEmpty) {
                                              _counterMeasure = '';
                                            }
                                          },
                                        );
                                      },
                                    );
                                  },
                                );
                              },

                          optionsViewBuilder: (context, onSelected, options) {
                            final optionList = options.toList(growable: false);

                            return Align(
                              alignment: Alignment.topLeft,
                              child: Transform.translate(
                                offset: const Offset(0, 8),
                                child: Material(
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.black.withOpacity(.5),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth,
                                      maxHeight: 250,
                                    ),
                                    child: ListView.separated(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: optionList.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(
                                            height: 1,
                                            thickness: .5,
                                          ),
                                      itemBuilder: (context, index) {
                                        final option = optionList[index];

                                        return InkWell(
                                          onTap: () => onSelected(option),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            child: Text(
                                              option.inputText,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  if (widget.patrolGroup != PatrolGroup.AssetUpdate) ...[
                    const SizedBox(width: 8),
                    // Ô 2: COUNTERMEASURE (gi? nguyên, không c?n linking ngu?c)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return RawAutocomplete<AutoCmp>(
                            textEditingController: _counterController,
                            focusNode: _counterFocusNode,
                            optionsViewOpenDirection:
                                OptionsViewOpenDirection.up,
                            displayStringForOption: (option) =>
                                option.inputText,

                            optionsBuilder: (TextEditingValue value) {
                              final keyword = value.text.trim().toLowerCase();

                              if (keyword.length < minLength || isLoading) {
                                return const Iterable<AutoCmp>.empty();
                              }

                              return allOptionsCounter
                                  .where(
                                    (option) => option.inputText
                                        .toLowerCase()
                                        .contains(keyword),
                                  )
                                  .take(5);
                            },

                            onSelected: (AutoCmp selection) {
                              final countermeasure = selection.inputText.trim();

                              _counterController.value = TextEditingValue(
                                text: countermeasure,
                                selection: TextSelection.collapsed(
                                  offset: countermeasure.length,
                                ),
                              );

                              setState(() {
                                _counterMeasure = countermeasure;
                                _counterFontSizeNotifier.value =
                                    _resolveFontSize(countermeasure);
                              });
                            },

                            fieldViewBuilder:
                                (
                                  context,
                                  controller,
                                  focusNode,
                                  onFieldSubmitted,
                                ) {
                                  // Không gán lại _counterController = controller.
                                  return ValueListenableBuilder<double>(
                                    valueListenable: _counterFontSizeNotifier,
                                    builder: (context, fontSize, _) {
                                      return TextField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        enabled: !_isSubmitting,
                                        maxLines: 3,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: fontSize,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'counterMeasureHint'.tr(
                                            context,
                                          ),
                                          filled: true,
                                          fillColor: Colors.green.withOpacity(
                                            .08,
                                          ),
                                          hintStyle: TextStyle(
                                            color: Colors.white.withOpacity(.6),
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.white.withOpacity(
                                                .35,
                                              ),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: const Color(
                                                0xFF90E14D,
                                              ).withOpacity(.25),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: const Color(
                                                0xFF90E14D,
                                              ).withOpacity(.45),
                                            ),
                                          ),
                                          contentPadding: const EdgeInsets.all(
                                            12,
                                          ),
                                        ),
                                        onChanged: (value) {
                                          _counterFontSizeNotifier.value =
                                              _resolveFontSize(value);

                                          _counterDebounce?.cancel();
                                          _counterDebounce = Timer(
                                            const Duration(milliseconds: 250),
                                            () {
                                              _counterMeasure = value;
                                            },
                                          );
                                        },
                                      );
                                    },
                                  );
                                },

                            optionsViewBuilder: (context, onSelected, options) {
                              final optionList = options.toList(
                                growable: false,
                              );

                              return Align(
                                alignment: Alignment.topLeft,
                                child: Transform.translate(
                                  offset: const Offset(0, 8),
                                  child: Material(
                                    elevation: 8,
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.black.withOpacity(.5),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: constraints.maxWidth,
                                        maxHeight: 250,
                                      ),
                                      child: ListView.separated(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: optionList.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(
                                              height: 1,
                                              thickness: .5,
                                            ),
                                        itemBuilder: (context, index) {
                                          final option = optionList[index];

                                          return InkWell(
                                            onTap: () => onSelected(option),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 14,
                                                  ),
                                              child: Text(
                                                option.inputText,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),

              // Checkbox và ph?n cu?i
              if (widget.patrolGroup != PatrolGroup.AssetUpdate)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Checkbox(
                          value: _needRecheck,
                          onChanged: _isSubmitting
                              ? null
                              : (v) =>
                                    setState(() => _needRecheck = v ?? false),
                          activeColor: Colors.orange.shade700,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "needRecheck".tr(context),
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                      ),
                      GlassActionButton(
                        icon: Icons.edit_calendar_sharp,
                        enabled: true,
                        onTap: () {
                          // if (_selectedGroup == null || _selectedGroup!.isEmpty) {
                          //   _showSelectGroupWarning(context);
                          //   return;
                          // }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditBeforeScreen(
                                machines: widget.machines,
                                accountCode: widget.accountCode,
                                selectedFac: _selectedFac,
                                selectedPlant: _selectedPlant,
                                selectedGrp: widget.autoTeam?.grp ?? '',
                                titleScreen: widget.titleScreen,
                                patrolGroup: widget.patrolGroup,
                              ),
                            ),
                          );
                        },
                        backgroundColor: const Color(
                          0xFF22C55E,
                        ).withOpacity(.4),
                        iconColor: Colors.white,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<AutoCmp> allOptionsComment = []; // Biến lưu trữ dữ liệu
  List<AutoCmp> allOptionsCounter = []; // Biến lưu trữ dữ liệu
  bool isLoading = true;

  Future<void> _loadInitialDataComment() async {
    try {
      final data = await AutoCmpApi.getAllComment(widget.lang);
      setState(() {
        allOptionsComment = data;
        isLoading = false;
      });
    } catch (e) {
      // Xử lý lỗi
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadInitialDataCounter() async {
    try {
      final data = await AutoCmpApi.getAllCounter(widget.lang);
      setState(() {
        allOptionsCounter = data;
        isLoading = false;
      });
    } catch (e) {
      // Xử lý lỗi
      setState(() => isLoading = false);
    }
  }

  Widget _buildRiskSection() {
    switch (widget.patrolGroup) {
      case PatrolGroup.QualityPatrol:
        return _buildQualityRiskSection();
      case PatrolGroup.Audit:
      case PatrolGroup.AssetUpdate:
      case PatrolGroup.Patrol:
        return _buildPatrolRiskSection();
    }
  }

  Widget _buildPatrolRiskSection() {
    final displayScore = RiskScoreCalculator.scoreSymbol(
      freqKey: _freq,
      probKey: _prob,
      sevKey: _sev,
      frequencyOptions: frequencyOptions,
      probabilityOptions: probabilityOptions,
      severityOptions: severityOptions,
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildRiskDropdown(
                labelKey: "label_freq",
                valueKey: _freq,
                items: frequencyOptions,
                onChanged: (v) => setState(() => _freq = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRiskDropdown(
                labelKey: "label_prob",
                valueKey: _prob,
                items: probabilityOptions,
                onChanged: (v) => setState(() => _prob = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildRiskDropdown(
                labelKey: "label_sev",
                valueKey: _sev,
                items: severityOptions,
                onChanged: (v) => setState(() => _sev = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _buildRiskScoreField(displayScore)),
          ],
        ),
      ],
    );
  }

  Widget _buildRiskScoreField(String displayScore) {
    return TextField(
      enabled: false,
      controller: TextEditingController(text: displayScore),
      decoration: InputDecoration(
        labelText: "label_risk".tr(context),
        filled: true,
        fillColor: Colors.deepOrange.withOpacity(0.15),
        labelStyle: TextStyle(
          fontSize: 14,
          color: Colors.white.withOpacity(0.65),
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: Colors.deepOrange,
          fontWeight: FontWeight.bold,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.deepOrange.withOpacity(0.6)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 18,
        color: (displayScore == "V" || displayScore == "IV")
            ? Colors.red
            : Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildQualityRiskSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 5. Tần suất phát sinh
        _buildRiskDropdown(
          labelKey: "label_freq",
          valueKey: _qaFreq,
          items: qaFrequencyOptions,
          onChanged: (v) => setState(() => _qaFreq = v),
        ),

        const SizedBox(height: 12),

        // 6. 5M phát sinh  (dropdown)
        _buildRiskDropdown(
          labelKey: "label_5m",
          valueKey: _qa5m,
          items: fiveMOptions,
          onChanged: (v) => setState(() => _qa5m = v),
        ),

        const SizedBox(height: 12),

        // 7. Mức độ ảnh hưởng đến chất lượng sản phẩm (dropdown)
        _buildRiskDropdown(
          labelKey: "label_quality_impact",
          valueKey: _qaImpact,
          items: qualityImpactOptions,
          onChanged: (v) => setState(() => _qaImpact = v),
        ),
      ],
    );
  }

  // 🔴 HÀM PHỤ TRỢ: _buildSearchableDropdown (Giữ nguyên)
  Widget _buildSearchableDropdown({
    required String label,
    required String? selectedValue,
    required List<String> items,
    required Function(String?)? onChanged,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          child: DropdownSearch<String>(
            popupProps: PopupProps.menu(
              showSearchBox: true,
              isFilterOnline: true,
              fit: FlexFit.loose,
              menuProps: MenuProps(
                backgroundColor: const Color(0xFF161D23),
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),

              /// 🔴 NO DATA FOUND CUSTOM
              emptyBuilder: (context, searchEntry) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 40,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "No data found", // hoặc "No data found"
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  hintText: "search_or_add_new".tr(context),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(
                  color: Colors.white, // <-- set màu chữ nhập thành trắng
                ),
              ),

              itemBuilder: (context, item, isSelected) {
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected
                        ? Colors.white.withOpacity(0.12)
                        : Colors.transparent,
                  ),
                  child: AutoSizeText(
                    item,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),

            // ... (các logic asyncItems, compareFn, v.v. giữ nguyên)
            asyncItems: (String filter) async {
              var result = items
                  .where((e) => e.toLowerCase().contains(filter.toLowerCase()))
                  .toList();

              // Nếu filter không rỗng và chưa có trong items thì thêm vào đầu danh sách
              if (filter.isNotEmpty && !items.contains(filter.trim())) {
                result.insert(0, filter.trim());
              }
              return result;
            },
            compareFn: (item, selectedItem) =>
                item.trim() == selectedItem.trim(),

            selectedItem: selectedValue ?? '',

            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                hintText: label,
                hintMaxLines: 1,
                floatingLabelBehavior: FloatingLabelBehavior.never,

                /// 🌫️ nền glass
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.35)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: const Color(0xFF4DD0E1).withOpacity(0.45),
                  ),
                ),

                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFF4DD0E1), // cyan
                    width: 1.6,
                  ),
                ),

                contentPadding: const EdgeInsets.fromLTRB(12, 14, 12, 12),

                /// 📝 hint
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ),

            dropdownBuilder: (context, selectedItem) {
              final bool isEmpty = selectedItem == null || selectedItem.isEmpty;

              Color textColor;
              FontWeight fontWeight;

              if (isEmpty && isRequired) {
                textColor = Colors.red.withOpacity(.6);
                fontWeight = FontWeight.w600;
              } else if (!isEmpty) {
                textColor = Colors.white;
                fontWeight = FontWeight.bold;
              } else {
                textColor = Colors.white.withOpacity(0.6);
                fontWeight = FontWeight.w500;
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  /// 📝 TEXT
                  Expanded(
                    child: AutoSizeText(
                      isEmpty ? label : selectedItem,
                      maxLines: 2,
                      minFontSize: 11,
                      stepGranularity: 0.5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: fontWeight,
                        color: textColor,
                      ),
                    ),
                  ),

                  /// ⭐ REQUIRED ICON
                  if (isRequired && isEmpty) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.star_rounded, // ⭐
                      size: 14,
                      color: Colors.red.withOpacity(.6),
                    ),
                  ],
                ],
              );
            },

            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // 🔴 HÀM PHỤ TRỢ: _buildRiskDropdown (Giữ nguyên)
  Widget _buildRiskDropdown({
    required String labelKey,
    required String? valueKey,
    required List<RiskOption> items,
    required Function(String?) onChanged,
  }) {
    // Tập key hợp lệ
    final validKeys = items.map((e) => e.labelKey).toSet();

    // ✅ Nếu valueKey null hoặc không nằm trong items -> trả null cho dropdown
    final safeValue = (valueKey != null && validKeys.contains(valueKey))
        ? valueKey
        : null;
    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      dropdownColor: const Color(0xFF2A2E32),

      // nền dropdown
      decoration: InputDecoration(
        labelText: labelKey.tr(context),

        /// 🌫️ nền mờ
        filled: true,
        fillColor: Colors.orange.withOpacity(0.08),

        /// 🔲 viền
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.35),
            width: 1.2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: const Color(0xFF7986CB).withOpacity(0.45),
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7986CB), width: 1.8),
        ),

        contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 14),

        /// 📝 label bình thường
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.65),
          fontSize: 14,
        ),

        /// 🏷️ label khi bay lên
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF7986CB),
          fontWeight: FontWeight.bold,
        ),
      ),

      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      selectedItemBuilder: (context) {
        return items.map((e) {
          return Container(
            alignment: Alignment.centerLeft,
            child: Text(
              e.labelKey.tr(context),
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }).toList();
      },

      items: items.map((e) {
        return DropdownMenuItem<String>(
          value: e.labelKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.labelKey.tr(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                "(${e.score})",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }).toList(),

      onChanged: (v) => setState(() => onChanged(v)),
    );
  }

  void showGlassDialog({
    required BuildContext context,
    IconData icon = Icons.info_outline,
    Color iconColor = Colors.blueAccent,
    String title = '',
    String message = '',
    String buttonText = 'OK',
    VoidCallback? onPressed,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// ICON
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: iconColor.withOpacity(0.15),
                    ),
                    child: Icon(icon, color: iconColor, size: 42),
                  ),

                  const SizedBox(height: 16),

                  /// TITLE
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),

                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),

                  /// BUTTON
                  SizedBox(
                    width: 150,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.9),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onPressed?.call();
                      },
                      child: Text(
                        buttonText,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
