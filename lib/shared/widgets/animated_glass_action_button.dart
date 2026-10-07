import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class AnimatedGlassActionButton extends StatefulWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final Color iconColor;
  final Color? backgroundColor;
  final double size;
  final EdgeInsets padding;
  final bool enabled;

  /// animation control
  final bool autoAnimate; // tự động chạy
  final Duration duration;

  const AnimatedGlassActionButton({
    super.key,
    required this.icon,
    this.onTap,
    this.iconColor = const Color(0xFFCBD5E1),
    this.backgroundColor,
    this.size = 22,
    this.padding = const EdgeInsets.all(6),
    this.enabled = true,
    this.autoAnimate = true,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<AnimatedGlassActionButton> createState() =>
      _AnimatedGlassActionButtonState();
}

class _AnimatedGlassActionButtonState extends State<AnimatedGlassActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _rotate;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(vsync: this, duration: widget.duration);

    _scale = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    _rotate = Tween<double>(
      begin: -0.06,
      end: 0.06,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    if (widget.autoAnimate && widget.enabled) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedGlassActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.enabled || !widget.autoAnimate) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color:
                widget.backgroundColor ??
                Colors.white.withOpacity(widget.enabled ? 0.08 : 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          padding: const EdgeInsets.all(8),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              return Transform.rotate(
                angle: _rotate.value,
                child: Transform.scale(
                  scale: _scale.value,
                  child: Icon(
                    widget.icon,
                    size: widget.size,
                    color: widget.enabled
                        ? widget.iconColor
                        : widget.iconColor.withOpacity(0.4),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class QrScanGlassButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool enabled;

  /// UI
  final EdgeInsets padding;
  final double radius;
  final double iconSize;
  final double innerPadding;

  final Color iconColor;
  final Color? backgroundColor;

  /// Scan line
  final Color lineColor;
  final Duration duration;

  /// Border animation
  final Color borderColor;
  final double borderWidth;

  const QrScanGlassButton({
    super.key,
    required this.onTap,
    this.enabled = true,
    this.padding = const EdgeInsets.all(6),
    this.radius = 14,
    this.iconSize = 40,
    this.innerPadding = 10,
    this.iconColor = const Color(0xFFCBD5E1),
    this.backgroundColor,
    this.lineColor = const Color(0xFF7CF8D6),
    this.duration = const Duration(milliseconds: 1400),
    this.borderColor = const Color(0xFF7CF8D6),
    this.borderWidth = 1.4,
  });

  @override
  State<QrScanGlassButton> createState() => _QrScanGlassButtonState();
}

class _QrScanGlassButtonState extends State<QrScanGlassButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);

    if (widget.enabled) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant QrScanGlassButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.enabled) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg =
        widget.backgroundColor ??
        Colors.white.withOpacity(widget.enabled ? 0.08 : 0.04);

    return Padding(
      padding: widget.padding,
      child: InkWell(
        borderRadius: BorderRadius.circular(widget.radius),
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value; // 0..1

            // border nhấp nháy + glow theo t
            final baseOpacity = widget.enabled ? 0.44 : 0.10;
            final pulse =
                (0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * math.pi * 2)));
            final borderOpacity = (baseOpacity + 0.35 * pulse).clamp(0.0, 1.0);

            return CustomPaint(
              painter: _AnimatedBorderPainter(
                t: t,
                radius: widget.radius,
                borderWidth: widget.borderWidth,
                color: widget.borderColor.withOpacity(borderOpacity),
                enabled: widget.enabled,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.radius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: EdgeInsets.all(widget.innerPadding),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(widget.radius),
                    ),
                    child: SizedBox(
                      width: widget.iconSize,
                      height: widget.iconSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 1️⃣ QR icon
                          Icon(
                            Icons.qr_code_rounded,
                            size: widget.iconSize,
                            color: widget.enabled
                                ? widget.iconColor
                                : widget.iconColor.withOpacity(0.4),
                          ),

                          // 2️⃣ Scan line chạy lên/xuống (dài hơn icon)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AnimatedBuilder(
                                animation: _ctrl,
                                builder: (_, __) {
                                  return FractionalTranslation(
                                    translation: Offset(
                                      0,
                                      -1 + 2 * _ctrl.value,
                                    ),
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: Container(
                                        width: widget.iconSize * 1.5,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              widget.enabled
                                                  ? widget.lineColor
                                                        .withOpacity(0.9)
                                                  : widget.lineColor
                                                        .withOpacity(0.35),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedBorderPainter extends CustomPainter {
  final double t; // 0..1
  final double radius;
  final double borderWidth;
  final Color color;
  final bool enabled;

  _AnimatedBorderPainter({
    required this.t,
    required this.radius,
    required this.borderWidth,
    required this.color,
    required this.enabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    // 1) border nền
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..color = color.withOpacity(enabled ? 0.35 : 0.18);
    canvas.drawRRect(rrect, basePaint);

    if (!enabled) return;

    // 2) highlight chạy quanh viền (sweep gradient)
    final sweep = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      transform: GradientRotation(math.pi * 2 * t),
      colors: [
        Colors.transparent,
        color.withOpacity(1),
        color.withOpacity(1.0), // 🔥 ĐẬM NHẤT
        color.withOpacity(1),
        Colors.transparent,
      ],
      stops: const [
        0.0,
        0.44,
        0.50, // 🎯 line rất gọn
        0.56,
        1.0,
      ],
    );

    // 👉 paint cho line chạy
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          borderWidth *
          0.9 // ✅ MẢNH HƠN
      ..shader = sweep.createShader(Offset.zero & size)
      ..strokeCap = StrokeCap
          .round // ✅ đầu line tròn → nhìn “xịn”
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        2, // ✅ blur nhỏ → đậm nét
      );

    canvas.drawRRect(rrect.deflate(borderWidth / 2), glowPaint);
  }

  @override
  bool shouldRepaint(covariant _AnimatedBorderPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.radius != radius ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.color != color ||
        oldDelegate.enabled != enabled;
  }
}
