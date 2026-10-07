part of '../camera_preview_box.dart';

class _QrLockPainter extends CustomPainter {
  final _QrLockData data;
  final double progress;

  const _QrLockPainter({required this.data, required this.progress});

  double _ease(double value) =>
      Curves.easeOutCubic.transform(value.clamp(0.0, 1.0).toDouble());

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = data.geometry;
    List<Offset> points;
    if (geometry != null) {
      final coverScale = math.max(
        size.width / geometry.sourceWidth,
        size.height / geometry.sourceHeight,
      );
      final dx = (size.width - geometry.sourceWidth * coverScale) / 2;
      final dy = (size.height - geometry.sourceHeight * coverScale) / 2;
      points = geometry.corners
          .map((p) => Offset(dx + p.dx * coverScale, dy + p.dy * coverScale))
          .toList(growable: false);
    } else {
      final side = size.shortestSide * .48;
      final rect = Rect.fromCenter(
        center: size.center(Offset.zero),
        width: side,
        height: side,
      );
      points = [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft];
    }

    final double scale;
    if (progress < .15) {
      scale = .92 + .08 * _ease(progress / .15);
    } else if (progress < .35) {
      scale = 1 + .06 * _ease((progress - .15) / .20);
    } else if (progress < .58) {
      scale = 1.06 - .06 * _ease((progress - .35) / .23);
    } else {
      scale = 1;
    }
    final opacity = progress < .15
        ? _ease(progress / .15)
        : progress < .75
        ? 1.0
        : 1 - _ease((progress - .75) / .25);
    if (opacity <= 0) return;

    final center = points.reduce((a, b) => a + b) / points.length.toDouble();
    final animated = points.map((p) => center + (p - center) * scale).toList();
    final color = Color.lerp(
      const Color(0xFF4DD0E1),
      const Color(0xFF4ADE80),
      progress.clamp(.20, .62).toDouble(),
    )!.withOpacity(opacity);
    final glow = Paint()
      ..color = color.withOpacity(.28 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < animated.length; i++) {
      final p = animated[i];
      final previous = animated[(i - 1 + animated.length) % animated.length];
      final next = animated[(i + 1) % animated.length];
      final towardPrevious = (previous - p) / (previous - p).distance * 18;
      final towardNext = (next - p) / (next - p).distance * 18;
      canvas.drawLine(p, p + towardPrevious, glow);
      canvas.drawLine(p, p + towardNext, glow);
      canvas.drawLine(p, p + towardPrevious, stroke);
      canvas.drawLine(p, p + towardNext, stroke);
    }

    if (data.label.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(
        text: data.label,
        style: TextStyle(
          color: Colors.white.withOpacity(opacity),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: .4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final minX = animated.map((p) => p.dx).reduce(math.min);
    final maxX = animated.map((p) => p.dx).reduce(math.max);
    final minY = animated.map((p) => p.dy).reduce(math.min);
    final maxY = animated.map((p) => p.dy).reduce(math.max);
    final pill = Size(painter.width + 18, painter.height + 9);
    final below = maxY + 9 + pill.height <= size.height - 5;
    final left = ((minX + maxX - pill.width) / 2)
        .clamp(5.0, size.width - pill.width - 5)
        .toDouble();
    final top = below ? maxY + 9 : minY - pill.height - 9;
    final rect = Rect.fromLTWH(
      left,
      top.clamp(5.0, size.height - pill.height - 5).toDouble(),
      pill.width,
      pill.height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()..color = const Color(0xDD111827).withOpacity(.86 * opacity),
    );
    painter.paint(canvas, Offset(rect.left + 9, rect.top + 4.5));
  }

  @override
  bool shouldRepaint(covariant _QrLockPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.data != data;
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

  /// true: text co theo chiều ngang được cấp, cắt "..." khi quá dài.
  final bool ellipsize;

  const _QrStatusBadge({required this.qr, this.ellipsize = false});

  @override
  Widget build(BuildContext context) {
    final value = qr?.trim() ?? '';
    final hasQr = value.isNotEmpty;
    final text = Text(
      hasQr ? value : 'Scan Patrol QR',
      maxLines: ellipsize ? 1 : null,
      overflow: ellipsize ? TextOverflow.ellipsis : null,
      style: TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: hasQr ? FontWeight.w800 : FontWeight.w600,
        letterSpacing: hasQr ? 0.8 : 0,
      ),
    );

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
          if (ellipsize) Flexible(child: text) else text,
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

/// Lớp video camera. Chỉ rebuild khi viewType/active/scale đổi (setState
/// của camera stream); overlay dùng notifier riêng nên không chạm tới lớp này.
class _CameraLayer extends StatelessWidget {
  final String viewType;
  final bool active;
  final double scale;

  /// Hiện khi camera không chạy (spinner / camera off / lỗi).
  final Widget inactive;

  const _CameraLayer({
    required this.viewType,
    required this.active,
    required this.scale,
    required this.inactive,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: active
          ? Transform.scale(
              // Zoom thật đã nằm trong frame camera: không
              // phóng UI thêm (giữ _zoom cũ cho màn hình khác).
              scale: scale,
              child: HtmlElementView(
                key: ValueKey(viewType),
                viewType: viewType,
              ),
            )
          : inactive,
    );
  }
}

class _CameraUnavailableView extends StatelessWidget {
  final CameraPowerState state;
  final bool enablePowerControl;
  final bool lifecycleSuspended;
  final VoidCallback onResume;

  const _CameraUnavailableView({
    required this.state,
    required this.enablePowerControl,
    required this.lifecycleSuspended,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    if (state == CameraPowerState.starting || state == CameraPowerState.stopping) {
      return Container(
        color: const Color(0xFF111827),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Color(0xFF4DD0E1),
          ),
        ),
      );
    }

    if (!enablePowerControl) {
      return Container(
        color: const Color(0xFF111827),
        alignment: Alignment.center,
        child: const Icon(
          Icons.videocam_off_rounded,
          color: Colors.white38,
          size: 42,
        ),
      );
    }

    final failed = state == CameraPowerState.error;
    return Container(
      color: const Color(0xFF111827),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            failed ? Icons.error_outline_rounded : Icons.videocam_off_rounded,
            color: failed ? const Color(0xFFF59E0B) : Colors.white54,
            size: 44,
          ),
          const SizedBox(height: 10),
          Text(
            failed ? 'Camera is unavailable' : 'Camera is off',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: lifecycleSuspended ? null : onResume,
            icon: Icon(
              failed ? Icons.refresh_rounded : Icons.videocam_rounded,
              size: 18,
            ),
            label: Text(failed ? 'TRY AGAIN' : 'TURN ON CAMERA'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF67E8F9),
              side: const BorderSide(color: Color(0x884DD0E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (!failed) ...[
            const SizedBox(height: 6),
            const Text(
              'Turn off the camera to save battery',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

class _CameraPowerControl extends StatelessWidget {
  final CameraPowerState state;
  final bool userCameraEnabled;
  final bool useSwitch;
  final VoidCallback onToggle;

  const _CameraPowerControl({
    required this.state,
    required this.userCameraEnabled,
    required this.useSwitch,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (useSwitch) {
      return _buildSwitch();
    }

    final transitioning =
        state == CameraPowerState.starting || state == CameraPowerState.stopping;
    final enabled = userCameraEnabled && state != CameraPowerState.error;
    final color = enabled ? const Color(0xFF4DD0E1) : Colors.white54;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: transitioning ? null : onToggle,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xDD111827),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withOpacity(.55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (transitioning)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.8),
                )
              else
                Icon(
                  enabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                  size: 16,
                  color: color,
                ),
              const SizedBox(width: 5),
              Text(
                enabled ? 'ON' : 'OFF',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitch() {
    final transitioning =
        state == CameraPowerState.starting || state == CameraPowerState.stopping;
    final enabled = userCameraEnabled && state != CameraPowerState.error;
    final activeColor = const Color(0xFF22B8C7);

    return Semantics(
      button: true,
      enabled: !transitioning,
      toggled: enabled,
      label: 'Camera power',
      value: enabled ? 'On' : 'Off',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: transitioning ? null : onToggle,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: 46,
            height: 42,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 38,
                height: 22,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: enabled ? activeColor : const Color(0xFF4B5563),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(.24)),
                  boxShadow: enabled
                      ? [
                          BoxShadow(
                            color: activeColor.withOpacity(.28),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: transitioning
                    ? const Center(
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.7,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : AnimatedAlign(
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOut,
                        alignment: enabled
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HwZoomControl extends StatelessWidget {
  final double zoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onChanged;

  const _HwZoomControl({
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final quickValues = const [1.0, 2.0, 3.0]
        .where((v) => v >= minZoom - 0.001 && v <= maxZoom + 0.001)
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xCC111827),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _zoomIconButton(
            Icons.remove_rounded,
            zoom > minZoom + 0.001
                ? () => onChanged(zoom - _HwZoomMixin._zoomButtonStep)
                : null,
          ),
          SizedBox(
            width: 42,
            child: Text(
              '${zoom.toStringAsFixed(1)}x',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _zoomIconButton(
            Icons.add_rounded,
            zoom < maxZoom - 0.001
                ? () => onChanged(zoom + _HwZoomMixin._zoomButtonStep)
                : null,
          ),
          if (quickValues.length > 1) ...[
            const SizedBox(width: 2),
            for (final value in quickValues) _zoomQuickChip(value),
          ],
        ],
      ),
    );
  }

  Widget _zoomIconButton(IconData icon, VoidCallback? onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: SizedBox(
        width: 30,
        height: 30,
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? Colors.white30 : Colors.white,
        ),
      ),
    );
  }

  Widget _zoomQuickChip(double value) {
    final selected = (zoom - value).abs() < _HwZoomMixin._zoomUpdateThreshold;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: selected ? null : () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF4DD0E1).withOpacity(.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${value.toInt()}x',
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SttBadge extends StatelessWidget {
  final int stt;
  final bool loading;

  const _SttBadge({required this.stt, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: loading
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
    );
  }
}
