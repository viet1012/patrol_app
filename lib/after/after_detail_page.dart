import 'dart:async';
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
import 'camera_after_box.dart';
import 'replaceable_image_item.dart';

class AfterDetailPage extends StatefulWidget {
  final PatrolReportModel report;
  final PatrolGroup patrolGroup;
  const AfterDetailPage({
    super.key,
    required this.report,
    required this.patrolGroup,
  });

  @override
  State<AfterDetailPage> createState() => _AfterDetailPageState();
}

class _AfterDetailPageState extends State<AfterDetailPage> {
  final GlobalKey<CameraAfterBoxState> _cameraKey =
      GlobalKey<CameraAfterBoxState>();

  bool _enableCamera = false;

  final TextEditingController _commentCtrl = TextEditingController();
  final TextEditingController _msnvCtrl = TextEditingController();
  String? _employeeName;
  bool _isLoadingName = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
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
          onTap: () => Navigator.pop(context, true),
        ),
        backgroundColor: const Color(0xFF121826),
        title: Column(
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
              widget.report.plant,
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

  Widget _buildRetakeSection() {
    return Card(
      color: const Color(0xFF121826).withOpacity(.4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),

            /// ===== MSNV =====
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _msnvCtrl,
                    decoration: InputDecoration(
                      labelText: 'Code',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.blueAccent.shade200,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.12),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (v) {
                      final value = v.trim();

                      // Hủy timer cũ nếu còn
                      if (_debounce?.isActive ?? false) {
                        _debounce!.cancel();
                      }

                      // Chỉ xử lý khi đủ 4 ký tự
                      if (value.length < 4) return;

                      _debounce = Timer(const Duration(milliseconds: 400), () {
                        fetchEmployeeName(value);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white38),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _isLoadingName
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _employeeName ?? 'Name',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            /// ===== THUMBNAIL PREVIEW =====
            _buildThumbPreview(),

            const SizedBox(height: 12),

            /// ===== CAMERA =====
            // if (_enableCamera)
            CameraAfterBox(
              key: _cameraKey,
              size: 280,
              plant: widget.report.plant,
              patrolGroup: widget.patrolGroup,
              type: "RETAKE",
              onImagesChanged: (_) => setState(() {}),
            ),

            /// ===== COMMENT =====
            if (_cameraKey.currentState != null &&
                _cameraKey.currentState!.images.isNotEmpty) ...[
              const SizedBox(height: 16),
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
                              reportId: widget.report.id!,
                              msnv: '${_msnvCtrl.text.trim()}_$_employeeName',
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

  Future<void> fetchEmployeeName(String code) async {
    if (code.trim().isEmpty) {
      setState(() {
        _employeeName = null;
      });
      return;
    }

    setState(() {
      _isLoadingName = true;
    });

    try {
      final dio = DioClient.dio;
      final response = await dio.get(
        '/api/hr/name',
        queryParameters: {'code': code.trim()},
      );

      if (response.statusCode == 200) {
        setState(() {
          _employeeName = response.data.toString();
        });
      } else {
        setState(() {
          _employeeName = null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching employee name: $e');
      setState(() {
        _employeeName = null;
      });
    } finally {
      setState(() {
        _isLoadingName = false;
      });
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
