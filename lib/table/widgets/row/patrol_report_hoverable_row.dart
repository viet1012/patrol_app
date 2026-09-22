import 'package:flutter/material.dart';

class PatrolReportHoverableRow extends StatefulWidget {
  final double height;
  final Color background;
  final Widget child;
  final VoidCallback? onDoubleTap;

  const PatrolReportHoverableRow({
    super.key,
    required this.height,
    required this.background,
    required this.child,
    this.onDoubleTap,
  });

  @override
  State<PatrolReportHoverableRow> createState() =>
      _PatrolReportHoverableRowState();
}

class _PatrolReportHoverableRowState extends State<PatrolReportHoverableRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final background = _hover
        ? Colors.blueGrey.withOpacity(0.06)
        : widget.background;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onDoubleTap: widget.onDoubleTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: widget.height,
          color: background,
          child: widget.child,
        ),
      ),
    );
  }
}
