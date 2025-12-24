import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../camera_preview_box.dart';
import '../homeScreen/patrol_home_screen.dart';
import '../model/patrol_report_model.dart';
import 'CameraBox.dart';
import 'replaceable_image_item.dart';

class ReportDetailPage extends StatefulWidget {
  final PatrolReportModel report;
  final PatrolGroup patrolGroup;
  const ReportDetailPage({
    super.key,
    required this.report,
    required this.patrolGroup,
  });

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  final GlobalKey<CameraPreviewBoxState> _cameraKey =
      GlobalKey<CameraPreviewBoxState>();

  List<Uint8List> _retakeImages = [];

  bool _enableCamera = false;

  final TextEditingController _commentCtrl = TextEditingController();
  final TextEditingController _msnvCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    _msnvCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Detail')),
      body: SingleChildScrollView(
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
                Expanded(
                  child: _sectionInline('Comment', widget.report.comment),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: _sectionInline(
                    'Countermeasure',
                    widget.report.countermeasure,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            _buildImageGrid(widget.report.imageNames),
            const SizedBox(height: 8),
            _buildRetakeSection(),
          ],
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
                color: Colors.black87,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionInline(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          content.isEmpty ? '-' : content,
          style: const TextStyle(color: Colors.black54),
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildImageGrid(List<String> images) {
    final h = MediaQuery.of(context).size.height;

    return SizedBox(
      height: 320, // 👈 đủ cho image + camera
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 280,
            child: ReplaceableImageItem(
              imageName: images[index],
              report: widget.report,
              patrolGroup: widget.patrolGroup,
              plant: widget.report.plant,
              onReplaced: (newImage) {
                setState(() {
                  images[index] = newImage; // 🔥 UPDATE LIST CHA
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildThumbPreview() {
    if (_retakeImages.isEmpty) return const SizedBox();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _retakeImages.asMap().entries.map((entry) {
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
                      setState(() {
                        _retakeImages.removeAt(idx);
                        if (_retakeImages.isEmpty) {
                          _enableCamera = true;
                        }
                      });
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

  Widget _buildRetakeSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // const Text(
            //   'Chụp lại & cập nhật',
            //   style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            // ),
            const SizedBox(height: 12),

            /// ===== MSNV =====
            TextField(
              controller: _msnvCtrl,
              decoration: const InputDecoration(
                labelText: 'MSNV',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                if (v.trim().isNotEmpty && !_enableCamera) {
                  setState(() => _enableCamera = true);
                }
              },
            ),

            const SizedBox(height: 12),

            /// ===== THUMBNAIL PREVIEW =====
            _buildThumbPreview(),

            const SizedBox(height: 12),

            /// ===== CAMERA =====
            if (_enableCamera)
              CameraUpdateBox(
                key: ValueKey(DateTime.now().millisecondsSinceEpoch),
                size: 280,
                plant: widget.report.plant,
                patrolGroup: widget.patrolGroup,
                type: "RETAKE",
                onImagesChanged: (images) {
                  if (images.isNotEmpty) {
                    setState(() {
                      _retakeImages.add(images.last);
                    });
                  }
                },
              ),

            /// ===== COMMENT =====
            if (_retakeImages.isNotEmpty) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _commentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Comment',
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            const SizedBox(height: 20),

            /// ===== SAVE =====
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed:
                    (_retakeImages.isNotEmpty &&
                        _msnvCtrl.text.trim().isNotEmpty)
                    ? () {
                        debugPrint('MSNV: ${_msnvCtrl.text}');
                        debugPrint('Comment: ${_commentCtrl.text}');
                        debugPrint('Total images: ${_retakeImages.length}');

                        // TODO: API upload nhiều ảnh
                      }
                    : null,
                icon: const Icon(Icons.save),
                label: const Text('Lưu cập nhật'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
