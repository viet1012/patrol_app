import 'package:flutter/material.dart';

class GlassActionButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final Color iconColor;
  final Color? backgroundColor;
  final double size;
  final EdgeInsets padding;
  final bool enabled;

  const GlassActionButton({
    super.key,
    required this.icon,
    this.onTap,
    this.iconColor = const Color(0xFFCBD5E1),
    this.backgroundColor,
    this.size = 22,
    this.padding = const EdgeInsets.all(6),
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color:
                backgroundColor ??
                Colors.white.withOpacity(enabled ? 0.08 : 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: size,
            color: enabled ? iconColor : iconColor.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}
