import 'dart:typed_data';

import 'package:chuphinh/api/api_config.dart';
import 'package:flutter/material.dart';

import '../api/replace_image_api.dart';
import '../homeScreen/patrol_home_screen.dart';
import '../model/patrol_report_model.dart';
import 'after_camera_box.dart';

class ReplaceableImageItem extends StatefulWidget {
  final String imageName;
  final PatrolReportModel report;
  final PatrolGroup patrolGroup;
  final String? plant;
  final void Function(String newImage) onReplaced;

  const ReplaceableImageItem({super.key, required this.imageName, required this.report, required this.patrolGroup, this.plant, required this.onReplaced});

  @override
  State<ReplaceableImageItem> createState() => _ReplaceableImageItemState();
}

class _ReplaceableImageItemState extends State<ReplaceableImageItem> {
  late String _currentImageName;
  int _imageVersion = 0;

  String get imageUrl => '${ApiConfig.baseUrl}/images/$_currentImageName?v=$_imageVersion';

  @override
  void initState() {
    super.initState();
    _currentImageName = widget.imageName;
  }

  @override
  void didUpdateWidget(covariant ReplaceableImageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageName != oldWidget.imageName && widget.imageName != _currentImageName) {
      _currentImageName = widget.imageName;
      _imageVersion++;
    }
  }

  Future<void> _openReplaceSheet() async {
    final reportId = widget.report.id;
    if (reportId == null) return;

    final newImageName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ReplaceImageSheet(
        reportId: reportId,
        oldImageName: _currentImageName,
        plant: widget.plant,
        patrolGroup: widget.patrolGroup,
      ),
    );

    if (!mounted || newImageName == null || newImageName.isEmpty) return;
    setState(() {
      _currentImageName = newImageName;
      _imageVersion = DateTime.now().millisecondsSinceEpoch;
    });
    widget.onReplaced(newImageName);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 280 / 320,
      child: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _openImageViewer,
            child: Hero(
              tag: imageUrl,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(imageUrl, width: double.infinity, height: double.infinity, fit: BoxFit.cover, key: ValueKey(imageUrl)),
              ),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Replace image',
              onPressed: _openReplaceSheet,
              icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
            ),
          ),
        ),
      ]),
    );
  }

  void _openImageViewer() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) => GestureDetector(
        onTap: () => Navigator.pop(dialogContext),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: SizedBox.expand(child: FittedBox(fit: BoxFit.contain, child: Image.network(imageUrl))),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(dialogContext)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class ReplaceImageSheet extends StatefulWidget {
  final int reportId;
  final String oldImageName;
  final String? plant;
  final PatrolGroup patrolGroup;

  const ReplaceImageSheet({super.key, required this.reportId, required this.oldImageName, this.plant, required this.patrolGroup});

  @override
  State<ReplaceImageSheet> createState() => _ReplaceImageSheetState();
}

class _ReplaceImageSheetState extends State<ReplaceImageSheet> {
  Uint8List? _image;
  bool _submitting = false;
  Key _cameraKey = UniqueKey();

  void _selectImage(List<Uint8List> images) {
    if (images.isEmpty || _image != null) return;
    setState(() => _image = images.last);
  }

  void _retake() {
    if (_submitting) return;
    setState(() {
      _image = null;
      _cameraKey = UniqueKey();
    });
  }

  Future<void> _replace() async {
    final image = _image;
    if (image == null || _submitting) return;
    setState(() => _submitting = true);

    try {
      final name = await replaceImageApi(id: widget.reportId, oldImage: widget.oldImageName, newImageBytes: image);
      if (!mounted) return;
      Navigator.pop(context, name);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Replace failed: $error')));
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 16),
          if (_image == null)
            AfterCameraBox(
              key: _cameraKey,
              size: 300,
              plant: widget.plant,
              patrolGroup: widget.patrolGroup,
              type: 'REPLACE',
              onImagesChanged: _selectImage,
            )
          else
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_image!, fit: BoxFit.cover)),
            ),
          if (_image != null) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: _submitting ? null : _retake, icon: const Icon(Icons.refresh), label: const Text('Retake'))),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _replace,
                  icon: _submitting
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: const Text('Replace'),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
