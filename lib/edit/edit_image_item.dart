import 'dart:typed_data';
import 'dart:ui';
import 'package:chuphinh/edit/camera_edit_box.dart';
import 'package:flutter/material.dart';
import '../api/api_config.dart';
import '../api/replace_image_api.dart';
import '../homeScreen/patrol_home_screen.dart';
import '../model/patrol_report_model.dart';
import '../widget/glass_action_button.dart';

class EditImageItem extends StatefulWidget {
  final String imageName;
  final PatrolReportModel report;
  final PatrolGroup patrolGroup;
  final String? plant;

  /// callback cho CHA
  final void Function(String newImage) onAdd;
  final VoidCallback onDelete;

  const EditImageItem({
    super.key,
    required this.imageName,
    required this.report,
    required this.patrolGroup,
    this.plant,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  State<EditImageItem> createState() => _EditImageItemState();
}

class _EditImageItemState extends State<EditImageItem> {
  bool _loading = false;
  List<Uint8List> _newImages = [];

  final GlobalKey<CameraEditBoxState> _cameraKey = GlobalKey();

  String get imageUrl => '${ApiConfig.baseUrl}/images/${widget.imageName}';
  static const int maxTotalImages = 2;
  late int _currentImageCount; // ✅ THÊM
  int get existingImages => _currentImageCount;
  int get remainAllow => maxTotalImages - existingImages;
  bool get _canAddImage => remainAllow > 0;

  // ================= ADD IMAGE =================

  // ================= DELETE IMAGE =================
  Future<void> _deleteImage() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.black.withOpacity(0.6),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ⚠️ ICON
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_forever,
                        color: Colors.redAccent,
                        size: 34,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // TITLE
                    const Text(
                      "Delete Image?",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // CONTENT
                    const Text(
                      "This image will be permanently deleted.\nThis action cannot be undone.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),

                    const SizedBox(height: 22),

                    // BUTTONS
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.25),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text("Cancel"),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.withOpacity(
                                0.9,
                              ),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              "Delete",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (ok != true) return;

    setState(() => _loading = true);

    try {
      await deleteImageApi(id: widget.report.id!, imageName: widget.imageName);

      setState(() {
        _currentImageCount--; // ✅
      });

      widget.onDelete(); // 🔥 báo CHA remove
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  // ================= ZOOM =================
  void _openViewer() {
    showDialog(
      context: context,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Image.network(
                    imageUrl,
                    headers: {'ngrok-skip-browser-warning': 'true'},
                    fit: BoxFit.contain,
                  ),
                ),
              ),
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
  }

  @override
  void initState() {
    super.initState();
    _currentImageCount = widget.report.imageNames.length;
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          GestureDetector(
            onTap: _openViewer,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                headers: {'ngrok-skip-browser-warning': 'true'},
              ),
            ),
          ),

          /// 🗑 DELETE
          Positioned(
            top: 8,
            right: 8,
            child: _iconBtn(Icons.delete_forever, _deleteImage),
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
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    final disabled = icon == Icons.add_a_photo && !_canAddImage;

    return InkWell(
      onTap: disabled
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chỉ được tối đa 2 ảnh'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          : onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: disabled ? Colors.black26 : Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          // 🔥 LUÔN HIỆN
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}
