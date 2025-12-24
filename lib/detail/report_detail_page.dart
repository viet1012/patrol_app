import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' hide MultipartFile;

import '../api/api_config.dart';
import '../api/dio_client.dart';
import '../camera_preview_box.dart';
import '../homeScreen/patrol_home_screen.dart';
import '../model/patrol_report_model.dart';
import '../widget/glass_action_button.dart';
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
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 4, // 👈 kéo sát về leading
        leading: GlassActionButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
        backgroundColor: const Color(0xFF121826),
        title: Text(
          'Patrol After',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
          ),
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

  Widget _sectionInline(String title, String content) {
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
        Text(
          content.isEmpty ? '-' : content,
          style: TextStyle(color: Colors.white.withOpacity(0.85)),

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
                    ? () async {
                        try {
                          await updateAtReport(
                            reportId: widget.report.id!,
                            msnv: _msnvCtrl.text.trim(),
                            comment: _commentCtrl.text.trim(),
                            images: _retakeImages,
                          );

                          /// RESET UI → cho phép chụp lại tiếp
                          setState(() {
                            _retakeImages.clear();
                            _commentCtrl.clear();
                            _enableCamera = false;
                          });

                          /// FORCE reload camera
                          await Future.delayed(
                            const Duration(milliseconds: 200),
                          );
                          setState(() => _enableCamera = true);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cập nhật AT thành công'),
                            ),
                          );
                        } catch (e) {
                          debugPrint('Update AT error: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lỗi cập nhật AT')),
                          );
                        }
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

  Future<void> updateAtReport({
    required int reportId,
    required String msnv,
    required String comment,
    required List<Uint8List> images,
  }) async {
    final dio = DioClient.dio;

    final dataJson = {"atComment": comment, "atPic": msnv};

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
