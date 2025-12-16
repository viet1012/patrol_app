import 'dart:ui';

import 'package:flutter/material.dart';

class GlassCircleButton extends StatelessWidget {
  final double size;
  final Widget? child;
  final bool showProgress;

  const GlassCircleButton({
    Key? key,
    required this.size,
    this.child,
    this.showProgress = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 🧊 GLASS BLUR
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            ),

            // ✨ SUBTLE BORDER
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.45),
                  width: 2,
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
    );
  }
}
