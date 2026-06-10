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

import 'ai/ai_analysis_toggle.dart';
import 'ai/machine_ai_alert_card.dart';
import 'api/auth_api.dart';
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

  TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  TextEditingController _counterController = TextEditingController();
  final FocusNode _counterFocusNode = FocusNode();

  Timer? _commentDebounce;
  Timer? _counterDebounce;

  String? _employeeName;
  bool _isLoadingName = false;

  // ✅ QA states
  String? _qaFreq; // dùng chung key frequency_often...
  String? _qa5m; // 1 lựa chọn
  String? _qaImpact; // 1 lựa chọn

  bool _isLoadingMachineInfo = false;
  String? _loadingMacId;

  HseMachineInfo? _qrFallbackMachine;

  MachineAiSummary? _machineAiSummary;
  bool _isLoadingMachineAi = false;
  String? _machineAiError;
  String? _lastAiMachine;

  bool _isTranslatingAi = false;
  String? _summaryJp;

  // @override
  // void initState() {
  //   // _selectedPlant = widget.selectedPlant;
  //   super.initState();
  //   final team = widget.autoTeam;
  //
  //   // auto select Plant - Fac - Group
  //   if (team != null) {
  //     _selectedPlant = team.plant;
  //     _selectedFac = team.fac;
  //     _selectedGroup = team.grp;
  //   } else {
  //     _selectedPlant = widget.selectedPlant;
  //   }
  //   fetchEmployeeName(
  //     widget.accountCode,
  //   ).then((name) => debugPrint('EMPLOYEE NAME = $name'));
  //   _loadInitialDataComment();
  //   _loadInitialDataCounter();
  // }

  @override
  void initState() {
    super.initState();

    final team = widget.autoTeam;

    // ✅ Patrol Before ưu tiên nhận Plant / Fac / Group từ _loadTeams
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
    _commentFocusNode.dispose();
    _counterFocusNode.dispose();
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
        // setState(() {
        //   _machineAiSummary = MachineAiSummary.fromJson(
        //     Map<String, dynamic>.from(data),
        //   );
        // });
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
    // Nếu chưa chọn đủ 3 thì trả về rỗng
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
      List.generate(numbersGroup, (index) => 'Group ${index + 1}');

  List<String> getPlants() {
    final Set<String> unique = {};
    return widget.machines
        .map((m) => m.plant.toString())
        .where((p) => p.isNotEmpty)
        .where((p) => unique.add(p))
        .toList();
  }

  List<String> getGroupsByPlant() {
    return widget.patrolTeams
        .where((e) => e.plant == _selectedPlant)
        .map((e) => e.grp)
        .whereType<String>()
        .toSet() // tránh trùng
        .toList();
  }

  List<String> getFacByPlant(String plant) {
    final Set<String> unique = {};
    return widget.machines
        .where((m) => m.plant.toString() == plant)
        .map((m) => m.fac.toString())
        .where((f) => f.isNotEmpty)
        .where((f) => unique.add(f))
        .toList();
  }

  List<String> getAreaByFac(String plant, String fac) {
    final Set<String> unique = {};
    return widget.machines
        .where((m) => m.plant.toString() == plant)
        .where((m) => m.fac.toString() == fac)
        .map((m) => m.area.toString())
        .where((a) => a.isNotEmpty)
        .where((a) => unique.add(a))
        .toList();
  }

  List<String> getMachineByArea(String plant, String fac, String area) {
    final Set<String> unique = {};
    return widget.machines
        .where((m) => m.plant.toString() == plant)
        .where((m) => m.fac.toString() == fac)
        .where((m) => m.area.toString() == area)
        .map((m) => m.macId.toString())
        .where((id) => id.isNotEmpty)
        .where((id) => unique.add(id))
        .toList();
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
    return widget.machines.any((m) {
      return _norm(m.plant.toString()) == _norm(info.plant) &&
          _norm(m.fac.toString()) == _norm(info.fac) &&
          _norm(m.area.toString()) == _norm(info.area) &&
          _norm(m.macId.toString()) == _norm(info.macId);
    });
  }

  Future<void> _handleQrDetected(String qr) async {
    if (_isLoadingMachineInfo) return;

    final rawQr = qr.trim();
    final isQrNumber = RegExp(r'^\d+$').hasMatch(rawQr);
    final macId = _extractMacIdFromQr(rawQr);

    if (isQrNumber) {
      setState(() {
        _qrKey = rawQr;
      });
      return;
    }

    setState(() {
      _isLoadingMachineInfo = true;
      _loadingMacId = macId;
      _qrKey = rawQr;
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
        if (shouldUseFallback) {
          _qrFallbackMachine = fallbackInfo;
        } else {
          _qrFallbackMachine = null;
        }

        _selectedPlant = selectedInfo.plant;
        _selectedFac = selectedInfo.fac;
        _selectedArea = selectedInfo.area;
        _selectedMachine = selectedInfo.macId;
      });

      if (_aiEnabled) {
        _loadMachineAiSummary(selectedInfo.macId);
      }
      // _loadMachineAiSummary(selectedInfo.macId);

      // setState(() {
      //   _selectedPlant = selectedInfo.plant;
      //   _selectedFac = selectedInfo.fac;
      //   _selectedArea = selectedInfo.area;
      //   _selectedMachine = selectedInfo.macId;
      // });

      if (shouldUseFallback) {
        CommonUI.showSnackBar(
          context: context,
          message: 'Machine added from QR: ${selectedInfo.macId}',
          color: Colors.orange,
        );
      } else {
        CommonUI.showSnackBar(
          context: context,
          message: 'Machine detected: ${selectedInfo.macId}',
          color: Colors.green,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMachineInfo = false;
          _loadingMacId = null;
        });
      }
    }
  }

  Future<void> _sendReport() async {
    final isPatrol = widget.patrolGroup == PatrolGroup.Patrol;
    final isQA = widget.patrolGroup == PatrolGroup.QualityPatrol;

    final images = _cameraKey.currentState?.images ?? [];
    final hasQr = _qrKey.trim().isNotEmpty;

    ////////////////////////////////////////////////////////////
    /// VALIDATE
    ////////////////////////////////////////////////////////////
    if (_qrKey.trim().isEmpty && isPatrol) {
      CommonUI.showWarning(
        context: context,
        icon: Icons.qr_code_rounded,
        title: "QR Required",
        message: "Please scan QR code before sending report.",
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
        title: "Information Required",
        message: "Please select Plant, Fac, Area and Machine.",
      );
      return;
    }

    if (_comment.trim().isEmpty) {
      CommonUI.showWarning(
        context: context,
        title: "Comment Required",
        message: "Please enter a comment.",
      );
      return;
    }

    ////////////////////////////////////////////////////////////
    /// LOADING
    ////////////////////////////////////////////////////////////
    LoadingDialog.show(context);

    try {
      ////////////////////////////////////////////////////////////
      /// IMAGE
      ////////////////////////////////////////////////////////////
      final imageFiles = <MultipartFile>[];

      for (int i = 0; i < images.length; i++) {
        imageFiles.add(
          MultipartFile.fromBytes(
            images[i],
            filename: 'photo_${i + 1}.jpg',
            contentType: http.MediaType('image', 'jpeg'),
          ),
        );
      }

      ////////////////////////////////////////////////////////////
      /// REPORT BASE
      ////////////////////////////////////////////////////////////
      final reportMap = <String, dynamic>{
        'userCreate': '${widget.accountCode}_$_employeeName',
        'qr_key': _qrKey ?? '',
        'qr_scan_sts': hasQr ? 'SUCCESS_1st' : '',
        'type': widget.patrolGroup.name,
        'group': _selectedGroup ?? '',
        'plant': _selectedPlant!.trim(),
        'division': _selectedFac!.trim(),
        'area': _selectedArea!.trim(),
        'machine': _selectedMachine!.trim(),
        'comment': _comment,
        'countermeasure': _counterMeasure,
        'check': _needRecheck
            ? (_selectedArea != null
                  ? ''.combinedViJa(context, 'needRecheck')
                  : ''.combinedViJa(context, 'needSelectArea'))
            : '',
      };

      ////////////////////////////////////////////////////////////
      /// REPORT TYPE
      ////////////////////////////////////////////////////////////
      if (!isQA) {
        reportMap.addAll({
          'riskFreq': ''.combinedViJa(context, _freq ?? ''),
          'riskProb': ''.combinedViJa(context, _prob ?? ''),
          'riskSev': ''.combinedViJa(context, _sev ?? ''),
          'riskTotal': getScoreSymbol(),
        });
      } else {
        reportMap.addAll({
          'riskFreq': ''.combinedViJa(context, _qaFreq ?? ''),
          'riskProb': ''.combinedViJa(context, _qa5m ?? ''),
          'riskSev': ''.combinedViJa(context, _qaImpact ?? ''),
        });
      }

      ////////////////////////////////////////////////////////////
      /// FORM DATA
      ////////////////////////////////////////////////////////////
      final formData = FormData.fromMap({
        'report': jsonEncode(reportMap),
        'images': imageFiles,
      });

      ////////////////////////////////////////////////////////////
      /// CALL API
      ////////////////////////////////////////////////////////////

      final response = await DioClient.postUpload(
        '/api/report',
        data: formData,
      );
      ////////////////////////////////////////////////////////////
      /// SUCCESS
      ////////////////////////////////////////////////////////////
      LoadingDialog.hide(context);

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        CommonUI.showSnackBar(
          context: context,
          message: 'Successfully sent ${images.length} images!',
          color: Colors.green,
        );

        _resetForm();
      } else {
        CommonUI.showSnackBar(
          context: context,
          message: AppMessage.serverError,
          color: Colors.red,
        );
      }
    }
    ////////////////////////////////////////////////////////////
    /// DIO ERROR (CHUẨN HỆ THỐNG)
    ////////////////////////////////////////////////////////////
    on DioException catch (e) {
      LoadingDialog.hide(context);

      final result = AuthApi.handleDioError(e);

      CommonUI.showSnackBar(
        context: context,
        message: result.message,
        color: Colors.red,
      );
    }
    ////////////////////////////////////////////////////////////
    /// UNKNOWN ERROR
    ////////////////////////////////////////////////////////////
    catch (e) {
      LoadingDialog.hide(context);

      CommonUI.showSnackBar(
        context: context,
        message: AppMessage.unknownError,
        color: Colors.red,
      );
    }
  }

  double _fontSize = 14;

  void _autoFont(String text) {
    setState(() {
      if (text.length > 120) {
        _fontSize = 11;
      } else if (text.length > 80)
        _fontSize = 12;
      else if (text.length > 40)
        _fontSize = 13;
      else
        _fontSize = 14;
    });
  }

  void _resetForm() {
    setState(() {
      _selectedMachine = null;
      _comment = '';
      _counterMeasure = '';
      _commentController.clear();
      _counterController.clear();
      _freq = null;
      _prob = null;
      _sev = null;
      _needRecheck = false;
      _qrKey = '';
    });
    _cameraKey.currentState?.clearAll(); // xóa hết ảnh
    _cameraKey.currentState?.resetQr(); // xóa hết ảnh
  }

  String _qrKey = '';

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

  Widget _buildMachineInfoLoadingCard() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: .94, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) {
          return Transform.scale(scale: scale, child: child);
        },

        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.black.withOpacity(.58),

            border: Border.all(color: Colors.white.withOpacity(.08)),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.28),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),

          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ////////////////////////////////////////////////////////////
              /// LOADING DOT
              ////////////////////////////////////////////////////////////
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.cyanAccent.withOpacity(.9),
                ),
              ),

              const SizedBox(width: 12),

              ////////////////////////////////////////////////////////////
              /// TEXT
              ////////////////////////////////////////////////////////////
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Scanning QR Machine',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .2,
                    ),
                  ),

                  if ((_loadingMacId ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _loadingMacId!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.6),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plantList = getPlants();
    final groupList = getGroupsByPlant();

    // final facList = _selectedPlant == null
    //     ? []
    //     : getFacByPlant(_selectedPlant!);

    // final areaList = _selectedPlant == null || _selectedFac == null
    //     ? []
    //     : getAreaByFac(_selectedPlant!, _selectedFac!);

    // final machineList =
    //     _selectedPlant == null || _selectedFac == null || _selectedArea == null
    //     ? []
    //     : getMachineByArea(_selectedPlant!, _selectedFac!, _selectedArea!);
    final facList = <String>[
      if (_selectedPlant != null) ...getFacByPlant(_selectedPlant!),

      if (_qrFallbackMachine != null &&
          _norm(_qrFallbackMachine!.plant) == _norm(_selectedPlant) &&
          _qrFallbackMachine!.fac.isNotEmpty)
        _qrFallbackMachine!.fac,
    ].toSet().toList();

    final areaList = <String>[
      if (_selectedPlant != null && _selectedFac != null)
        ...getAreaByFac(_selectedPlant!, _selectedFac!),

      if (_qrFallbackMachine != null &&
          _norm(_qrFallbackMachine!.plant) == _norm(_selectedPlant) &&
          _norm(_qrFallbackMachine!.fac) == _norm(_selectedFac) &&
          _qrFallbackMachine!.area.isNotEmpty)
        _qrFallbackMachine!.area,
    ].toSet().toList();

    final machineList = <String>[
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
    ].toSet().toList();

    final imageCount = _cameraKey.currentState?.images.length ?? 0;
    final hasImages = imageCount > 0;
    final images = _cameraKey.currentState?.images ?? [];

    final symbol = getScoreSymbol();
    final minLength = (widget.lang == 'JP') ? 1 : 2;

    return Scaffold(
      // ✅ QUAN TRỌNG: Giúp giao diện tự co lên khi bàn phím hiện
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
          // HIỂN THỊ ẢNH THUMBNAIL TRÊN APPBAR
          if (images.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: images.asMap().entries.map((entry) {
                  int idx = entry.key;
                  Uint8List img = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            img,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: GestureDetector(
                            onTap: () =>
                                _cameraKey.currentState?.removeImage(idx),
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
                }).toList(),
              ),
            ),
          GlassActionButton(
            icon: Icons.send_rounded,
            enabled: hasImages,
            onTap: hasImages ? _sendReport : null,
            backgroundColor: hasImages ? const Color(0xFF22C55E) : null,
            iconColor: hasImages ? Colors.black : Colors.white,
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
              // CAMERA + GRID ẢNH
              Stack(
                children: [
                  CameraPreviewBox(
                    key: _cameraKey,
                    size: 340,
                    plant: _selectedPlant,
                    type: widget.patrolGroup.name,
                    group: _selectedGroup,
                    onImagesChanged: (_) => setState(() {}),
                    patrolGroup: widget.patrolGroup,
                    onQrDetected: (qr) async {
                      await _handleQrDetected(qr);
                    },
                  ),

                  if (_isLoadingMachineInfo)
                    Positioned.fill(
                      child: Container(
                        alignment: Alignment.center,
                        color: Colors.black.withOpacity(.18),
                        child: _buildMachineInfoLoadingCard(),
                      ),
                    ),
                ],
              ),

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

                            // if (autoMachine != null) {
                            //   _loadMachineAiSummary(autoMachine);
                            // }
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

                        // onChanged: (v) {
                        //   setState(() => _selectedMachine = v);
                        //
                        //   // _loadMachineAiSummary(v);
                        // },
                        onChanged: _onMachineChanged,
                        isRequired: true,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),

              // _buildAiAnalyzeSwitch(),
              AiAnalysisToggle(
                enabled: _aiEnabled,
                loading: _isLoadingMachineAi,
                hasMachine: (_selectedMachine?.isNotEmpty ?? false),
                onTap: () {
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
              if (_aiEnabled)
                // MachineAiAlertCard(
                //   lang: widget.lang,
                //   machine: _selectedMachine,
                //   loading: _isLoadingMachineAi,
                //   error: _machineAiError,
                //   summary: _machineAiSummary,
                //   onRetry: () =>
                //       _loadMachineAiSummary(_selectedMachine, force: true),
                // ),
                MachineAiAlertCard(
                  lang: widget.lang,
                  machine: _selectedMachine,
                  loading: _isLoadingMachineAi,
                  translatingJp: _isTranslatingAi,
                  error: _machineAiError,
                  summary: _machineAiSummary,
                  summaryJp: _summaryJp,
                  onTranslateJp: _translateAiSummaryToJp,
                  onRetry: () =>
                      _loadMachineAiSummary(_selectedMachine, force: true),
                ),
              const SizedBox(height: 16),
              // CÁC DROPDOWN RISK
              if (widget.patrolGroup != PatrolGroup.AssetUpdate)
                _buildRiskSection(),

              const SizedBox(height: 8),

              // ---------------------------------------------------------
              // PHẦN AUTO COMPLETE ĐÃ TỐI ƯU CHO MOBILE
              // ---------------------------------------------------------
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ô 1: COMMENT
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Autocomplete<AutoCmp>(
                          optionsViewOpenDirection: OptionsViewOpenDirection.up,
                          optionsBuilder: (TextEditingValue value) {
                            if (value.text.length < minLength || isLoading) {
                              return const Iterable<AutoCmp>.empty();
                            }

                            // FILTER TRỰC TIẾP TẠI ĐÂY
                            return allOptionsComment
                                .where((AutoCmp option) {
                                  return option.inputText
                                      .toLowerCase()
                                      .contains(
                                        value.text.toLowerCase(),
                                      ); // Tìm kiếm không phân biệt hoa thường
                                })
                                .take(
                                  5,
                                ); // Chỉ lấy 5 kết quả đầu tiên giống như logic cũ của BE
                          },
                          displayStringForOption: (option) => option.inputText,
                          onSelected: (AutoCmp selection) {
                            // Khi CHỌN gợi ý → điền vào comment

                            _commentController.text = selection.inputText;
                            _commentController
                                .selection = TextSelection.fromPosition(
                              TextPosition(offset: selection.inputText.length),
                            ); // Đưa con trỏ ra cuối
                            _comment = selection.inputText;
                            _autoFont(_comment);

                            // === TỰ ĐỘNG ĐIỀN COUNTERMEASURE NẾU CÓ ===
                            if (selection.countermeasure.isNotEmpty) {
                              _counterController.text =
                                  selection.countermeasure;
                              _counterMeasure = selection.countermeasure;
                            } else {
                              // Nếu không có countermeasure → để trống (tùy yêu cầu)
                              _counterController.clear();
                              _counterMeasure = '';
                            }
                          },
                          fieldViewBuilder:
                              (
                                context,
                                controller,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                _commentController = controller;
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  maxLines: 3,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: _fontSize,
                                  ),

                                  decoration: InputDecoration(
                                    // hintText: '${"commentHint".tr(context)}*',
                                    filled: true,
                                    hint: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "commentHint".tr(context),
                                          style: TextStyle(
                                            color: Colors.red.withOpacity(.6),
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
                                    fillColor: Colors.green.withOpacity(0.08),

                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Colors.white.withOpacity(0.35),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Color(
                                          0xFF90E14D,
                                        ).withOpacity(0.25),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Color(
                                          0xFF90E14D,
                                        ).withOpacity(.45), // cyan
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.all(12),
                                  ),

                                  onChanged: (v) {
                                    _comment = v;
                                    _autoFont(v);

                                    // Debounce search
                                    if (_commentDebounce?.isActive ?? false) {
                                      _commentDebounce!.cancel();
                                    }

                                    // === KHI XÓA HẾT COMMENT → XÓA LUÔN COUNTERMEASURE ===
                                    if (v.trim().isEmpty) {
                                      _counterController.clear();
                                      _counterMeasure = '';
                                    }
                                  },
                                );
                              },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Transform.translate(
                                offset: const Offset(0, 8), // Sát ô, đẹp đều
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
                                      itemCount: options.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(
                                            height: 1,
                                            thickness: 0.5,
                                          ),
                                      itemBuilder: (context, index) {
                                        final option = options.elementAt(index);
                                        return InkWell(
                                          onTap: () => onSelected(option),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            child: Text(
                                              option.inputText,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
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
                    // Ô 2: COUNTERMEASURE (giữ nguyên, không cần linking ngược)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Autocomplete<AutoCmp>(
                            optionsViewOpenDirection:
                                OptionsViewOpenDirection.up,
                            optionsBuilder: (TextEditingValue value) {
                              if (value.text.length < minLength || isLoading) {
                                return const Iterable<AutoCmp>.empty();
                              }

                              return allOptionsCounter
                                  .where((AutoCmp option) {
                                    return option.inputText
                                        .toLowerCase()
                                        .contains(
                                          value.text.toLowerCase(),
                                        ); // Tìm kiếm không phân biệt hoa thường
                                  })
                                  .take(
                                    5,
                                  ); // Chỉ lấy 5 kết quả đầu tiên giống như logic cũ của BE
                            },
                            displayStringForOption: (option) =>
                                option.inputText,
                            onSelected: (AutoCmp selection) {
                              _counterController.text = selection.inputText;

                              _counterController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(
                                      offset: selection.inputText.length,
                                    ),
                                  );
                              _counterMeasure = selection.inputText;
                              _autoFont(_counterMeasure);
                            },
                            fieldViewBuilder:
                                (
                                  context,
                                  controller,
                                  focusNode,
                                  onFieldSubmitted,
                                ) {
                                  _counterController = controller;
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    maxLines: 3,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: _fontSize,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: "counterMeasureHint".tr(
                                        context,
                                      ),
                                      filled: true,
                                      fillColor: Colors.green.withOpacity(0.08),
                                      hintStyle: TextStyle(
                                        color: Colors.white.withOpacity(.6),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.35),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: Color(
                                            0xFF90E14D,
                                          ).withOpacity(0.25),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: Color(
                                            0xFF90E14D,
                                          ).withOpacity(.45), // cyan
                                        ),
                                      ),

                                      contentPadding: const EdgeInsets.all(12),
                                    ),
                                    onChanged: (v) {
                                      _counterMeasure = v;
                                      _autoFont(v);

                                      if (_counterDebounce?.isActive ?? false) {
                                        _counterDebounce!.cancel();
                                      }
                                    },
                                  );
                                },
                            optionsViewBuilder: (context, onSelected, options) {
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
                                        itemCount: options.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(
                                              height: 1,
                                              thickness: 0.5,
                                            ),
                                        itemBuilder: (context, index) {
                                          final option = options.elementAt(
                                            index,
                                          );
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
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
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

              // Checkbox và phần cuối
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
                          onChanged: (v) =>
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
                        iconColor: hasImages ? Colors.black : Colors.white,
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
