import 'package:flutter/material.dart';

class AuthBottomSheetShell extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Gradient? gradient;
  final Color? color;
  final bool showHandle;
  final bool keyboardInsetInside;

  const AuthBottomSheetShell({
    super.key,
    required this.child,
    required this.padding,
    required this.borderRadius,
    this.gradient,
    this.color,
    this.showHandle = true,
    this.keyboardInsetInside = false,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final content = Container(
      padding: keyboardInsetInside
          ? padding.copyWith(bottom: padding.bottom + bottomInset)
          : padding,
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle) ...[
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 18),
          ],
          child,
        ],
      ),
    );

    if (keyboardInsetInside) return content;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: content,
    );
  }
}
