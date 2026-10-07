part of '../camera_preview_box.dart';

enum _QrWarningState { hidden, reading, unreadable, error }

enum CameraPowerState { starting, on, stopping, off, error }

class QrDetectionGeometry {
  final String value;
  final List<Offset> corners;
  final double sourceWidth;
  final double sourceHeight;

  const QrDetectionGeometry({
    required this.value,
    required this.corners,
    required this.sourceWidth,
    required this.sourceHeight,
  });
}

class _QrLockData {
  final String label;
  final QrDetectionGeometry? geometry;

  const _QrLockData({required this.label, required this.geometry});
}

/// Snapshot cho UI zoom thật. Record so sánh theo giá trị nên notifier
/// chỉ báo khi có thay đổi thật.
typedef _HwZoomUi = ({bool supported, double min, double max, double zoom});

typedef _SttUi = ({int value, bool loading});

/// Chỉ dùng để phát hiện thay đổi; UI vẫn đọc trực tiếp [cameraPowerState].
typedef _PowerUi = ({
  CameraPowerState state,
  bool userEnabled,
  bool suspended,
});
