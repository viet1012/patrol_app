import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';
import 'package:flutter/material.dart';

class PatrolReportHeaderFilterCell extends StatelessWidget {
  static const double height = 44;
  static const double _handleWidth = 6;

  final String label;
  final String tooltip;
  final double width;
  final TextAlign align;
  final bool hasFilter;
  final VoidCallback onFilterTap;
  final LayerLink layerLink;

  /// null = không cho resize (mobile).
  final ValueChanged<double>? onResize;
  final VoidCallback? onResizeEnd;
  final VoidCallback? onResetWidth;

  const PatrolReportHeaderFilterCell({
    super.key,
    required this.label,
    required this.width,
    required this.onFilterTap,
    required this.layerLink,
    String? tooltip,
    this.align = TextAlign.left,
    this.hasFilter = false,
    this.onResize,
    this.onResizeEnd,
    this.onResetWidth,
  }) : tooltip = tooltip ?? label;

  @override
  Widget build(BuildContext context) {
    final cell = Container(
      width: width,
      height: height,
      padding: const EdgeInsets.only(left: 6, right: 2 + _handleWidth),
      decoration: BoxDecoration(
        color: PatrolReportTokens.tableHeaderBg,
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: tooltip,
              waitDuration: const Duration(milliseconds: 400),
              child: _HeaderLabel(label: label, align: align),
            ),
          ),
          InkWell(
            onTap: onFilterTap,
            borderRadius: BorderRadius.circular(6),
            child: Tooltip(
              message: 'Filter $tooltip',
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  hasFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
                  size: 16,
                  color: hasFilter ? Colors.blue : Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final resize = onResize;

    return CompositedTransformTarget(
      link: layerLink,
      child: resize == null
          ? cell
          : Stack(
              children: [
                cell,
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: _handleWidth,
                  child: _ResizeHandle(
                    onDrag: resize,
                    onDragEnd: onResizeEnd,
                    onDoubleTap: onResetWidth,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Nhãn header: xuống tối đa 2 dòng THEO TỪ. Nếu có từ dài hơn bề rộng ô
/// (vd. cột bị kéo hẹp) thì hiện 1 dòng + "…" thay vì gãy giữa chữ.
class _HeaderLabel extends StatelessWidget {
  static const _style = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: PatrolReportTokens.fsMd,
    height: 1.15,
  );

  final String label;
  final TextAlign align;

  const _HeaderLabel({required this.label, required this.align});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final style = DefaultTextStyle.of(context).style.merge(_style);
        final scaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);

        var longest = 0.0;
        for (final word in label.split(RegExp(r'\s+'))) {
          final painter = TextPainter(
            text: TextSpan(text: word, style: style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          if (painter.width > longest) longest = painter.width;
          painter.dispose();
        }
        final wordsFit = longest <= c.maxWidth;

        return Text(
          label,
          maxLines: wordsFit ? 2 : 1,
          softWrap: wordsFit,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: _style,
        );
      },
    );
  }
}

class _ResizeHandle extends StatefulWidget {
  final ValueChanged<double> onDrag;
  final VoidCallback? onDragEnd;
  final VoidCallback? onDoubleTap;

  const _ResizeHandle({required this.onDrag, this.onDragEnd, this.onDoubleTap});

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _active = true),
      onExit: (_) => setState(() => _active = false),
      child: Tooltip(
        message: 'Drag to resize · double-click to reset',
        waitDuration: const Duration(milliseconds: 800),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
          onHorizontalDragEnd: (_) => widget.onDragEnd?.call(),
          onDoubleTap: widget.onDoubleTap,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: _active ? 3 : 1,
              color: _active
                  ? PatrolReportTokens.accentStrong
                  : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}
