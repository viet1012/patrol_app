part of '../camera_preview_box.dart';

/// Zoom thật trên camera track (chỉ khi enableZoomControls).
mixin _HwZoomMixin on State<CameraPreviewBox>, _CameraStreamMixin {
  // =========================
  // Camera zoom thật (chỉ khi enableZoomControls)
  // =========================

  /// Trần zoom cho QR: zoom số quá lớn thường làm QR mờ hơn, không giúp đọc.
  static const double _qrMaxZoom = 4.0;

  /// Bỏ qua thay đổi pinch nhỏ hơn mức này (tránh gọi applyConstraints dày).
  static const double _zoomUpdateThreshold = 0.05;

  static const double _zoomButtonStep = 0.5;

  double get _hwZoom => _hwZoomNotifier.value.zoom;

  set _hwZoom(double value) {
    final z = _hwZoomNotifier.value;
    _updateHwZoomUi((supported: z.supported, min: z.min, max: z.max, zoom: value));
  }

  double _desiredHwZoom = 1.0;
  double _hwScaleStartZoom = 1.0;

  /// Chỉ một applyConstraints chạy tại một thời điểm; giá trị mới nhất
  /// được gộp vào [_hwPendingZoom].
  bool _hwZoomApplying = false;

  bool get _hwZoomVisible =>
      widget.enableZoomControls &&
      _hwZoomSupported &&
      _video != null &&
      !_cameraSleeping;

  // =========================
  // Camera zoom thật (MediaStreamTrack)
  // =========================

  /// Track video hiện tại: cùng stream với <video id="qr-video"> mà QR loop
  /// đọc frame, nên zoom track = đổi chính input của decoder.
  html.MediaStreamTrack? _currentVideoTrack() {
    final stream = _stream;
    if (stream == null) return null;
    final tracks = stream.getVideoTracks();
    return tracks.isEmpty ? null : tracks.first;
  }

  double? _jsNumber(Object? object, String name) {
    if (object == null || !js_util.hasProperty(object, name)) return null;
    final value = js_util.getProperty<Object?>(object, name);
    return value is num ? value.toDouble() : null;
  }

  /// Đọc zoom capability của track (Chrome Android...). Không hỗ trợ /
  /// lỗi -> ẩn control, camera và QR vẫn chạy bình thường.
  @override
  void _initHardwareZoom(int session) {
    if (!widget.enableZoomControls) return;

    var supported = false;
    var minZoom = 1.0;
    var maxZoom = 1.0;
    var currentZoom = 1.0;

    try {
      final track = _currentVideoTrack();
      if (track != null && js_util.hasProperty(track, 'getCapabilities')) {
        final capabilities =
            js_util.callMethod<Object?>(track, 'getCapabilities', const []);
        final zoom = capabilities == null
            ? null
            : js_util.getProperty<Object?>(capabilities, 'zoom');
        final deviceMin = _jsNumber(zoom, 'min');
        final deviceMax = _jsNumber(zoom, 'max');

        if (deviceMin != null && deviceMax != null && deviceMax > deviceMin) {
          minZoom = deviceMin;
          // Trần QR: min(device max, 4x); không thấp hơn min của device.
          maxZoom = math.max(minZoom, math.min(deviceMax, _qrMaxZoom));
          supported = maxZoom > minZoom;

          final settings =
              js_util.hasProperty(track, 'getSettings')
                  ? js_util.callMethod<Object?>(track, 'getSettings', const [])
                  : null;
          currentZoom = (_jsNumber(settings, 'zoom') ?? minZoom)
              .clamp(minZoom, maxZoom)
              .toDouble();
        }
      }
    } catch (error) {
      debugPrint('Camera zoom not available: $error');
      supported = false;
    }

    if (!mounted || session != _cameraSession) return;

    // Một lần notify cho cả 4 giá trị (trước đây là một setState).
    _updateHwZoomUi(
      (supported: supported, min: minZoom, max: maxZoom, zoom: currentZoom),
    );
    _hwPendingZoom = null;

    if (!supported) return;

    // Phiên camera mới bắt đầu ở 1x (hoặc giá trị hợp lệ gần nhất).
    final initialZoom = _desiredHwZoom.clamp(minZoom, maxZoom).toDouble();
    if ((initialZoom - currentZoom).abs() >= 0.001) {
      _setHardwareZoom(initialZoom);
    }
  }

  /// Áp zoom lên camera track (applyConstraints). Không restart camera,
  /// không đổi resolution; lỗi chỉ log, scanner tiếp tục chạy.
  Future<void> _setHardwareZoom(double requested) async {
    if (!_hwZoomSupported) return;

    final target = requested.clamp(_hwMinZoom, _hwMaxZoom).toDouble();
    _desiredHwZoom = target;
    if (mounted && (target - _hwZoom).abs() >= 0.001) {
      _hwZoom = target;
    }

    _hwPendingZoom = target;
    if (_hwZoomApplying) return;

    final operationGeneration = _zoomOperationGeneration;
    _hwZoomApplying = true;
    try {
      while (_hwPendingZoom != null) {
        if (operationGeneration != _zoomOperationGeneration) break;
        final value = _hwPendingZoom!;
        _hwPendingZoom = null;

        final track = _currentVideoTrack();
        if (!mounted || track == null || _cameraSleeping) break;

        final constraints = js_util.jsify({
          'advanced': [
            {'zoom': value},
          ],
        });
        await js_util.promiseToFuture<Object?>(
          js_util.callMethod<Object>(track, 'applyConstraints', [constraints]),
        );
      }
    } catch (error) {
      debugPrint('Camera zoom apply failed: $error');
    } finally {
      final restartForNewTrack =
          operationGeneration != _zoomOperationGeneration &&
          mounted &&
          _hwZoomSupported &&
          !_cameraSleeping;
      _hwZoomApplying = false;
      _hwPendingZoom = null;
      if (restartForNewTrack) {
        unawaited(_setHardwareZoom(_desiredHwZoom));
      }
    }
  }

  /// Pinch 2 ngón trên preview -> zoom thật. 1 ngón không bị bắt (vẫn cuộn
  /// trang bình thường). Không ảnh hưởng QR callback (QR đến từ JS event).
  Widget _wrapPinchZoom(Widget child) {
    if (!widget.enableZoomControls) return child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onScaleStart: (_) => _hwScaleStartZoom = _hwZoom,
      onScaleUpdate: (details) {
        if (!_hwZoomVisible || details.pointerCount < 2) return;

        final next = (_hwScaleStartZoom * details.scale)
            .clamp(_hwMinZoom, _hwMaxZoom)
            .toDouble();
        if ((next - _hwZoom).abs() < _zoomUpdateThreshold) return;

        _setHardwareZoom(next);
      },
      child: child,
    );
  }
}
