part of '../camera_preview_box.dart';

/// Bật/tắt camera theo người dùng + visibility (enablePowerControl).
mixin _PowerMixin on State<CameraPreviewBox>, _CameraStreamMixin {
  bool _powerReconciling = false;
  StreamSubscription<html.Event>? _visibilitySub;

  /// Báo cho power control / màn hình camera-off khi trạng thái nguồn đổi.
  /// Được đồng bộ sau mỗi setState (xem CameraPreviewBoxState.setState), nên
  /// cập nhật đúng các thời điểm UI cũ được rebuild.
  final ValueNotifier<_PowerUi> _powerStateNotifier = ValueNotifier<_PowerUi>(
    (state: CameraPowerState.off, userEnabled: true, suspended: false),
  );

  void _syncPowerState() {
    if (!mounted) return;
    _powerStateNotifier.value = (
      state: cameraPowerState,
      userEnabled: _userCameraEnabled,
      suspended: _lifecycleSuspended,
    );
  }

  CameraPowerState get cameraPowerState {
    if (_cameraStarting) return CameraPowerState.starting;
    if (_cameraStopping) return CameraPowerState.stopping;
    if (_cameraStartFailed &&
        _userCameraEnabled &&
        !_lifecycleSuspended &&
        !_routeSuspended) {
      return CameraPowerState.error;
    }
    if (!_cameraSleeping && _stream != null && _video != null) {
      return CameraPowerState.on;
    }
    return CameraPowerState.off;
  }

  // =========================
  // Lựa chọn bật/tắt của user, dùng chung giữa các màn (chỉ trong phiên chạy)
  // =========================

  /// Chỉ instance có enablePowerControl mới đọc/ghi. Không lưu storage.
  static final ValueNotifier<bool> _sharedUserCameraEnabled =
      ValueNotifier<bool>(true);

  void _bindSharedUserCameraEnabled() {
    if (!widget.enablePowerControl) return;
    _userCameraEnabled = _sharedUserCameraEnabled.value;
    _sharedUserCameraEnabled.addListener(_onSharedUserCameraEnabledChanged);
  }

  void _unbindSharedUserCameraEnabled() {
    if (!widget.enablePowerControl) return;
    _sharedUserCameraEnabled.removeListener(_onSharedUserCameraEnabledChanged);
  }

  void _onSharedUserCameraEnabledChanged() {
    if (!mounted) return;
    final enabled = _sharedUserCameraEnabled.value;
    if (enabled == _userCameraEnabled) return;
    // Route đang suspended: chỉ đổi cờ; _cameraShouldRun chặn start cho tới
    // khi route active lại.
    _applySharedUserCameraEnabled(enabled);
  }

  // =========================
  // Suspend theo route (bị page che / đang pop)
  // =========================
  ModalRoute<dynamic>? _route;

  void _bindRouteObserver() {
    CameraPreviewRouteObserver.instance._revision.addListener(
      _onRouteMaybeChanged,
    );
  }

  void _unbindRouteObserver() {
    CameraPreviewRouteObserver.instance._revision.removeListener(
      _onRouteMaybeChanged,
    );
  }

  /// Gọi từ didChangeDependencies (isCurrent/route đổi).
  void _updateRoute(ModalRoute<dynamic>? route) {
    _route = route;
    _onRouteMaybeChanged();
  }

  bool _computeRouteSuspended() {
    final route = _route;
    if (route == null) return false;
    // Đang pop / đã bị remove khỏi navigator.
    if (!route.isActive) return true;
    // Popup route (dialog, dropdown...) không tính là che.
    return CameraPreviewRouteObserver.instance._isCoveredByPage(route);
  }

  /// Chỉ đọc và lên lịch (có thể đang trong build / navigator flush).
  /// Dừng: microtask (ngay). Chạy lại: Timer 0, tức là sau khi các instance
  /// khác đã dừng xong trong các microtask, để không có 2 stream cùng lúc.
  void _onRouteMaybeChanged() {
    if (!mounted) return;
    final suspended = _computeRouteSuspended();
    if (suspended == _routeSuspended) return;
    if (suspended) {
      scheduleMicrotask(_applyRouteSuspended);
    } else {
      Timer.run(_applyRouteSuspended);
    }
  }

  void _applyRouteSuspended() {
    if (!mounted) return;
    final suspended = _computeRouteSuspended();
    if (suspended == _routeSuspended) return;
    // Giống listener visibility: không đổi _userCameraEnabled / state dùng chung.
    _routeSuspended = suspended;
    if (suspended) _invalidateActiveCameraSession();
    _reconcileCameraPower();
  }

  /// Giống suspendCamera/resumeCamera nhưng không ghi lại state dùng chung.
  void _applySharedUserCameraEnabled(bool enabled) {
    _userCameraEnabled = enabled;
    _cameraStartFailed = false;
    if (!enabled) _invalidateActiveCameraSession();
    if (mounted) setState(() {});
    _reconcileCameraPower();
  }

  Future<void> suspendCamera() async {
    if (!widget.enablePowerControl) {
      await sleepCamera();
      return;
    }
    _userCameraEnabled = false;
    _sharedUserCameraEnabled.value = false;
    _cameraStartFailed = false;
    _invalidateActiveCameraSession();
    if (mounted) setState(() {});
    await _reconcileCameraPower();
  }

  Future<bool> resumeCamera() async {
    if (!widget.enablePowerControl) return wakeCamera();
    _userCameraEnabled = true;
    _sharedUserCameraEnabled.value = true;
    _cameraStartFailed = false;
    if (mounted) setState(() {});
    await _reconcileCameraPower();
    return cameraPowerState == CameraPowerState.on;
  }

  Future<void> _toggleCameraPower() async {
    if (_userCameraEnabled) {
      await suspendCamera();
    } else {
      await resumeCamera();
    }
  }

  Future<void> _reconcileCameraPower() async {
    if (_powerReconciling || !mounted) return;
    _powerReconciling = true;
    try {
      while (mounted) {
        if (_cameraShouldRun) {
          if (!_cameraSleeping && _stream != null && _video != null) break;
          if (_cameraStarting || _cameraStopping) {
            await Future.delayed(const Duration(milliseconds: 25));
            continue;
          }
          await wakeCamera();
          if (_cameraStartFailed) break;
        } else {
          if (_cameraStarting) _invalidateActiveCameraSession();
          if (_cameraStopping) {
            await Future.delayed(const Duration(milliseconds: 25));
            continue;
          }
          if (_stream == null && _video == null && !_cameraStarting) {
            _setCameraSleeping(true);
            if (mounted) setState(() {});
            break;
          }
          await sleepCamera();
        }

        final settledOn = !_cameraSleeping && _stream != null && _video != null;
        final settledOff = _cameraSleeping && _stream == null && _video == null;
        if ((_cameraShouldRun && settledOn) ||
            (!_cameraShouldRun && settledOff)) {
          break;
        }
      }
    } finally {
      _powerReconciling = false;
      if (mounted) setState(() {});
      final settledOn = !_cameraSleeping && _stream != null && _video != null;
      final settledOff = _cameraSleeping && _stream == null && _video == null;
      if (mounted &&
          ((_cameraShouldRun && !settledOn && !_cameraStartFailed) ||
              (!_cameraShouldRun && !settledOff))) {
        _reconcileCameraPower();
      }
    }
  }
}
