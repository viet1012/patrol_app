import 'package:flutter/material.dart';

import '../api/hse_master_service.dart';
import '../api/patrol_report_api.dart';
import '../api/replace_image_api.dart';
import '../common/common_risk_dropdown.dart';
import '../common/common_searchable_dropdown.dart';
import '../common/common_ui_helper.dart';
import '../model/machine_model.dart';
import '../model/patrol_report_model.dart';
import '../model/reason_model.dart';
import '../model/risk_score_calculator.dart';
import '../translator.dart';
import '../widget/glass_action_button.dart';

class EditReportDialog extends StatefulWidget {
  final PatrolReportModel report;
  final BuildContext parentContext;

  const EditReportDialog({
    super.key,
    required this.report,
    required this.parentContext,
  });

  static Future<PatrolReportModel?> show(
    BuildContext context, {
    required PatrolReportModel model,
  }) {
    return showDialog<PatrolReportModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditReportDialog(report: model, parentContext: context),
    );
  }

  @override
  State<EditReportDialog> createState() => _EditReportDialogState();
}

class _EditReportDialogState extends State<EditReportDialog> {
  final TextEditingController _commentCtrl = TextEditingController();
  final TextEditingController _counterCtrl = TextEditingController();

  String? _selectedGroup;
  String? _selectedDivision; // fac
  String? _selectedArea;
  String? _selectedMachine;

  String? _riskFreq;
  String? _riskProb;
  String? _riskSev;

  List<MachineModel> machines = [];

  bool _loadingMaster = false;
  String? _masterError;

  bool _dirty = false;

  // ✅ PIC dropdown
  List<String> _picItems = [];
  bool _loadingPic = false;
  String? _picError;

  static const String emptyLabel = 'UNKNOWN';
  Future<List<String>>? _futurePics;
  String? _selectedPIC; // UI selected
  String? _oldPIC;

  // ✅ AT Status dropdown
  static const List<String> atStatusOptions = ['Wait', 'Done', 'Completed'];
  String? _selectedAtStatus;
  String? _oldAtStatus;

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  @override
  void initState() {
    super.initState();

    _commentCtrl.text = widget.report.comment;
    _counterCtrl.text = widget.report.countermeasure;
    _commentCtrl.addListener(_markDirty);
    _counterCtrl.addListener(_markDirty);

    _selectedGroup = widget.report.grp;
    _selectedDivision = widget.report.division;
    _selectedArea = widget.report.area;

    _riskFreq = widget.report.riskFreq;
    _riskProb = widget.report.riskProb;
    _riskSev = widget.report.riskSev;

    // final m = widget.report.machine.trim();
    // _selectedMachine = (m == "<Null>" || m.isEmpty) ? null : m;
    _selectedMachine = _norm(widget.report.machine);
    if (_selectedMachine!.isEmpty || _selectedMachine == "<Null>") {
      _selectedMachine = null;
    }

    _selectedPIC = widget.report.pic;

    _selectedAtStatus = _norm(widget.report.atStatus);
    if (_selectedAtStatus!.isEmpty || _selectedAtStatus == '<Null>') {
      _selectedAtStatus = null;
    }

    // nếu giá trị lạ (không nằm trong list) thì set null hoặc fallback
    if (_selectedAtStatus != null &&
        !atStatusOptions.contains(_selectedAtStatus)) {
      _selectedAtStatus = null;
    }

    _loadHseMaster();
  }

  String? _ensureRiskKey(
    String? raw,
    List<RiskOption> options,
    BuildContext ctx,
  ) {
    if (raw == null) return null;

    // Normalize: tách theo newline, trim, bỏ rỗng
    final parts = raw
        .split(RegExp(r'[\r\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Nếu chỉ có 1 dòng thì vẫn hoạt động như cũ
    // 1) raw/parts đã là key
    for (final p in parts) {
      final byKey = options.where((e) => e.labelKey == p);
      if (byKey.length == 1) return p;
    }

    // 2) raw/parts là text đã dịch -> map ngược về key
    for (final p in parts) {
      final byText = options.where((e) => e.labelKey.tr(ctx) == p);
      if (byText.length == 1) return byText.first.labelKey;
    }

    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    debugPrint('RAW FREQ = "${widget.report.riskFreq}"');
    debugPrint('RAW PROB = "${widget.report.riskProb}"');
    debugPrint('RAW SEV  = "${widget.report.riskSev}"');

    _riskFreq = _ensureRiskKey(
      widget.report.riskFreq,
      frequencyOptions,
      context,
    );
    _riskProb = _ensureRiskKey(
      widget.report.riskProb,
      probabilityOptions,
      context,
    );
    _riskSev = _ensureRiskKey(widget.report.riskSev, severityOptions, context);

    debugPrint('KEY FREQ = "$_riskFreq"');
    debugPrint('KEY PROB = "$_riskProb"');
    debugPrint('KEY SEV  = "$_riskSev"');
  }

  List<String> get groupList => List.generate(10, (i) => 'Group ${i + 1}');

  String _norm(String? s) => (s ?? '').trim();

  bool _eq(String? a, String? b) => _norm(a) == _norm(b);

  Future<void> _loadHseMaster() async {
    setState(() {
      _loadingMaster = true;
      _loadingPic = true;
      _masterError = null;
      _picError = null;
    });

    try {
      final plant = widget.report.plant;

      // ✅ chạy song song
      final results = await Future.wait([
        HseMasterService.fetchMachines(), // returns List<MachineModel>
        findPicsByPlantFromApi(plant), // returns List<String>
      ]);

      if (!mounted) return;

      final master = results[0] as List<MachineModel>;
      final pics = results[1] as List<String>;

      setState(() {
        machines = master;

        // build items PIC
        _picItems = {emptyLabel, ...pics}.toList();

        _loadingMaster = false;
        _loadingPic = false;

        // nếu bạn muốn auto-fix selection sau khi có master:
        // _autoFixInvalidSelections();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMaster = false;
        _loadingPic = false;

        // tùy bạn: tách error ra 2 cái hay gộp
        _masterError = e.toString();
        _picError = e.toString();
      });
    }
  }

  Future<List<String>> findPicsByPlantFromApi(String plant) async {
    final reports = await PatrolReportApi.fetchReports(plant: plant);
    final Set<String> uniquePics = {};
    final List<String> pics = [];

    for (final r in reports) {
      final rawPic = r.pic?.trim();
      final pic = (rawPic == null || rawPic.isEmpty) ? emptyLabel : rawPic;

      if (uniquePics.add(pic)) {
        pics.add(pic);
      }
    }
    return pics;
  }

  List<String> getFacByPlant(String plant) {
    final unique = <String>{};
    return machines
        .where((m) => _eq(m.plant?.toString(), plant))
        .map((m) => _norm(m.fac?.toString()))
        .where((s) => s.isNotEmpty)
        .where(unique.add)
        .toList();
  }

  List<String> getAreaByFac(String plant, String fac) {
    final unique = <String>{};
    return machines
        .where((m) => _eq(m.plant?.toString(), plant))
        .where((m) => _eq(m.fac?.toString(), fac))
        .map((m) => _norm(m.area?.toString()))
        .where((s) => s.isNotEmpty)
        .where(unique.add)
        .toList();
  }

  List<String> getMachineByArea(String plant, String fac, String area) {
    final unique = <String>{};
    return machines
        .where((m) => _eq(m.plant?.toString(), plant))
        .where((m) => _eq(m.fac?.toString(), fac))
        .where((m) => _eq(m.area?.toString(), area))
        .map((m) => _norm(m.macId?.toString())) // <-- dùng name
        .where((s) => s.isNotEmpty)
        .where(unique.add)
        .toList();
  }

  void _autoFixInvalidSelections() {
    final plant = widget.report.plant;

    final facList = getFacByPlant(plant);
    if (facList.isEmpty) {
      _selectedDivision = null;
      _selectedArea = null;
      _selectedMachine = null;
      return;
    }

    if (_selectedDivision == null ||
        !facList.any((f) => _eq(f, _selectedDivision))) {
      _selectedDivision = facList.first;
    } else {
      _selectedDivision = facList.firstWhere((f) => _eq(f, _selectedDivision));
    }

    final areaList = getAreaByFac(plant, _selectedDivision!);
    if (areaList.isEmpty) {
      _selectedArea = null;
      _selectedMachine = null;
      return;
    }

    if (_selectedArea == null || !areaList.any((a) => _eq(a, _selectedArea))) {
      _selectedArea = areaList.first;
    } else {
      _selectedArea = areaList.firstWhere((a) => _eq(a, _selectedArea));
    }
  }

  bool get _canSave {
    if (_loadingMaster) return false;
    if (_selectedGroup == null) return false;
    if (_selectedDivision == null) return false;
    if (_selectedArea == null) return false;
    if (_selectedMachine == null) return false;
    return true;
  }

  void _showInvalidToast() {
    CommonUI.showWarning(
      context: context,
      title: 'Missing information',
      message: _loadingMaster
          ? 'Master data is loading. Please wait...'
          : 'Please select Group/Division/Area/Machine before saving.',
    );
  }

  Widget _buildEditableMeta() {
    final plant = widget.report.plant;

    final facList = getFacByPlant(plant);
    final areaList = (_selectedDivision == null)
        ? <String>[]
        : getAreaByFac(plant, _selectedDivision!);
    final machineList = (_selectedDivision == null || _selectedArea == null)
        ? <String>[]
        : getMachineByArea(plant, _selectedDivision!, _selectedArea!);

    final disabled = _loadingMaster || machines.isEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        children: [
          if (_loadingMaster)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Loading master data...",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          if (_masterError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Load master failed: $_masterError",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadHseMaster,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: CommonSearchableDropdown(
                  label: "Group",
                  selectedValue: _selectedGroup,
                  items: groupList,
                  onChanged: (v) {
                    setState(() => _selectedGroup = v);
                    _markDirty();
                  },

                  isRequired: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AbsorbPointer(
                  absorbing: disabled,
                  child: Opacity(
                    opacity: disabled ? 0.6 : 1,
                    child: CommonSearchableDropdown(
                      label: "Division",
                      selectedValue: _selectedDivision,
                      items: facList,
                      onChanged: (v) {
                        setState(() {
                          _selectedDivision = v;
                          _selectedArea = null;
                          _selectedMachine = null;

                          if (v == null) return;

                          final areas = getAreaByFac(plant, v);
                          if (areas.length == 1) {
                            _selectedArea = areas.first;
                            final macs = getMachineByArea(
                              plant,
                              v,
                              areas.first,
                            );
                            if (macs.length == 1) _selectedMachine = macs.first;
                          }
                        });
                        _markDirty();
                      },
                      isRequired: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: AbsorbPointer(
                  absorbing: disabled || _selectedDivision == null,
                  child: Opacity(
                    opacity: (disabled || _selectedDivision == null) ? 0.6 : 1,
                    child: CommonSearchableDropdown(
                      label: "Area",
                      selectedValue: _selectedArea,
                      items: areaList,
                      onChanged: (v) {
                        setState(() {
                          _selectedArea = v;
                          _selectedMachine = null;

                          if (_selectedDivision == null || v == null) return;

                          final macs = getMachineByArea(
                            plant,
                            _selectedDivision!,
                            v,
                          );
                          if (macs.length == 1) _selectedMachine = macs.first;
                        });
                        _markDirty();
                      },
                      isRequired: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AbsorbPointer(
                  absorbing: disabled,
                  child: Opacity(
                    opacity: (disabled) ? 0.6 : 1,
                    child: CommonSearchableDropdown(
                      label: "Machine",
                      selectedValue: _selectedMachine,
                      items: machineList,
                      onChanged: (v) {
                        setState(() => _selectedMachine = v);
                        _markDirty();
                      },
                      isRequired: true,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: CommonRiskDropdown(
                  labelKey: "label_freq",
                  valueKey: _riskFreq,
                  items: frequencyOptions, // List<RiskOption>
                  onChanged: (v) {
                    setState(() => _riskFreq = v);
                    _markDirty();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CommonRiskDropdown(
                  labelKey: "label_prob",
                  valueKey: _riskProb,
                  items: probabilityOptions,
                  onChanged: (v) {
                    setState(() => _riskProb = v);
                    _markDirty();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CommonRiskDropdown(
                  labelKey: "label_sev",
                  valueKey: _riskSev,
                  items: severityOptions,
                  onChanged: (v) {
                    setState(() => _riskSev = v);
                    _markDirty();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        "label_risk".tr(context),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          shape: BoxShape.circle, // 👈 QUAN TRỌNG
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                        child: Text(
                          _riskScoreSymbol.isEmpty ? "-" : _riskScoreSymbol,
                          style: TextStyle(
                            color:
                                (_riskScoreSymbol == "V" ||
                                    _riskScoreSymbol == "IV")
                                ? Colors.redAccent
                                : Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 160,
                  child: Row(
                    children: [
                      Text(
                        'PIC',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _buildPicDropdown()),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 220,
                  child: Row(
                    children: [
                      const Text(
                        'AT Status',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _buildAfStatusDropdown()),
                      // Expanded(
                      //   child: AbsorbPointer(
                      //     absorbing: disabled,
                      //     // nếu đang loading master thì disable
                      //     child: Opacity(
                      //       opacity: disabled ? 0.6 : 1,
                      //       child: CommonSearchableDropdown(
                      //         label: "AT Status",
                      //         selectedValue: _selectedAtStatus,
                      //         items: atStatusOptions,
                      //         isRequired: false,
                      //         // tùy bạn
                      //         onChanged: (v) {
                      //           setState(() => _selectedAtStatus = v);
                      //           _markDirty();
                      //         },
                      //       ),
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionInlineEdit(String title, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: 5,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter $title',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPicDropdown() {
    return CommonSearchableDropdown(
      label: "PIC",
      selectedValue: _selectedPIC,
      items: _picItems,
      isRequired: true,
      onChanged: (v) async {
        if (v == null || v == _selectedPIC) return;

        final prev = _selectedPIC;
        setState(() => _selectedPIC = v);

        final ok = await CommonUI.showGlassConfirm(
          context: context,
          icon: Icons.help_outline_rounded,
          iconColor: Colors.orangeAccent,
          title: "Confirm update",
          message: 'Update PIC to "$v" ?',
          cancelText: "Cancel",
          confirmText: "Update",
          confirmColor: const Color(0xFF22C55E),
        );

        if (!ok) {
          setState(() => _selectedPIC = prev);
          return;
        }

        await _onSave();
        _oldPIC = _selectedPIC;
      },
    );
  }

  Widget _buildAfStatusDropdown() {
    return CommonSearchableDropdown(
      label: "At_Status",
      selectedValue: _selectedAtStatus,
      items: atStatusOptions,
      isRequired: true,
      onChanged: (v) async {
        if (v == null || v == _selectedAtStatus) return;

        final prev = _selectedAtStatus;
        setState(() => _selectedAtStatus = v);

        final ok = await CommonUI.showGlassConfirm(
          context: context,
          icon: Icons.help_outline_rounded,
          iconColor: Colors.orangeAccent,
          title: "Confirm update",
          message: 'Update Af_Status to "$v" ?',
          cancelText: "Cancel",
          confirmText: "Update",
          confirmColor: const Color(0xFF22C55E),
        );

        if (!ok) {
          setState(() => _selectedAtStatus = prev);
          return;
        }

        await _onSave();
        _oldAtStatus = _selectedAtStatus;
      },
    );
  }

  Future<void> _onSave() async {
    if (!_canSave) return;

    try {
      final freqKey = _riskFreq ?? '';
      final probKey = _riskProb ?? '';
      final sevKey = _riskSev ?? '';

      // ✅ text song ngữ VN + JP (dùng extension của bạn)
      final freqBi = ''.combinedViJa(context, freqKey);
      final probBi = ''.combinedViJa(context, probKey);
      final sevBi = ''.combinedViJa(context, sevKey);

      await updateReportApi(
        id: widget.report.id!,
        comment: _commentCtrl.text.trim(),
        countermeasure: _counterCtrl.text.trim(),
        grp: _selectedGroup,
        plant: widget.report.plant,
        division: _selectedDivision,
        area: _selectedArea,
        machine: _selectedMachine,
        riskFreq: freqBi,
        riskProb: probBi,
        riskSev: sevBi,
        riskTotal: _riskScoreSymbol,
        atStatus: _selectedAtStatus,
        pic: _selectedPIC,
      );

      if (!mounted) return;

      // ? build updated model t? report cu + các field m?i
      final updated = PatrolReportModel(
        id: widget.report.id,
        stt: widget.report.stt,
        type: widget.report.type,
        qr_key: widget.report.qr_key,

        grp: _selectedGroup ?? widget.report.grp,
        plant: widget.report.plant,
        // plant b?n không cho s?a
        division: _selectedDivision ?? widget.report.division,
        area: _selectedArea ?? widget.report.area,
        machine: _selectedMachine ?? widget.report.machine,

        riskFreq: freqBi,
        riskProb: probBi,
        riskSev: sevBi,
        riskTotal: widget.report.riskTotal,

        comment: _commentCtrl.text.trim(),
        countermeasure: _counterCtrl.text.trim(),
        checkInfo: widget.report.checkInfo,

        createdAt: widget.report.createdAt,
        pic: _selectedPIC ?? widget.report.pic,
        dueDate: widget.report.dueDate,
        patrol_user: widget.report.patrol_user,

        imageNames: widget.report.imageNames,
        atImageNames: widget.report.atImageNames,
        atComment: widget.report.atComment,
        atDate: widget.report.atDate,
        atPic: widget.report.atPic,
        atStatus: _selectedAtStatus ?? widget.report.atStatus,

        hseJudge: widget.report.hseJudge,
        hseImageNames: widget.report.hseImageNames,
        hseComment: widget.report.hseComment,
        hseDate: widget.report.hseDate,

        loadStatus: widget.report.loadStatus,
      );

      // ? 1) dóng dialog edit và tr? updated v? màn cha
      Navigator.of(context).pop(updated);

      // ? 2) show success ? parentContext (né _debugLocked)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CommonUI.showGlassDialog(
          context: widget.parentContext,
          icon: Icons.check_circle_rounded,
          iconColor: Colors.greenAccent,
          title: 'Update Successful',
          message: 'The report has been updated successfully.',
          buttonText: 'OK',
        );
      });
    } catch (e, s) {
      debugPrint('? UPDATE FAILED: $e');
      debugPrintStack(stackTrace: s);

      if (!mounted) return;

      // ? show warning ? parentContext (không dùng context dialog)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CommonUI.showWarning(
          context: widget.parentContext,
          title: 'Update Failed',
          message:
              'Unable to update the report.\nPlease check your connection or try again.',
        );
      });
    }
  }

  @override
  void dispose() {
    _commentCtrl.removeListener(_markDirty);
    _counterCtrl.removeListener(_markDirty);
    _commentCtrl.dispose();
    _counterCtrl.dispose();
    super.dispose();
  }

  String get _riskScoreSymbol => RiskScoreCalculator.scoreSymbol(
    freqKey: _riskFreq,
    probKey: _riskProb,
    sevKey: _riskSev,
    frequencyOptions: frequencyOptions,
    probabilityOptions: probabilityOptions,
    severityOptions: severityOptions,
  );

  // ? Dialog UI (thay Scaffold)
  @override
  Widget build(BuildContext context) {
    final maxW = 720.0;
    final w = MediaQuery.of(context).size.width;
    final dialogW = w < 520 ? w - 24 : (w < maxW ? w - 48 : maxW);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogW,
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF121826), Color(0xFF1F2937), Color(0xFF374151)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                blurRadius: 24,
                spreadRadius: 2,
                color: Colors.black.withOpacity(0.35),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ===== Header (like AppBar) =====
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    GlassActionButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Edit Detail',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${widget.report.plant} • ID: ${widget.report.id}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_dirty)
                      GlassActionButton(
                        icon: Icons.save_rounded,
                        onTap: _canSave ? _onSave : _showInvalidToast,
                      )
                    else
                      Opacity(
                        opacity: 0.3,
                        child: GlassActionButton(
                          icon: Icons.save_rounded,
                          onTap:
                              null, // hoặc () {} nếu widget bắt buộc non-null
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Divider(color: Colors.white.withOpacity(0.08), height: 1),

              // ===== Body (scroll) =====
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEditableMeta(),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _sectionInlineEdit('Comment', _commentCtrl),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _sectionInlineEdit(
                              'Countermeasure',
                              _counterCtrl,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
