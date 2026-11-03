import 'package:flutter/material.dart';

class EmbossGlowTitle extends StatefulWidget {
  final String text;
  final double fontSize;

  /// false: glow cố định, không tạo controller (dùng khi màn cha tự animate).
  final bool animate;

  const EmbossGlowTitle({
    super.key,
    required this.text,
    this.fontSize = 26, // default size nếu không truyền
    this.animate = true,
  });

  @override
  State<EmbossGlowTitle> createState() => _EmbossGlowTitleState();
}

class _EmbossGlowTitleState extends State<EmbossGlowTitle>
    with SingleTickerProviderStateMixin {
  static const _staticGlow = 10.0;

  AnimationController? _controller;
  Animation<double>? _glow;

  @override
  void initState() {
    super.initState();
    if (!widget.animate) return;

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _controller = controller;

    _glow = Tween<double>(begin: _staticGlow, end: 28).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = _glow;
    if (glow == null) return _buildText(_staticGlow);

    return AnimatedBuilder(
      animation: glow,
      builder: (_, __) => _buildText(glow.value),
    );
  }

  Widget _buildText(double glow) {
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
          // Glow (động khi animate = true)
          Shadow(
            blurRadius: glow,
            color: Color(0xFF4F8CFF).withOpacity(0.8),
          ),
          Shadow(
            blurRadius: glow * 1.5,
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
  }
}
