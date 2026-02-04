import 'dart:async';
import 'dart:html' as html;
import 'dart:ui';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:js/js.dart';

@JS('startQrLoop')
external void startQrLoop();

@JS('stopQrLoop')
external void stopQrLoop();

class QrCodeCamera extends StatefulWidget {
  final ValueChanged<String>? onQrDetected;
  final double size;

  const QrCodeCamera({super.key, this.size = 320, this.onQrDetected});

  @override
  State<QrCodeCamera> createState() => QrCodeCameraState();
}

class QrCodeCameraState extends State<QrCodeCamera>
    with TickerProviderStateMixin {
  // ===== Config =====
  static const Duration _qrDedupe = Duration(milliseconds: 1200);
  static const Duration _qrWarmup = Duration(milliseconds: 250);
  static const Duration _videoReadyTimeout = Duration(seconds: 3);

  static const double _minZoom = 1.0;
  static const double _maxZoom = 10.0;

  // ===== Runtime =====
  html.MediaStream? _stream;
  html.VideoElement? _video;
  late final String _viewType;

  double _zoom = 1.0;

  StreamSubscription<html.Event>? _qrSub;
  bool _qrScanning = false;

  String? _lastQr;
  DateTime? _lastQrAt;

  late final AnimationController _fxCtrl;
  late final AnimationController _scanCtrl;
  late final Animation<double> _scanY;

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

    _boot();
  }

  @override
  void dispose() {
    _fxCtrl.dispose();
    _scanCtrl.dispose();
    _shutdown(); // stop scan + camera
    super.dispose();
  }

  Future<void> _boot() async {
    await _startCamera();
    if (!mounted) return;

    // wait video ready + warmup
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

  // =============================
  // Camera
  // =============================
  Future<void> _startCamera() async {
    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'facingMode': 'environment',
          'width': {'ideal': 1280, 'min': 640},
          'height': {'ideal': 720, 'min': 480},
        },
      });

      final video = _buildVideoElement(stream);
      _registerViewFactory(video);

      if (!mounted) {
        // widget disposed during permission prompt
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

  html.VideoElement _buildVideoElement(html.MediaStream stream) {
    return html.VideoElement()
      ..id = 'qr-video'
      ..setAttribute('autoplay', 'true')
      ..setAttribute('playsinline', 'true')
      ..setAttribute('muted', 'true')
      ..style.objectFit = 'cover'
      ..style.pointerEvents = 'none'
      ..srcObject = stream;
  }

  void _registerViewFactory(html.VideoElement video) {
    // Register view factory once per widget instance
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => video,
    );
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
    // stop tracks
    try {
      _stream?.getTracks().forEach((t) => t.stop());
    } catch (_) {}

    // cleanup element
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

  // =============================
  // QR Scan loop (JS + CustomEvent)
  // =============================
  Future<void> _startQrScan() async {
    if (_qrScanning) return;
    _qrScanning = true;

    await _qrSub?.cancel();

    // Listen custom event from JS: window.dispatchEvent(new CustomEvent("qr-from-image", {detail:{...}}))
    _qrSub = html.window.on['qr-from-image'].listen(_onQrEvent);

    try {
      startQrLoop();
      if (!_scanCtrl.isAnimating) {
        _scanCtrl.repeat(reverse: true);
      }
    } catch (e) {
      debugPrint('startQrLoop error: $e');
    }
  }

  Future<void> stopNow() async {
    await _stopQrScan();
    if (_scanCtrl.isAnimating) _scanCtrl.stop();
    _stopCamera();
    if (mounted) setState(() {});
  }

  Future<void> stopCamera() => stopNow();

  Future<void> _stopQrScan() async {
    try {
      stopQrLoop();
    } catch (_) {}

    try {
      await _qrSub?.cancel();
    } catch (_) {}
    _qrSub = null;

    _qrScanning = false;
  }

  void _onQrEvent(html.Event event) {
    if (!mounted) return;
    if (event is! html.CustomEvent) return;

    final detail = event.detail;
    // detail thường là JS object -> Map-like trên dart:html
    final text = (detail is Map ? detail['text'] : null)?.toString() ?? '';
    final err = (detail is Map ? detail['error'] : null)?.toString() ?? '';

    if (err.isNotEmpty || text.isEmpty) return;

    final now = DateTime.now();
    if (_lastQr == text &&
        _lastQrAt != null &&
        now.difference(_lastQrAt!) < _qrDedupe) {
      return;
    }

    _lastQr = text;
    _lastQrAt = now;

    _playFx();
    if (mounted) setState(() {});
    widget.onQrDetected?.call(text);
  }

  void _playFx() {
    _fxCtrl.forward(from: 0).then((_) {
      if (mounted) _fxCtrl.reverse();
    });
  }

  // =============================
  // UI
  // =============================
  @override
  Widget build(BuildContext context) {
    final video = _video;

    return Stack(
      children: [
        _frame(
          child: video == null
              ? const Center(child: CircularProgressIndicator())
              : Transform.scale(
                  scale: _zoom,
                  child: HtmlElementView(
                    key: ValueKey(_viewType),
                    viewType: _viewType,
                  ),
                ),
        ),

        // QR badge (top-left)
        Positioned(
          top: 12,
          left: 12,
          child: AnimatedBuilder(
            animation: _fxCtrl,
            builder: (context, child) {
              final scale = 1.0 + (0.10 * _fxCtrl.value);
              final dx = (_fxCtrl.value < 0.5 ? -1 : 1) * 4.0 * _fxCtrl.value;
              return Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.scale(scale: scale, child: child),
              );
            },
            child: _QrBadge(text: _lastQr ?? ''),
          ),
        ),

        // zoom control (bottom-right)
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

        // scan line overlay
        Positioned.fill(child: _scanOverlay()),
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
                          const Color(0xFF7CF8D6).withOpacity(0.14),
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
                          color: const Color(0xFF7CF8D6).withOpacity(0.55),
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
              const Icon(Icons.qr_code_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.elasticOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.9),
                      end: Offset.zero,
                    ).animate(anim),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.7, end: 1.12).animate(anim),
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

/// Zoom control nhẹ, để bạn thay bằng GlassZoomControl của bạn nếu muốn.
/// (Nếu bạn muốn giữ widget cũ: chỉ cần thay _ZoomControl => GlassZoomControl)
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
