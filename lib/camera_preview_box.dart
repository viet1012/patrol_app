import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:chuphinh/socket/SttWebSocket.dart';
import 'package:chuphinh/widget/glass_circle_button.dart';
import 'package:chuphinh/widget/glass_zoom_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:js/js.dart';

import 'api/api_config.dart';
import 'api/stt_api.dart';
import 'homeScreen/patrol_home_screen.dart';

// Giữ nguyên các import project hiện tại của bạn:
// import 'package:chuphinh/socket/SttWebSocket.dart';
// import 'package:chuphinh/widget/glass_circle_button.dart';
// import 'package:chuphinh/widget/glass_zoom_control.dart';
// import 'api/api_config.dart';
// import 'api/stt_api.dart';
// import 'homeScreen/patrol_home_screen.dart';

enum _QrWarningState { hidden, reading, unreadable, error }

@JS('startQrLoop')
external void startQrLoop();

@JS('stopQrLoop')
external void stopQrLoop();

@JS('decodeQrFromImageBytes')
external void _decodeQrFromImageBytesJs(String objectUrl);

class CameraPreviewBox extends StatefulWidget {
  final double size;
  final Function(List<Uint8List> images)? onImagesChanged;

  final String? plant;
  final String? group;
  final String type;
  final String? wsUrl;
  final PatrolGroup patrolGroup;

  /// Gửi QR về màn hình cha.
  final ValueChanged<String>? onQrDetected;

  /// Chỉ thông báo trạng thái để màn hình cha cập nhật UI.
  /// CameraPreviewBoxState vẫn là nguồn trạng thái thật duy nhất.
  final ValueChanged<bool>? onCameraSleepingChanged;

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
    this.onCameraSleepingChanged,
  });

  @override
  State<CameraPreviewBox> createState() => CameraPreviewBoxState();
}

class CameraPreviewBoxState extends State<CameraPreviewBox>
    with TickerProviderStateMixin {
  // =========================
  // Config
  // =========================
  int get _maxImages {
    if (widget.patrolGroup == PatrolGroup.AssetUpdate) {
      return 10;
    }

    return 3;
  }

  static const int _maxCaptureEdge = 2048;
  static const int _maxImportedEdge = 1600;

  static const int _idealCameraFps = 20;
  static const int _maxCameraFps = 24;

  static const Duration _qrDedupe = Duration(milliseconds: 900);
  static const Duration _qrWarmup = Duration(milliseconds: 250);

  static const double _minZoom = 1.0;
  static const double _maxZoom = 10.0;

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

  /// Mỗi lần start/wake tạo một session mới.
  /// Khi OFF, tăng session để vô hiệu hóa getUserMedia đang chạy dở.
  int _cameraSession = 0;

  double _zoom = 1.0;

  bool get isCameraSleeping => _cameraSleeping;

  bool get isCameraStarting => _cameraStarting;

  void _setCameraSleeping(bool value, {bool notifyParent = true}) {
    final changed = _cameraSleeping != value;
    _cameraSleeping = value;

    if (changed && notifyParent) {
      widget.onCameraSleepingChanged?.call(value);
    }
  }

  // =========================
  // QR scanning (JS ZXing)
  // =========================
  StreamSubscription? _qrSub;
  StreamSubscription? _qrStatusSub;
  bool _qrScanning = false;
  bool _qrLoading = false;

  /// QR Patrol dạng số đang hiển thị trên UI.
  /// ValueNotifier giúp chỉ rebuild badge QR, không rebuild toàn camera.
  final ValueNotifier<String?> _patrolQrNotifier = ValueNotifier<String?>(null);

  /// true: hiện khung hướng dẫn căn QR.
  /// false: đã đọc được QR bất kỳ nên ẩn khung.
  final ValueNotifier<bool> _showQrGuideNotifier = ValueNotifier<bool>(true);

  /// Chỉ hiện khi JS xác định có hình giống QR nhưng chưa đọc được,
  /// hoặc scanner/camera gặp lỗi thật.
  final ValueNotifier<_QrWarningState> _qrWarningStateNotifier =
      ValueNotifier<_QrWarningState>(_QrWarningState.hidden);

  final ValueNotifier<String> _qrWarningMessageNotifier = ValueNotifier<String>(
    '',
  );

  /// QR raw gần nhất, dùng chống callback lặp liên tục.
  String? _lastDetectedQr;
  DateTime? _lastDetectedQrAt;

  // =========================
  // Capture
  // =========================
  bool _isCapturing = false;
  final List<Uint8List> _capturedImages = [];
  late final AnimationController _flashController;

  bool get canUpload => _capturedImages.length < _maxImages;

  List<Uint8List> get images => List<Uint8List>.unmodifiable(_capturedImages);

  void _notifyImagesChanged() {
    widget.onImagesChanged?.call(List<Uint8List>.unmodifiable(_capturedImages));
  }

  // =========================
  // STT / Socket
  // =========================
  late String _fac;
  late String _group;
  late String _wsUrl;

  int stt = 0;
  bool _sttLoading = true;
  SttWebSocket? sttSocket;

  void _setQrWarning(_QrWarningState state, [String message = '']) {
    if (!mounted) return;

    if (_qrWarningStateNotifier.value != state) {
      _qrWarningStateNotifier.value = state;
    }

    if (_qrWarningMessageNotifier.value != message) {
      _qrWarningMessageNotifier.value = message;
    }
  }

  void _hideQrWarning() {
    _setQrWarning(_QrWarningState.hidden);
  }

  // =========================
  // Lifecycle
  // =========================

  @override
  void initState() {
    super.initState();

    _viewType = _nextViewType();
    _fac = (widget.plant ?? '').trim();
    _group = (widget.group ?? '').trim();
    _wsUrl = widget.wsUrl ?? '${ApiConfig.wsBaseUrl}/ws-stt/websocket';

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _bindQrListeners();
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
    /*
   * Vô hiệu hóa session camera trước.
   */
    _cameraSession++;

    try {
      stopQrLoop();
    } catch (_) {}

    try {
      _qrSub?.cancel();
    } catch (_) {}

    try {
      _qrStatusSub?.cancel();
    } catch (_) {}

    _qrSub = null;
    _qrStatusSub = null;
    _qrScanning = false;

    _stopCamera();

    try {
      sttSocket?.dispose();
    } catch (_) {}

    _flashController.dispose();
    _patrolQrNotifier.dispose();
    _showQrGuideNotifier.dispose();
    _qrWarningStateNotifier.dispose();
    _qrWarningMessageNotifier.dispose();

    super.dispose();
  }

  String _nextViewType() {
    _viewGeneration++;
    return 'camera_${DateTime.now().microsecondsSinceEpoch}_$_viewGeneration';
  }

  void _bindQrListeners() {
    _qrSub ??= html.window.on['qr-from-image'].listen(_onQrEvent);
    _qrStatusSub ??= html.window.on['qr-scan-status'].listen(_onQrStatusEvent);
  }

  /// Tắt camera thật trên Web nhưng giữ state widget, ảnh đã chụp và QR Patrol.
  Future<void> sleepCamera() async {
    if (_cameraSleeping || _cameraStopping) return;

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
      _hideQrWarning();

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

  bool _isQrNumber(String value) {
    return RegExp(r'^\d{1,5}$').hasMatch(value.trim());
  }

  bool _isDuplicateQr(String qr, DateTime now) {
    return _lastDetectedQr == qr &&
        _lastDetectedQrAt != null &&
        now.difference(_lastDetectedQrAt!) < _qrDedupe;
  }

  /// Nhận QR từ camera, nhập tay hoặc ảnh upload.
  /// Hàm này không gọi setState nên không rebuild toàn bộ camera.
  void _acceptDetectedQr(String rawQr, {bool haptic = true}) {
    if (!mounted) return;

    final qr = rawQr.trim();

    if (qr.isEmpty) return;

    /*
   * Chặn dữ liệu bất thường.
   */
    if (qr.length > 2048) {
      debugPrint(
        'QR rejected because content is too long: '
        '${qr.length}',
      );

      return;
    }

    final now = DateTime.now();

    if (_isDuplicateQr(qr, now)) {
      return;
    }

    _lastDetectedQr = qr;
    _lastDetectedQrAt = now;

    _hideQrWarning();

    if (_showQrGuideNotifier.value) {
      _showQrGuideNotifier.value = false;
    }

    /*
   * Chỉ QR Patrol dạng số mới hiện trên badge.
   * QR máy không xóa QR Patrol trước đó.
   */
    // if (_isQrNumber(qr) && _patrolQrNotifier.value != qr) {
    //   _patrolQrNotifier.value = qr;
    // }

    if (widget.patrolGroup == PatrolGroup.Patrol) {
      // Patrol chỉ hiện QR dạng số
      if (_isQrNumber(qr) && _patrolQrNotifier.value != qr) {
        _patrolQrNotifier.value = qr;
      }
    } else {
      // Asset / các loại khác:
      // hiện nguyên nội dung QR
      if (_patrolQrNotifier.value != qr) {
        _patrolQrNotifier.value = qr;
      }
    }

    if (haptic) {
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
    }

    try {
      widget.onQrDetected?.call(qr);
    } catch (error, stackTrace) {
      debugPrint('onQrDetected callback error: $error');

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // =========================
  // Camera
  // =========================

  Future<void> _inputQrManually() async {
    final controller = TextEditingController();

    try {
      final value = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1F2937),
            title: const Text(
              'Enter QR Code',
              style: TextStyle(color: Colors.white),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),

              keyboardType: widget.patrolGroup == PatrolGroup.Patrol
                  ? TextInputType.number
                  : TextInputType.text,

              inputFormatters: widget.patrolGroup == PatrolGroup.Patrol
                  ? [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ]
                  : null,

              decoration: const InputDecoration(
                hintText: 'Input QR code manually',
                hintStyle: TextStyle(color: Colors.white54),
              ),

              onSubmitted: (text) {
                Navigator.pop(dialogContext, text.trim());
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext, controller.text.trim());
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (value == null || value.trim().isEmpty) return;

      _acceptDetectedQr(value, haptic: false);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _startCamera() async {
    if (_cameraStopping || _cameraStarting) return;

    _cameraStarting = true;
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
    } catch (error, stackTrace) {
      debugPrint('Camera start error: $error');
      debugPrintStack(stackTrace: stackTrace);

      _disposeVideoElement(createdVideo);
      _stopStream(createdStream);

      if (!mounted || session != _cameraSession) return;

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

  // =========================
  // QR (ZXing JS) start/stop
  // =========================
  Future<void> _startAutoQrScan() async {
    if (_qrScanning) return;
    if (_cameraSleeping) return;
    if (_stream == null) return;
    if (_video == null) return;

    final video = _video!;

    if (video.videoWidth <= 0 || video.videoHeight <= 0) {
      debugPrint('QR scan not started: video is not ready.');

      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _qrScanning = true;
      _qrLoading = true;
    });

    _hideQrWarning();

    try {
      /*
     * JS chỉ đọc video hiện có.
     * JS không được gọi getUserMedia.
     */
      startQrLoop();

      debugPrint(
        'QR loop started: '
        '${video.videoWidth}x${video.videoHeight}',
      );

      await Future.delayed(const Duration(milliseconds: 150));
    } catch (error, stackTrace) {
      debugPrint('startQrLoop error: $error');

      debugPrintStack(stackTrace: stackTrace);

      _qrScanning = false;
      _setQrWarning(_QrWarningState.error, 'QR scanner could not start.');
    } finally {
      if (mounted) {
        setState(() {
          _qrLoading = false;
        });
      }
    }
  }

  Future<void> _stopQrScan({bool updateUi = true}) async {
    /*
   * Đặt false trước để event đang bay về
   * không còn được xử lý.
   */
    _qrScanning = false;
    try {
      stopQrLoop();
    } catch (error) {
      debugPrint('stopQrLoop warning: $error');
    }

    _hideQrWarning();

    if (mounted && updateUi) {
      setState(() {
        _qrScanning = false;
        _qrLoading = false;
      });
    } else {
      _qrLoading = false;
    }
  }

  Map<String, dynamic>? _parseJsEventDetail(html.CustomEvent event) {
    try {
      final rawDetail = event.detail;

      if (rawDetail == null) {
        return null;
      }

      /*
     * Bản JS mới luôn gửi JSON string.
     */
      if (rawDetail is String) {
        final decoded = jsonDecode(rawDetail);

        if (decoded is Map<String, dynamic>) {
          return decoded;
        }

        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }

        return null;
      }

      /*
     * Fallback tạm thời nếu browser đang cache JS cũ.
     */
      if (rawDetail is Map) {
        return Map<String, dynamic>.from(rawDetail);
      }

      debugPrint(
        'Unsupported JS event detail type: '
        '${rawDetail.runtimeType}',
      );

      return null;
    } catch (error, stackTrace) {
      debugPrint('Cannot parse JS event detail: $error');

      debugPrintStack(stackTrace: stackTrace);

      return null;
    }
  }

  void _onQrStatusEvent(dynamic event) {
    if (!mounted || _cameraSleeping || !_qrScanning) return;
    if (event is! html.CustomEvent) return;

    final detail = _parseJsEventDetail(event);
    if (detail == null) return;

    final status = detail['status']?.toString().trim().toLowerCase() ?? '';
    final message = detail['message']?.toString().trim() ?? '';

    switch (status) {
      case 'reading':
        /*
         * Có hình giống QR nhưng chưa đủ lâu để coi là lỗi.
         * Không hiện banner, giữ UI sạch.
         */
        _hideQrWarning();
        break;

      case 'unreadable':
        _setQrWarning(
          _QrWarningState.unreadable,
          message.isEmpty
              ? 'Cannot read QR. Move closer or hold steady.'
              : message,
        );
        break;

      case 'clear':
        _hideQrWarning();
        break;
    }
  }

  void _onQrEvent(dynamic event) {
    if (!mounted) return;
    if (_cameraSleeping) return;
    if (!_qrScanning) return;
    if (event is! html.CustomEvent) return;

    final detail = _parseJsEventDetail(event);

    if (detail == null) {
      return;
    }

    final error = detail['error']?.toString().trim() ?? '';

    if (error.isNotEmpty) {
      /*
     * Not found trong một frame là bình thường,
     * không nên hiển thị lỗi cho người dùng.
     */
      if (!error.toLowerCase().contains('not found')) {
        debugPrint('QR scanner event error: $error');

        _setQrWarning(
          _QrWarningState.error,
          'QR scanner error. Please restart the camera.',
        );
      }

      return;
    }

    final text = detail['text']?.toString().trim() ?? '';

    if (text.isEmpty) {
      return;
    }

    debugPrint('QR detected from camera: $text');

    _acceptDetectedQr(text);
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
  Future<String?> _decodeQrFromBytes(Uint8List bytes) async {
    if (bytes.isEmpty) {
      return null;
    }

    String? objectUrl;
    StreamSubscription<html.Event>? subscription;

    final completer = Completer<String?>();

    try {
      debugPrint('[QR-UPLOAD] start: ${bytes.length} bytes');

      final blob = html.Blob(<dynamic>[bytes], 'image/jpeg');

      objectUrl = html.Url.createObjectUrlFromBlob(blob);

      subscription = html.window.on['qr-from-uploaded-image'].listen((event) {
        if (event is! html.CustomEvent) {
          return;
        }

        final detail = _parseJsEventDetail(event);

        if (detail == null) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }

          return;
        }

        final text = detail['text']?.toString().trim() ?? '';

        final error = detail['error']?.toString().trim() ?? '';

        if (error.isNotEmpty) {
          debugPrint('[QR-UPLOAD] error: $error');
        }

        if (!completer.isCompleted) {
          completer.complete(text.isEmpty ? null : text);
        }
      });

      _decodeQrFromImageBytesJs(objectUrl);

      final result = await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('[QR-UPLOAD] timeout after 8 seconds');

          return null;
        },
      );

      debugPrint('[QR-UPLOAD] result: $result');

      return result;
    } catch (error, stackTrace) {
      debugPrint('[QR-UPLOAD] exception: $error');

      debugPrintStack(stackTrace: stackTrace);

      return null;
    } finally {
      try {
        await subscription?.cancel();
      } catch (_) {}

      if (objectUrl != null) {
        html.Url.revokeObjectUrl(objectUrl);
      }
    }
  }

  // Future<void> pickImagesFromDevice(BuildContext context) async {
  //   final remain = _maxImages - _capturedImages.length;
  //   if (remain <= 0) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text("You can upload up to 3 images only."),
  //         backgroundColor: Colors.redAccent,
  //         behavior: SnackBarBehavior.floating,
  //       ),
  //     );
  //     return;
  //   }
  //
  //   final uploadInput = html.FileUploadInputElement()
  //     ..accept = 'image/*'
  //     ..multiple = true;
  //
  //   uploadInput.click();
  //
  //   uploadInput.onChange.listen((_) async {
  //     final files = uploadInput.files;
  //     if (files == null || files.isEmpty) return;
  //
  //     final selected = files.take(remain);
  //
  //     for (final file in selected) {
  //       final reader = html.FileReader();
  //       reader.readAsArrayBuffer(file);
  //       await reader.onLoadEnd.first;
  //
  //       final bytes = reader.result as Uint8List;
  //
  //       // decode QR trong chính ảnh upload
  //       final qrText = await _decodeQrFromBytes(bytes);
  //
  //       if (qrText != null && qrText.isNotEmpty) {
  //         if (widget.type != 'Patrol' || RegExp(r'^\d{4}$').hasMatch(qrText)) {
  //           setState(() {
  //             _lastQr = qrText;
  //             _lastQrAt = DateTime.now();
  //           });
  //
  //           widget.onQrDetected?.call(qrText);
  //           HapticFeedback.mediumImpact();
  //           _playQrChangedFx();
  //         }
  //       }
  //
  //       // add ảnh sau khi đọc QR
  //       setState(() {
  //         _capturedImages.add(bytes);
  //       });
  //     }
  //
  //     widget.onImagesChanged?.call(_capturedImages);
  //   });
  // }
  ({int width, int height}) _fitInsideMaxEdge({
    required int sourceWidth,
    required int sourceHeight,
    required int maxEdge,
  }) {
    if (sourceWidth <= 0 || sourceHeight <= 0) {
      return (width: 0, height: 0);
    }

    final longestEdge = math.max(sourceWidth, sourceHeight);

    if (longestEdge <= maxEdge) {
      return (width: sourceWidth, height: sourceHeight);
    }

    final scale = maxEdge / longestEdge;

    return (
      width: math.max(1, (sourceWidth * scale).round()),
      height: math.max(1, (sourceHeight * scale).round()),
    );
  }

  Future<Uint8List?> _canvasToJpegBytes(
    html.CanvasElement canvas, {
    double quality = 0.82,
  }) async {
    final blob = await canvas.toBlob('image/jpeg', quality);
    if (blob == null) return null;

    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    await reader.onLoadEnd.first;

    final result = reader.result;

    if (result is ByteBuffer) {
      return Uint8List.view(result);
    }

    if (result is Uint8List) {
      return result;
    }

    if (result is List<int>) {
      return Uint8List.fromList(result);
    }

    return null;
  }

  Future<void> pickImagesFromDevice(BuildContext context) async {
    final remain = _maxImages - _capturedImages.length;

    if (remain <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can upload up to 3 images only.'),
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

    await uploadInput.onChange.first;

    final files = uploadInput.files;
    if (files == null || files.isEmpty) return;

    for (final file in files.take(remain)) {
      String? objectUrl;

      try {
        objectUrl = html.Url.createObjectUrl(file);

        final image = html.ImageElement();
        final imageReady = Completer<void>();

        late final StreamSubscription<html.Event> loadSub;
        late final StreamSubscription<html.Event> errorSub;

        loadSub = image.onLoad.listen((_) {
          if (!imageReady.isCompleted) imageReady.complete();
        });

        errorSub = image.onError.listen((_) {
          if (!imageReady.isCompleted) {
            imageReady.completeError(StateError('Failed to load image'));
          }
        });

        image.src = objectUrl;

        try {
          await imageReady.future.timeout(const Duration(seconds: 10));
        } finally {
          await loadSub.cancel();
          await errorSub.cancel();
        }

        final width = image.naturalWidth ?? image.width ?? 0;
        final height = image.naturalHeight ?? image.height ?? 0;

        if (width <= 0 || height <= 0) continue;

        final target = _fitInsideMaxEdge(
          sourceWidth: width,
          sourceHeight: height,
          maxEdge: _maxImportedEdge,
        );

        if (target.width <= 0 || target.height <= 0) continue;

        final canvas = html.CanvasElement(
          width: target.width,
          height: target.height,
        );

        canvas.context2D.drawImageScaled(
          image,
          0,
          0,
          target.width.toDouble(),
          target.height.toDouble(),
        );

        final bytes = await _canvasToJpegBytes(canvas, quality: 0.82);

        if (bytes == null || bytes.isEmpty) continue;

        final qrText = await _decodeQrFromBytes(bytes);
        if (qrText != null && qrText.trim().isNotEmpty) {
          _acceptDetectedQr(qrText, haptic: false);
        }

        if (!mounted) return;

        setState(() {
          _capturedImages.add(bytes);
        });

        _notifyImagesChanged();
      } catch (error, stackTrace) {
        debugPrint('pickImagesFromDevice error: $error');
        debugPrintStack(stackTrace: stackTrace);
      } finally {
        if (objectUrl != null) {
          html.Url.revokeObjectUrl(objectUrl);
        }
      }
    }
  }

  void removeImage(int index) {
    if (index < 0 || index >= _capturedImages.length) return;

    setState(() {
      _capturedImages.removeAt(index);
    });

    _notifyImagesChanged();
  }

  void clearAll() {
    if (_capturedImages.isEmpty) return;

    setState(() {
      _capturedImages.clear();
    });

    _notifyImagesChanged();
  }

  void resetQr() {
    _lastDetectedQr = null;
    _lastDetectedQrAt = null;

    _patrolQrNotifier.value = null;
    _showQrGuideNotifier.value = true;

    if (_qrScanning && !_cameraSleeping) {
      _hideQrWarning();
    }
  }

  Future<void> _takePhoto() async {
    if (_cameraSleeping || _cameraStarting) return;
    if (_isCapturing || _video == null) return;
    if (_capturedImages.length >= _maxImages) return;

    setState(() => _isCapturing = true);
    _flashController.forward().then((_) => _flashController.reverse());

    try {
      final video = _video!;
      final vw = video.videoWidth.toDouble();
      final vh = video.videoHeight.toDouble();
      if (vw == 0 || vh == 0) return;

      final outputSize = math.min(math.max(vw, vh), _maxCaptureEdge).toInt();
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

      final bytes = await _canvasToJpegBytes(canvas, quality: 0.88);

      if (bytes == null || bytes.isEmpty || !mounted) return;

      setState(() {
        _capturedImages.add(bytes);
      });

      _notifyImagesChanged();
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
          clipBehavior: Clip.none,
          children: [
            RepaintBoundary(
              child: Container(
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
                      _video != null && !_cameraSleeping
                          ? Transform.scale(
                              scale: _zoom,
                              child: HtmlElementView(
                                key: ValueKey(_viewType),
                                viewType: _viewType,
                              ),
                            )
                          : Container(
                              color: const Color(0xFF111827),
                              alignment: Alignment.center,
                              child: _cameraStarting
                                  ? const SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Color(0xFF22C55E),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.videocam_off_rounded,
                                      color: Colors.white38,
                                      size: 42,
                                    ),
                            ),

                      // Khung căn QR tĩnh: vẽ một lần, không chạy animation.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _showQrGuideNotifier,
                            child: const RepaintBoundary(
                              child: _QrGuideOverlay(),
                            ),
                            builder: (context, showGuide, child) {
                              return showGuide
                                  ? child!
                                  : const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),

                      // Tint nhẹ thay cho BackdropFilter.
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(.035),
                                Colors.transparent,
                                Colors.black.withOpacity(.08),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Flash chỉ rebuild lớp flash khi chụp ảnh.
                      AnimatedBuilder(
                        animation: _flashController,
                        builder: (_, __) {
                          return IgnorePointer(
                            child: Container(
                              color: Colors.white.withOpacity(
                                0.85 * _flashController.value,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 14,
              left: 7,
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
              left: 65,
              child: GestureDetector(
                onTap: _inputQrManually,
                child: const GlassCircleButton(
                  size: 50,
                  child: Icon(
                    Icons.keyboard_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),

            // Chỉ badge QR rebuild khi QR Patrol thay đổi.
            Positioned(
              top: 12,
              left: 12,
              child: RepaintBoundary(
                child: ValueListenableBuilder<String?>(
                  valueListenable: _patrolQrNotifier,
                  builder: (context, qr, _) {
                    return _QrStatusBadge(qr: qr);
                  },
                ),
              ),
            ),

            Positioned(
              top: 12,
              right: 12,
              child: RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCC111827),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(.30)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.18),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
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

            Positioned(
              bottom: 14,
              right: 14,
              child: GlassZoomControl(
                zoom: _zoom,
                minZoom: _minZoom,
                maxZoom: _maxZoom,
                onChanged: (value) {
                  if ((value - _zoom).abs() < 0.001) return;
                  setState(() => _zoom = value);
                },
              ),
            ),

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

            Positioned(
              left: 12,
              right: 12,
              bottom: 78,
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: ValueListenableBuilder<_QrWarningState>(
                    valueListenable: _qrWarningStateNotifier,
                    builder: (context, state, _) {
                      return ValueListenableBuilder<String>(
                        valueListenable: _qrWarningMessageNotifier,
                        builder: (context, message, __) {
                          return _QrWarningBanner(
                            state: state,
                            message: message,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),

            if (_qrLoading)
              const Positioned(
                top: 12,
                left: 150,
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

class _QrWarningBanner extends StatelessWidget {
  final _QrWarningState state;
  final String message;

  const _QrWarningBanner({required this.state, required this.message});

  @override
  Widget build(BuildContext context) {
    if (state == _QrWarningState.hidden) {
      return const SizedBox.shrink();
    }

    final isError = state == _QrWarningState.error;
    final color = isError ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final icon = isError
        ? Icons.error_outline_rounded
        : Icons.qr_code_scanner_rounded;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey('${state.name}-$message'),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xE6111827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.82)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 9,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrStatusBadge extends StatelessWidget {
  final String? qr;

  const _QrStatusBadge({required this.qr});

  @override
  Widget build(BuildContext context) {
    final value = qr?.trim() ?? '';
    final hasQr = value.isNotEmpty;

    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xD9111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasQr
              ? const Color(0xFF22C55E).withOpacity(0.75)
              : Colors.redAccent.withOpacity(0.50),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.20),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasQr ? Icons.qr_code_2_rounded : Icons.qr_code_scanner_rounded,
            size: 19,
            color: hasQr ? const Color(0xFF22C55E) : Colors.redAccent,
          ),
          const SizedBox(width: 7),
          Text(
            hasQr ? value : 'Scan Patrol QR',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: hasQr ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: hasQr ? 0.8 : 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _QrGuideOverlay extends StatelessWidget {
  const _QrGuideOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 205,
        height: 205,
        child: CustomPaint(
          painter: const _QrGuidePainter(),
          child: const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Place QR inside frame',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QrGuidePainter extends CustomPainter {
  const _QrGuidePainter();

  static const double _cornerLength = 38;
  static const double _radius = 13;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);

    final paint = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      // Top left
      ..moveTo(rect.left, rect.top + _cornerLength)
      ..lineTo(rect.left, rect.top + _radius)
      ..quadraticBezierTo(rect.left, rect.top, rect.left + _radius, rect.top)
      ..lineTo(rect.left + _cornerLength, rect.top)
      // Top right
      ..moveTo(rect.right - _cornerLength, rect.top)
      ..lineTo(rect.right - _radius, rect.top)
      ..quadraticBezierTo(rect.right, rect.top, rect.right, rect.top + _radius)
      ..lineTo(rect.right, rect.top + _cornerLength)
      // Bottom right
      ..moveTo(rect.right, rect.bottom - _cornerLength)
      ..lineTo(rect.right, rect.bottom - _radius)
      ..quadraticBezierTo(
        rect.right,
        rect.bottom,
        rect.right - _radius,
        rect.bottom,
      )
      ..lineTo(rect.right - _cornerLength, rect.bottom)
      // Bottom left
      ..moveTo(rect.left + _cornerLength, rect.bottom)
      ..lineTo(rect.left + _radius, rect.bottom)
      ..quadraticBezierTo(
        rect.left,
        rect.bottom,
        rect.left,
        rect.bottom - _radius,
      )
      ..lineTo(rect.left, rect.bottom - _cornerLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _QrGuidePainter oldDelegate) => false;
}
