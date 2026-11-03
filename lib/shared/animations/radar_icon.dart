import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Icon có nền radar (vòng tĩnh + tia quét + vòng ping + blip).
///
/// [animation] là controller dùng chung (12s / vòng), [phase] (0..1) để lệch
/// nhịp giữa các icon. Icon đứng yên, chỉ lớp nền vẽ lại theo animation.
class RadarIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Animation<double> animation;
  final double phase;

  /// Card đang mở: tia quét đậm hơn (không đổi tốc độ).
  final bool expanded;

  const RadarIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.animation,
    this.phase = 0,
    this.expanded = false,
  });

  @override
  State<RadarIcon> createState() => _RadarIconState();
}

class _RadarIconState extends State<RadarIcon> {
  // Giữ shader qua các lần rebuild của card.
  final _shaderCache = _SweepShaderCache();

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return RepaintBoundary(
      child: SizedBox(
        width: 40,
        height: 40,
        child: CustomPaint(
          painter: _RadarPainter(
            animation: reduceMotion ? null : widget.animation,
            color: widget.color,
            phase: widget.phase,
            sweepOpacity: widget.expanded ? .5 : .35,
            shaderCache: _shaderCache,
          ),
          child: Center(
            child: Icon(widget.icon, color: widget.color, size: 22),
          ),
        ),
      ),
    );
  }
}

class _SweepShaderCache {
  Shader? _shader;
  double _radius = -1;
  Color? _color;

  /// Shader quạt tâm (0, 0): trong suốt ở mép sau → màu đậm ở mép trước.
  /// Độ đậm thật lấy từ alpha của Paint nên đổi opacity không cần tạo lại.
  Shader shaderFor(double radius, Color color) {
    if (_shader == null || radius != _radius || color != _color) {
      _radius = radius;
      _color = color;
      _shader = SweepGradient(
        endAngle: _RadarPainter.sweepAngle,
        colors: [color.withOpacity(0), color],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
    }
    return _shader!;
  }
}

class _RadarPainter extends CustomPainter {
  static const sweepAngle = 70 * math.pi / 180;

  // Controller 12s: quét 3s (4 vòng), ping 2.4s (5 vòng).
  static const _sweepTurns = 4;
  static const _pingTurns = 5;

  static const _ringRadius = 18.0;
  static const _pingFrom = 12.0;
  static const _pingTo = 20.0;

  static const _blipAngle = -0.75 * math.pi;
  static const _blipDistance = 11.0;
  static const _blipRadius = 1.5;

  // 0.6s trên 3s mỗi vòng quét.
  static const _blipFade = .2;

  final Animation<double>? animation;
  final Color color;
  final double phase;
  final double sweepOpacity;
  final _SweepShaderCache shaderCache;

  final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final Paint _sweepPaint = Paint();
  final Paint _pingPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final Paint _blipPaint = Paint();

  _RadarPainter({
    required this.animation,
    required this.color,
    required this.phase,
    required this.sweepOpacity,
    required this.shaderCache,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    _ringPaint.color = color.withOpacity(.25);
    canvas.drawCircle(center, _ringRadius, _ringPaint);

    final anim = animation;
    if (anim == null) return;
    final value = anim.value;

    // Tia quét
    final rotation = ((value * _sweepTurns + phase) % 1) * 2 * math.pi;
    final radius = size.shortestSide / 2;
    _sweepPaint
      ..shader = shaderCache.shaderFor(radius, color)
      ..color = Color.fromRGBO(0, 0, 0, sweepOpacity);
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(rotation)
      ..drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        0,
        sweepAngle,
        true,
        _sweepPaint,
      )
      ..restore();

    // Vòng ping
    final ping = (value * _pingTurns + phase) % 1;
    _pingPaint.color = color.withOpacity(.5 * (1 - ping));
    canvas.drawCircle(center, lerpDouble(_pingFrom, _pingTo, ping)!, _pingPaint);

    // Blip: sáng khi mép trước tia quét đi qua, mờ dần.
    final leading = rotation + sweepAngle;
    final since = ((leading - _blipAngle) % (2 * math.pi)) / (2 * math.pi);
    if (since < _blipFade) {
      _blipPaint.color = color.withOpacity(1 - since / _blipFade);
      canvas.drawCircle(
        center + Offset.fromDirection(_blipAngle, _blipDistance),
        _blipRadius,
        _blipPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.color != color ||
        oldDelegate.phase != phase ||
        oldDelegate.sweepOpacity != sweepOpacity;
  }
}

/// Vạch quét ngang chạy lên xuống, dùng chung controller 12s (chu kỳ 2s).
class ScanLinePainter extends CustomPainter {
  static const _cycles = 6;

  final Animation<double> animation;
  final Color color;

  final Paint _linePaint = Paint()
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round;

  ScanLinePainter({required this.animation, required this.color})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final t = (animation.value * _cycles) % 1;
    final y = (t < .5 ? t * 2 : 2 - t * 2) * size.height;

    _linePaint.color = color.withOpacity(.6);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), _linePaint);
  }

  @override
  bool shouldRepaint(covariant ScanLinePainter oldDelegate) {
    return oldDelegate.animation != animation || oldDelegate.color != color;
  }
}
