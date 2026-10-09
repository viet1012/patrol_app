import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';
import 'package:flutter/material.dart';

/// Nền dòng + hover. Hover dùng `hoverIndex` chung để phần pinned và phần
/// cuộn của cùng một dòng sáng đồng thời. `hoverIndex == null` = tắt hover.
class PatrolReportHoverableRow extends StatelessWidget {
  final int index;
  final ValueNotifier<int?>? hoverIndex;
  final double height;
  final Color background;
  final Widget child;
  final VoidCallback? onDoubleTap;

  /// Viền trái màu nhấn (vd. dòng Late). Vẽ đè, không làm lệch cột.
  final Color? leftMarker;

  const PatrolReportHoverableRow({
    super.key,
    required this.index,
    required this.height,
    required this.background,
    required this.child,
    this.hoverIndex,
    this.onDoubleTap,
    this.leftMarker,
  });

  Widget _row(bool hovered) {
    final marker = leftMarker;
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        color: hovered
            ? Color.alphaBlend(
                PatrolReportTokens.rowHover.withValues(alpha: 0.7),
                background,
              )
            : background,
        foregroundDecoration: marker == null
            ? null
            : BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: marker,
                    width: PatrolReportTokens.rowLateMarkerWidth,
                  ),
                ),
              ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hover = hoverIndex;
    if (hover == null) return _row(false);

    return MouseRegion(
      onEnter: (_) => hover.value = index,
      onExit: (_) {
        if (hover.value == index) hover.value = null;
      },
      child: ValueListenableBuilder<int?>(
        valueListenable: hover,
        builder: (_, value, _) => _row(value == index),
      ),
    );
  }
}
