import 'dart:typed_data';
import 'package:chuphinh/api/api_config.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../api/replace_image_api.dart';
import '../homeScreen/patrol_home_screen.dart';
import '../model/patrol_report_model.dart';
import 'camera_update_box.dart';

class ReplaceableImageItem extends StatefulWidget {
  final String imageName;
  final PatrolReportModel report;
  final PatrolGroup patrolGroup;
  final String? plant;
  final void Function(String newImage) onReplaced;

  const ReplaceableImageItem({
    super.key,
    required this.imageName,
    required this.report,
    required this.patrolGroup,
    this.plant,
    required this.onReplaced,
  });

  @override
  State<ReplaceableImageItem> createState() => _ReplaceableImageItemState();
}

class _ReplaceableImageItemState extends State<ReplaceableImageItem> {
  bool _loading = false;
  Uint8List? _newImage;

  late String _currentImageName;
  Key _cameraKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _currentImageName = widget.imageName;
  }

  void _retake(StateSetter setModalState) {
    setModalState(() {
      _newImage = null;
      _cameraKey = UniqueKey(); // 🔥 ép CameraUpdateBox reset
    });
  }

  String get imageUrl => '${ApiConfig.baseUrl}/images/$_currentImageName';

  // ================= CAMERA OVERLAY =================
  Future<void> _openCameraOverlay() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),

                  /// 🔥 PREVIEW
                  if (_newImage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: AspectRatio(
                        aspectRatio: 1, // 👈 1:1 = vuông
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(_newImage!, fit: BoxFit.cover),
                        ),
                      ),
                    ),

                  /// 📷 CAMERA
                  CameraUpdateBox(
                    key: _cameraKey,
                    size: 300,
                    plant: widget.plant,
                    patrolGroup: widget.patrolGroup,
                    type: "REPLACE",
                    onImagesChanged: (images) {
                      if (images.isNotEmpty) {
                        setModalState(() {
                          _newImage = images.last;
                        });
                      }
                    },
                  ),

                  /// 🔘 BUTTONS
                  if (_newImage != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _retake(setModalState),
                              icon: const Icon(Icons.refresh),
                              label: const Text("Chụp lại"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _submitReplace();
                              },
                              icon: const Icon(Icons.check),
                              label: const Text("Replace"),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ================= SUBMIT =================
  Future<void> _submitReplace() async {
    if (_newImage == null) return;

    setState(() => _loading = true);

    try {
      final newImageName = await replaceImageApi(
        id: widget.report.id!,
        oldImage: _currentImageName,
        newImageBytes: _newImage!,
      );

      setState(() {
        _currentImageName = newImageName;
        _newImage = null;
      });

      widget.onReplaced(newImageName);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Replace failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220, // 🔥 CỐ ĐỊNH – KHÔNG BAO GIỜ ĐẨY LAYOUT
      child: Stack(
        children: [
          // ClipRRect(
          //   borderRadius: BorderRadius.circular(14),
          //   child: Image.network(
          //     imageUrl,
          //     width: double.infinity,
          //     height: double.infinity,
          //     fit: BoxFit.cover,
          //     key: ValueKey(imageUrl),
          //     headers: {'ngrok-skip-browser-warning': 'true'},
          //     // ?? FIX QUAN TR?NG
          //     // webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          //     //
          //     // errorBuilder: (context, error, stack) {
          //     //   print('error: ${error}');
          //     //
          //     //   return Center(
          //     //     child: Icon(Icons.broken_image, color: Colors.red),
          //     //   );
          //     // },
          //   ),
          // ),
          GestureDetector(
            onTap: _openImageViewer,
            child: Hero(
              tag: imageUrl, // 👈 tag phải unique
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  key: ValueKey(imageUrl),
                  headers: {'ngrok-skip-browser-warning': 'true'},
                ),
              ),
            ),
          ),

          /// CAMERA BUTTON
          // Positioned(
          //   top: 6,
          //   right: 6,
          //   child: InkWell(
          //     onTap: _openCameraOverlay,
          //     child: Container(
          //       padding: const EdgeInsets.all(6),
          //       decoration: const BoxDecoration(
          //         color: Colors.black54,
          //         shape: BoxShape.circle,
          //       ),
          //       child: const Icon(
          //         Icons.delete_forever,
          //         size: 18,
          //         color: Colors.white,
          //       ),
          //     ),
          //   ),
          // ),
          if (_loading)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black38,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  void _openImageViewer() {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: Hero(
                      tag: imageUrl,
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 5,
                        child: Image.network(
                          imageUrl,
                          headers: {'ngrok-skip-browser-warning': 'true'},
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  /// ❌ Close button
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
