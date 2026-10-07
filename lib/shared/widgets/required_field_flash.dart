import 'package:flutter/material.dart';

/// Bọc một ô nhập liệu; gọi `key.currentState?.flash()` để nhấp nháy viền
/// một lần (0 → 1 → 0) và cuộn tới ô đó nếu đang bị khuất.
class RequiredFieldFlash extends StatefulWidget {
  final Widget child;
  final Color color;
  final double radius;

  const RequiredFieldFlash({
    super.key,
    required this.child,
    this.color = const Color(0xFF4DD0E1),
    this.radius = 14,
  });

  @override
  State<RequiredFieldFlash> createState() => RequiredFieldFlashState();
}

class RequiredFieldFlashState extends State<RequiredFieldFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _t = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 65),
  ]).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  void flash({bool scrollTo = false}) {
    if (scrollTo) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        alignment: 0.2,
      );
    }
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final v = _t.value;
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: widget.color.withValues(alpha: v),
              width: 2,
            ),
            boxShadow: v == 0
                ? null
                : [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.35 * v),
                      blurRadius: 10,
                    ),
                  ],
          ),
          child: child,
        );
      },
    );
  }
}
