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
  bool _replaceMode = false;
  bool _loading = false;

  Uint8List? _newImage;

  /// 🔥 QUAN TRỌNG: ảnh hiện tại
  late String _currentImageName;

  @override
  void initState() {
    super.initState();
    _currentImageName = widget.imageName;
  }

  String get imageUrl => 'http://localhost:7000/$_currentImageName';

  Future<void> _submitReplace() async {
    if (_newImage == null) return;

    setState(() => _loading = true);

    try {
      final newImageName = await replaceImageApi(
        id: widget.report.id!,
        oldImage: _currentImageName, // ✅ LUÔN ĐÚNG
        newImageBytes: _newImage!,
      );

      setState(() {
        _currentImageName = newImageName; // 🔥 UPDATE ẢNH HIỆN TẠI
        _replaceMode = false;
        _newImage = null;
      });

      widget.onReplaced(newImageName);
      // nếu parent cần reload list
    } catch (e) {
      print("err: ${e.toString()}");
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
        /// ================= IMAGE =================
        SizedBox(
          height: 220,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _newImage != null
                    ? Image.memory(
                        _newImage!,
                        key: ValueKey(_newImage),
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

              /// CAMERA BUTTON
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

        /// ================= CAMERA =================
        if (_replaceMode)
          Expanded(
            child: Column(
              children: [
                CameraUpdateBox(
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
