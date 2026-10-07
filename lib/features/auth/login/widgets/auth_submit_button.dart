import 'package:flutter/material.dart';

class AuthSubmitButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;
  final double borderRadius;
  final double? height;
  final double elevation;
  final FontWeight fontWeight;
  final Color textColor;
  final double loadingStrokeWidth;

  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.borderRadius = 14,
    this.height,
    this.elevation = 0,
    this.fontWeight = FontWeight.w700,
    this.textColor = Colors.white70,
    this.loadingStrokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        disabledBackgroundColor: const Color(0xFF2563EB).withOpacity(.45),
        foregroundColor: Colors.white,
        elevation: elevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: isLoading
            ? SizedBox(
                key: ValueKey('auth-loading'),
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: loadingStrokeWidth,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                key: const ValueKey('auth-label'),
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                  fontWeight: fontWeight,
                ),
              ),
      ),
    );

    return SizedBox(width: double.infinity, height: height, child: button);
  }
}
