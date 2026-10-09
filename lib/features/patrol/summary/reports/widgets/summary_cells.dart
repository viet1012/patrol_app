import 'package:flutter/material.dart';

import 'package:chuphinh/features/patrol/summary/reports/widgets/summary_grid_style.dart';

/// Chiều cao cố định của ô (dùng chung để ô gộp / cột cố định khớp hàng).
const double kSummaryHeaderCellHeight = 34;
const double kSummaryCellHeight = 38;

class SummaryCellSpec {
  final String text;
  final double w;
  final bool bold;
  final TextAlign align;
  final Color? bg;

  /// Hiện tooltip khi text bị cắt.
  final bool tooltip;

  /// Ghi đè màu chữ (vd. "-" xám nhạt); null = màu mặc định của ô.
  final Color? textColor;

  const SummaryCellSpec(
    this.text, {
    required this.w,
    this.bold = false,
    this.align = TextAlign.center,
    this.bg,
    this.tooltip = false,
    this.textColor,
  });
}

class SummaryCellRow extends StatelessWidget {
  final List<SummaryCellSpec> cells;
  final Color? bg;
  final bool header;

  const SummaryCellRow({
    super.key,
    required this.cells,
    this.bg,
    this.header = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: cells.map((c) => _cell(c, bg: bg, header: header)).toList(),
    );
  }
}

/// Thanh tiêu đề card SUMMARY (desktop) và các section mobile: icon + chữ
/// căn giữa, nền nhạt ấm, viền dưới tách khỏi bảng.
class SummaryTitleBar extends StatelessWidget {
  static const double height = 44;

  final String text;
  final Color color;
  final IconData icon;
  final double? width;

  const SummaryTitleBar({
    super.key,
    required this.text,
    this.color = SummaryGridStyle.summaryTitleText,
    this.icon = Icons.summarize_rounded,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Tông màu ~8% phủ trên nền header sáng.
        color: Color.alphaBlend(
          color.withValues(alpha: 0.08),
          SummaryGridStyle.headerBg,
        ),
        border: Border(bottom: BorderSide(color: color, width: 2)),
      ),
      // Card hẹp (mobile): thu nhỏ thay vì cắt chữ.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              text,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryGlass extends StatelessWidget {
  final Widget child;

  const SummaryGlass({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: child,
    );
  }
}

Widget summaryGroupHeader(String title, Color color, double width) {
  return Container(
    width: width,
    alignment: Alignment.center,
    child: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: SummaryGridStyle.headerStyle.copyWith(color: color),
    ),
  );
}

/// Header: căn giữa, [SummaryGridStyle.headerStyle]. Dữ liệu: [bold] = dòng
/// SUM / % ([SummaryGridStyle.totalCellStyle]).
Widget _cell(SummaryCellSpec c, {bool header = false, Color? bg}) {
  final baseBg =
      c.bg ??
      (header
          ? (bg ?? const Color(0xFFDDDDDD))
          : (bg ?? const Color(0xFFEFEFEF)));

  final style = header
      ? SummaryGridStyle.headerStyle
      : (c.bold ? SummaryGridStyle.totalCellStyle : SummaryGridStyle.cellStyle);

  return Container(
    width: c.w,
    height: header ? kSummaryHeaderCellHeight : kSummaryCellHeight,
    alignment: header ? Alignment.center : _resolveAlignment(c),
    padding: const EdgeInsets.symmetric(
      horizontal: SummaryGridStyle.cellPaddingH,
    ),
    decoration: BoxDecoration(
      color: baseBg,
      border: Border.all(color: Colors.black12, width: 1),
    ),
    child: _cellText(
      c,
      c.textColor == null ? style : style.copyWith(color: c.textColor),
    ),
  );
}

/// Tooltip chỉ khi text bị cắt (trừ padding ngang 2 bên).
Widget _cellText(SummaryCellSpec c, TextStyle style) {
  final text = Text(c.text, overflow: TextOverflow.ellipsis, style: style);
  if (!c.tooltip || c.text.isEmpty) return text;

  final painter = TextPainter(
    text: TextSpan(text: c.text, style: style),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: c.w - SummaryGridStyle.cellPaddingH * 2);

  return painter.didExceedMaxLines
      ? Tooltip(message: c.text, child: text)
      : text;
}

Alignment _resolveAlignment(SummaryCellSpec c) {
  if (c.align == TextAlign.left) return Alignment.centerLeft;
  if (c.align == TextAlign.right) return Alignment.centerRight;

  final text = c.text.trim();

  final isNumberLike =
      text == '-' ||
      text.endsWith('%') ||
      double.tryParse(text.replaceAll(',', '')) != null;

  return isNumberLike ? Alignment.centerRight : Alignment.centerLeft;
}
