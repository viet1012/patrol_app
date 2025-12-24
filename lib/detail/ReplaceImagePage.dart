import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api/replace_image_api.dart';
import '../camera_preview_box.dart';
import '../homeScreen/patrol_home_screen.dart';
import '../model/patrol_report_model.dart';
import 'CameraBox.dart';

class ReplaceableImageItem extends StatefulWidget {
  final String imageName;
  final PatrolReportModel report;
  final PatrolGroup patrolGroup;
  final String? plant;
  final VoidCallback onReplaced;

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
  bool _replaceMode = false;
  Uint8List? _newImage;
  bool _loading = false;

  String get imageUrl => 'http://192.168.122.15:7000/${widget.imageName}';

  Future<void> _submitReplace() async {
    if (_newImage == null) return;

    setState(() => _loading = true);

    try {
      await replaceImageApi(
        id: widget.report.id!,
        oldImage: widget.imageName,
        newImageBytes: _newImage!,
      );

      widget.onReplaced();

      setState(() {
        _replaceMode = false;
        // _newImage = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Replace failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// 🖼 IMAGE – height cố định
        SizedBox(
          height: 220,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _newImage != null
                    ? Image.memory(
                        _newImage!,
                        key: ValueKey(_newImage), // 👈 QUAN TRỌNG
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        imageUrl,
                        key: ValueKey(imageUrl),
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),

              /// BTN CAMERA
              Positioned(
                top: 6,
                right: 6,
                child: InkWell(
                  onTap: () => setState(() => _replaceMode = !_replaceMode),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              if (_loading)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black38,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),

        ///  CAMERA – ăn phần còn lại
        if (_replaceMode)
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: CameraUpdateBox(
                    plant: widget.plant,
                    patrolGroup: widget.patrolGroup,
                    type: "REPLACE",
                    onImagesChanged: (images) {
                      if (images.isNotEmpty) {
                        setState(() {
                          _newImage = images.last;
                        });
                      }
                    },
                  ),
                ),

                /// BUTTON – height cố định
                if (_newImage != null)
                  SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitReplace,
                      icon: const Icon(Icons.check),
                      label: const Text("Replace"),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
