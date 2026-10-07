import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:chuphinh/core/socket/stt_web_socket.dart';
import 'package:chuphinh/shared/widgets/glass_circle_button.dart';
import 'package:chuphinh/shared/widgets/glass_zoom_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:js/js.dart';

import 'package:chuphinh/core/api/api_config.dart';
import 'package:chuphinh/core/api/stt_api.dart';
import 'package:chuphinh/core/models/patrol_group.dart';

part 'camera_preview_box/models.dart';
part 'camera_preview_box/camera_stream.dart';
part 'camera_preview_box/qr_scan.dart';
part 'camera_preview_box/hw_zoom.dart';
part 'camera_preview_box/power.dart';
part 'camera_preview_box/stt.dart';
part 'camera_preview_box/capture.dart';
part 'camera_preview_box/overlays.dart';
part 'camera_preview_box/route_observer.dart';

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
  final ValueChanged<QrDetectionGeometry>? onQrDetectedDetailed;

  /// Chỉ thông báo trạng thái để màn hình cha cập nhật UI.
  /// CameraPreviewBoxState vẫn là nguồn trạng thái thật duy nhất.
  final ValueChanged<bool>? onCameraSleepingChanged;

  /// true: chỉ hiển thị preview + QR guide/badge/warning, ẩn upload,
  /// nhập QR tay, zoom và nút chụp. Chỉ ẩn UI, không tắt camera/QR logic.
  final bool qrOnly;

  /// true: zoom THẬT trên camera track (MediaStreamTrack zoom constraint) +
  /// nút [-] 1.0x [+] và pinch. QR loop đọc frame từ chính video đã zoom.
  /// false (mặc định): giữ nguyên hành vi cũ của mọi màn hình khác.
  final bool enableZoomControls;

  /// false: ẩn badge "No. x" góc phải (chỉ hiển thị; STT vẫn load như cũ)
  /// và cho badge QR dùng hết chiều ngang. true (mặc định): giữ nguyên hành
  /// vi cũ của mọi màn hình khác.
  final bool showQrNumber;

  /// false: the host draws its own QR chip (the raw-QR badge is hidden).
  final bool showQrBadge;
  final bool enableQrLockAnimation;
  final bool enablePowerControl;
  final bool useSwitchPowerControl;

  /// false: không load STT / không mở socket STT (vd. dialog quét QR không
  /// gắn với plant). true (mặc định): giữ nguyên hành vi cũ.
  final bool enableStt;

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
    this.onQrDetectedDetailed,
    this.onCameraSleepingChanged,
    this.qrOnly = false,
    this.enableZoomControls = false,
    this.showQrNumber = true,
    this.showQrBadge = true,
    this.enableQrLockAnimation = false,
    this.enablePowerControl = false,
    this.useSwitchPowerControl = false,
    this.enableStt = true,
  });

  @override
  State<CameraPreviewBox> createState() => CameraPreviewBoxState();
}

class CameraPreviewBoxState extends State<CameraPreviewBox>
    with
        TickerProviderStateMixin,
        _CameraStreamMixin,
        _QrScanMixin,
        _HwZoomMixin,
        _PowerMixin,
        _SttMixin,
        _CaptureMixin {
  static const double _minZoom = 1.0;
  static const double _maxZoom = 10.0;

  // =========================
  // Animation (vsync = State)
  // =========================
  @override
  late final AnimationController _qrLockController;

  @override
  late final AnimationController _flashController;

  /// Mọi setState (camera stream / power / ảnh) đều đồng bộ lại
  /// [_powerStateNotifier], để power control và màn hình camera-off cập nhật
  /// đúng như khi chúng còn đọc trực tiếp trong build.
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _syncPowerState();
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
    _qrLockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _bindQrListeners();
    // Lấy lựa chọn bật/tắt dùng chung trước khi quyết định start camera.
    _bindSharedUserCameraEnabled();
    _bindRouteObserver();
    if (widget.enablePowerControl) {
      _lifecycleSuspended = html.document.hidden == true;
      _visibilitySub = html.document.onVisibilityChange.listen(
        _onVisibilityChange,
      );
    }
    if (_cameraShouldRun) {
      _startCamera();
    } else {
      _setCameraSleeping(true, notifyParent: false);
    }
    if (widget.enableStt) {
      _loadStt();
      _connectSocket();
    }
    _syncPowerState();
  }

  /// Listener toàn cục (window QR event, visibility, shared power, route
  /// observer) gỡ ở deactivate: nếu dispose() của widget con ném lỗi, Flutter
  /// bỏ dở unmount và dispose() của box này không chạy, còn deactivate() thì
  /// luôn chạy. Chỉ gỡ/gắn listener, không dừng/khởi động camera.
  @override
  void deactivate() {
    _detachGlobalListeners();
    super.deactivate();
  }

  /// Reparent (GlobalKey): deactivate -> activate, gắn lại đúng một lần.
  @override
  void activate() {
    super.activate();
    _attachGlobalListeners();
  }

  void _detachGlobalListeners() {
    try {
      _qrSub?.cancel();
    } catch (_) {}
    try {
      _qrStatusSub?.cancel();
    } catch (_) {}
    _qrSub = null;
    _qrStatusSub = null;

    try {
      _visibilitySub?.cancel();
    } catch (_) {}
    _visibilitySub = null;

    _unbindSharedUserCameraEnabled();
    _unbindRouteObserver();
  }

  void _attachGlobalListeners() {
    _bindQrListeners();
    if (widget.enablePowerControl) {
      _visibilitySub ??= html.document.onVisibilityChange.listen(
        _onVisibilityChange,
      );
    }
    // Chỉ gắn lại listener; không đọc lại giá trị dùng chung.
    _attachSharedUserCameraListener();
    _bindRouteObserver();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateRoute(ModalRoute.of(context));
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

    try {
      _visibilitySub?.cancel();
    } catch (_) {}
    _visibilitySub = null;
    _unbindSharedUserCameraEnabled();
    _unbindRouteObserver();

    _stopCamera();

    try {
      sttSocket?.dispose();
    } catch (_) {}

    _flashController.dispose();
    _qrLockController.dispose();
    _qrLockNotifier.dispose();
    _patrolQrNotifier.dispose();
    _showQrGuideNotifier.dispose();
    _qrWarningStateNotifier.dispose();
    _qrWarningMessageNotifier.dispose();
    _sttNotifier.dispose();
    _hwZoomNotifier.dispose();
    _qrLoadingNotifier.dispose();
    _capturingNotifier.dispose();
    _powerStateNotifier.dispose();

    super.dispose();
  }

  /// Nút chụp: trạng thái chụp + trạng thái camera (power notifier được đồng
  /// bộ sau mỗi setState, kể cả instance không có power control).
  late final Listenable _captureButtonListenable = Listenable.merge([
    _capturingNotifier,
    _powerStateNotifier,
  ]);

  /// Khoảng chừa bên phải của badge QR; null = badge tự co theo nội dung.
  double? get _qrBadgeRightInset {
    if (widget.enablePowerControl) {
      return widget.useSwitchPowerControl ? 70 : 86;
    }
    return widget.showQrNumber ? null : 12;
  }

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
                  child: _wrapPinchZoom(
                    Stack(
                    fit: StackFit.expand,
                    children: [
                      _CameraLayer(
                        viewType: _viewType,
                        active: _video != null && !_cameraSleeping,
                        scale: widget.enableZoomControls ? 1.0 : _zoom,
                        inactive: ValueListenableBuilder<_PowerUi>(
                          valueListenable: _powerStateNotifier,
                          builder: (context, _, __) => _CameraUnavailableView(
                            state: cameraPowerState,
                            enablePowerControl: widget.enablePowerControl,
                            lifecycleSuspended: _lifecycleSuspended,
                            onResume: resumeCamera,
                          ),
                        ),
                      ),

                      // Khung căn QR tĩnh: vẽ một lần, không chạy animation.
                      if (!_cameraSleeping) Positioned.fill(
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
                      if (widget.enableQrLockAnimation)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: RepaintBoundary(
                              child: ValueListenableBuilder<_QrLockData?>(
                                valueListenable: _qrLockNotifier,
                                builder: (context, data, _) {
                                  if (data == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return AnimatedBuilder(
                                    animation: _qrLockController,
                                    builder: (context, _) => CustomPaint(
                                      painter: _QrLockPainter(
                                        data: data,
                                        progress: _qrLockController.value,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

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
            ),

            if (!widget.qrOnly) ...[
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
            ],

            // Chỉ badge QR rebuild khi QR Patrol thay đổi.
            if (widget.showQrBadge)
            Positioned(
              top: 12,
              left: 12,
              // Có power control: luôn chừa chỗ cho control (mọi màn cùng một
              // công thức). Không có control và không có badge "No.": badge QR
              // được dùng hết chiều ngang.
              right: _qrBadgeRightInset,
              child: RepaintBoundary(
                child: ValueListenableBuilder<String?>(
                  valueListenable: _patrolQrNotifier,
                  builder: (context, qr, _) {
                    final constrained = _qrBadgeRightInset != null;
                    final badge = _QrStatusBadge(
                      qr: qr,
                      ellipsize: constrained,
                    );
                    return constrained
                        ? Align(alignment: Alignment.centerLeft, child: badge)
                        : badge;
                  },
                ),
              ),
            ),

            // Badge STT "No. x": không build khi tắt STT (enableStt == false).
            if (widget.showQrNumber && widget.enableStt)
            Positioned(
              top: widget.enablePowerControl ? 50 : 12,
              right: 12,
              child: RepaintBoundary(
                child: ValueListenableBuilder<_SttUi>(
                  valueListenable: _sttNotifier,
                  builder: (context, value, _) => _SttBadge(
                    stt: value.value,
                    loading: value.loading,
                  ),
                ),
              ),
            ),

            if (widget.enablePowerControl)
              Positioned(
                top: 12,
                right: 12,
                child: ValueListenableBuilder<_PowerUi>(
                  valueListenable: _powerStateNotifier,
                  builder: (context, _, __) => _CameraPowerControl(
                    state: cameraPowerState,
                    userCameraEnabled: _userCameraEnabled,
                    useSwitch: widget.useSwitchPowerControl,
                    onToggle: _toggleCameraPower,
                  ),
                ),
              ),

            if (!widget.qrOnly) ...[
            if (!widget.enableZoomControls)
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
                // canUpload đổi qua setState (ảnh) nên builder chạy lại theo cha.
                child: ListenableBuilder(
                  listenable: _captureButtonListenable,
                  builder: (context, _) {
                    final capturing = _capturingNotifier.value;
                    // Camera không chạy (tắt/đang khởi động/suspend/error):
                    // mờ và không nhận tap.
                    final cameraOn = cameraPowerState == CameraPowerState.on;
                    return Opacity(
                      opacity: cameraOn ? 1 : 0.4,
                      child: GestureDetector(
                        onTap: (cameraOn && !capturing && canUpload)
                            ? _takePhoto
                            : null,
                        child: GlassCircleButton(
                          size: 80,
                          showProgress: capturing,
                          child: capturing
                              ? null
                              : Icon(
                                  Icons.camera_alt_rounded,
                                  color: canUpload ? Colors.white : Colors.grey,
                                  size: 36,
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            ],

            if (!widget.enablePowerControl || !_cameraSleeping)
            // bottom phụ thuộc _hwZoomVisible: zoom supported (notifier) +
            // _video/_cameraSleeping (setState của cha chạy lại builder).
            ValueListenableBuilder<_HwZoomUi>(
              valueListenable: _hwZoomNotifier,
              builder: (context, _, child) => Positioned(
                left: 12,
                right: 12,
                // Không có toolbar ở dưới khi qrOnly nên banner hạ xuống sát đáy
                // (nhường chỗ cho zoom control nếu đang hiện).
                bottom: widget.qrOnly
                    ? (_hwZoomVisible ? 52 : 12)
                    : (_hwZoomVisible ? 116 : 78),
                child: child!,
              ),
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

            // Ẩn = Positioned rỗng (0 chiều cao, không nhận hit test).
            ValueListenableBuilder<_HwZoomUi>(
              valueListenable: _hwZoomNotifier,
              builder: (context, zoom, _) => Positioned(
                left: 0,
                right: 0,
                // Chế độ chụp ảnh: đặt trên nút chụp để không che nút.
                bottom: widget.qrOnly ? 10 : 72,
                child: _hwZoomVisible
                    ? Center(
                        child: _HwZoomControl(
                          zoom: zoom.zoom,
                          minZoom: zoom.min,
                          maxZoom: zoom.max,
                          onChanged: _setHardwareZoom,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),

            ValueListenableBuilder<bool>(
              valueListenable: _qrLoadingNotifier,
              builder: (context, loading, _) => Positioned(
                top: 12,
                left: 150,
                child: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

