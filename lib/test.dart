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

part 'camera_screen/camera_screen_models.dart';
part 'camera_screen/camera_screen_ai.dart';
part 'camera_screen/camera_screen_qr.dart';
part 'camera_screen/camera_screen_report.dart';
part 'camera_screen/camera_screen_camera.dart';
part 'camera_screen/camera_screen_view.dart';
part 'camera_screen/camera_screen_form_widgets.dart';

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

  @override
  Widget build(BuildContext context) => _buildCameraScreen(context);

  List<AutoCmp> allOptionsComment = []; // Biến lưu trữ dữ liệu
  List<AutoCmp> allOptionsCounter = []; // Biến lưu trữ dữ liệu
  bool isLoading = true;
}
