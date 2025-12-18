import 'package:flutter/material.dart';

class EmbossGlowTitle extends StatefulWidget {
  final String text;
  const EmbossGlowTitle({super.key, required this.text});

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

    _glow = Tween<double>(
      begin: 6,
      end: 14,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Colors.white,

            // 🎯 MAGIC HERE
            shadows: [
              // ⬇️ Shadow đậm phía dưới → nổi
              Shadow(
                offset: const Offset(0, 4),
                blurRadius: 6,
                color: Colors.black.withOpacity(0.6),
              ),

              // ⬆️ Highlight phía trên → emboss
              Shadow(
                offset: const Offset(0, -2),
                blurRadius: 2,
                color: Colors.white.withOpacity(0.35),
              ),

              // ✨ Glow nhẹ (animated)
              Shadow(
                blurRadius: _glow.value,
                color: Colors.lightBlueAccent.withOpacity(0.6),
              ),
            ],
          ),
        );
      },
    );
  }
}
