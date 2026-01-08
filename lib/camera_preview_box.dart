import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:js/js.dart';
import 'package:js/js_util.dart' as js_util;

import 'api/api_config.dart';
import 'api/stt_api.dart';
import 'homeScreen/patrol_home_screen.dart';
import 'package:chuphinh/socket/SttWebSocket.dart';
import 'package:chuphinh/widget/glass_circle_button.dart';
import 'package:chuphinh/widget/glass_zoom_control.dart';

@JS('startQrLoop')
external void startQrLoop();
@JS('stopQrLoop')
external void stopQrLoop();

class CameraPreviewBox extends StatefulWidget {
  final double size;
  final Function(List<Uint8List> images)? onImagesChanged;

  final String? plant;
  final String? group;
  final String type;
  final String? wsUrl;
  final PatrolGroup patrolGroup;

  /// ✅ Gửi QR về class cha
  final ValueChanged<String>? onQrDetected;

  const CameraPreviewBox({
    super.key,
    this.size = 320,
    this.onImagesChanged,
    this.plant,
    this.group,
    required this.type,
    this.wsUrl,
    required this.patrolGroup,
    this.onQrDetected,
  });

  @override
  State<CameraPreviewBox> createState() => CameraPreviewBoxState();
}

class CameraPreviewBoxState extends State<CameraPreviewBox>
    with TickerProviderStateMixin {
  // =========================
  // Config
  // =========================
  static const int _maxImages = 3;

  static const Duration _qrDedupe = Duration(milliseconds: 1200);
  static const Duration _qrWarmup = Duration(milliseconds: 250);

  static const double _minZoom = 1.0;
  static const double _maxZoom = 10.0;

  // =========================
  // Camera / View
  // =========================
  html.MediaStream? _stream;
  html.VideoElement? _video;
  late String _viewType;

  double _zoom = 1.0;

  // =========================
  // QR scanning (JS ZXing)
  // =========================
  StreamSubscription? _qrSub;
  bool _qrScanning = false;
  bool _qrLoading = false;

  String? _lastQr;
  DateTime? _lastQrAt;

  /// points from JS (video pixel coords)
  List<Offset>? _qrPoints;
  Size? _videoSize;

  // =========================
  // Capture
  // =========================
  bool _isCapturing = false;
  final List<Uint8List> _capturedImages = [];
  late final AnimationController _flashController;

  bool get canUpload => _capturedImages.length < _maxImages;
  List<Uint8List> get images => List.unmodifiable(_capturedImages);

  // =========================
  // STT / Socket
  // =========================
  late String _fac;
  late String _group;
  late String _wsUrl;

  int stt = 0;
  bool _sttLoading = true;
  SttWebSocket? sttSocket;

  // =========================
  // Lifecycle
  // =========================
  @override
  void initState() {
    super.initState();

    _viewType = 'camera_${DateTime.now().millisecondsSinceEpoch}';
    _fac = (widget.plant ?? '').trim();
    _group = (widget.group ?? '').trim();
    _wsUrl = widget.wsUrl ?? '${ApiConfig.wsBaseUrl}/ws-stt/websocket';

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _startCamera();
    _loadStt();
    _connectSocket();
  }

  @override
  void didUpdateWidget(covariant CameraPreviewBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newFac = (widget.plant ?? '').trim();
    final newGroup = (widget.group ?? '').trim();

    if (newFac != _fac || newGroup != _group) {
      _fac = newFac;
      _group = newGroup;
      // Nếu cần reload STT/socket theo group/fac thì bật lại:
      // _loadStt();
      // _connectSocket();
    }
  }

  @override
  void dispose() {
    _stopQrScan();
    _flashController.dispose();
    _stopCamera();
    try {
      sttSocket?.dispose();
    } catch (_) {}
    super.dispose();
  }

  // =========================
  // Camera
  // =========================
  Future<void> _startCamera() async {
    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'facingMode': 'environment',
          // ✅ đừng xin 4K (nặng + decode chậm)
          'width': {'ideal': 1280, 'min': 640},
          'height': {'ideal': 720, 'min': 480},
        },
      });

      final video = html.VideoElement()
        ..id = 'qr-video'
        ..setAttribute('autoplay', 'true')
        ..setAttribute('playsinline', 'true')
        ..setAttribute('muted', 'true')
        ..style.objectFit = 'cover'
        ..style.pointerEvents = 'none'
        ..srcObject = stream;

      ui_web.platformViewRegistry.registerViewFactory(_viewType, (id) => video);

      setState(() {
        _stream = stream;
        _video = video;
      });

      // ✅ đợi video ready rồi auto scan
      await _waitVideoReady(timeout: const Duration(seconds: 3));
      if (!mounted) return;
      await Future.delayed(_qrWarmup);
      _startAutoQrScan();
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  Future<void> _waitVideoReady({required Duration timeout}) async {
    final start = DateTime.now();
    while (mounted) {
      final v = _video;
      if (v != null && v.videoWidth > 0 && v.videoHeight > 0) return;
      if (DateTime.now().difference(start) > timeout) return;
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  void _stopCamera() {
    try {
      _stream?.getTracks().forEach((t) => t.stop());
    } catch (_) {}
  }

  // =========================
  // QR (ZXing JS) start/stop
  // =========================
  Future<void> _startAutoQrScan() async {
    if (_qrScanning) return;

    setState(() {
      _qrScanning = true;
      _qrLoading = true;
    });

    // ✅ listener trước rồi mới start loop
    await _qrSub?.cancel();
    _qrSub = html.window.on['qr-from-image'].listen(_onQrEvent);

    // start JS loop
    try {
      startQrLoop();
    } catch (e) {
      debugPrint('startQrLoop error: $e');
    }

    if (mounted) setState(() => _qrLoading = false);
  }

  Future<void> _stopQrScan() async {
    try {
      stopQrLoop();
    } catch (_) {}

    try {
      await _qrSub?.cancel();
    } catch (_) {}
    _qrSub = null;

    if (mounted) {
      setState(() {
        _qrScanning = false;
        _qrLoading = false;
        _qrPoints = null;
        _videoSize = null;
      });
    }
  }

  void _onQrEvent(dynamic event) {
    if (!mounted) return;

    final e = event as html.CustomEvent;

    // ✅ đọc detail an toàn (đừng cast Map cứng)
    final detail = e.detail;
    final text = detail['text']?.toString() ?? '';
    final err = detail['error']?.toString() ?? '';
    if (err.isNotEmpty) {
      // Bạn có thể log nhẹ thôi để không spam
      // debugPrint("QR err: $err");
      return;
    }
    if (text.isEmpty) return;

    // ✅ dedupe
    final now = DateTime.now();
    if (_lastQr == text &&
        _lastQrAt != null &&
        now.difference(_lastQrAt!) < _qrDedupe) {
      return;
    }
    _lastQr = text;
    _lastQrAt = now;

    // ✅ points (nếu có)
    final pointsRaw = detail['points'];
    List<Offset>? pts;
    if (pointsRaw is List) {
      pts = pointsRaw
          .whereType<Map>()
          .map(
            (m) => Offset(
              (m['x'] as num?)?.toDouble() ?? 0,
              (m['y'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList();
      if (pts.isEmpty) pts = null;
    }

    if (err.isNotEmpty) {
      debugPrint("QR loop err: $err");
      return;
    }

    // ✅ chỉ setState khi cần
    final v = _video;
    final vSize = (v != null)
        ? Size(v.videoWidth.toDouble(), v.videoHeight.toDouble())
        : null;

    setState(() {
      // _qrPoints = pts;
      _videoSize = vSize;
    });

    // ✅ gửi về class cha
    widget.onQrDetected?.call(text);
  }

  // =========================
  // STT / socket
  // =========================
  Future<void> _loadStt() async {
    if (_fac.isEmpty) return;
    try {
      setState(() => _sttLoading = true);

      final value = await SttApi.getCurrentStt(
        fac: _fac,
        type: widget.patrolGroup.name,
      );

      if (!mounted) return;
      setState(() {
        stt = value;
        _sttLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _sttLoading = false);
    }
  }

  void _connectSocket() {
    sttSocket?.dispose();
    sttSocket = SttWebSocket(
      serverUrl: _wsUrl,
      fac: _fac,
      type: widget.patrolGroup.name,
      onSttUpdate: (value) {
        if (!mounted) return;
        setState(() {
          stt = value;
          _sttLoading = false;
        });
      },
    );
    sttSocket!.connect();
  }

  // =========================
  // Capture / Upload
  // =========================
  Future<void> pickImagesFromDevice(BuildContext context) async {
    final remain = _maxImages - _capturedImages.length;
    if (remain <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You can upload up to 2 images only."),
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

    uploadInput.onChange.listen((_) async {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;

      final selected = files.take(remain);
      for (final file in selected) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoadEnd.first;
        final bytes = reader.result as Uint8List;
        setState(() => _capturedImages.add(bytes));
      }

      widget.onImagesChanged?.call(_capturedImages);
    });
  }

  void removeImage(int index) {
    setState(() => _capturedImages.removeAt(index));
    widget.onImagesChanged?.call(_capturedImages);
  }

  void clearAll() {
    setState(() => _capturedImages.clear());
    widget.onImagesChanged?.call(_capturedImages);
  }

  void resetQr() {
    setState(() {
      _lastQr = null;
    });
  }

  Future<void> _takePhoto() async {
    if (_isCapturing || _video == null) return;
    if (_capturedImages.length >= _maxImages) return;

    setState(() => _isCapturing = true);
    _flashController.forward().then((_) => _flashController.reverse());

    try {
      final video = _video!;
      final vw = video.videoWidth.toDouble();
      final vh = video.videoHeight.toDouble();
      if (vw == 0 || vh == 0) return;

      final outputSize = math.min(math.max(vw, vh), 2048).toInt();
      final canvas = html.CanvasElement(width: outputSize, height: outputSize);
      final ctx = canvas.context2D;

      final srcSize = math.min(vw, vh) / _zoom;
      final sx = (vw - srcSize) / 2;
      final sy = (vh - srcSize) / 2;

      ctx.drawImageScaledFromSource(
        video,
        sx,
        sy,
        srcSize,
        srcSize,
        0,
        0,
        outputSize.toDouble(),
        outputSize.toDouble(),
      );

      final blob = await canvas.toBlob('image/jpeg', 0.8);
      final reader = html.FileReader();
      reader.readAsArrayBuffer(blob);
      await reader.onLoadEnd.first;

      final bytes = reader.result as Uint8List;
      setState(() => _capturedImages.add(bytes));
      widget.onImagesChanged?.call(_capturedImages);
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  // =========================
  // UI
  // =========================
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
                    _video != null
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

                    // QR box overlay (if points exist)
                    if (_qrPoints != null && _videoSize != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _QrBoxPainterCoverSquare(
                              points: _qrPoints!,
                              videoSize: _videoSize!,
                              viewSize: Size(widget.size, widget.size),
                              zoom: _zoom,
                            ),
                          ),
                        ),
                      ),

                    // glass overlay
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: Container(color: Colors.white.withOpacity(0.08)),
                    ),

                    // flash
                    AnimatedBuilder(
                      animation: _flashController,
                      builder: (_, __) => Container(
                        color: Colors.white.withOpacity(
                          0.85 * _flashController.value,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Upload
            Positioned(
              bottom: 14,
              left: 14,
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

            // QR text
            Positioned(
              top: 12,
              left: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.qr_code_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        SizedBox(width: 8),
                        Text(
                          _lastQr ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // STT
            Positioned(
              top: 12,
              right: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: _sttLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'No. ${stt + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                  ),
                ),
              ),
            ),

            // Zoom
            Positioned(
              bottom: 14,
              right: 14,
              child: GlassZoomControl(
                zoom: _zoom,
                minZoom: _minZoom,
                maxZoom: _maxZoom,
                onChanged: (v) => setState(() => _zoom = v),
              ),
            ),

            // Capture
            Positioned(
              bottom: -18,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: (!_isCapturing && canUpload) ? _takePhoto : null,
                  child: GlassCircleButton(
                    size: 80,
                    showProgress: _isCapturing,
                    child: _isCapturing
                        ? null
                        : Icon(
                            Icons.camera_alt_rounded,
                            color: canUpload ? Colors.white : Colors.grey,
                            size: 36,
                          ),
                  ),
                ),
              ),
            ),

            // QR status spinner (optional)
            if (_qrLoading)
              const Positioned(
                top: 12,
                left: 120,
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Painter: map ZXing points (video coords) -> square widget with objectFit.cover + zoom
class _QrBoxPainterCoverSquare extends CustomPainter {
  final List<Offset> points;
  final Size videoSize;
  final Size viewSize;
  final double zoom;

  _QrBoxPainterCoverSquare({
    required this.points,
    required this.videoSize,
    required this.viewSize,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || videoSize.width <= 0 || videoSize.height <= 0) return;

    // 1) cover crop to square (center crop)
    final vw = videoSize.width;
    final vh = videoSize.height;

    double cropX = 0, cropY = 0, cropW = vw, cropH = vh;
    final aspect = vw / vh;
    if (aspect > 1) {
      // landscape -> crop width
      cropW = vh;
      cropX = (vw - cropW) / 2;
    } else if (aspect < 1) {
      // portrait -> crop height
      cropH = vw;
      cropY = (vh - cropH) / 2;
    }

    // 2) apply zoom (your UI uses Transform.scale)
    final z = zoom.clamp(
      _CameraPreviewBoxStateShim.minZoom,
      _CameraPreviewBoxStateShim.maxZoom,
    );
    final zoomedSide = cropW / z; // cropW == cropH == square
    final zx = cropX + (cropW - zoomedSide) / 2;
    final zy = cropY + (cropH - zoomedSide) / 2;

    // 3) map to view square
    final sx = viewSize.width / zoomedSide;
    final sy = viewSize.height / zoomedSide;

    Offset map(Offset p) {
      final x = (p.dx - zx) * sx;
      final y = (p.dy - zy) * sy;
      return Offset(x, y);
    }

    final mapped = points.map(map).toList();

    // draw bounding rect (stable)
    Rect rect = Rect.fromLTWH(mapped.first.dx, mapped.first.dy, 0, 0);
    for (final p in mapped) {
      rect = rect.expandToInclude(Rect.fromLTWH(p.dx, p.dy, 0, 0));
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.greenAccent;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(6), const Radius.circular(12)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _QrBoxPainterCoverSquare oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.videoSize != videoSize ||
        oldDelegate.viewSize != viewSize ||
        oldDelegate.zoom != zoom;
  }
}

/// Hack: painter is outside state; keep constants accessible cleanly.
class _CameraPreviewBoxStateShim {
  static const double minZoom = 1.0;
  static const double maxZoom = 10.0;
}
