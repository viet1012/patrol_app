import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

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

class AfterPatrol extends StatefulWidget {
  final String accountCode;

  // final String plant;
  final int? id; // bắt buộc
  final String? qrCode; // có thể null
  final PatrolGroup patrolGroup;

  const AfterPatrol({
    super.key,
    required this.accountCode,
    // required this.plant,
    this.id,
    this.qrCode,
    required this.patrolGroup,
  });

  @override
  State<AfterPatrol> createState() => _AfterPatrolState();
}

class _AfterPatrolState extends State<AfterPatrol> {
  final GlobalKey<CameraAfterBoxState> _cameraKey =
      GlobalKey<CameraAfterBoxState>();

  bool _enableCamera = false;
  final TextEditingController _commentAfStatusCtrl = TextEditingController();
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

  PatrolReportModel? _report;
  bool _loading = true;
  String? _error;

  String get _lookupKey {
    final q = widget.qrCode?.trim();
    if (q != null && q.isNotEmpty) return q;
    return widget.id?.toString() ?? 'NO_ID';
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final q = widget.qrCode?.trim();
      final list = await PatrolReportApi.fetchReports(
        qrKey: (q != null && q.isNotEmpty) ? q : null,
        id: (q == null || q.isEmpty) ? widget.id : null,
      );

      if (list.isEmpty) {
        setState(() {
          _error = 'Không tìm thấy report cho key=$_lookupKey';
          _loading = false;
        });
        return;
      }

      // nếu API trả nhiều cái, lấy cái đúng nhất
      final picked = (widget.id != null)
          ? list.firstWhere((e) => e.id == widget.id, orElse: () => list.first)
          : list.first;

      final rawPic = picked.pic?.trim();
      final selected = (rawPic == null || rawPic.isEmpty) ? emptyLabel : rawPic;
      setState(() {
        _report = picked;
        _selectedPIC = selected;
        _oldPIC = selected;
        _futurePics = findPicsByPlantFromApi(picked.plant);
        _loading = false;
        _enableCamera = true;
      });
      _commentAfStatusCtrl.text = _report?.atComment ?? '';
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _msnvCtrl.text = widget.accountCode;
    fetchEmployeeName(
      widget.accountCode,
    ).then((name) => debugPrint('EMPLOYEE NAME = $name'));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReport(); // ✅ gọi sau khi build frame đầu
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _commentAfStatusCtrl.dispose();

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
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121826),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return CommonUI.warningPage(context: context, message: _error!);
    }

    final report = _report!; //  dùng report thay widget.report
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
                  'Patrol After',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Text(
                  report.plant,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
            Text(
              widget.id == null
                  ? 'QR: ${widget.qrCode ?? "-"}'
                  : 'ID: ${widget.id}',
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
                          value: report.grp,
                          color: Colors.blue.shade400,
                        ),
                        const SizedBox(height: 8),
                        _buildInfoCard(
                          icon: Icons.location_on_rounded,
                          label: "area".tr(context),
                          value: report.area,
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
                          value: report.division,
                          color: Colors.purple.shade400,
                        ),
                        const SizedBox(height: 8),

                        _buildInfoCard(
                          icon: Icons.precision_manufacturing_rounded,
                          label: "machine".tr(context),
                          value: report.machine,
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
                        content: report.comment,
                        icon: Icons.comment_rounded,
                        accentColor: Colors.amber.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSectionCard(
                        title: 'Countermeasure',
                        content: report.countermeasure,
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
                            value: formatDateTime(report.createdAt),
                          ),
                          const SizedBox(height: 8),
                          _buildRiskCard(
                            icon: Icons.groups_rounded,
                            label: "Review Similar Cases",
                            value: report.checkInfo,
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
                            value: formatDateTime(report.dueDate),
                            color: Colors.white70,
                          ),
                          const SizedBox(height: 8),
                          _buildRiskCard(
                            icon: Icons.groups_rounded,
                            label: "label_risk".tr(context),
                            value: report.riskTotal,
                            color:
                                (report.riskTotal == "V" ||
                                    report.riskTotal == "IV")
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
                  value: report.patrol_user!,
                ),
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

              Row(
                children: [
                  Expanded(
                    child: _sectionInlineEdit('Comment', _commentAfStatusCtrl),
                  ),
                  if (_commentAfStatusCtrl.text.trim().isNotEmpty)
                    GlassActionButton(
                      icon: Icons.browser_updated,
                      onTap: _onSaveUpdateAfStatus,
                      backgroundColor: Colors.lightBlue,
                    ),
                ],
              ),

              const SizedBox(height: 12),
              _buildImageGrid(report.imageNames, report),
              const SizedBox(height: 8),
              _buildRetakeSection(report),
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
        crossAxisAlignment: CrossAxisAlignment.start, // 👈 quan trọng
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),

          // 👇 CHO PHÉP XUỐNG DÒNG
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              softWrap: true,
              maxLines: null, // 👈 không giới hạn dòng
              overflow: TextOverflow.visible,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
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

  Widget _buildImageGrid(List<String> images, PatrolReportModel patrolReport) {
    // ===== CASE 1: chỉ có 1 ảnh → căn giữa =====
    if (images.length == 1) {
      return SizedBox(
        height: 320,
        child: Center(
          child: SizedBox(
            width: 320,
            child: ReplaceableImageItem(
              imageName: images.first,
              report: patrolReport,
              patrolGroup: widget.patrolGroup,
              plant: patrolReport.plant,
              onReplaced: (newImage) {
                setState(() {
                  images[0] = newImage;
                });
              },
            ),
          ),
        ),
      );
    }

    // ===== CASE 2: nhiều ảnh → scroll ngang =====
    return SizedBox(
      height: 320,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 320,
            child: ReplaceableImageItem(
              imageName: images[index],
              report: patrolReport,
              patrolGroup: widget.patrolGroup,
              plant: patrolReport.plant,
              onReplaced: (newImage) {
                setState(() {
                  images[index] = newImage;
                });
              },
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

                      // setState(() {
                      //   _retakeImages.removeAt(idx);
                      //   if (_retakeImages.isEmpty) {
                      //     _enableCamera = true;
                      //   }
                      // });
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
        final items = <String>{emptyLabel, ...picList}.toList();
        return CommonSearchableDropdown(
          label: "PIC",
          selectedValue: _selectedPIC,
          items: items,
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

  Future<void> _onSaveUpdateAfStatus() async {
    try {
      await updateReportApi(
        id: _report!.id!,
        atComment: _commentAfStatusCtrl.text.trim(),
        atStatus: 'Wait',
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
          onChanged: (value) {
            setState(
              () {},
            ); // Bắt buộc gọi setState để UI rebuild và nút lưu hiện/ẩn đúng
          },
        ),
      ],
    );
  }

  Widget _buildRetakeSection(PatrolReportModel report) {
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
              plant: report.plant,
              patrolGroup: widget.patrolGroup,
              type: "RETAKE",
              onImagesChanged: (_) => setState(() {}),
            ),

            /// ===== COMMENT =====
            if (_cameraKey.currentState != null &&
                _cameraKey.currentState!.images.isNotEmpty) ...[
              //   const SizedBox(height: 16),
              //   TextField(
              //     controller: _commentCtrl,
              //     maxLines: 3,
              //     decoration: InputDecoration(
              //       labelText: 'Comment',
              //       labelStyle: const TextStyle(color: Colors.white70),
              //       enabledBorder: OutlineInputBorder(
              //         borderSide: BorderSide(color: Colors.white54),
              //         borderRadius: BorderRadius.circular(8),
              //       ),
              //       focusedBorder: OutlineInputBorder(
              //         borderSide: BorderSide(color: Colors.blueAccent.shade200),
              //         borderRadius: BorderRadius.circular(8),
              //       ),
              //       filled: true,
              //       fillColor: Colors.white.withOpacity(0.12),
              //     ),
              //     style: const TextStyle(color: Colors.white),
              //     onChanged: (value) {
              //       setState(
              //         () {},
              //       ); // Bắt buộc gọi setState để UI rebuild và nút lưu hiện/ẩn đúng
              //     },
              //   ),
              const SizedBox(height: 20),

              /// ===== SAVE =====
              // if (_commentAfStatusCtrl.text.trim().isNotEmpty)
              SizedBox(
                width: 60,
                height: 60,
                child: GlassActionButton(
                  onTap:
                      (_cameraKey.currentState != null &&
                          _cameraKey.currentState!.images.isNotEmpty &&
                          _msnvCtrl.text.trim().isNotEmpty)
                      ? () async {
                          if (_commentAfStatusCtrl.text.trim().isEmpty) {
                            _showSnackBar(
                              'Please enter comment before saving.',
                              Colors.orange,
                            );
                            return;
                          }

                          try {
                            showLoading(context);

                            await updateAtReport(
                              userAfter: widget.accountCode,
                              reportId: report.id!,
                              atPic: '${_msnvCtrl.text.trim()}_$_employeeName',
                              // comment: _commentCtrl.text.trim(),
                              comment: _commentAfStatusCtrl.text.trim(),

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
      // final picToApi = (_selectedPIC == emptyLabel) ? null : _selectedPIC;
      final picToApi = _selectedPIC; // gửi luôn kể cả UNKNOWN
      await updateReportApi(id: _report!.id!, pic: picToApi);

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
    final dio = DioClient.dio;

    final dataJson = {"atComment": comment, "atPic": atPic};

    final formData = FormData();

    // data (JSON STRING)
    formData.fields.add(MapEntry('data', jsonEncode(dataJson)));

    // images (BYTES)
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

    final url = '/api/patrol_report/$reportId/update_at';

    debugPrint('Calling PUT $url');
    debugPrint('Base URL: ${dio.options.baseUrl}');
    debugPrint('Full URL: ${dio.options.baseUrl}$url');

    try {
      final response = await dio.put(
        url,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response data: ${response.data}');
    } catch (e) {
      debugPrint('Error during PUT request: $e');
      rethrow;
    }
  }
}
