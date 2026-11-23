import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCircleButton extends StatelessWidget {
  final double size;
  final Widget? child;
  final bool showProgress;
  final VoidCallback? onTap;

  const GlassCircleButton({
    super.key,
    required this.size,
    this.child,
    this.showProgress = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: showProgress ? null : onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            // 🌫 Outer soft shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 🧊 BACKDROP BLUR
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // 🌈 Glass gradient
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.35),
                        Colors.white.withValues(alpha: 0.10),
                      ],
                    ),
                  ),
                ),
              ),

              // ✨ INNER HIGHLIGHT
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.4, -0.4),
                    radius: 1.1,
                    colors: [
                      Colors.white.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // 🪟 GLASS BORDER
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                ),
              ),

              // 🔄 LOADING OR CONTENT
              if (showProgress)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              else
                child ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
