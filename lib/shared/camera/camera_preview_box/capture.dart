part of '../camera_preview_box.dart';

/// Chụp ảnh / upload ảnh từ thiết bị.
mixin _CaptureMixin
    on State<CameraPreviewBox>, _CameraStreamMixin, _QrScanMixin {
  /// Do CameraPreviewBoxState tạo (giữ vsync tại State).
  AnimationController get _flashController;

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

  // =========================
  // Capture
  // =========================
  /// Trạng thái nút chụp: chỉ rebuild nút, không rebuild camera.
  final ValueNotifier<bool> _capturingNotifier = ValueNotifier<bool>(false);

  bool get _isCapturing => _capturingNotifier.value;

  set _isCapturing(bool value) => _capturingNotifier.value = value;

  final List<Uint8List> _capturedImages = [];

  bool get canUpload => _capturedImages.length < _maxImages;

  List<Uint8List> get images => List<Uint8List>.unmodifiable(_capturedImages);

  void _notifyImagesChanged() {
    widget.onImagesChanged?.call(List<Uint8List>.unmodifiable(_capturedImages));
  }

  // =========================
  // Capture / Upload
  // =========================
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

  Future<void> _takePhoto() async {
    if (_cameraSleeping || _cameraStarting) return;
    if (_isCapturing || _video == null) return;
    if (_capturedImages.length >= _maxImages) return;

    _isCapturing = true;
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
      if (mounted) _isCapturing = false;
    }
  }
}
