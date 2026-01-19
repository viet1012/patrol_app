import 'dart:async';

import 'dart:typed_data';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import '../api/replace_image_api.dart';
import '../common/common_ui_helper.dart';
import '../model/machine_model.dart';
import '../translator.dart';
import 'edit_image_item.dart';
import '../homeScreen/patrol_home_screen.dart';
import '../model/patrol_report_model.dart';
import '../widget/glass_action_button.dart';
import 'camera_edit_box.dart';

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

  @override
  void initState() {
    super.initState();
    _commentCtrl.text = widget.report.comment;
    _counterCtrl.text = widget.report.countermeasure;

    _selectedGroup = widget.report.grp;
    _selectedDivision = widget.report.division; // nếu division == fac
    _selectedArea = widget.report.area;

    final m = widget.report.machine.trim();
    _selectedMachine = (m == "<Null>" || m.isEmpty) ? null : m;

    _autoFixInvalidSelections();
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
                child: _buildSearchableDropdown(
                  label: "Group",
                  selectedValue: _selectedGroup,
                  items: groupList,
                  onChanged: (v) => setState(() => _selectedGroup = v),
                  isRequired: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSearchableDropdown(
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
                child: _buildSearchableDropdown(
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
                child: _buildSearchableDropdown(
                  label: "Machine",
                  selectedValue: _selectedMachine,
                  items: machineList,
                  onChanged: (v) => setState(() => _selectedMachine = v),
                  isRequired: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Timer? _debounce;

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
        titleSpacing: 4, // 👈 kéo sát về leading
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

      await updateReportApi(
        id: widget.report.id!,
        comment: _commentCtrl.text.trim(),
        countermeasure: _counterCtrl.text.trim(),

        grp: _selectedGroup,
        plant: widget.report.plant,
        division: _selectedDivision,
        area: _selectedArea,
        machine: _selectedMachine,
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

  Widget _buildImageGrid(List<String> images) {
    const int maxImages = 2;
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
