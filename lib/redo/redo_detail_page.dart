import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' hide MultipartFile;

import '../after/camera_after_box.dart';
import '../after/replaceable_image_item.dart';
import '../api/dio_client.dart';
import '../api/hse_master_service.dart';
import '../api/patrol_report_api.dart';
import '../api/replace_image_api.dart';
import '../common/common_searchable_dropdown.dart';
import '../common/common_ui_helper.dart';
import '../homeScreen/patrol_home_screen.dart';
import '../model/patrol_report_model.dart';
import '../translator.dart';
import '../widget/glass_action_button.dart';

class RedoDetailPage extends StatefulWidget {
  final String accountCode;
  final PatrolReportModel report;
  final PatrolGroup patrolGroup;
  final String? qrCode; // có thể null

  const RedoDetailPage({
    super.key,
    required this.accountCode,
    required this.report,
    required this.patrolGroup,
    this.qrCode,
  });

  @override
  State<RedoDetailPage> createState() => _RedoDetailPageState();
}

class _RedoDetailPageState extends State<RedoDetailPage> {
  final GlobalKey<CameraAfterBoxState> _cameraKey =
      GlobalKey<CameraAfterBoxState>();

  bool _enableCamera = false;

  final TextEditingController _commentCtrl = TextEditingController();
  final TextEditingController _msnvCtrl = TextEditingController();
  String? _employeeName;
  bool _isLoadingName = false;
  Timer? _debounce;

  // ✅ PIC dropdown
  static const String emptyLabel = 'UNKNOWN';
  Future<List<String>>? _futurePics;
  String? _selectedPIC; // UI selected
  String? _oldPIC;
  String? _hseJudge; // "OK" | "NG"

  DateTime? _selectedDueDate;
  int? _dueDateUpdateCount;

  @override
  void initState() {
    super.initState();
    _msnvCtrl.text = widget.accountCode;

    _selectedDueDate = widget.report.dueDateUpdatedAt;
    _dueDateUpdateCount = widget.report.dueDateUpdateCount;

    fetchEmployeeName(
      widget.accountCode,
    ).then((name) => debugPrint('EMPLOYEE NAME = $name'));

    // ✅ init PIC
    final rawPic = widget.report.pic?.trim();
    _selectedPIC = (rawPic == null || rawPic.isEmpty) ? emptyLabel : rawPic;
    _oldPIC = _selectedPIC;

    // ✅ cache list PIC theo plant
    _futurePics = findPicsByPlantFromApi(widget.report.plant);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _commentCtrl.dispose();
    _msnvCtrl.dispose();
    super.dispose();
  }

  Future<List<String>> findPicsByPlantFromApi(String plant) async {
    debugPrint('🔍 Fetch reports for plant = [$plant]');

    final reports = await PatrolReportApi.fetchReports(plant: plant);
    debugPrint('📦 Total reports: ${reports.length}');

    final Set<String> uniquePics = {};
    final List<String> pics = [];

    for (final r in reports) {
      final rawPic = r.pic?.trim();
      final pic = (rawPic == null || rawPic.isEmpty) ? emptyLabel : rawPic;

      if (uniquePics.add(pic)) {
        pics.add(pic);
      }
    }

    debugPrint('🎯 Unique PIC count: ${pics.length}');
    debugPrint('📋 PIC LIST: $pics');
    return pics;
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
          onTap: () {
            final hasQr = (widget.qrCode ?? '').trim().isNotEmpty;
            if (hasQr) {
              context.go('/home');
            } else {
              Navigator.pop(context, true);
            }
          },
        ),
        backgroundColor: const Color(0xFF121826),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Text(
                  'Patrol Redo',
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
            // crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ===== THÔNG TIN CHÍNH (Group, Area, Fac, Machine) =====
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoCard(
                          icon: Icons.groups_rounded,
                          label: "group".tr(context),
                          value: widget.report.grp,
                          color: Colors.blue.shade400,
                        ),
                        const SizedBox(height: 8),
                        _buildInfoCard(
                          icon: Icons.location_on_rounded,
                          label: "area".tr(context),
                          value: widget.report.area,
                          color: Colors.orange.shade400,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoCard(
                          icon: Icons.business_rounded,
                          label: "fac".tr(context),
                          value: widget.report.division,
                          color: Colors.purple.shade400,
                        ),
                        const SizedBox(height: 8),

                        _buildInfoCard(
                          icon: Icons.precision_manufacturing_rounded,
                          label: "machine".tr(context),
                          value: widget.report.machine,
                          color: Colors.teal.shade400,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch, // ⭐ QUAN TRỌNG
                  children: [
                    Expanded(
                      child: _buildSectionCard(
                        title: 'Comment',
                        content: widget.report.comment,
                        icon: Icons.comment_rounded,
                        accentColor: Colors.amber.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSectionCard(
                        title: 'Countermeasure',
                        content: widget.report.countermeasure,
                        icon: Icons.handyman_rounded,
                        accentColor: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              IntrinsicHeight(
                child: _buildInfoCard(
                  icon: Icons.groups_rounded,
                  label: "Patrol User",
                  color: Colors.white70,
                  value: widget.report.patrol_user ?? '-',
                ),
              ),
              const SizedBox(height: 12),

              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoCard(
                            icon: Icons.groups_rounded,
                            label: "Patrol at",
                            color: Colors.white70,
                            value: formatDateTime(widget.report.createdAt),
                          ),
                          const SizedBox(height: 8),
                          _buildRiskCard(
                            icon: Icons.groups_rounded,
                            label: "Review Similar Cases",
                            value: widget.report.checkInfo,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoCard(
                            icon: Icons.groups_rounded,
                            label: "Deadline",
                            value: formatDateTime(widget.report.dueDate),
                            color: Colors.white70,
                          ),
                          const SizedBox(height: 8),
                          _buildRiskCard(
                            icon: Icons.groups_rounded,
                            label: "label_risk".tr(context),
                            value: widget.report.riskTotal,
                            color:
                                (widget.report.riskTotal == "V" ||
                                    widget.report.riskTotal == "IV")
                                ? Colors.red
                                : Colors.white70,
                            riskTotal: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              ////////////////////////////////////////////////////////////
              /// UPDATE DUE DATE + COUNT
              ////////////////////////////////////////////////////////////
              Row(
                children: [
                  Expanded(flex: 1, child: _buildDueDateUpdateBox()),

                  const SizedBox(width: 8),

                  Expanded(child: _buildDueDateUpdateCountBox(widget.report)),
                ],
              ),
              const SizedBox(height: 12),
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

              const SizedBox(height: 12),
              Column(
                children: [
                  _imageSection(
                    title: 'BEFORE',
                    images: widget.report.imageNames,
                    onReplace: (i, newImage) {
                      setState(() => widget.report.imageNames[i] = newImage);
                    },
                  ),
                  const SizedBox(height: 18), // ✅ ngăn cách rõ ràng
                  _imageSection(
                    title: 'AFTER',
                    images: widget.report.atImageNames,
                    onReplace: (i, newImage) {
                      setState(() => widget.report.atImageNames[i] = newImage);
                    },
                    isAfter: true,
                  ),

                  _imageSection(
                    title: 'HSE Check',
                    images: widget.report.hseImageNames,
                    onReplace: (i, newImage) {
                      setState(() => widget.report.hseImageNames[i] = newImage);
                    },
                    isRedo: true,
                  ),
                ],
              ),

              _buildRetakeSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String formatDateTime(DateTime? dt) {
    if (dt == null) return '-';

    // tuỳ bạn muốn format kiểu nào
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} ';
  }

  Widget _buildRiskCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool riskTotal = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.45),
          width: 1,
        ), // ✅ dùng color
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Align(
                  alignment: riskTotal
                      ? Alignment.center
                      : Alignment.centerLeft,
                  child: Text(
                    value.trim().isEmpty ? '-' : value.trim(),
                    style: TextStyle(
                      color: color, // ✅ dùng color
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String content,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08), // mờ nhẹ hơn một chút
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withOpacity(0.25), width: 1),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, // ⭐
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              content.isEmpty ? '-' : content,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageSection({
    required String title,
    required List<String> images,
    required void Function(int index, String newImage) onReplace,
    bool isAfter = false,
    bool isRedo = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              if (isAfter)
                _buildInfoCard(
                  icon: Icons.groups_rounded,
                  label: "After PIC:",
                  color: Colors.white70,
                  value: widget.report.atPic ?? '-',
                ),

              if (isRedo)
                _buildInfoCard(
                  icon: Icons.groups_rounded,
                  label: "HSE Judge:",
                  color: Colors.white70,
                  value: widget.report.hseJudge ?? '-',
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildImageGrid(images: images, onReplace: onReplace),
          const SizedBox(height: 8),
          if (isAfter)
            Center(
              child: _buildSectionCard(
                title: 'Comment',
                content: widget.report.atComment ?? '-',
                icon: Icons.comment_rounded,
                accentColor: Colors.amber.shade600,
              ),
            ),

          if (isRedo)
            Center(
              child: _buildSectionCard(
                title: 'Comment',
                content: widget.report.hseComment ?? '-',
                icon: Icons.comment_rounded,
                accentColor: Colors.amber.shade600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageGrid({
    required List<String> images,
    required void Function(int index, String newImage) onReplace,
  }) {
    // ===== CASE 1: chỉ có 1 ảnh → căn giữa =====
    if (images.length == 1) {
      return SizedBox(
        height: 320,
        child: Center(
          child: SizedBox(
            width: 320,
            child: ReplaceableImageItem(
              imageName: images.first,
              report: widget.report,
              patrolGroup: widget.patrolGroup,
              plant: widget.report.plant,
              onReplaced: (newImage) => onReplace(0, newImage),
            ),
          ),
        ),
      );
    }

    // ===== CASE 2: nhiều ảnh → scroll ngang =====
    return SizedBox(
      height: 320,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 320,
            child: ReplaceableImageItem(
              imageName: images[index],
              report: widget.report,
              patrolGroup: widget.patrolGroup,
              plant: widget.report.plant,
              onReplaced: (newImage) => onReplace(index, newImage),
            ),
          );
        },
      ),
    );
  }

  Widget _buildThumbPreview() {
    if (_cameraKey.currentState == null ||
        _cameraKey.currentState!.images.isEmpty) {
      return const SizedBox();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _cameraKey.currentState!.images.asMap().entries.map((entry) {
          final idx = entry.key;
          final img = entry.value;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    img,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),

                /// ❌ REMOVE
                Positioned(
                  top: -4,
                  right: -4,
                  child: GestureDetector(
                    onTap: () {
                      _cameraKey.currentState?.removeImage(idx);
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
        }).toList(),
      ),
    );
  }

  Widget _buildPicDropdown() {
    return FutureBuilder<List<String>>(
      future: _futurePics,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Text(
            'Load PIC failed',
            style: TextStyle(color: Colors.redAccent),
          );
        }

        final picList = snapshot.data ?? const <String>[];

        return CommonSearchableDropdown(
          label: "PIC",
          selectedValue: _selectedPIC,
          items: picList,
          isRequired: true,
          onChanged: (v) async {
            if (v == null || v == _selectedPIC) return;

            final prev = _selectedPIC;

            // cập nhật UI trước để user thấy họ vừa chọn gì
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
              // ❌ user cancel -> revert lại giá trị cũ
              setState(() => _selectedPIC = prev);
              return;
            }

            // ✅ user confirm -> gọi save
            await _onSave();

            // nếu save OK thì commit old
            _oldPIC = _selectedPIC;
          },
        );
      },
    );
  }

  Widget _buildDueDateUpdateCountBox(PatrolReportModel report) {
    final count = _dueDateUpdateCount ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.history_rounded,
            color: Colors.orangeAccent,
            size: 18,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$count Revisions',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueDateUpdateBox() {
    final text = _selectedDueDate == null
        ? '--'
        : formatDateTime(_selectedDueDate);

    return InkWell(
      onTap: _pickAndConfirmDueDate,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orangeAccent.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Revise Deadline',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            ////////////////////////////////////////////////////
            /// ACTION
            ////////////////////////////////////////////////////
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white70.withOpacity(.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_calendar_rounded,
                    size: 16,
                    color: Colors.white70,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Select',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetakeSection() {
    return Card(
      color: const Color(0xFF121826).withOpacity(.4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// ===== THUMBNAIL PREVIEW =====
            _buildThumbPreview(),

            const SizedBox(height: 12),

            /// ===== CAMERA =====
            // if (_enableCamera)
            CameraAfterBox(
              key: _cameraKey,
              size: 320,
              patrolGroup: widget.patrolGroup,
              type: "RETAKE",
              onImagesChanged: (_) => setState(() {}),
            ),

            /// ===== COMMENT =====
            if (_cameraKey.currentState != null &&
                _cameraKey.currentState!.images.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _commentCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Comment',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white54),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blueAccent.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.12),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  setState(
                    () {},
                  ); // Bắt buộc gọi setState để UI rebuild và nút lưu hiện/ẩn đúng
                },
              ),
            ],

            const SizedBox(height: 20),

            /// ===== SAVE =====
            if (_commentCtrl.text.trim().isNotEmpty)
              SizedBox(
                width: 60,
                height: 60,
                child: GlassActionButton(
                  onTap:
                      (_cameraKey.currentState != null &&
                          _cameraKey.currentState!.images.isNotEmpty &&
                          _msnvCtrl.text.trim().isNotEmpty)
                      ? () async {
                          try {
                            showLoading(context);

                            await updateAtReport(
                              userAfter: widget.accountCode,
                              reportId: widget.report.id!,
                              atPic: '${_msnvCtrl.text.trim()}_$_employeeName',
                              comment: _commentCtrl.text.trim(),
                              images: _cameraKey.currentState!.images,
                            );
                            hideLoading(context);

                            /// RESET UI → cho phép chụp lại tiếp
                            setState(() {
                              _commentCtrl.clear();
                              _enableCamera = false;
                            });
                            _cameraKey.currentState?.clearAll(); // xóa hết ảnh

                            /// FORCE reload camera
                            await Future.delayed(
                              const Duration(milliseconds: 200),
                            );
                            setState(() => _enableCamera = true);

                            _showSnackBar(
                              'Update AF successful!',
                              Colors.green,
                            );
                          } catch (e) {
                            debugPrint('Update AT error: $e');
                            _showSnackBar('Server error: $e', Colors.red);
                          }
                        }
                      : null,
                  icon: Icons.save,
                  backgroundColor: Color(0xFF2665B6),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(
    String message,
    Color color, {
    Duration duration = const Duration(seconds: 10),
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _onSave() async {
    try {
      const emptyLabel = 'UNKNOWN';
      final picToApi = (_selectedPIC == emptyLabel) ? null : _selectedPIC;

      await updateReportApi(id: widget.report.id!, pic: picToApi);

      if (!mounted) return;

      CommonUI.showGlassDialog(
        context: context,
        icon: Icons.check_circle_rounded,
        iconColor: Colors.greenAccent,
        title: 'Update Successful',
        message: 'The report has been updated successfully.',
        buttonText: 'OK',
      );

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, s) {
      debugPrint('❌ UPDATE FAILED: $e');
      debugPrintStack(stackTrace: s);

      if (!mounted) return;

      // ❌ nếu fail thì revert về old cho chắc
      setState(() => _selectedPIC = _oldPIC);

      CommonUI.showWarning(
        context: context,
        title: 'Update Failed',
        message:
            'Unable to update the report.\nPlease check your connection or try again.',
      );
    }
  }

  Future<void> _pickAndConfirmDueDate() async {
    final now = DateTime.now();
    final prev = _selectedDueDate ?? widget.report.dueDate;

    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );

    if (picked == null) return;

    final sameDate =
        prev != null &&
        prev.year == picked.year &&
        prev.month == picked.month &&
        prev.day == picked.day;

    if (sameDate) return;

    final ok = await CommonUI.showGlassConfirm(
      context: context,
      icon: Icons.event_available_rounded,
      iconColor: Colors.orangeAccent,
      title: "Confirm Due Date",
      message: "Update Due Date to ${formatDateTime(picked)} ?",
      cancelText: "Cancel",
      confirmText: "Update",
      confirmColor: const Color(0xFF22C55E),
    );

    if (!ok) return;

    setState(() {
      _selectedDueDate = picked;
    });

    await _onSaveDueDate(picked, rollbackDate: prev);
  }

  Future<void> _onSaveDueDate(
    DateTime newDueDate, {
    DateTime? rollbackDate,
  }) async {
    try {
      showLoading(context);
      final name = await fetchEmployeeName(widget.accountCode);
      final editUser = "${widget.accountCode}_${name ?? ''}".trim();

      debugPrint("SAVE DUE DATE editUser = [$editUser]");
      await updateReportApi(
        id: widget.report.id!,
        dueDate: newDueDate,
        editUser: "${widget.accountCode}_$name",
      );

      hideLoading(context);

      if (!mounted) return;

      setState(() {
        _selectedDueDate = newDueDate;
        _dueDateUpdateCount = (widget.report.dueDateUpdateCount ?? 0) + 1;
      });

      CommonUI.showGlassDialog(
        context: context,
        icon: Icons.check_circle_rounded,
        iconColor: Colors.greenAccent,
        title: 'Update Successful',
        message: 'Due date has been updated successfully.',
        buttonText: 'OK',
      );
    } catch (e) {
      hideLoading(context);

      if (!mounted) return;

      setState(() {
        _selectedDueDate = rollbackDate;
      });

      CommonUI.showWarning(
        context: context,
        title: 'Update Failed',
        message: 'Unable to update due date.\nPlease try again.',
      );
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

  void showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  void hideLoading(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> updateAtReport({
    required String userAfter,
    required int reportId,
    required String atPic,
    required String comment,
    required List<Uint8List> images,
  }) async {
    final dataJson = {"atComment": comment, "atPic": atPic};

    final formData = FormData();

    formData.fields.add(MapEntry('data', jsonEncode(dataJson)));

    for (int i = 0; i < images.length; i++) {
      formData.files.add(
        MapEntry(
          'images',
          MultipartFile.fromBytes(
            images[i],
            filename: 'retake_${i + 1}.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        ),
      );
    }

    final path = '/api/patrol_report/$reportId/update_at';

    debugPrint('Calling PUT $path');
    debugPrint('Base URL: ${DioClient.dio.options.baseUrl}');
    debugPrint('Full URL: ${DioClient.dio.options.baseUrl}$path');

    try {
      final response = await DioClient.putUpload(path, data: formData);

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response data: ${response.data}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Update AT failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('Update AT Dio error: ${e.message}');
      debugPrint('Status: ${e.response?.statusCode}');
      debugPrint('Data: ${e.response?.data}');

      throw Exception(
        e.response?.data?.toString() ?? e.message ?? 'Update AT failed',
      );
    } catch (e) {
      debugPrint('Update AT error: $e');
      rethrow;
    }
  }
}
