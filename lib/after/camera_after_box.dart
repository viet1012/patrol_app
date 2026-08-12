import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:chuphinh/socket/SttWebSocket.dart';
import 'package:chuphinh/widget/glass_circle_button.dart';
import 'package:chuphinh/widget/glass_zoom_control.dart';
import 'package:flutter/material.dart';

import '../homeScreen/patrol_home_screen.dart';

class CameraAfterBox extends StatefulWidget {
  final double size;

  final ValueChanged<List<Uint8List>>? onImagesChanged;

  final String? plant;

  final String? group;

  final String type;

  final String? wsUrl;

  final PatrolGroup patrolGroup;

  const CameraAfterBox({
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
  State<CameraAfterBox> createState() => CameraAfterBoxState();
}

class CameraAfterBoxState extends State<CameraAfterBox>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // CONSTANTS
  // ============================================================

  static const int maxImages = 2;

  static const double _minZoom = 1.0;

  static const double _maxZoom = 10.0;

  static const int _maxOutputSize = 2048;

  // ============================================================
  // CAMERA
  // ============================================================

  html.MediaStream? _stream;

  html.VideoElement? _videoElement;

  late String _viewType;

  bool _cameraStarting = false;

  bool _cameraReady = false;

  // ============================================================
  // CAPTURE
  // ============================================================

  bool _isCapturing = false;

  double _zoom = 1.0;

  final List<Uint8List> _capturedImages = [];

  // ============================================================
  // ANIMATION
  // ============================================================

  late final AnimationController _flashController;

  // ============================================================
  // META
  // ============================================================

  late String _fac;

  late String _group;

  int stt = 0;

  SttWebSocket? sttSocket;

  // ============================================================
  // GETTERS
  // ============================================================

  bool get canUpload => _capturedImages.length < maxImages;

  bool get canCapture => !_isCapturing && _cameraReady && canUpload;

  List<Uint8List> get images => List.unmodifiable(_capturedImages);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _fac = _normalize(widget.plant);

    _group = _normalize(widget.group);

    _viewType = _newViewType();

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );

    unawaited(_startCamera());
  }

  // ============================================================
  // UPDATE
  // ============================================================

  @override
  void didUpdateWidget(covariant CameraAfterBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newFac = _normalize(widget.plant);

    final newGroup = _normalize(widget.group);

    if (_fac == newFac && _group == newGroup) {
      return;
    }

    _fac = newFac;

    _group = newGroup;

    debugPrint('CameraAfterBox updated: fac=$_fac, group=$_group');
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _flashController.dispose();

    _disposeCamera();

    sttSocket?.dispose();

    super.dispose();
  }

  // ============================================================
  // CAMERA
  // ============================================================

  Future<void> _startCamera() async {
    if (_cameraStarting) {
      return;
    }

    _cameraStarting = true;

    try {
      _disposeCamera();

      final viewType = _newViewType();

      final mediaDevices = html.window.navigator.mediaDevices;

      if (mediaDevices == null) {
        throw StateError('MediaDevices is unavailable.');
      }

      final stream = await mediaDevices.getUserMedia({
        'video': {
          'facingMode': {'ideal': 'environment'},
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
        'audio': false,
      });

      if (!mounted) {
        _stopStream(stream);
        return;
      }

      final video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        // FULL CAMERA
        ..style.position = 'absolute'
        ..style.top = '0'
        ..style.left = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.minWidth = '100%'
        ..style.minHeight = '100%'
        // COVER toàn bộ box
        ..style.objectFit = 'cover'
        // bỏ mọi khoảng cách của HTML element
        ..style.margin = '0'
        ..style.padding = '0'
        ..style.border = 'none'
        ..style.outline = 'none'
        ..style.display = 'block'
        // QUAN TRỌNG
        ..style.backgroundColor = 'transparent'
        ..style.pointerEvents = 'none'
        ..srcObject = stream;

      ui_web.platformViewRegistry.registerViewFactory(viewType, (_) => video);

      await video.onLoadedMetadata.first;

      await video.play();

      if (!mounted) {
        video.pause();
        _stopStream(stream);
        return;
      }

      setState(() {
        _stream = stream;

        _videoElement = video;

        _viewType = viewType;

        _cameraReady = true;
      });
    } catch (e, stackTrace) {
      debugPrint('Camera start error: $e');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _cameraReady = false;
      });
    } finally {
      _cameraStarting = false;
    }
  }

  void _disposeCamera() {
    try {
      _videoElement?.pause();

      _videoElement?.srcObject = null;
    } catch (_) {}

    _videoElement = null;

    final stream = _stream;

    _stream = null;

    if (stream != null) {
      _stopStream(stream);
    }

    _cameraReady = false;
  }

  void _stopStream(html.MediaStream stream) {
    try {
      for (final track in stream.getTracks()) {
        track.stop();
      }
    } catch (_) {}
  }

  // ============================================================
  // CAPTURE
  // ============================================================

  Future<void> _takePhoto() async {
    if (!canCapture) {
      return;
    }

    final video = _videoElement;

    if (video == null) {
      return;
    }

    final videoWidth = video.videoWidth.toDouble();

    final videoHeight = video.videoHeight.toDouble();

    if (videoWidth <= 0 || videoHeight <= 0) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    unawaited(
      _flashController.forward(from: 0).then((_) => _flashController.reverse()),
    );

    try {
      final bytes = await _captureVideoFrame(video, videoWidth, videoHeight);

      if (!mounted || bytes == null) {
        return;
      }

      setState(() {
        _capturedImages.add(bytes);
      });

      _notifyImages();
    } catch (e, stackTrace) {
      debugPrint('Capture error: $e');

      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<Uint8List?> _captureVideoFrame(
    html.VideoElement video,
    double videoWidth,
    double videoHeight,
  ) async {
    final sourceSize = math.min(videoWidth, videoHeight) / _zoom;

    final sourceX = (videoWidth - sourceSize) / 2;

    final sourceY = (videoHeight - sourceSize) / 2;

    final outputSize = math
        .min(math.max(videoWidth, videoHeight), _maxOutputSize)
        .round();

    final canvas = html.CanvasElement(width: outputSize, height: outputSize);

    canvas.context2D.drawImageScaledFromSource(
      video,
      sourceX,
      sourceY,
      sourceSize,
      sourceSize,
      0,
      0,
      outputSize,
      outputSize,
    );

    final blob = await canvas.toBlob('image/jpeg', .82);

    final reader = html.FileReader();

    reader.readAsArrayBuffer(blob);

    await reader.onLoadEnd.first;

    final result = reader.result;

    if (result is Uint8List) {
      return result;
    }

    return null;
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> pickImagesFromDevice(BuildContext context) async {
    final remain = maxImages - _capturedImages.length;

    if (remain <= 0) {
      _showMessage(
        context,
        'You can upload up to '
        '$maxImages images only.',
        Colors.redAccent,
      );

      return;
    }

    final uploadInput = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = true;

    uploadInput.click();

    await uploadInput.onChange.first;

    final files = uploadInput.files;

    if (files == null || files.isEmpty) {
      return;
    }

    if (files.length > remain) {
      _showMessage(
        context,
        'You can select only $remain '
        'more image${remain > 1 ? 's' : ''}.',
        Colors.orange,
      );
    }

    final newImages = <Uint8List>[];

    for (final file in files.take(remain)) {
      final bytes = await _readFile(file);

      if (bytes != null) {
        newImages.add(bytes);
      }
    }

    if (!mounted || newImages.isEmpty) {
      return;
    }

    // Chỉ setState 1 lần,
    // thay vì mỗi ảnh 1 lần.
    setState(() {
      _capturedImages.addAll(newImages);
    });

    _notifyImages();
  }

  Future<Uint8List?> _readFile(html.File file) async {
    final reader = html.FileReader();

    reader.readAsArrayBuffer(file);

    await reader.onLoadEnd.first;

    final result = reader.result;

    if (result is Uint8List) {
      return result;
    }

    return null;
  }

  // ============================================================
  // IMAGE STATE
  // ============================================================

  void removeImage(int index) {
    if (index < 0 || index >= _capturedImages.length) {
      return;
    }

    setState(() {
      _capturedImages.removeAt(index);
    });

    _notifyImages();
  }

  void clearAll() {
    if (_capturedImages.isEmpty) {
      return;
    }

    setState(() {
      _capturedImages.clear();
    });

    _notifyImages();
  }

  void _notifyImages() {
    widget.onImagesChanged?.call(List.unmodifiable(_capturedImages));
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: _buildCameraView()),

          _buildUploadButton(),

          _buildZoomControl(),

          _buildCaptureButton(),

          _buildFlashOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_videoElement == null)
            const ColoredBox(
              color: Color(0xFF1E293B),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Positioned.fill(
              child: HtmlElementView(
                key: ValueKey(_viewType),
                viewType: _viewType,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadButton() {
    return Positioned(
      bottom: 14,
      left: 6,
      child: GestureDetector(
        onTap: canUpload ? () => pickImagesFromDevice(context) : null,
        child: GlassCircleButton(
          size: 50,
          child: Icon(
            Icons.upload_rounded,
            color: canUpload ? Colors.white : Colors.grey,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildZoomControl() {
    return Positioned(
      bottom: 14,
      right: 6,
      child: GlassZoomControl(
        zoom: _zoom,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
        onChanged: (value) {
          if (_zoom == value) {
            return;
          }

          setState(() {
            _zoom = value;
          });
        },
      ),
    );
  }

  Widget _buildCaptureButton() {
    return Positioned(
      bottom: -8,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: canCapture ? _takePhoto : null,
          child: GlassCircleButton(
            size: 60,
            showProgress: _isCapturing,
            child: _isCapturing
                ? null
                : Icon(
                    Icons.camera_alt_rounded,
                    color: canCapture ? Colors.white : Colors.grey,
                    size: 34,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlashOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _flashController,
          builder: (context, _) {
            final opacity = .75 * _flashController.value;

            if (opacity <= 0) {
              return const SizedBox.shrink();
            }

            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ColoredBox(color: Colors.white.withOpacity(opacity)),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _normalize(String? value) {
    return value?.trim() ?? '';
  }

  String _newViewType() {
    return 'camera_'
        '${DateTime.now().microsecondsSinceEpoch}';
  }

  void _showMessage(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
