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
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,

            /// 🌊 Avatar blue
            color: const Color(0xFF7DF9FF), // neon cyan

            shadows: [
              /// 🌑 Deep shadow (xanh tím)
              Shadow(
                offset: const Offset(0, 4),
                blurRadius: 10,
                color: const Color(0xFF081A2F).withOpacity(0.9),
              ),

              /// ❄️ Soft top highlight (bioluminescent)
              Shadow(
                offset: const Offset(0, -2),
                blurRadius: 4,
                color: const Color(0xFFB8FFFF).withOpacity(0.6),
              ),

              /// ✨ MAIN GLOW – Pandora energy
              Shadow(
                blurRadius: _glow.value,
                color: const Color(0xFF00E5FF).withOpacity(0.8),
              ),

              /// 🔮 Secondary aura (xanh tím)
              Shadow(
                blurRadius: _glow.value * 1.4,
                color: const Color(0xFF4F8CFF).withOpacity(0.35),
              ),
            ],
          ),
        );
      },
    );
  }
}
