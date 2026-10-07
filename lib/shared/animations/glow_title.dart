import 'package:flutter/material.dart';

class EmbossGlowTitle extends StatefulWidget {
  final String text;
  final double fontSize;
  const EmbossGlowTitle({
    super.key,
    required this.text,
    this.fontSize = 26, // default size nếu không truyền
  });

  @override
  State<EmbossGlowTitle> createState() => _EmbossGlowTitleState();
}

class _EmbossGlowTitleState extends State<EmbossGlowTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _glow = Tween<double>(begin: 10, end: 28).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) {
        return Text(
          widget.text,
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: Offset(-1, -1),
                color: Color(0xFF4F8CFF),
              ), // trên trái
              Shadow(
                offset: Offset(1, -1),
                color: Color(0xFF4F8CFF),
              ), // trên phải
              Shadow(
                offset: Offset(-1, 1),
                color: Color(0xFF4F8CFF),
              ), // dưới trái
              Shadow(
                offset: Offset(1, 1),
                color: Color(0xFF4F8CFF),
              ), // dưới phải
              // Glow động
              Shadow(
                blurRadius: _glow.value,
                color: Color(0xFF4F8CFF).withOpacity(0.8),
              ),
              Shadow(
                blurRadius: _glow.value * 1.5,
                color: Color(0xFF4F8CFF).withOpacity(0.4),
              ),

              // Bóng đổ dưới
              Shadow(
                offset: Offset(0, 3),
                blurRadius: 6,
                color: Colors.black.withOpacity(0.6),
              ),
            ],
          ),
        );
      },
    );
  }
}
