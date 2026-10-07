import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

class ChristmasTitle extends StatefulWidget {
  const ChristmasTitle({super.key});

  @override
  State<ChristmasTitle> createState() => _ChristmasTitleState();
}

class _ChristmasTitleState extends State<ChristmasTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Snowflake> _flakes;

  @override
  void initState() {
    super.initState();
    _flakes = List.generate(30, (index) => Snowflake.random());
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..addListener(() {
            setState(() {
              _flakes.forEach((flake) => flake.fall());
            });
          })
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Title Glass container
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 32,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.park,
                      color: Colors.greenAccent,
                      size: 32,
                    ), // cây thông Noel bên trái
                    const SizedBox(width: 12),
                    Flexible(
                      child: GradientText(
                        'SAFETY CROSS PATROL',
                        gradient: LinearGradient(
                          colors: [Colors.red.shade400, Colors.green.shade400],
                        ),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.park,
                      color: Colors.greenAccent,
                      size: 32,
                    ), // cây thông Noel bên phải
                  ],
                ),
              ),
            ),
          ),
        ),

        // Snowfall effect
        Positioned.fill(child: CustomPaint(painter: SnowPainter(_flakes))),
      ],
    );
  }
}

// Gradient text widget
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;

  const GradientText(
    this.text, {
    required this.gradient,
    required this.style,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

// Snowflake model
class Snowflake {
  double x;
  double y;
  double radius;
  double speed;

  Snowflake(this.x, this.y, this.radius, this.speed);

  factory Snowflake.random() {
    final random = Random();
    return Snowflake(
      random.nextDouble(), // x normalized 0-1
      random.nextDouble(), // y normalized 0-1
      1 + random.nextDouble() * 3, // radius 1-4
      0.002 + random.nextDouble() * 0.006, // speed
    );
  }

  void fall() {
    y += speed;
    if (y > 1) y = 0;
  }
}

// SnowPainter vẽ tuyết rơi
class SnowPainter extends CustomPainter {
  final List<Snowflake> flakes;
  SnowPainter(this.flakes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.7);

    for (var flake in flakes) {
      final offset = Offset(flake.x * size.width, flake.y * size.height);
      canvas.drawCircle(offset, flake.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SnowPainter oldDelegate) => true;
}
