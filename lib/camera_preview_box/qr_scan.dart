part of '../camera_preview_box.dart';

/// Quét QR (ZXing JS), QR nhập tay / từ ảnh upload, badge/guide/warning
/// notifiers và QR lock animation.
mixin _QrScanMixin on State<CameraPreviewBox>, _CameraStreamMixin {
  /// Do CameraPreviewBoxState tạo (giữ vsync tại State).
  AnimationController get _qrLockController;

  static const Duration _qrDedupe = Duration(milliseconds: 900);

  // =========================
  // QR scanning (JS ZXing)
  // =========================
  StreamSubscription? _qrSub;
  StreamSubscription? _qrStatusSub;

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
  QrDetectionGeometry? _latestQrGeometry;
  DateTime? _latestQrGeometryAt;
  final ValueNotifier<_QrLockData?> _qrLockNotifier =
      ValueNotifier<_QrLockData?>(null);

  @override
  void _setQrWarning(_QrWarningState state, [String message = '']) {
    if (!mounted) return;

    if (_qrWarningStateNotifier.value != state) {
      _qrWarningStateNotifier.value = state;
    }

    if (_qrWarningMessageNotifier.value != message) {
      _qrWarningMessageNotifier.value = message;
    }
  }

  @override
  void _hideQrWarning() {
    _setQrWarning(_QrWarningState.hidden);
  }

  void _bindQrListeners() {
    _qrSub ??= html.window.on['qr-from-image'].listen(_onQrEvent);
    _qrStatusSub ??= html.window.on['qr-scan-status'].listen(_onQrStatusEvent);
  }

  @override
  void _clearCameraSessionUi() {
    _lastDetectedQr = null;
    _lastDetectedQrAt = null;
    _latestQrGeometry = null;
    _latestQrGeometryAt = null;
    _patrolQrNotifier.value = null;
    _showQrGuideNotifier.value = true;
    _qrLockController.stop();
    _qrLockController.reset();
    _qrLockNotifier.value = null;
    _hideQrWarning();
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
  void _acceptDetectedQr(
    String rawQr, {
    bool haptic = true,
    QrDetectionGeometry? geometry,
  }) {
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
      if (geometry != null) {
        widget.onQrDetectedDetailed?.call(geometry);
      }
      widget.onQrDetected?.call(qr);
    } catch (error, stackTrace) {
      debugPrint('onQrDetected callback error: $error');

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Called by Fixed Asset only after its validation accepts this raw QR.
  /// The backend pipeline is not awaited by this visual-only method.
  void showAcceptedQrLock(String rawQr, String machineCode) {
    if (!mounted || !widget.enableQrLockAnimation) return;
    final normalized = rawQr.trim();
    final geometry = _latestQrGeometry;
    final isFreshMatch = geometry != null &&
        geometry.value == normalized &&
        _latestQrGeometryAt != null &&
        DateTime.now().difference(_latestQrGeometryAt!) <
            const Duration(seconds: 2);

    _qrLockNotifier.value = _QrLockData(
      label: machineCode.trim(),
      geometry: isFreshMatch ? geometry : null,
    );
    _qrLockController.forward(from: 0);
  }

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

  // =========================
  // QR (ZXing JS) start/stop
  // =========================
  @override
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

    // _qrScanning không hiển thị; _qrLoading tự báo qua _qrLoadingNotifier.
    _qrScanning = true;
    _qrLoading = true;

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
        _qrLoading = false;
      }
    }
  }

  @override
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
      _qrScanning = false;
      _qrLoading = false;
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
    final geometry = _geometryFromJsDetail(text, detail);
    if (geometry != null) {
      _latestQrGeometry = geometry;
      _latestQrGeometryAt = DateTime.now();
    }

    _acceptDetectedQr(text, geometry: geometry);
  }

  QrDetectionGeometry? _geometryFromJsDetail(
    String text,
    Map<String, dynamic> detail,
  ) {
    double number(String key) =>
        double.tryParse(detail[key]?.toString() ?? '') ?? 0;

    final sourceWidth = number('sourceWidth');
    final sourceHeight = number('sourceHeight');
    final cropX = number('cropX');
    final cropY = number('cropY');
    final cropWidth = number('cropWidth');
    final cropHeight = number('cropHeight');
    final analysisWidth = number('analysisWidth');
    final analysisHeight = number('analysisHeight');
    final rawCorners = detail['corners'];

    if (sourceWidth <= 0 ||
        sourceHeight <= 0 ||
        cropWidth <= 0 ||
        cropHeight <= 0 ||
        analysisWidth <= 0 ||
        analysisHeight <= 0 ||
        rawCorners is! List ||
        rawCorners.length < 3) {
      return null;
    }

    final corners = <Offset>[];
    for (final raw in rawCorners.take(4)) {
      if (raw is! Map) continue;
      final x = double.tryParse(raw['x']?.toString() ?? '');
      final y = double.tryParse(raw['y']?.toString() ?? '');
      if (x == null || y == null) continue;
      corners.add(Offset(
        cropX + x * cropWidth / analysisWidth,
        cropY + y * cropHeight / analysisHeight,
      ));
    }
    if (corners.length < 3) return null;
    if (corners.length == 3) {
      // ZXing QRCodeReader commonly returns bottom-left, top-left, top-right.
      corners.add(corners[0] + corners[2] - corners[1]);
      final ordered = <Offset>[corners[1], corners[2], corners[3], corners[0]];
      corners
        ..clear()
        ..addAll(ordered);
    }

    return QrDetectionGeometry(
      value: text,
      corners: List<Offset>.unmodifiable(corners),
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    );
  }

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

  void resetQr() {
    _lastDetectedQr = null;
    _lastDetectedQrAt = null;

    _patrolQrNotifier.value = null;
    _showQrGuideNotifier.value = true;

    if (_qrScanning && !_cameraSleeping) {
      _hideQrWarning();
    }
  }
}
