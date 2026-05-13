import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api/replace_image_api.dart';
import '../common/common_risk_dropdown.dart';
import '../common/common_searchable_dropdown.dart';
import '../common/common_ui_helper.dart';
import '../homeScreen/patrol_home_screen.dart';
import '../model/machine_model.dart';
import '../model/patrol_report_model.dart';
import '../model/reason_model.dart';
import '../model/risk_score_calculator.dart';
import '../translator.dart';
import '../widget/glass_action_button.dart';
import 'camera_edit_box.dart';
import 'edit_image_item.dart';

class EditDetailPage extends StatefulWidget {
  final PatrolReportModel report;
  final PatrolGroup patrolGroup;
  final List<MachineModel> machines; // ✅ thêm

  const EditDetailPage({
    super.key,
    required this.report,
    required this.patrolGroup,
    required this.machines,
  });

  @override
  State<EditDetailPage> createState() => _EditDetailPageState();
}

class _EditDetailPageState extends State<EditDetailPage> {
  final GlobalKey<CameraEditBoxState> _cameraKey =
      GlobalKey<CameraEditBoxState>();

  final TextEditingController _commentCtrl = TextEditingController();
  final TextEditingController _counterCtrl = TextEditingController();
  String? _selectedGroup;
  String? _selectedDivision; // map = fac
  String? _selectedArea;
  String? _selectedMachine;

  String? _riskFreq;
  String? _riskProb;
  String? _riskSev;

  bool _needRecheck = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _commentCtrl.text = widget.report.comment;
    _counterCtrl.text = widget.report.countermeasure;

    _selectedGroup = widget.report.grp;
    _selectedDivision = widget.report.division; // nếu division == fac
    _selectedArea = widget.report.area;

    _riskFreq = widget.report.riskFreq;
    _riskProb = widget.report.riskProb;
    _riskSev = widget.report.riskSev;

    final checkInfo = widget.report.checkInfo.trim();

    _needRecheck =
        checkInfo.contains('Cần rà soát lại vấn đề tương tự') ||
        checkInfo.contains('類似問題を再確認する必要があります');

    final m = widget.report.machine.trim();
    _selectedMachine = (m == "<Null>" || m.isEmpty) ? null : m;

    _autoFixInvalidSelections();
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
  }

  List<String> get groupList => List.generate(10, (i) => 'Group ${i + 1}');

  List<String> getFacByPlant(String plant) {
    final unique = <String>{};
    return widget.machines
        .where((m) => m.plant.toString() == plant)
        .map((m) => m.fac.toString())
        .where((s) => s.trim().isNotEmpty)
        .where(unique.add)
        .toList();
  }

  List<String> getAreaByFac(String plant, String fac) {
    final unique = <String>{};
    return widget.machines
        .where((m) => m.plant.toString() == plant)
        .where((m) => m.fac.toString() == fac)
        .map((m) => m.area.toString())
        .where((s) => s.trim().isNotEmpty)
        .where(unique.add)
        .toList();
  }

  List<String> getMachineByArea(String plant, String fac, String area) {
    final unique = <String>{};
    return widget.machines
        .where((m) => m.plant.toString() == plant)
        .where((m) => m.fac.toString() == fac)
        .where((m) => m.area.toString() == area)
        .map((m) => m.macId.toString())
        .where((s) => s.trim().isNotEmpty)
        .where(unique.add)
        .toList();
  }

  void _autoFixInvalidSelections() {
    final plant = widget.report.plant;

    final facList = getFacByPlant(plant);
    if (_selectedDivision == null || !facList.contains(_selectedDivision)) {
      _selectedDivision = facList.isNotEmpty ? facList.first : null;
    }
    if (_selectedDivision == null) return;

    final areaList = getAreaByFac(plant, _selectedDivision!);
    if (_selectedArea == null || !areaList.contains(_selectedArea)) {
      _selectedArea = areaList.isNotEmpty ? areaList.first : null;
    }
    if (_selectedArea == null) return;

    final machineList = getMachineByArea(
      plant,
      _selectedDivision!,
      _selectedArea!,
    );
    if (_selectedMachine == null || !machineList.contains(_selectedMachine)) {
      _selectedMachine = machineList.isNotEmpty ? machineList.first : null;
    }
  }

  String get _riskScoreSymbol => RiskScoreCalculator.scoreSymbol(
    freqKey: _riskFreq,
    probKey: _riskProb,
    sevKey: _riskSev,
    frequencyOptions: frequencyOptions,
    probabilityOptions: probabilityOptions,
    severityOptions: severityOptions,
  );

  Widget _buildEditableMeta() {
    final plant = widget.report.plant;

    final facList = getFacByPlant(plant);
    final areaList = (_selectedDivision == null)
        ? <String>[]
        : getAreaByFac(plant, _selectedDivision!);
    final machineList = (_selectedDivision == null || _selectedArea == null)
        ? <String>[]
        : getMachineByArea(plant, _selectedDivision!, _selectedArea!);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: CommonSearchableDropdown(
                  label: "Group",
                  selectedValue: _selectedGroup,
                  items: groupList,
                  onChanged: (v) => setState(() => _selectedGroup = v),

                  isRequired: true,
                ),
              ),

              const SizedBox(width: 8),
              Expanded(
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
                        final machines = getMachineByArea(
                          plant,
                          v,
                          areas.first,
                        );
                        if (machines.length == 1)
                          _selectedMachine = machines.first;
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
              Expanded(
                child: CommonSearchableDropdown(
                  label: "Area",
                  selectedValue: _selectedArea,
                  items: areaList,
                  onChanged: (v) {
                    setState(() {
                      _selectedArea = v;
                      _selectedMachine = null;

                      if (_selectedDivision == null || v == null) return;

                      final machines = getMachineByArea(
                        plant,
                        _selectedDivision!,
                        v,
                      );
                      if (machines.length == 1)
                        _selectedMachine = machines.first;
                    });
                  },
                  isRequired: true,
                ),
              ),

              const SizedBox(width: 8),
              Expanded(
                child: CommonSearchableDropdown(
                  label: "Machine",
                  selectedValue: _selectedMachine,
                  items: machineList,
                  onChanged: (v) => setState(() => _selectedMachine = v),
                  isRequired: true,
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
                  onChanged: (v) => setState(() => _riskFreq = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CommonRiskDropdown(
                  labelKey: "label_prob",
                  valueKey: _riskProb,
                  items: probabilityOptions,
                  onChanged: (v) => setState(() => _riskProb = v),
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
                  onChanged: (v) => setState(() => _riskSev = v),
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
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _commentCtrl.dispose();
    _counterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 4,
        // 👈 kéo sát về leading
        leading: GlassActionButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context, true),
        ),
        backgroundColor: const Color(0xFF121826),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Text(
                  'Edit Detail',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Text(
                  widget.report.plant,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
            Text(
              'ID: ${widget.report.id.toString()}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        actions: [GlassActionButton(icon: Icons.save_rounded, onTap: _onSave)],
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEditableMeta(),
              const SizedBox(height: 16),

              // ===== Comment & Countermeasure =====
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _sectionInlineEdit('Comment', _commentCtrl)),
                  const SizedBox(width: 32),
                  Expanded(
                    child: _sectionInlineEdit('Countermeasure', _counterCtrl),
                  ),
                ],
              ),
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
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        "needRecheck".tr(context),
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              _buildImageGrid(widget.report.imageNames),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    try {
      // ⏳ Có thể show loading nếu muốn
      // CommonUI.showSnackBar(
      //   context: context,
      //   message: 'Saving...',
      // );

      if (_selectedMachine == null) {
        CommonUI.showWarning(
          context: context,
          title: "Information Required",
          message: "Please select all required information.",
        );
        return;
      }
      final needRecheckValue = _needRecheck
          ? (_selectedArea != null
                ? ''.combinedViJa(context, 'needRecheck')
                : ''.combinedViJa(context, 'needSelectArea'))
          : '';

      debugPrint("needRecheck = $needRecheckValue");

      final freqKey = _riskFreq ?? '';
      final probKey = _riskProb ?? '';
      final sevKey = _riskSev ?? '';

      // ✅ text song ngữ VN + JP
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
        needRecheck: _needRecheck
            ? (_selectedArea != null
                  ? ''.combinedViJa(context, 'needRecheck')
                  : ''.combinedViJa(context, 'needSelectArea'))
            : '',
      );

      if (!mounted) return;

      /// ✅ THÀNH CÔNG → dialog glass
      CommonUI.showGlassDialog(
        context: context,
        icon: Icons.check_circle_rounded,
        iconColor: Colors.greenAccent,
        title: 'Update Successful',
        message: 'The report has been updated successfully.',
        buttonText: 'OK',
      );

      /// ⏳ đợi dialog đóng rồi pop
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      Navigator.pop(context, true); // báo màn trước reload API
    } catch (e, s) {
      debugPrint('❌ UPDATE FAILED: $e');
      debugPrintStack(stackTrace: s);

      if (!mounted) return;

      /// ❌ THẤT BẠI → warning dialog
      CommonUI.showWarning(
        context: context,
        title: 'Update Failed',
        message:
            'Unable to update the report.\nPlease check your connection or try again.',
      );
    }
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
          maxLines: 6,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter $title',
            hintStyle: TextStyle(color: Colors.white38),
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

  Widget _buildImageGrid(List<String> images) {
    const int maxImages = 3;
    final bool canAdd = images.length < maxImages;

    return SizedBox(
      height: 320,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length + (canAdd ? 1 : 0), // 🔥 CHỈ +1 KHI ĐƯỢC ADD
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          // ===== Ô ADD IMAGE =====
          if (canAdd && index == images.length) {
            return SizedBox(
              width: 280,
              child: _AddImageTile(
                onTap: () => _openAddCameraFromParent(context),
              ),
            );
          }

          // ===== ẢNH CŨ =====
          return SizedBox(
            width: 280,
            child: EditImageItem(
              imageName: images[index],
              report: widget.report,
              patrolGroup: widget.patrolGroup,
              plant: widget.report.plant,
              onAdd: (newImage) {
                setState(() {
                  widget.report.imageNames.add(newImage);
                });
              },
              onDelete: () {
                setState(() {
                  widget.report.imageNames.removeAt(index);
                });
              },
            ),
          );
        },
      ),
    );
  }

  void _openAddCameraFromParent(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) {
        List<Uint8List> captured = [];

        return StatefulBuilder(
          builder: (context, setModal) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CameraEditBox(
                  size: 300,
                  plant: widget.report.plant,
                  type: "ADD",
                  maxAllowImages: 2 - widget.report.imageNames.length,
                  onImagesChanged: (imgs) {
                    setModal(() => captured = imgs);
                  },
                ),

                GlassActionButton(
                  backgroundColor: captured.isNotEmpty
                      ? const Color(0xFF22C55E)
                      : null,
                  iconColor: captured.isNotEmpty ? Colors.black : Colors.white,
                  icon: Icons.send_rounded,
                  enabled: captured.isNotEmpty,
                  onTap: () async {
                    Navigator.pop(context);

                    for (final img in captured) {
                      final name = await addImageApi(
                        id: widget.report.id!,
                        imageBytes: img,
                      );

                      setState(() {
                        widget.report.imageNames.add(name);
                      });
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AddImageTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddImageTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24, width: 1.2),
          color: Colors.white.withOpacity(0.05),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.add_a_photo, color: Colors.white70, size: 36),
              SizedBox(height: 8),
              Text("Add Image", style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}
