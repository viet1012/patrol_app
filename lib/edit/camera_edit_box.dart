import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:ui';
import 'dart:ui_web' as ui_web;

import 'package:chuphinh/socket/SttWebSocket.dart';
import 'package:chuphinh/widget/glass_circle_button.dart';
import 'package:chuphinh/widget/glass_zoom_control.dart';
import 'package:flutter/material.dart';

import '../homeScreen/patrol_home_screen.dart';

class CameraEditBox extends StatefulWidget {
  final double size;
  final Function(List<Uint8List> images)? onImagesChanged;

  final String? plant; // ✅ THÊM
  final String? group; // ✅ BẮT BUỘC
  final String type;
  final String? wsUrl;
  final PatrolGroup patrolGroup;

  const CameraEditBox({
    super.key,
    this.size = 320,
    this.onImagesChanged,
    this.group,
    required this.type,
    this.plant,

    this.wsUrl,

    required this.patrolGroup,
  });

  @override
  State<CameraEditBox> createState() => CameraEditBoxState();
}

class CameraEditBoxState extends State<CameraEditBox>
    with TickerProviderStateMixin {
  html.MediaStream? _stream;
  html.VideoElement? _videoElement;
  String _viewType = 'camera_${DateTime.now().millisecondsSinceEpoch}';
  bool _isCapturing = false;
  late AnimationController _flashController;

  final List<Uint8List> _capturedImages = [];

  // internal api (use widget.sttCtrl if provided)
  late String _fac;
  late String _group;

  int stt = 0;
  SttWebSocket? sttSocket;

  static const int maxImages = 2;

  Future<void> pickImagesFromDevice(BuildContext context) async {
    final remain = maxImages - _capturedImages.length;

    // ❌ Đã đủ ảnh → báo ngay
    if (remain <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You can upload up to $maxImages images only."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final uploadInput = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = true;

    uploadInput.click();

    uploadInput.onChange.listen((event) async {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;

      // ⚠️ Nếu chọn vượt quá số còn lại → báo
      if (files.length > remain) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "You can select only $remain more image${remain > 1 ? 's' : ''} "
              "(maximum $maxImages images).",
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      final selectedFiles = files.take(remain);

      for (final file in selectedFiles) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoadEnd.first;

        final bytes = reader.result as Uint8List;

        setState(() {
          _capturedImages.add(bytes);
        });
      }

      widget.onImagesChanged?.call(_capturedImages);
    });
  }

  bool get canUpload => _capturedImages.length < maxImages;

  @override
  void initState() {
    super.initState();

    _fac = (widget.plant ?? "").trim();
    _group = (widget.group ?? "").trim();

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _startCamera();
  }

  @override
  void didUpdateWidget(covariant CameraEditBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newFac = (widget.plant ?? "").trim();
    final newGroup = (widget.group ?? "").trim();

    final groupChanged = oldWidget.group != widget.group;
    final facChanged = oldWidget.plant != widget.plant;

    if (groupChanged || facChanged) {
      setState(() {
        _fac = newFac;
        _group = newGroup;
      });

      debugPrint("CameraEditBox updated: fac=$_fac, group=$_group");
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    _stopCamera();
    try {
      sttSocket?.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _stopCamera() {
    try {
      _stream?.getTracks().forEach((track) => track.stop());
    } catch (_) {}
  }

  Future<void> _startCamera() async {
    try {
      final newViewType = 'camera_${DateTime.now().millisecondsSinceEpoch}';

      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'facingMode': 'environment',
          'width': {'ideal': 4096, 'min': 1080},
          'height': {'ideal': 4096, 'min': 1080},
        },
      });

      final video = html.VideoElement()
        ..setAttribute('autoplay', 'true')
        ..setAttribute('playsinline', 'true')
        ..setAttribute('muted', 'true')
        ..style.objectFit = 'cover'
        ..style.pointerEvents = 'none'
        ..srcObject = stream;

      // register view: tuỳ project, bạn có thể đã import đúng ui_web
      ui_web.platformViewRegistry.registerViewFactory(
        newViewType,
        (id) => video,
      );

      setState(() {
        _stream = stream;
        _videoElement = video;
        _viewType = newViewType;
      });
    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  // Digital Zoom
  double _zoom = 1.0;
  static const double _minZoom = 1.0;
  static const double _maxZoom = 10.0;

  Future<void> _takePhoto() async {
    if (_isCapturing || _videoElement == null) return;
    setState(() => _isCapturing = true);

    ///////////////////////////////////////////////////
    _flashController.forward().then((_) => _flashController.reverse());

    try {
      final video = _videoElement!;
      final videoWidth = video.videoWidth.toDouble();
      final videoHeight = video.videoHeight.toDouble();

      if (videoWidth == 0 || videoHeight == 0) return;

      final int outputSize = math
          .min(math.max(videoWidth, videoHeight), 2048)
          .toInt();

      final canvas = html.CanvasElement(width: outputSize, height: outputSize);
      final ctx = canvas.context2D;

      final srcSize = math.min(videoWidth, videoHeight) / _zoom;

      final sx = (videoWidth - srcSize) / 2;
      final sy = (videoHeight - srcSize) / 2;

      ctx.drawImageScaledFromSource(
        video,
        sx,
        sy,
        srcSize,
        srcSize,
        0,
        0,
        outputSize,
        outputSize,
      );

      final blob = await canvas.toBlob('image/jpeg', 0.8);
      final reader = html.FileReader();
      reader.readAsArrayBuffer(blob);
      await reader.onLoadEnd.first;

      final bytes = reader.result as Uint8List;

      setState(() {
        _capturedImages.add(bytes);
      });

      widget.onImagesChanged?.call(_capturedImages);
    } catch (e) {
      debugPrint('Capture error: $e');
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  void removeImage(int index) {
    setState(() {
      _capturedImages.removeAt(index);
    });
    widget.onImagesChanged?.call(_capturedImages);
  }

  void clearAll() {
    setState(() {
      _capturedImages.clear();
    });
    widget.onImagesChanged?.call(_capturedImages);
  }

  List<Uint8List> get images => List.unmodifiable(_capturedImages);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 🎥 CAMERA
                    _videoElement != null
                        ? Transform.scale(
                            scale: _zoom,
                            child: HtmlElementView(
                              key: ValueKey(_viewType),
                              viewType: _viewType,
                            ),
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),

                    // 🧊 GLASS OVERLAY (NHẸ)
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: Container(color: Colors.white.withOpacity(0.08)),
                    ),

                    // ⚡ FLASH EFFECT
                    AnimatedBuilder(
                      animation: _flashController,
                      builder: (context, child) => Container(
                        color: Colors.white.withOpacity(
                          0.85 * _flashController.value,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              bottom: 14,
              left: 1,
              child: GestureDetector(
                onTap: canUpload ? () => pickImagesFromDevice(context) : null,
                child: GlassCircleButton(
                  size: 50,
                  child: Icon(
                    Icons.upload_rounded,
                    color: canUpload ? Colors.white : Colors.grey,
                    size: 30,
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 14,
              right: 1,
              child: GlassZoomControl(
                zoom: _zoom,
                minZoom: _minZoom,
                maxZoom: _maxZoom,
                onChanged: (v) => setState(() => _zoom = v),
              ),
            ),

            Positioned(
              bottom: -10,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: (!_isCapturing && canUpload) ? _takePhoto : null,

                  child: GlassCircleButton(
                    size: 60,
                    showProgress: _isCapturing,
                    child: _isCapturing
                        ? null // showProgress sẽ hiển thị loading
                        : Icon(
                            Icons.camera_alt_rounded,
                            color: canUpload ? Colors.white : Colors.grey,
                            size: 36,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
