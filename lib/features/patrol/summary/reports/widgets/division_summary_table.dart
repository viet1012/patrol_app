import 'package:flutter/material.dart';

import 'package:chuphinh/shared/utils/formatters.dart';
import 'package:chuphinh/core/models/division_summary.dart';
import 'package:chuphinh/features/patrol/summary/reports/widgets/summary_cells.dart';

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
  final String title;
  final Color titleColor;

  /// Desktop dùng màu tiêu đề nhóm khác mobile (Deadline).
  final Color? desktopTitleColor;
  final Color headerColor;
  final Color bodyColor;
  final List<String> headers;
  final List<double> Function(DivisionSummary r) values;

  /// Section dạng TTL + I..V: ô TTL hiện % ở dòng '%'.
  final bool hasPctTtl;

  const SummarySection({
    required this.title,
    required this.titleColor,
    this.desktopTitleColor,
    required this.headerColor,
    required this.bodyColor,
    required this.headers,
    required this.values,
    required this.hasPctTtl,
  });

  Color get groupColorDesktop => desktopTitleColor ?? titleColor;

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
          SummaryCellSpec(headers[i], w: width(i), bold: !hasPctTtl || i == 0),
      ],
    );
  }

  Widget dataRow(DivisionSummary r, double Function(int i) width) {
    final isPct = r.isPctRow;
    final v = values(r);

    return SummaryCellRow(
      bg: r.isSumRow ? SummaryTableStyle.sumBg : (isPct ? null : bodyColor),
      cells: [
        for (var i = 0; i < v.length; i++)
          if (hasPctTtl && i == 0)
            SummaryCellSpec(
              isPct ? fmtPct(v[i]) : fmtNum(v[i]),
              w: width(i),
              bold: true,
              bg: isPct ? SummaryTableStyle.pctTtlBg : null,
            )
          else
            SummaryCellSpec(isPct ? '' : fmtNum(v[i]), w: width(i)),
      ],
    );
  }
}

const _metricHeaders = ['TTL', 'I', 'II', 'III', 'IV', 'V'];

final List<SummarySection> summarySections = [
  SummarySection(
    title: 'Before',
    titleColor: Colors.yellow,
    headerColor: SummaryTableStyle.beforeHeader,
    bodyColor: SummaryTableStyle.beforeBody,
    headers: _metricHeaders,
    hasPctTtl: true,
    values: (r) => [r.allTtl, r.allI, r.allII, r.allIII, r.allIV, r.allV],
  ),
  SummarySection(
    title: 'Finished (Pro)',
    titleColor: Colors.greenAccent,
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
    title: 'Remain',
    titleColor: Colors.redAccent,
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
    title: 'Deadline',
    titleColor: Colors.orangeAccent,
    desktopTitleColor: Colors.orange,
    headerColor: SummaryTableStyle.deadlineHeader,
    bodyColor: SummaryTableStyle.deadlineBody,
    headers: const ['Still', '3 Days', 'Late'],
    hasPctTtl: false,
    values: (r) => [r.stillTime, r.threeDaysAgo, r.late],
  ),
  SummarySection(
    title: 'Finished (HSE recheck)',
    titleColor: Colors.blueAccent,
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

/// Bảng SUMMARY theo division: desktop 1 bảng ngang, mobile mỗi section 1 bảng.
class DivisionSummaryTable extends StatelessWidget {
  final List<DivisionSummary> rows;
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
        final isMobile =
            constraints.maxWidth < SummaryTableStyle.mobileBreakpoint;

        return SummaryGlass(
          child: isMobile
              ? _MobileTables(rows: rows)
              : _DesktopTable(rows: rows, controller: controller),
        );
      },
    );
  }
}

class _DesktopTable extends StatelessWidget {
  final List<DivisionSummary> rows;
  final ScrollController controller;

  const _DesktopTable({required this.rows, required this.controller});

  @override
  Widget build(BuildContext context) {
    final width =
        SummaryTableStyle.leadWidth +
        summarySections.fold<double>(0, (sum, s) => sum + s.desktopWidth);

    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SummaryTitleBar(
                text: 'SUMMARY',
                color: SummaryTableStyle.tableTitle,
                width: width,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const SizedBox(width: SummaryTableStyle.leadWidth),
                  for (final s in summarySections)
                    summaryGroupHeader(
                      s.title,
                      s.groupColorDesktop,
                      s.desktopWidth,
                    ),
                ],
              ),
              Row(
                children: [
                  _leadHeader,
                  for (final s in summarySections)
                    s.headerRow(s.desktopCellWidth),
                ],
              ),
              const SizedBox(height: 6),
              ..._facGroupedRows(
                rows,
                (r) => [
                  for (final s in summarySections)
                    s.dataRow(r, s.desktopCellWidth),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileTables extends StatelessWidget {
  final List<DivisionSummary> rows;

  const _MobileTables({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < summarySections.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _MobileSectionTable(section: summarySections[i], rows: rows),
        ],
      ],
    );
  }
}

class _MobileSectionTable extends StatelessWidget {
  final SummarySection section;
  final List<DivisionSummary> rows;

  const _MobileSectionTable({required this.section, required this.rows});

  @override
  Widget build(BuildContext context) {
    final width = SummaryTableStyle.leadWidth + section.mobileWidth;

    return ClipRect(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SummaryTitleBar(
                text: section.title,
                color: section.titleColor,
                width: width,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const SizedBox(width: SummaryTableStyle.leadWidth),
                  summaryGroupHeader(
                    section.title,
                    section.titleColor,
                    section.mobileWidth,
                  ),
                ],
              ),
              Row(
                children: [
                  _leadHeader,
                  section.headerRow(section.mobileCellWidth),
                ],
              ),
              const SizedBox(height: 6),
              ..._facGroupedRows(
                rows,
                (r) => [section.dataRow(r, section.mobileCellWidth)],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

const _leadHeader = SummaryCellRow(
  header: true,
  cells: [
    SummaryCellSpec('Fac', w: SummaryTableStyle.wFac, align: TextAlign.left),
    SummaryCellSpec('Area', w: SummaryTableStyle.wDiv, align: TextAlign.left),
  ],
);

/// Fac chỉ hiện ở dòng đầu mỗi nhóm nhà máy liên tiếp (giả lập gộp ô),
/// kẻ phân cách nhẹ giữa 2 nhà máy. Dòng SUM / % để trống.
List<Widget> _facGroupedRows(
  List<DivisionSummary> rows,
  List<Widget> Function(DivisionSummary r) sectionRows,
) {
  final out = <Widget>[];
  String? prev;

  for (final r in rows) {
    final isTotal = r.isSumRow || r.isPctRow;
    final plant = isTotal ? '' : r.plant;
    final isFirst = plant != prev;

    final row = Row(
      children: [
        SummaryCellRow(
          cells: [
            SummaryCellSpec(
              isFirst ? plant : '',
              w: SummaryTableStyle.wFac,
              align: TextAlign.left,
              bold: true,
            ),
            SummaryCellSpec(
              r.division,
              w: SummaryTableStyle.wDiv,
              align: TextAlign.left,
              bold: isTotal,
              tooltip: true,
            ),
          ],
        ),
        ...sectionRows(r),
      ],
    );

    // Vẽ foreground để không đổi chiều cao dòng.
    out.add(
      isFirst && prev != null
          ? DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: SummaryTableStyle.facDividerColor,
                    width: SummaryTableStyle.facDividerWidth,
                  ),
                ),
              ),
              child: row,
            )
          : row,
    );
    prev = plant;
  }

  return out;
}
