import 'package:flutter/material.dart';

class PatrolReportHeaderFilterCell extends StatelessWidget {
  final String label;
  final double width;
  final TextAlign align;
  final bool hasFilter;
  final VoidCallback onFilterTap;
  final LayerLink layerLink;

  const PatrolReportHeaderFilterCell({
    super.key,
    required this.label,
    required this.width,
    required this.onFilterTap,
    required this.layerLink,
    this.align = TextAlign.left,
    this.hasFilter = false,
  });

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: layerLink,
      child: Container(
        width: width,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          border: Border(right: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: align,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            InkWell(
              onTap: onFilterTap,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  hasFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
                  size: 18,
                  color: hasFilter ? Colors.blue : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
