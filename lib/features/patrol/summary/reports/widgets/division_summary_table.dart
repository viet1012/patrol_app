import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'package:chuphinh/shared/utils/formatters.dart';
import 'package:chuphinh/core/models/division_summary.dart';
import 'package:chuphinh/features/patrol/summary/reports/widgets/summary_cells.dart';
import 'package:chuphinh/features/patrol/summary/reports/widgets/summary_grid_style.dart';

class SummaryTableStyle {
  SummaryTableStyle._();

  static const double mobileBreakpoint = 700;

  // Width
  static const double wFac = 80;
  static const double wDiv = 150;
  static const double wNum = 68; // desktop: mọi ô số
  static const double wTotal = 68; // mobile: TTL
  static const double wRisk = 42; // mobile: I..V
  static const double wDeadline = 76; // mobile: Still / 3 Days / Late
  static const double leadWidth = wFac + wDiv;

  // Đường phân cách giữa 2 nhà máy: chỉ nổi hơn viền ô thường (black12) một chút.
  static const double facDividerWidth = 1.5;
  static const Color facDividerColor = Color(0x40000000); // black ~25%

  // 2 hàng header nhóm (BEFORE / AFTER / HSE RECHECK và tiêu đề section) +
  // ô góc trên cột Fac/Area: nền trắng liền khối, viền xám nhạt.
  static const Color groupHeaderBg = Colors.white;
  static const Color parentBorder = SummaryGridStyle.borderColor;

  // Chữ tiêu đề section: tông đậm để đọc rõ trên nền trắng.
  static const Color beforeTitle = Color(0xFFB45309); // amber-700
  static const Color finishedTitle = Color(0xFF15803D); // green-700
  static const Color remainTitle = Color(0xFFDC2626); // red-600
  static const Color deadlineTitle = Color(0xFFEA580C); // orange-600
  static const Color hseTitle = Color(0xFF1D4ED8); // blue-700

  // Phân cách dọc giữa 2 nhóm cha: rõ hơn viền ô thường (black12), thấy được
  // cả trên nền tối (header) lẫn nền pastel (ô dữ liệu).
  static const double parentDividerWidth = 2;
  static const Color parentDividerColor = Color(0xFF64748B);

  // Chiều cao cố định cho các hàng phía trên dữ liệu: cột Fac/Area (đứng yên)
  // và phần số (cuộn ngang) phải thẳng hàng.
  static const double parentRowHeight = 32;
  static const double groupRowHeight = 40;
  static const double headerGap = 6;

  // Thanh cuộn ngang: dày, bo tròn, tương phản trên nền tối.
  static const double scrollbarThickness = 10;
  static const double scrollbarGap = 8; // cách dòng % phía trên
  static const Color scrollbarThumb = Color(0xCCFFFFFF);
  static const Color scrollbarTrack = Color(0x26FFFFFF);
  static const Color scrollbarTrackBorder = Color(0x40FFFFFF);

  /// Khoảng trống dưới dòng cuối: chỗ cho thanh cuộn, không đè lên dòng %.
  static const double bottomGap = scrollbarGap + scrollbarThickness;

  // Card: đồng bộ với card PIC (FacPicSummaryCard / SummaryGridTable).
  static const double bodyPadding = 8;

  // Dòng SUM (bắt đầu khối SUM / %): viền trên đậm hơn phân cách nhà máy.
  static const double totalDividerWidth = 2;
  static const Color totalDividerColor = Color(0x80000000); // black ~50%

  /// Giá trị "-" (0): xám nhạt để số thật nổi bật.
  static const Color zeroText = Color(0x52000000);

  /// Hover dòng (desktop).
  static const Color hoverTint = Color(0x1A1E88E5);

  // Color
  static const Color tableTitle = Color(0xFFD8F5C7);
  static const Color sumBg = Color(0xFFDDD6FE);
  static const Color pctTtlBg = Color(0xFFBA94E1);

  static const Color beforeHeader = Color(0xFFEFE28F);
  static const Color beforeBody = Color(0xFFF1E6A7);
  static const Color proHeader = Color(0xFF8FEFA0);
  static const Color proBody = Color(0xFFBFF2C8);
  static const Color remainHeader = Color(0xFFF89292);
  static const Color remainBody = Color(0xFFFFC2C2);
  static const Color deadlineHeader = Color(0xFFFFE7A3);
  static const Color deadlineBody = Color(0xFFFFF3C4);
  static const Color hseHeader = Color(0xFF72C7F4);
  static const Color hseBody = Color(0xFFBFE0F2);
}

class SummarySection {
  /// Nhóm cha (hàng header trên cùng). Các section liên tiếp cùng [parent]
  /// được gom thành 1 ô cha.
  final String parent;
  final String title;
  final Color titleColor;
  final Color headerColor;
  final Color bodyColor;
  final List<String> headers;
  final List<double> Function(DivisionSummary r) values;

  /// Section dạng TTL + I..V: ô TTL hiện % ở dòng '%'.
  final bool hasPctTtl;

  const SummarySection({
    required this.parent,
    required this.title,
    required this.titleColor,
    required this.headerColor,
    required this.bodyColor,
    required this.headers,
    required this.values,
    required this.hasPctTtl,
  });

  /// Title trùng parent ("Before" / "BEFORE"): desktop không lặp lại ở hàng
  /// tiêu đề section (gộp ô với hàng cha).
  bool get sameAsParent => title.toUpperCase() == parent.toUpperCase();

  /// Tiêu đề bảng mobile: kèm parent ("AFTER · Remain"); chỉ parent khi trùng
  /// title ("BEFORE").
  String get mobileTitle => sameAsParent ? parent : '$parent · $title';

  double get desktopWidth => headers.length * SummaryTableStyle.wNum;

  double get mobileWidth {
    var total = 0.0;
    for (var i = 0; i < headers.length; i++) {
      total += mobileCellWidth(i);
    }
    return total;
  }

  double desktopCellWidth(int _) => SummaryTableStyle.wNum;

  double mobileCellWidth(int i) {
    if (!hasPctTtl) return SummaryTableStyle.wDeadline;
    return i == 0 ? SummaryTableStyle.wTotal : SummaryTableStyle.wRisk;
  }

  Widget headerRow(double Function(int i) width) {
    return SummaryCellRow(
      header: true,
      bg: headerColor,
      cells: [
        for (var i = 0; i < headers.length; i++)
          SummaryCellSpec(headers[i], w: width(i)),
      ],
    );
  }

  Widget dataRow(DivisionSummary r, double Function(int i) width) {
    final isPct = r.isPctRow;
    final isTotal = r.isSumRow || isPct;
    final v = values(r);

    return SummaryCellRow(
      bg: r.isSumRow ? SummaryTableStyle.sumBg : (isPct ? null : bodyColor),
      cells: [
        for (var i = 0; i < v.length; i++)
          if (hasPctTtl && i == 0)
            _valueCell(
              isPct ? fmtPct(v[i]) : fmtNum(v[i]),
              w: width(i),
              bold: isTotal,
              bg: isPct ? SummaryTableStyle.pctTtlBg : null,
            )
          else
            _valueCell(isPct ? '' : fmtNum(v[i]), w: width(i), bold: isTotal),
      ],
    );
  }
}

/// Ô số: "-" (giá trị 0) xám nhạt. [bold]: dòng SUM / %.
SummaryCellSpec _valueCell(
  String text, {
  required double w,
  bool bold = false,
  Color? bg,
}) {
  return SummaryCellSpec(
    text,
    w: w,
    bold: bold,
    bg: bg,
    textColor: text == '-' ? SummaryTableStyle.zeroText : null,
  );
}

const _metricHeaders = [SummaryGridStyle.colTotal, 'I', 'II', 'III', 'IV', 'V'];

const _parentBefore = SummaryGridStyle.groupBefore;
const _parentAfter = SummaryGridStyle.groupAfter;
const _parentHse = SummaryGridStyle.groupHseRecheck;

/// Mọi section theo thứ tự hiển thị. Desktop: 1 bảng SUMMARY (hàng cha
/// BEFORE | AFTER | HSE RECHECK). Mobile: mỗi section 1 card.
final List<SummarySection> summarySections = [
  SummarySection(
    parent: _parentBefore,
    title: 'Before',
    titleColor: SummaryTableStyle.beforeTitle,
    headerColor: SummaryTableStyle.beforeHeader,
    bodyColor: SummaryTableStyle.beforeBody,
    headers: _metricHeaders,
    hasPctTtl: true,
    values: (r) => [r.allTtl, r.allI, r.allII, r.allIII, r.allIV, r.allV],
  ),
  SummarySection(
    parent: _parentAfter,
    title: 'Finished',
    titleColor: SummaryTableStyle.finishedTitle,
    headerColor: SummaryTableStyle.proHeader,
    bodyColor: SummaryTableStyle.proBody,
    headers: _metricHeaders,
    hasPctTtl: true,
    values: (r) => [
      r.proDoneTtl,
      r.proDoneI,
      r.proDoneII,
      r.proDoneIII,
      r.proDoneIV,
      r.proDoneV,
    ],
  ),
  SummarySection(
    parent: _parentAfter,
    title: 'Remain',
    titleColor: SummaryTableStyle.remainTitle,
    headerColor: SummaryTableStyle.remainHeader,
    bodyColor: SummaryTableStyle.remainBody,
    headers: _metricHeaders,
    hasPctTtl: true,
    values: (r) => [
      r.remainTtl,
      r.remainI,
      r.remainII,
      r.remainIII,
      r.remainIV,
      r.remainV,
    ],
  ),
  SummarySection(
    parent: _parentAfter,
    title: 'Deadline',
    titleColor: SummaryTableStyle.deadlineTitle,
    headerColor: SummaryTableStyle.deadlineHeader,
    bodyColor: SummaryTableStyle.deadlineBody,
    headers: const ['Still', '3 Days', 'Late'],
    hasPctTtl: false,
    values: (r) => [r.stillTime, r.threeDaysAgo, r.late],
  ),
  SummarySection(
    parent: _parentHse,
    title: 'Finished',
    titleColor: SummaryTableStyle.hseTitle,
    headerColor: SummaryTableStyle.hseHeader,
    bodyColor: SummaryTableStyle.hseBody,
    headers: _metricHeaders,
    hasPctTtl: true,
    values: (r) => [
      r.hseDoneTtl,
      r.hseDoneI,
      r.hseDoneII,
      r.hseDoneIII,
      r.hseDoneIV,
      r.hseDoneV,
    ],
  ),
];

/// Bảng SUMMARY theo division trong card (đồng bộ card PIC).
/// Desktop: 1 card SUMMARY gồm Before | After | HSE Recheck. Mobile: mỗi
/// section 1 card.
class DivisionSummaryTable extends StatelessWidget {
  final List<DivisionSummary> rows;

  /// Scroll ngang của card SUMMARY (desktop).
  final ScrollController controller;

  const DivisionSummaryTable({
    super.key,
    required this.rows,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isMobile = maxWidth < SummaryTableStyle.mobileBreakpoint;

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < summarySections.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _SummaryTableCard(
                  title: summarySections[i].mobileTitle,
                  sections: [summarySections[i]],
                  rows: rows,
                  mobile: true,
                  maxWidth: maxWidth,
                ),
              ],
            ],
          );
        }

        return _SummaryTableCard(
          title: 'SUMMARY',
          sections: summarySections,
          rows: rows,
          showParentRow: true,
          hover: true,
          maxWidth: maxWidth,
          controller: controller,
        );
      },
    );
  }
}

/// Thông tin vẽ của 1 dòng dữ liệu, dùng chung cho cột Fac/Area và phần số.
typedef _RowDeco = ({String plant, bool isFirst, BorderSide? top});

/// [isFirst]: dòng đầu nhóm plant liên tiếp (cột Fac gộp từ dòng này).
/// [top]: phân cách nhẹ giữa 2 nhà máy; dòng SUM (đầu khối SUM / %) kẻ đậm
/// hơn. Dòng SUM / % không thuộc plant nào ([plant] rỗng).
List<_RowDeco> _rowDecos(List<DivisionSummary> rows) {
  final out = <_RowDeco>[];
  String? prev;
  var prevTotal = false;

  for (final r in rows) {
    final isTotal = r.isSumRow || r.isPctRow;
    final plant = isTotal ? '' : r.plant;
    final isFirst = plant != prev;

    BorderSide? top;
    if (prev != null && isTotal && !prevTotal) {
      top = const BorderSide(
        color: SummaryTableStyle.totalDividerColor,
        width: SummaryTableStyle.totalDividerWidth,
      );
    } else if (prev != null && isFirst) {
      top = const BorderSide(
        color: SummaryTableStyle.facDividerColor,
        width: SummaryTableStyle.facDividerWidth,
      );
    }

    out.add((plant: plant, isFirst: isFirst, top: top));
    prev = plant;
    prevTotal = isTotal;
  }

  return out;
}

/// 1 card bảng: header (tiêu đề + chỉ số), cột Fac/Area cố định, phần số cuộn
/// ngang. Desktop và mobile dùng chung; [mobile] chỉ đổi độ rộng ô / màu
/// tiêu đề nhóm.
class _SummaryTableCard extends StatefulWidget {
  final String title;
  final List<SummarySection> sections;
  final List<DivisionSummary> rows;
  final bool mobile;

  /// Hàng cha gom section cùng parent (Before | After).
  final bool showParentRow;

  /// Hover dòng (desktop).
  final bool hover;

  /// Card co theo bảng nhưng không vượt quá chỗ có.
  final double maxWidth;

  /// null: scroll view tự tạo controller riêng, không có Scrollbar.
  final ScrollController? controller;

  const _SummaryTableCard({
    required this.title,
    required this.sections,
    required this.rows,
    required this.maxWidth,
    this.mobile = false,
    this.showParentRow = false,
    this.hover = false,
    this.controller,
  });

  @override
  State<_SummaryTableCard> createState() => _SummaryTableCardState();
}

class _SummaryTableCardState extends State<_SummaryTableCard> {
  /// Index dòng đang hover; cột cố định và phần số cùng lắng nghe.
  final ValueNotifier<int?> _hovered = ValueNotifier<int?>(null);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  double _cellWidth(SummarySection s, int i) =>
      widget.mobile ? s.mobileCellWidth(i) : s.desktopCellWidth(i);

  double _sectionWidth(SummarySection s) =>
      widget.mobile ? s.mobileWidth : s.desktopWidth;

  @override
  Widget build(BuildContext context) {
    final sections = widget.sections;
    final rows = widget.rows;
    final decos = _rowDecos(rows);
    final numbersWidth = sections.fold<double>(
      0,
      (sum, s) => sum + _sectionWidth(s),
    );

    // Card vừa khít bảng (không chừa khoảng trống), tối đa bằng chỗ có.
    const chrome = SummaryTableStyle.bodyPadding * 2 + 2; // padding + viền
    final cardWidth = math.min(
      SummaryTableStyle.leadWidth + numbersWidth + chrome,
      widget.maxWidth,
    );

    return SizedBox(
      width: cardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(SummaryGridStyle.borderRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          // Trừ viền 1px để nội dung nằm trong góc bo.
          borderRadius: BorderRadius.circular(
            SummaryGridStyle.borderRadius - 1,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SummaryTitleBar(text: widget.title),
              Padding(
                padding: const EdgeInsets.all(SummaryTableStyle.bodyPadding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLead(rows, decos),
                    Expanded(child: _buildNumbers(rows, decos, numbersWidth)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Cột Fac/Area: đứng yên khi phần số cuộn ngang.
  /// Các dòng liên tiếp cùng plant: 1 ô Fac gộp cao bằng tổng các dòng.
  /// Dòng SUM / %: Fac + Area gộp 1 ô ghi "SUM" / "%".
  Widget _buildLead(List<DivisionSummary> rows, List<_RowDeco> decos) {
    final children = <Widget>[];
    var i = 0;
    while (i < rows.length) {
      final r = rows[i];
      if (r.isSumRow || r.isPctRow) {
        children.add(
          _row(
            i,
            decos[i],
            SummaryCellRow(
              cells: [
                SummaryCellSpec(
                  r.division,
                  w: SummaryTableStyle.leadWidth,
                  align: TextAlign.left,
                  bold: true,
                ),
              ],
            ),
          ),
        );
        i++;
        continue;
      }

      // Nhóm plant: từ dòng isFirst tới trước dòng isFirst kế tiếp / SUM.
      final start = i;
      i++;
      while (i < rows.length &&
          !rows[i].isSumRow &&
          !rows[i].isPctRow &&
          !decos[i].isFirst) {
        i++;
      }

      final block = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MergedFacCell(text: decos[start].plant, rowCount: i - start),
          Column(
            children: [
              for (var k = start; k < i; k++)
                _row(
                  k,
                  // Phân cách nằm ở cả khối (ô gộp + Area), không ở từng dòng.
                  (plant: decos[k].plant, isFirst: decos[k].isFirst, top: null),
                  SummaryCellRow(
                    cells: [
                      SummaryCellSpec(
                        rows[k].division,
                        w: SummaryTableStyle.wDiv,
                        align: TextAlign.left,
                        tooltip: true,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      );

      final top = decos[start].top;
      children.add(
        DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: top == null ? null : Border(top: top),
          ),
          child: block,
        ),
      );
    }

    return SizedBox(
      width: SummaryTableStyle.leadWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ô góc trên Fac/Area: liền khối với 2 hàng header nhóm.
          SizedBox(
            height:
                (widget.showParentRow ? SummaryTableStyle.parentRowHeight : 0) +
                SummaryTableStyle.groupRowHeight,
            width: double.infinity,
            child: const ColoredBox(color: SummaryTableStyle.groupHeaderBg),
          ),
          _leadHeader,
          const SizedBox(height: SummaryTableStyle.headerGap),
          ...children,
          const SizedBox(height: SummaryTableStyle.bottomGap),
        ],
      ),
    );
  }

  /// Phần số: hàng cha / tiêu đề nhóm / header cột / dữ liệu, cuộn ngang.
  Widget _buildNumbers(
    List<DivisionSummary> rows,
    List<_RowDeco> decos,
    double numbersWidth,
  ) {
    final sections = widget.sections;
    final groups = widget.showParentRow
        ? _parentGroups(sections, _sectionWidth)
        : const <_ParentGroup>[];

    // Vị trí x (trong phần số) của phân cách giữa 2 nhóm cha.
    final dividerXs = <double>[];
    var x = 0.0;
    for (var g = 0; g < groups.length - 1; g++) {
      x += groups[g].width;
      dividerXs.add(x);
    }

    final content = SizedBox(
      width: numbersWidth,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showParentRow)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final g in groups) _parentGroupHeader(g)],
                )
              else
                Row(children: [for (final s in sections) _sectionTitle(s)]),
              Row(
                children: [
                  for (final s in sections)
                    s.headerRow((i) => _cellWidth(s, i)),
                ],
              ),
              const SizedBox(height: SummaryTableStyle.headerGap),
              for (var i = 0; i < rows.length; i++)
                _row(
                  i,
                  decos[i],
                  Row(
                    children: [
                      for (final s in sections)
                        s.dataRow(rows[i], (c) => _cellWidth(s, c)),
                    ],
                  ),
                ),
              const SizedBox(height: SummaryTableStyle.bottomGap),
            ],
          ),
          for (final dx in dividerXs)
            Positioned(
              left: dx - SummaryTableStyle.parentDividerWidth / 2,
              top: 0,
              bottom: SummaryTableStyle.bottomGap,
              width: SummaryTableStyle.parentDividerWidth,
              child: const IgnorePointer(
                child: ColoredBox(color: SummaryTableStyle.parentDividerColor),
              ),
            ),
        ],
      ),
    );

    final ctrl = widget.controller;
    // Kéo bằng chuột / trackpad (web mặc định không kéo bằng chuột).
    // Shift + wheel: Scrollable tự đảo trục (pointerAxisModifiers).
    final scroll = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        // Thanh cuộn do _TableScrollbar vẽ; tắt scrollbar tự động.
        scrollbars: false,
        dragDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      child: SingleChildScrollView(
        controller: ctrl,
        scrollDirection: Axis.horizontal,
        child: content,
      ),
    );
    if (ctrl == null) return scroll;
    return _TableScrollbar(controller: ctrl, child: scroll);
  }

  /// Ô tiêu đề section (hàng header dưới).
  Widget _sectionTitle(SummarySection s) {
    return Container(
      height: SummaryTableStyle.groupRowHeight,
      color: SummaryTableStyle.groupHeaderBg,
      child: summaryGroupHeader(s.title, s.titleColor, _sectionWidth(s)),
    );
  }

  /// Nhóm cha + tiêu đề các section bên dưới. Nhóm chỉ có 1 section trùng tên
  /// (BEFORE): gộp 1 ô cao 2 hàng, không lặp lại "Before".
  Widget _parentGroupHeader(_ParentGroup g) {
    final merged = g.sections.length == 1 && g.sections.first.sameAsParent;
    if (merged) {
      return _parentHeader(
        g.parent,
        g.width,
        height:
            SummaryTableStyle.parentRowHeight +
            SummaryTableStyle.groupRowHeight,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _parentHeader(g.parent, g.width),
        Row(children: [for (final s in g.sections) _sectionTitle(s)]),
      ],
    );
  }

  /// Phân cách trên (nhà máy / SUM) + hover. Cấu trúc cây cố định để hover
  /// không mount lại ô.
  Widget _row(int index, _RowDeco deco, Widget child) {
    final top = deco.top;
    Widget row = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(border: top == null ? null : Border(top: top)),
      child: child,
    );

    if (!widget.hover) return row;

    row = ValueListenableBuilder<int?>(
      valueListenable: _hovered,
      child: row,
      builder: (context, hovered, child) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          color: hovered == index ? SummaryTableStyle.hoverTint : null,
        ),
        child: child,
      ),
    );

    return MouseRegion(
      onEnter: (_) => _hovered.value = index,
      onExit: (_) {
        if (_hovered.value == index) _hovered.value = null;
      },
      child: row,
    );
  }
}

/// Ô Fac gộp cho [rowCount] dòng liên tiếp cùng plant: cao đúng bằng tổng
/// chiều cao các dòng, chữ căn giữa theo chiều dọc. Style như ô thường.
class _MergedFacCell extends StatelessWidget {
  final String text;
  final int rowCount;

  const _MergedFacCell({required this.text, required this.rowCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: SummaryTableStyle.wFac,
      height: kSummaryCellHeight * rowCount,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(
        horizontal: SummaryGridStyle.cellPaddingH,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        border: Border.all(color: Colors.black12, width: 1),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        maxLines: rowCount,
        style: SummaryGridStyle.cellStyle,
      ),
    );
  }
}

/// Thanh cuộn ngang của bảng: dày, bo tròn, luôn hiện track + thumb, kéo
/// được. Click vào track: nhảy tới đúng vị trí đó (mặc định chỉ cuộn 1 trang).
class _TableScrollbar extends RawScrollbar {
  const _TableScrollbar({
    required ScrollController super.controller,
    required super.child,
  }) : super(
         thumbVisibility: true,
         trackVisibility: true,
         interactive: true,
         thickness: SummaryTableStyle.scrollbarThickness,
         radius: const Radius.circular(
           SummaryTableStyle.scrollbarThickness / 2,
         ),
         trackRadius: const Radius.circular(
           SummaryTableStyle.scrollbarThickness / 2,
         ),
         thumbColor: SummaryTableStyle.scrollbarThumb,
         trackColor: SummaryTableStyle.scrollbarTrack,
         trackBorderColor: SummaryTableStyle.scrollbarTrackBorder,
         crossAxisMargin: 0,
         mainAxisMargin: 0,
         // Chỉ scroll ngang của bảng (không ăn notification của dialog).
         notificationPredicate: _horizontalOnly,
       );

  static bool _horizontalOnly(ScrollNotification n) =>
      n.metrics.axis == Axis.horizontal;

  @override
  RawScrollbarState<_TableScrollbar> createState() => _TableScrollbarState();
}

class _TableScrollbarState extends RawScrollbarState<_TableScrollbar> {
  @override
  void handleTrackTapDown(TapDownDetails details) {
    final controller = widget.controller;
    final box = context.findRenderObject();
    if (controller == null || !controller.hasClients || box is! RenderBox) {
      super.handleTrackTapDown(details);
      return;
    }

    final position = controller.position;
    final trackLength = box.size.width;
    final viewport = position.viewportDimension;
    final content = position.maxScrollExtent + viewport;
    if (trackLength <= 0 || content <= 0 || position.maxScrollExtent <= 0) {
      return;
    }

    // Đặt tâm thumb tại điểm click.
    final thumbLength = trackLength * viewport / content;
    final fraction =
        ((details.localPosition.dx - thumbLength / 2) /
                (trackLength - thumbLength))
            .clamp(0.0, 1.0);
    position.jumpTo(
      position.minScrollExtent + fraction * position.maxScrollExtent,
    );
  }
}

typedef _ParentGroup = ({
  String parent,
  double width,
  List<SummarySection> sections,
});

/// Gom các section liên tiếp cùng parent: (parent, tổng width, sections).
List<_ParentGroup> _parentGroups(
  List<SummarySection> sections,
  double Function(SummarySection s) width,
) {
  final groups = <_ParentGroup>[];
  for (final s in sections) {
    if (groups.isNotEmpty && groups.last.parent == s.parent) {
      final last = groups.removeLast();
      groups.add((
        parent: last.parent,
        width: last.width + width(s),
        sections: [...last.sections, s],
      ));
    } else {
      groups.add((parent: s.parent, width: width(s), sections: [s]));
    }
  }
  return groups;
}

Widget _parentHeader(
  String text,
  double width, {
  double height = SummaryTableStyle.parentRowHeight,
}) {
  return Container(
    width: width,
    height: height,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: SummaryTableStyle.groupHeaderBg,
      border: Border(
        bottom: BorderSide(color: SummaryTableStyle.parentBorder, width: 1.5),
      ),
    ),
    child: Text(text, style: SummaryGridStyle.titleStyle),
  );
}

const _leadHeader = SummaryCellRow(
  header: true,
  cells: [
    SummaryCellSpec('Fac', w: SummaryTableStyle.wFac, align: TextAlign.left),
    SummaryCellSpec('Area', w: SummaryTableStyle.wDiv, align: TextAlign.left),
  ],
);
