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

class RecheckDetailPage extends StatefulWidget {
  final String accountCode;
  final PatrolReportModel report;
  final PatrolGroup patrolGroup;
  final String? qrCode; // có thể null

  const RecheckDetailPage({
    super.key,
    required this.accountCode,
    required this.report,
    required this.patrolGroup,
    this.qrCode,
  });

  @override
  State<RecheckDetailPage> createState() => _RecheckDetailPageState();
}

class _RecheckDetailPageState extends State<RecheckDetailPage> {
  final GlobalKey<CameraAfterBoxState> _cameraKey =
      GlobalKey<CameraAfterBoxState>();

  final TextEditingController _commentCtrl = TextEditingController();

  final TextEditingController _msnvCtrl = TextEditingController();

  Timer? _employeeDebounce;

  String? _employeeName;

  String? _employeeError;

  bool _employeeLoading = false;

  bool _employeeResolved = false;

  /// Chống request cũ trả về sau request mới.
  int _employeeRequestToken = 0;

  // ✅ PIC dropdown
  static const String emptyLabel = 'UNKNOWN';
  Future<List<String>>? _futurePics;
  String? _selectedPIC; // UI selected
  String? _oldPIC;
  String? _hseJudge; // "OK" | "NG"
  String? _selectedAssignPIC; // dropdown

  @override
  void initState() {
    super.initState();

    // ============================================================
    // EMPLOYEE
    // ============================================================

    final initialCode = _normalizeEmployeeCode(widget.accountCode);

    _msnvCtrl.text = initialCode;

    if (initialCode.isNotEmpty) {
      unawaited(_resolveEmployee(initialCode));
    }

    // ============================================================
    // PIC
    // ============================================================

    final rawPic = widget.report.pic?.trim();

    _selectedPIC = rawPic == null || rawPic.isEmpty ? emptyLabel : rawPic;

    _oldPIC = _selectedPIC;

    final assignUser = widget.report.atAssign?.trim();

    _selectedAssignPIC = assignUser == null || assignUser.isEmpty
        ? emptyLabel
        : assignUser;

    _futurePics = findPicsByPlantFromApi(widget.report.plant);
  }

  @override
  void dispose() {
    _employeeRequestToken++;

    _employeeDebounce?.cancel();

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
          // onTap: () => Navigator.pop(context, true),
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
                  'Patrol Recheck',
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

              const SizedBox(height: 14),

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
              IntrinsicHeight(
                child: _buildInfoCard(
                  icon: Icons.groups_rounded,
                  label: "Patrol User",
                  color: Colors.white70,
                  value: widget.report.patrol_user!,
                ),
              ),
              const SizedBox(height: 12),
              // Align(
              //   alignment: Alignment.centerLeft,
              //   child: SizedBox(
              //     width: 160,
              //     child: Row(
              //       children: [
              //         Text(
              //           'PIC',
              //           style: const TextStyle(
              //             fontWeight: FontWeight.w600,
              //             color: Colors.white,
              //           ),
              //         ),
              //         const SizedBox(width: 8),
              //         Expanded(child: _buildPicDropdown()),
              //       ],
              //     ),
              //   ),
              // ),
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    ////////////////////////////////////////////////////////////
                    /// PIC LABEL
                    ////////////////////////////////////////////////////////////
                    const SizedBox(
                      width: 30,
                      child: Text(
                        'PIC',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    ////////////////////////////////////////////////////////////
                    /// CURRENT PIC VALUE
                    ////////////////////////////////////////////////////////////
                    Flexible(flex: 2, child: _buildPicDropdown()),
                    const SizedBox(width: 8),

                    ////////////////////////////////////////////////////////////
                    /// ASSIGN LABEL
                    ////////////////////////////////////////////////////////////
                    const Text(
                      'Assign To',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(width: 8),

                    ////////////////////////////////////////////////////////////
                    /// DROPDOWN
                    ////////////////////////////////////////////////////////////
                    Flexible(flex: 2, child: _buildAssignDropdown()),
                  ],
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
                  label: "PIC:",
                  color: Colors.white70,
                  value: (widget.report.atPic?.trim().isNotEmpty ?? false)
                      ? widget.report.atPic!.trim()
                      : '-',
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
                content: (widget.report.atComment?.trim().isNotEmpty ?? false)
                    ? widget.report.atComment!.trim()
                    : '-',
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

  Widget _buildAssignDropdown() {
    return FutureBuilder<List<String>>(
      future: _futurePics,

      builder: (context, snapshot) {
        ////////////////////////////////////////////////////////////
        /// LOADING
        ////////////////////////////////////////////////////////////
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 48,

            child: Center(child: CircularProgressIndicator()),
          );
        }

        ////////////////////////////////////////////////////////////
        /// ERROR
        ////////////////////////////////////////////////////////////
        if (snapshot.hasError) {
          return const Text(
            'Load PIC failed',

            style: TextStyle(color: Colors.redAccent),
          );
        }

        ////////////////////////////////////////////////////////////
        /// DATA
        ////////////////////////////////////////////////////////////
        final picList = snapshot.data ?? const <String>[];

        final items = <String>{emptyLabel, ...picList}.toList();

        ////////////////////////////////////////////////////////////
        /// READ ONLY
        ////////////////////////////////////////////////////////////
        return IgnorePointer(
          ignoring: true,

          child: Opacity(
            opacity: 0.75,

            child: CommonSearchableDropdown(
              label: "Assign PIC",
              selectedValue: _selectedAssignPIC,
              items: items,
              isRequired: true,
              allowAddNew: false,
              showSearchBox: false,
              onChanged: (_) {},
            ),
          ),
        );
      },
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

        return IgnorePointer(
          ignoring: true,

          child: Opacity(
            opacity: 0.75,

            child: CommonSearchableDropdown(
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
            ),
          ),
        );
      },
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
            _buildEmployeeField(),
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
            // if (_cameraKey.currentState != null &&
            //     _cameraKey.currentState!.images.isNotEmpty) ...[
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
            const SizedBox(height: 8),

            _buildHseJudgeButtons(),

            // ],
          ],
        ),
      ),
    );
  }

  Widget _buildHseJudgeButtons() {
    return Row(
      children: [
        Expanded(
          child: _judgeButton(
            label: 'OK',
            value: 'OK',
            color: Colors.greenAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _judgeButton(
            label: 'NG',
            value: 'NG',
            color: Colors.redAccent,
          ),
        ),
      ],
    );
  }

  Widget _judgeButton({
    required String label,
    required String value,
    required Color color,
  }) {
    final selected = _hseJudge == value;

    final enabled = _canSubmitHse;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),

      opacity: enabled ? 1 : .42,

      child: InkWell(
        borderRadius: BorderRadius.circular(16),

        onTap: enabled ? () => _submitHseJudge(value) : null,

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),

          padding: const EdgeInsets.symmetric(vertical: 14),

          decoration: BoxDecoration(
            color: selected ? color.withOpacity(.9) : color.withOpacity(.15),

            borderRadius: BorderRadius.circular(16),

            border: Border.all(
              color: selected ? color : Colors.white.withOpacity(.15),
            ),
          ),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              Icon(
                value == 'OK'
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,

                color: enabled ? Colors.white : Colors.white38,

                size: 20,
              ),

              const SizedBox(width: 6),

              Text(
                label,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.white38,

                  fontSize: 16,

                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
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

  Widget _buildEmployeeField() {
    final code = _msnvCtrl.text.trim();

    final Color statusColor;
    final IconData statusIcon;

    if (_employeeLoading) {
      statusColor = Colors.orangeAccent;
      statusIcon = Icons.sync_rounded;
    } else if (_employeeResolved) {
      statusColor = Colors.greenAccent;
      statusIcon = Icons.verified_user_rounded;
    } else if (_employeeError != null) {
      statusColor = Colors.redAccent;
      statusIcon = Icons.error_outline_rounded;
    } else {
      statusColor = Colors.white54;
      statusIcon = Icons.badge_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =====================================================
          // TITLE
          // =====================================================
          const Text(
            'HSE USER',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: .8,
            ),
          ),

          const SizedBox(height: 10),

          // =====================================================
          // USER INFO
          // =====================================================
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 26),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // =========================
                    // TÊN NHÂN VIÊN
                    // =========================
                    if (_employeeLoading)
                      const Text(
                        'Đang tìm nhân viên...',
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else if (_employeeResolved &&
                        _employeeName != null &&
                        _employeeName!.trim().isNotEmpty)
                      Text(
                        _employeeName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else if (_employeeError != null)
                      Text(
                        _employeeError!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      const Text(
                        'Chưa xác định nhân viên',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),

                    const SizedBox(height: 4),

                    // =========================
                    // MSNV
                    // =========================
                    Text(
                      code.isEmpty ? 'MSNV: --' : 'MSNV: $code',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              if (_employeeLoading)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.orangeAccent,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _normalizeEmployeeCode(String? value) {
    if (value == null) {
      return '';
    }

    return value.trim().replaceAll(' ', '').toUpperCase();
  }

  Future<void> _resolveEmployee(String rawCode) async {
    final code = _normalizeEmployeeCode(rawCode);

    if (code.isEmpty || !mounted) {
      return;
    }

    final token = ++_employeeRequestToken;

    setState(() {
      _employeeLoading = true;
      _employeeResolved = false;
      _employeeName = null;
      _employeeError = null;
    });

    try {
      final result = await HseMasterService.fetchEmployeeName(code);

      debugPrint('[EMPLOYEE LOOKUP] code=$code | result=$result');

      if (!mounted || token != _employeeRequestToken) {
        return;
      }

      final name = result?.trim();

      if (name == null || name.isEmpty || name.toLowerCase() == 'null') {
        setState(() {
          _employeeName = null;
          _employeeResolved = false;
          _employeeError = 'Không tìm thấy nhân viên';
        });

        return;
      }

      setState(() {
        _employeeName = name;
        _employeeResolved = true;
        _employeeError = null;
      });
    } catch (e, stackTrace) {
      debugPrint(
        '[EMPLOYEE LOOKUP ERROR] '
        'code=$code | error=$e',
      );

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted || token != _employeeRequestToken) {
        return;
      }

      setState(() {
        _employeeName = null;
        _employeeResolved = false;
        _employeeError = 'Không thể kiểm tra MSNV';
      });
    } finally {
      if (mounted && token == _employeeRequestToken) {
        setState(() {
          _employeeLoading = false;
        });
      }
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

  bool get _canSubmitHse {
    if (_employeeLoading) {
      return false;
    }

    if (!_employeeResolved) {
      return false;
    }

    if (_employeeName == null || _employeeName!.trim().isEmpty) {
      return false;
    }

    if (_msnvCtrl.text.trim().isEmpty) {
      return false;
    }

    return true;
  }

  Future<void> updateHseReport({
    required int reportId,
    required String hseUser,
    required String hseJudge,
    required String comment,
    required List<Uint8List> images,
  }) async {
    final String atStatus = hseJudge == 'OK' ? 'Closed' : 'Redo';

    final dataJson = {
      "hseUser": hseUser,
      "hseJudge": hseJudge,
      "hseComment": comment,
      "atStatus": atStatus,
    };

    final formData = FormData();

    // JSON
    formData.fields.add(MapEntry('data', jsonEncode(dataJson)));

    // Images
    for (int i = 0; i < images.length; i++) {
      formData.files.add(
        MapEntry(
          'images',
          MultipartFile.fromBytes(
            images[i],
            filename: 'hse_${i + 1}.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        ),
      );
    }

    final path = '/api/patrol_report/$reportId/hse_recheck';

    try {
      final response = await DioClient.putUpload(path, data: formData);

      debugPrint('=========== HSE UPDATE SUCCESS ==========');
      debugPrint('STATUS : ${response.statusCode}');
      debugPrint('DATA   : ${response.data}');
      debugPrint('=========================================');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('============= HSE UPDATE ERROR ==========');
      debugPrint('TYPE    : ${e.type}');
      debugPrint('MESSAGE : ${e.message}');
      debugPrint('STATUS  : ${e.response?.statusCode}');
      debugPrint('DATA    : ${e.response?.data}');
      debugPrint('=========================================');

      throw Exception(
        e.response?.data?.toString() ?? e.message ?? 'Upload failed',
      );
    }
  }

  Future<void> _submitHseJudge(String value) async {
    if (_employeeLoading) {
      _showSnackBar(
        'Đang kiểm tra MSNV, vui lòng chờ.',
        Colors.orange,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    if (!_employeeResolved ||
        _employeeName == null ||
        _employeeName!.trim().isEmpty) {
      _showSnackBar(
        'MSNV không hợp lệ hoặc chưa tìm thấy tên nhân viên.',
        Colors.orange,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    final reportId = widget.report.id;

    if (reportId == null) {
      _showSnackBar('Report ID không hợp lệ.', Colors.redAccent);
      return;
    }

    final employeeCode = _normalizeEmployeeCode(_msnvCtrl.text);

    final employeeName = _employeeName!.trim();

    final hseUser = '${employeeCode}_$employeeName';

    try {
      setState(() {
        _hseJudge = value;
      });

      showLoading(context);

      await updateHseReport(
        reportId: reportId,
        hseUser: hseUser,
        hseJudge: value,
        comment: _commentCtrl.text.trim(),
        images: _cameraKey.currentState?.images ?? const <Uint8List>[],
      );

      if (!mounted) return;

      hideLoading(context);

      if (!mounted) return;

      // ⭐ Báo màn trước rằng data đã thay đổi
      Navigator.of(context).pop(true);
    } catch (e, stackTrace) {
      debugPrint('[HSE UPDATE ERROR] $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      hideLoading(context);

      setState(() {
        _hseJudge = null;
      });

      _showSnackBar('Server error: $e', Colors.redAccent);
    }
  }
}
