import 'package:flutter/material.dart';

class CallToActionArrow extends StatefulWidget {
  final Color color;
  final bool active; // cho phép pause animation

  const CallToActionArrow({super.key, required this.color, this.active = true});

  @override
  State<CallToActionArrow> createState() => _CallToActionArrowState();
}

class _CallToActionArrowState extends State<CallToActionArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _offset;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200), // ⚡ nhanh, rõ CTA
    );

    _offset = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.active) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant CallToActionArrow oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 🧠 PAUSE / RESUME animation → tiết kiệm CPU
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _offset,
        builder: (_, __) {
          return Transform.translate(
            offset: Offset(_offset.value, 0),
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              color: widget.color,
              size: 26,
            ),
          );
        },
      ),
    );
  }
}
