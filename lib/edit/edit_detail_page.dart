import 'dart:async';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../api/replace_image_api.dart';
import '../common/common_ui_helper.dart';
import 'edit_image_item.dart';
import '../homeScreen/patrol_home_screen.dart';
import '../model/patrol_report_model.dart';
import '../widget/glass_action_button.dart';
import 'camera_edit_box.dart';

class EditDetailPage extends StatefulWidget {
  final PatrolReportModel report;
  final PatrolGroup patrolGroup;
  const EditDetailPage({
    super.key,
    required this.report,
    required this.patrolGroup,
  });

  @override
  State<EditDetailPage> createState() => _EditDetailPageState();
}

class _EditDetailPageState extends State<EditDetailPage> {
  final GlobalKey<CameraEditBoxState> _cameraKey =
      GlobalKey<CameraEditBoxState>();

  final TextEditingController _commentCtrl = TextEditingController();
  final TextEditingController _counterCtrl = TextEditingController();

  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    _commentCtrl.text = widget.report.comment;
    _counterCtrl.text = widget.report.countermeasure;
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
              // ===== 2 cột thông tin =====
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoItem('Group', widget.report.grp),
                        _infoItem('Area', widget.report.area),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoItem('Division', widget.report.division),
                        _infoItem('Machine', widget.report.machine),
                      ],
                    ),
                  ),
                ],
              ),

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

  Widget _infoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(color: Colors.white.withOpacity(0.85)),
            ),
          ],
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
