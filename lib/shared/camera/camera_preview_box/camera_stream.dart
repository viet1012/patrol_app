part of '../camera_preview_box.dart';

/// Camera stream (getUserMedia + <video id="qr-video">) và các field
/// session/flag dùng chung cho các mixin khác.
mixin _CameraStreamMixin on State<CameraPreviewBox> {
  static const int _idealCameraFps = 20;
  static const int _maxCameraFps = 24;

  static const Duration _qrWarmup = Duration(milliseconds: 250);

  // =========================
  // Camera / View
  // =========================
  html.MediaStream? _stream;
  html.VideoElement? _video;
  late String _viewType;
  int _viewGeneration = 0;

  bool _cameraSleeping = false;
  bool _cameraStarting = false;
  bool _cameraStopping = false;
  bool _cameraStartFailed = false;

  bool _userCameraEnabled = true;
  bool _lifecycleSuspended = false;

  /// Route bị page route khác che hoặc đang pop (áp dụng cho mọi instance,
  /// kể cả không có power control). Xử lý giống [_lifecycleSuspended].
  bool _routeSuspended = false;

  /// Mỗi lần start/wake tạo một session mới.
  /// Khi OFF, tăng session để vô hiệu hóa getUserMedia đang chạy dở.
  int _cameraSession = 0;

  double _zoom = 1.0;

  // =========================
  // Trạng thái dùng chung với QR / zoom
  // =========================
  bool _qrScanning = false;

  /// Spinner "QR loading": chỉ rebuild indicator, không rebuild camera.
  final ValueNotifier<bool> _qrLoadingNotifier = ValueNotifier<bool>(false);

  /// Chỉ có setter: UI đọc trực tiếp [_qrLoadingNotifier].
  set _qrLoading(bool value) {
    // Sau dispose notifier không còn dùng được; giá trị cũng không còn ý nghĩa.
    if (!mounted) return;
    _qrLoadingNotifier.value = value;
  }

  /// supported/min/max/zoom của zoom thật. Mọi chỗ ghi (kể cả sleep/stop)
  /// đi qua setter bên dưới nên notifier luôn khớp.
  final ValueNotifier<_HwZoomUi> _hwZoomNotifier = ValueNotifier<_HwZoomUi>(
    (supported: false, min: 1.0, max: 1.0, zoom: 1.0),
  );

  void _updateHwZoomUi(_HwZoomUi value) {
    if (!mounted) return;
    _hwZoomNotifier.value = value;
  }

  bool get _hwZoomSupported => _hwZoomNotifier.value.supported;

  set _hwZoomSupported(bool value) {
    final z = _hwZoomNotifier.value;
    _updateHwZoomUi((supported: value, min: z.min, max: z.max, zoom: z.zoom));
  }

  double get _hwMinZoom => _hwZoomNotifier.value.min;

  set _hwMinZoom(double value) {
    final z = _hwZoomNotifier.value;
    _updateHwZoomUi((supported: z.supported, min: value, max: z.max, zoom: z.zoom));
  }

  double get _hwMaxZoom => _hwZoomNotifier.value.max;

  set _hwMaxZoom(double value) {
    final z = _hwZoomNotifier.value;
    _updateHwZoomUi((supported: z.supported, min: z.min, max: value, zoom: z.zoom));
  }

  double? _hwPendingZoom;
  int _zoomOperationGeneration = 0;

  bool get isCameraSleeping => _cameraSleeping;

  bool get isCameraStarting => _cameraStarting;

  bool get _cameraShouldRun =>
      !_routeSuspended &&
      (!widget.enablePowerControl ||
          (_userCameraEnabled && !_lifecycleSuspended));

  void _setCameraSleeping(bool value, {bool notifyParent = true}) {
    final changed = _cameraSleeping != value;
    _cameraSleeping = value;

    if (changed && notifyParent) {
      widget.onCameraSleepingChanged?.call(value);
    }
  }

  // =========================
  // Hook do mixin khác cài đặt
  // =========================
  void _setQrWarning(_QrWarningState state, [String message = '']);

  void _hideQrWarning();

  void _clearCameraSessionUi();

  Future<void> _startAutoQrScan();

  Future<void> _stopQrScan({bool updateUi = true});

  void _initHardwareZoom(int session);

  String _nextViewType() {
    _viewGeneration++;
    return 'camera_${DateTime.now().microsecondsSinceEpoch}_$_viewGeneration';
  }

  /// Tắt camera thật trên Web nhưng giữ state widget, ảnh đã chụp và QR Patrol.
  void _invalidateActiveCameraSession() {
    _cameraSession++;
    _qrScanning = false;
    _qrLoading = false;
    try {
      stopQrLoop();
    } catch (_) {}
  }

  Future<void> sleepCamera() async {
    if (_cameraStopping) return;
    if (_cameraSleeping && _stream == null && _video == null && !_cameraStarting) {
      return;
    }

    // Vô hiệu hóa mọi request getUserMedia đang chạy dở.
    _cameraSession++;
    _cameraStopping = true;
    _setCameraSleeping(true);

    if (mounted) {
      setState(() {
        _cameraStarting = false;
      });
    }

    try {
      await _stopQrScan(updateUi: false);
      _clearCameraSessionUi();

      _hwZoomSupported = false;
      _hwMinZoom = 1.0;
      _hwMaxZoom = 1.0;
      _hwPendingZoom = null;
      _zoomOperationGeneration++;

      final oldStream = _stream;
      final oldVideo = _video;

      // Bỏ reference trước để build không dùng Platform View cũ.
      _stream = null;
      _video = null;

      _disposeVideoElement(oldVideo);
      _stopStream(oldStream);

      // Phòng trường hợp video cũ vẫn còn trong DOM.
      final domVideo = html.document.getElementById('qr-video');
      if (domVideo is html.VideoElement) {
        final domStream = domVideo.srcObject;
        if (domStream is html.MediaStream) {
          _stopStream(domStream);
        }
        _disposeVideoElement(domVideo);
      }

      if (!mounted) return;

      setState(() {
        _qrScanning = false;
        _qrLoading = false;
        _cameraStarting = false;

        // Buộc Flutter bỏ HtmlElementView cũ.
        _viewType = _nextViewType();
      });

      debugPrint('Camera completely stopped.');
    } finally {
      _cameraStopping = false;
    }
  }

  /// Khởi động lại camera sau khi sleep.
  Future<bool> wakeCamera() async {
    if (_cameraStarting || _cameraStopping) return false;

    if (!_cameraSleeping && _stream != null && _video != null) {
      return true;
    }

    /*
     * QUAN TRỌNG:
     * Phải chuyển sleeping=false trước khi gọi _startCamera().
     * Nếu vẫn true, điều kiện bảo vệ trong _startCamera() sẽ stop
     * stream mới ngay sau khi getUserMedia trả về.
     */
    _setCameraSleeping(false);
    _clearCameraSessionUi();

    if (mounted) {
      setState(() {});
    }

    await _startCamera();

    final started =
        mounted && _stream != null && _video != null && !_cameraSleeping;

    if (!started) {
      _setCameraSleeping(true);
      if (mounted) setState(() {});
    }

    debugPrint('Wake camera result: started=$started, qrScanning=$_qrScanning');

    return started;
  }

  Future<void> _startCamera() async {
    if (_cameraStopping || _cameraStarting) return;
    if (!_cameraShouldRun) return;

    _cameraStarting = true;
    _cameraStartFailed = false;
    final session = ++_cameraSession;

    _hideQrWarning();

    if (mounted) setState(() {});

    html.MediaStream? createdStream;
    html.VideoElement? createdVideo;

    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        throw StateError('Camera API is not available in this browser.');
      }

      createdStream = await mediaDevices.getUserMedia({
        'video': {
          'facingMode': {'ideal': 'environment'},
          'width': {'ideal': 1920},
          'height': {'ideal': 1080},
          'frameRate': {'ideal': _idealCameraFps, 'max': _maxCameraFps},
        },
      });

      if (!mounted ||
          _cameraStopping ||
          _cameraSleeping ||
          session != _cameraSession) {
        _stopStream(createdStream);
        return;
      }

      final viewType = _nextViewType();

      createdVideo = html.VideoElement()
        // JS startQrLoop() tìm đúng phần tử này.
        ..id = 'qr-video'
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.display = 'block'
        ..style.visibility = 'visible'
        ..style.opacity = '1'
        ..style.objectFit = 'cover'
        ..style.pointerEvents = 'none'
        ..style.position = 'absolute'
        ..style.top = '0'
        ..style.right = '0'
        ..style.bottom = '0'
        ..style.left = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.zIndex = '0'
        ..srcObject = createdStream;

      ui_web.platformViewRegistry.registerViewFactory(
        viewType,
        (_) => createdVideo!,
      );

      if (!mounted ||
          _cameraStopping ||
          _cameraSleeping ||
          session != _cameraSession) {
        _disposeVideoElement(createdVideo);
        _stopStream(createdStream);
        return;
      }

      setState(() {
        _viewType = viewType;
        _stream = createdStream;
        _video = createdVideo;
      });

      _setCameraSleeping(false);
      _cameraStartFailed = false;

      try {
        await createdVideo.play();
      } catch (error) {
        debugPrint('Video play warning: $error');
      }

      final videoReady = await _waitVideoReady(
        timeout: const Duration(seconds: 4),
        session: session,
      );

      if (!videoReady) {
        if (mounted && session == _cameraSession) {
          _setQrWarning(
            _QrWarningState.error,
            'Camera started but no video frames became available.',
          );
        }
        throw StateError('Camera video readiness timed out.');
      }

      if (!mounted ||
          _cameraSleeping ||
          session != _cameraSession ||
          _stream == null ||
          _video == null) {
        return;
      }

      await Future.delayed(_qrWarmup);

      if (!mounted ||
          _cameraSleeping ||
          session != _cameraSession ||
          _stream == null ||
          _video == null) {
        return;
      }

      await _startAutoQrScan();

      // Đọc khả năng zoom sau khi QR đã chạy; lỗi ở đây không ảnh hưởng camera.
      _initHardwareZoom(session);
    } catch (error, stackTrace) {
      debugPrint('Camera start error: $error');
      debugPrintStack(stackTrace: stackTrace);

      _disposeVideoElement(createdVideo);
      _stopStream(createdStream);

      if (!mounted || session != _cameraSession) return;

      _cameraStartFailed = true;

      setState(() {
        _stream = null;
        _video = null;
        _qrScanning = false;
        _qrLoading = false;
      });

      _setCameraSleeping(true);

      _setQrWarning(
        _QrWarningState.error,
        'Cannot start camera. Check camera permission and HTTPS.',
      );
    } finally {
      if (session == _cameraSession) {
        _cameraStarting = false;
        if (mounted) setState(() {});
      }
    }
  }

  Future<bool> _waitVideoReady({
    required Duration timeout,
    required int session,
  }) async {
    final start = DateTime.now();
    while (mounted && session == _cameraSession) {
      final v = _video;
      if (v != null &&
          v.srcObject != null &&
          v.readyState >= 2 &&
          v.videoWidth > 0 &&
          v.videoHeight > 0) {
        return true;
      }
      if (DateTime.now().difference(start) > timeout) return false;
      await Future.delayed(const Duration(milliseconds: 50));
    }
    return false;
  }

  void _stopStream(html.MediaStream? stream) {
    if (stream == null) return;

    try {
      for (final track in stream.getTracks()) {
        track.enabled = false;
        track.stop();
        debugPrint(
          'Stopped camera track: kind=${track.kind}, readyState=${track.readyState}',
        );
      }
    } catch (error) {
      debugPrint('Stop stream error: $error');
    }
  }

  void _disposeVideoElement(html.VideoElement? video) {
    if (video == null) return;

    try {
      video.pause();
      video.srcObject = null;
      video.style.display = 'none';
      video.style.visibility = 'hidden';
      video.style.opacity = '0';
      video.removeAttribute('src');
      video.load();
      video.remove();
    } catch (error) {
      debugPrint('Dispose video element error: $error');
    }
  }

  void _stopCamera() {
    _cameraSession++;
    _zoomOperationGeneration++;
    _hwPendingZoom = null;
    _hwZoomSupported = false;

    final oldStream = _stream;
    final oldVideo = _video;

    _stream = null;
    _video = null;

    _disposeVideoElement(oldVideo);
    _stopStream(oldStream);

    final domVideo = html.document.getElementById('qr-video');
    if (domVideo is html.VideoElement) {
      final domStream = domVideo.srcObject;
      if (domStream is html.MediaStream) {
        _stopStream(domStream);
      }
      _disposeVideoElement(domVideo);
    }
  }
}
