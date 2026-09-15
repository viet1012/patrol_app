import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:js/js.dart';

@JS('startQrLoop')
external void startQrLoop();

@JS('stopQrLoop')
external void stopQrLoop();

class QrCodeCamera extends StatefulWidget {
  final ValueChanged<String>? onQrDetected;
  final double size;

  /// Nếu cần chỉ nhận QR 4 số như Patrol thì bật lên
  final bool only4Digits;

  const QrCodeCamera({
    super.key,
    this.size = 320,
    this.onQrDetected,
    this.only4Digits = false,
  });

  @override
  State<QrCodeCamera> createState() => QrCodeCameraState();
}

class QrCodeCameraState extends State<QrCodeCamera>
    with TickerProviderStateMixin {
  static const Duration _qrDedupe = Duration(milliseconds: 1200);
  static const Duration _qrWarmup = Duration(milliseconds: 250);
  static const Duration _videoReadyTimeout = Duration(seconds: 3);

  static const double _minZoom = 1.0;
  static const double _maxZoom = 10.0;

  html.MediaStream? _stream;
  html.VideoElement? _video;
  late final String _viewType;

  double _zoom = 1.0;

  StreamSubscription<html.Event>? _qrSub;
  bool _qrScanning = false;
  bool _qrLoading = false;
  bool _qrDelivered = false;

  String? _lastQr;
  DateTime? _lastQrAt;

  List<Offset>? _qrPoints;
  Size? _videoSize;

  late final AnimationController _fxCtrl;
  late final AnimationController _scanCtrl;
  late final Animation<double> _scanY;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();

    _viewType = 'qr_cam_${DateTime.now().millisecondsSinceEpoch}';

    _fxCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scanY = CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut);
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _fxCtrl, curve: Curves.easeOut));

    _shakeAnim = Tween<double>(
      begin: 0.0,
      end: 3.0,
    ).animate(CurvedAnimation(parent: _fxCtrl, curve: Curves.easeInOut));

    _boot();
  }

  @override
  void dispose() {
    _fxCtrl.dispose();
    _scanCtrl.dispose();
    _shutdown();
    super.dispose();
  }

  Future<void> _boot() async {
    await _startCamera();
    if (!mounted) return;

    await _waitVideoReady(timeout: _videoReadyTimeout);
    if (!mounted) return;

    await Future.delayed(_qrWarmup);
    if (!mounted) return;

    await _startQrScan();
  }

  Future<void> _shutdown() async {
    await _stopQrScan();
    _stopCamera();
  }

  Future<void> _startCamera() async {
    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'facingMode': 'environment',
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
        ..style.position = 'absolute'
        ..style.top = '0'
        ..style.left = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..srcObject = stream;

      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) => video,
      );

      if (!mounted) {
        stream.getTracks().forEach((t) => t.stop());
        return;
      }

      setState(() {
        _stream = stream;
        _video = video;
      });
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

    try {
      final v = _video;
      if (v != null) {
        v.pause();
        v.srcObject = null;
        v.load();
        v.remove();
      }
    } catch (_) {}

    _stream = null;
    _video = null;
  }

  Future<void> _startQrScan() async {
    if (_qrScanning) return;

    setState(() {
      _qrScanning = true;
      _qrLoading = true;
      _qrDelivered = false;
    });

    await _qrSub?.cancel();
    _qrSub = html.window.on['qr-from-image'].listen(_onQrEvent);

    try {
      startQrLoop();
      if (!_scanCtrl.isAnimating) {
        _scanCtrl.repeat(reverse: true);
      }
    } catch (e) {
      debugPrint('startQrLoop error: $e');
    }

    if (mounted) {
      setState(() => _qrLoading = false);
    }
  }

  Future<void> _stopQrScan() async {
    try {
      stopQrLoop();
    } catch (_) {}

    try {
      await _qrSub?.cancel();
    } catch (_) {}

    _qrSub = null;
    _qrScanning = false;

    if (_scanCtrl.isAnimating) {
      _scanCtrl.stop();
    }

    if (mounted) {
      setState(() {
        _qrLoading = false;
        _qrPoints = null;
        _videoSize = null;
      });
    }
  }

  void _onQrEvent(html.Event event) {
    if (!mounted || _qrDelivered) return;
    if (event is! html.CustomEvent) return;

    final rawDetail = event.detail;
    Map<String, dynamic>? detail;
    if (rawDetail is String) {
      try {
        final decoded = jsonDecode(rawDetail);
        if (decoded is Map) {
          detail = decoded.map((key, value) => MapEntry('$key', value));
        }
      } catch (_) {
        return;
      }
    } else if (rawDetail is Map) {
      detail = rawDetail.map((key, value) => MapEntry('$key', value));
    }
    if (detail == null) return;

    final text = detail['text']?.toString().trim() ?? '';
    final err = detail['error']?.toString() ?? '';

    if (err.isNotEmpty) return;
    if (text.isEmpty) return;

    if (widget.only4Digits && !RegExp(r'^\d{4}$').hasMatch(text)) {
      return;
    }

    final now = DateTime.now();
    if (_lastQr == text &&
        _lastQrAt != null &&
        now.difference(_lastQrAt!) < _qrDedupe) {
      return;
    }

    HapticFeedback.mediumImpact();

    _lastQr = text;
    _lastQrAt = now;
    _qrDelivered = true;

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

    final v = _video;
    final vSize = (v != null)
        ? Size(v.videoWidth.toDouble(), v.videoHeight.toDouble())
        : null;

    _playFx();

    setState(() {
      _qrPoints = pts;
      _videoSize = vSize;
    });

    widget.onQrDetected?.call(text);
  }

  void _playFx() {
    _fxCtrl.forward(from: 0).then((_) {
      if (mounted) _fxCtrl.reverse();
    });
  }

  Future<void> stopNow() async {
    await _shutdown();
    if (mounted) setState(() {});
  }

  Future<void> stopCamera() async {
    await stopNow();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;

    return Stack(
      children: [
        _frame(
          child: video == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Transform.scale(
                      scale: _zoom,
                      child: HtmlElementView(
                        key: ValueKey(_viewType),
                        viewType: _viewType,
                      ),
                    ),

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

                  ],
                ),
        ),

        Positioned(
          top: 12,
          left: 12,
          child: AnimatedBuilder(
            animation: _fxCtrl,
            builder: (context, child) {
              final dx = (_fxCtrl.value < 0.5
                  ? -_shakeAnim.value
                  : _shakeAnim.value);

              return Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.scale(scale: _scaleAnim.value, child: child),
              );
            },
            child: _QrBadge(text: _lastQr ?? ''),
          ),
        ),

        Positioned(
          bottom: 14,
          right: 14,
          child: _ZoomControl(
            zoom: _zoom,
            minZoom: _minZoom,
            maxZoom: _maxZoom,
            onChanged: (v) => setState(() => _zoom = v),
          ),
        ),

        Positioned.fill(child: _scanOverlay()),

        if (_qrLoading)
          const Positioned(
            top: 14,
            left: 120,
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  Widget _frame({required Widget child}) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
    );
  }

  Widget _scanOverlay() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AnimatedBuilder(
        animation: _scanY,
        builder: (context, _) {
          final h = widget.size;
          final y = (_scanY.value * (h - 28)).clamp(0.0, h);

          return Stack(
            children: [
              Positioned(
                top: y - 22,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF7CF8D6).withOpacity(0.00),
                          const Color(0xFF7CF8D6).withOpacity(0.10),
                          const Color(0xFF7CF8D6).withOpacity(0.00),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: y,
                left: 10,
                right: 10,
                child: IgnorePointer(
                  child: Container(
                    height: 2.6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF7CF8D6).withOpacity(0.0),
                          const Color(0xFF7CF8D6).withOpacity(0.95),
                          const Color(0xFF7CF8D6).withOpacity(0.0),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7CF8D6).withOpacity(0.45),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QrBadge extends StatelessWidget {
  final String text;

  const _QrBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.45), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.qr_code_rounded,
                size: 18,
                color: text.isEmpty ? Colors.red.withOpacity(.7) : Colors.white,
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.9),
                      end: Offset.zero,
                    ).animate(anim),
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.75,
                        end: 1.08,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                ),
                child: Text(
                  text,
                  key: ValueKey(text),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoomControl extends StatelessWidget {
  final double zoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onChanged;

  const _ZoomControl({
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, color: Colors.white),
                onPressed: () =>
                    onChanged((zoom - 0.2).clamp(minZoom, maxZoom)),
              ),
              Text(
                '${zoom.toStringAsFixed(1)}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () =>
                    onChanged((zoom + 0.2).clamp(minZoom, maxZoom)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

    final vw = videoSize.width;
    final vh = videoSize.height;

    double cropX = 0, cropY = 0, cropW = vw, cropH = vh;
    final aspect = vw / vh;

    if (aspect > 1) {
      cropW = vh;
      cropX = (vw - cropW) / 2;
    } else if (aspect < 1) {
      cropH = vw;
      cropY = (vh - cropH) / 2;
    }

    final z = zoom.clamp(1.0, 10.0);
    final zoomedSide = cropW / z;
    final zx = cropX + (cropW - zoomedSide) / 2;
    final zy = cropY + (cropH - zoomedSide) / 2;

    final sx = viewSize.width / zoomedSide;
    final sy = viewSize.height / zoomedSide;

    Offset map(Offset p) {
      final x = (p.dx - zx) * sx;
      final y = (p.dy - zy) * sy;
      return Offset(x, y);
    }

    final mapped = points.map(map).toList();

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
