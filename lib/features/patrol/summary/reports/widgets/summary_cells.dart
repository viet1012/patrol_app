import 'package:flutter/material.dart';

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

class SummaryTitleBar extends StatelessWidget {
  final String text;
  final Color color;
  final double? width;

  const SummaryTitleBar({
    super.key,
    required this.text,
    required this.color,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.w900,
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
    padding: const EdgeInsets.symmetric(vertical: 10),
    alignment: Alignment.center,
    child: Text(
      title,
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16),
    ),
  );
}

Widget _cell(SummaryCellSpec c, {bool header = false, Color? bg}) {
  final textColor = header ? Colors.black : Colors.black87;

  final baseBg =
      c.bg ??
      (header
          ? (bg ?? const Color(0xFFDDDDDD))
          : (bg ?? const Color(0xFFEFEFEF)));

  return Container(
    width: c.w,
    height: header ? kSummaryHeaderCellHeight : kSummaryCellHeight,
    alignment: _resolveAlignment(c),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: baseBg,
      border: Border.all(color: Colors.black12, width: 1),
    ),
    child: _cellText(
      c,
      TextStyle(
        color: c.textColor ?? textColor,
        fontSize: 14,
        fontWeight: c.bold ? FontWeight.w800 : FontWeight.w600,
      ),
    ),
  );
}

/// Tooltip chỉ khi text bị cắt (padding ngang 8 mỗi bên).
Widget _cellText(SummaryCellSpec c, TextStyle style) {
  final text = Text(c.text, overflow: TextOverflow.ellipsis, style: style);
  if (!c.tooltip || c.text.isEmpty) return text;

  final painter = TextPainter(
    text: TextSpan(text: c.text, style: style),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: c.w - 16);

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
