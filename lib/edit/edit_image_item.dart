import 'dart:typed_data';
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

  int get existingImages => widget.report.imageNames.length;
  int get remainAllow => maxTotalImages - existingImages;
  bool get _canAddImage => remainAllow > 0;

  // ================= ADD IMAGE =================
  Future<void> _openAddCamera() async {
    if (!_canAddImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chỉ được tối đa 2 ảnh'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),

                if (_newImages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _newImages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  _newImages[index],
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                ),
                              ),

                              /// ❌ nút xoá từng ảnh
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () {
                                    setModal(() {
                                      _newImages.removeAt(index);
                                    });

                                    // 🔥 BÁO CameraEditBox xoá ảnh tương ứng
                                    _cameraKey.currentState?.removeImage(index);
                                  },

                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                CameraEditBox(
                  key: _cameraKey,
                  size: 300,
                  plant: widget.plant,
                  type: "ADD",
                  maxAllowImages: remainAllow,
                  onImagesChanged: (imgs) {
                    setModal(() {
                      _newImages = List.from(imgs);
                    });
                  },
                ),

                // if (_newImages.isNotEmpty)
                //   Padding(
                //     padding: const EdgeInsets.all(12),
                //     child: ElevatedButton.icon(
                //       icon: const Icon(Icons.check),
                //       label: const Text("Thêm ảnh"),
                //       onPressed: () async {
                //         Navigator.pop(context);
                //         await _submitAdd();
                //       },
                //     ),
                //   ),
                GlassActionButton(
                  icon: Icons.send_rounded,
                  enabled: _newImages.isNotEmpty,
                  onTap: () async {
                    Navigator.pop(context);
                    await _submitAdd();
                  },
                  backgroundColor: _newImages.isNotEmpty
                      ? const Color(0xFF22C55E)
                      : null,
                  iconColor: _newImages.isNotEmpty
                      ? Colors.black
                      : Colors.white,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitAdd() async {
    if (_newImages.isEmpty) return;

    setState(() => _loading = true);

    try {
      for (final img in _newImages) {
        final newImageName = await addImageApi(
          id: widget.report.id!,
          imageBytes: img,
        );

        widget.onAdd(newImageName);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Add failed: $e')));
    } finally {
      setState(() {
        _loading = false;
        _newImages.clear();
      });
    }
  }

  // ================= DELETE IMAGE =================
  Future<void> _deleteImage() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ⚠️ ICON
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_forever,
                    color: Colors.white,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 16),

                // TITLE
                const Text(
                  "Delete Image?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                // CONTENT
                const Text(
                  "This image will be permanently deleted.\nThis action cannot be undone.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),

                const SizedBox(height: 20),

                // BUTTONS
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text("Delete"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (ok != true) return;

    setState(() => _loading = true);

    try {
      await deleteImageApi(id: widget.report.id!, imageName: widget.imageName);

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

          /// ➕ ADD
          Positioned(
            bottom: 8,
            left: 8,
            child: _iconBtn(Icons.add_a_photo, _openAddCamera),
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
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: disabled ? Colors.black26 : Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: disabled ? Colors.white38 : Colors.white,
          size: 18,
        ),
      ),
    );
  }
}
