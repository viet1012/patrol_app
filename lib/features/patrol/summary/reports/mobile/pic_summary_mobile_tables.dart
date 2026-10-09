import 'package:flutter/material.dart';

import 'package:chuphinh/core/models/pic_summary_response_dto.dart';
import 'package:chuphinh/features/patrol/summary/reports/tables/pic_before_table.dart';
import 'package:chuphinh/features/patrol/summary/reports/widgets/rate_pair.dart';
import 'package:chuphinh/features/patrol/summary/reports/widgets/summary_grid_style.dart';
import 'package:chuphinh/features/patrol/summary/reports/widgets/summary_grid_table.dart';

/// Mobile: mỗi nhóm số liệu 1 bảng, xếp dọc.
class PicSummaryMobileTables extends StatelessWidget {
  final FacPicSummaryDto fac;
  final double tableHeight;

  const PicSummaryMobileTables({
    super.key,
    required this.fac,
    required this.tableHeight,
  });

  @override
  Widget build(BuildContext context) {
    final riskWidth = SummaryGridStyle.tableWidth(
      SummaryGridStyle.beforeColumns,
    );

    return Column(
      children: [
        _scrollable(
          width: riskWidth,
          child: PicBeforeTable(fac: fac),
        ),
        const SizedBox(height: 12),
        _scrollable(
          width: riskWidth,
          child: _PicMobileRiskTable(
            title: SummaryGridStyle.groupAfter,
            subtitle: SummaryGridStyle.subtitleAfter,
            groupLabel: 'Finished',
            rate: fac.finishedRate,
            goodRate: true,
            headerColor: SummaryGridStyle.finishedHeaderBg,
            bodyColor: SummaryGridStyle.finishedBg,
            borderColor: SummaryGridStyle.finishedBorder,
            fac: fac,
            valueOf: (row) => row.finished,
          ),
        ),
        const SizedBox(height: 12),
        _scrollable(
          width: riskWidth,
          child: _PicMobileRiskTable(
            title: SummaryGridStyle.groupAfter,
            subtitle: SummaryGridStyle.subtitleAfter,
            groupLabel: 'Remain',
            rate: fac.remainRate,
            goodRate: false,
            headerColor: SummaryGridStyle.remainHeaderBg,
            bodyColor: SummaryGridStyle.remainBg,
            borderColor: SummaryGridStyle.remainBorder,
            fac: fac,
            valueOf: (row) => row.remain,
          ),
        ),
        const SizedBox(height: 12),
        _scrollable(
          width: SummaryGridStyle.tableWidth(SummaryGridStyle.deadlineColumns),
          child: _PicMobileDeadlineTable(fac: fac),
        ),
        const SizedBox(height: 12),
        _scrollable(
          width: riskWidth,
          child: _PicMobileRiskTable(
            title: SummaryGridStyle.groupHseRecheck,
            subtitle: SummaryGridStyle.subtitleHseRecheck,
            groupLabel: 'OK',
            rate: fac.okRate,
            goodRate: true,
            headerColor: SummaryGridStyle.okHeaderBg,
            bodyColor: SummaryGridStyle.okBg,
            borderColor: SummaryGridStyle.okBorder,
            fac: fac,
            valueOf: (row) => row.recheckOk,
          ),
        ),
        const SizedBox(height: 12),
        _scrollable(
          width: riskWidth,
          child: _PicMobileRiskTable(
            title: SummaryGridStyle.groupHseRecheck,
            subtitle: SummaryGridStyle.subtitleHseRecheck,
            groupLabel: 'NG',
            rate: fac.ngRate,
            goodRate: false,
            headerColor: SummaryGridStyle.ngHeaderBg,
            bodyColor: SummaryGridStyle.ngBg,
            borderColor: SummaryGridStyle.ngBorder,
            fac: fac,
            valueOf: (row) => row.recheckNg,
          ),
        ),
      ],
    );
  }

  Widget _scrollable({required double width, required Widget child}) {
    return SizedBox(
      height: tableHeight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: width, child: child),
      ),
    );
  }
}

/// Bảng TTL + I..V của 1 nhóm (Finished / Remain / OK / NG).
class _PicMobileRiskTable extends StatelessWidget {
  final String title;
  final String subtitle;
  final String groupLabel;
  final double? rate;

  /// Màu tỉ lệ: xanh (Finished / OK) hay đỏ (Remain / NG).
  final bool goodRate;
  final Color headerColor;
  final Color bodyColor;
  final Color borderColor;
  final FacPicSummaryDto fac;
  final RiskCountDto Function(PicSummaryRowDto row) valueOf;

  const _PicMobileRiskTable({
    required this.title,
    required this.subtitle,
    required this.groupLabel,
    required this.rate,
    required this.goodRate,
    required this.headerColor,
    required this.bodyColor,
    required this.borderColor,
    required this.fac,
    required this.valueOf,
  });

  @override
  Widget build(BuildContext context) {
    return SummaryGridTable(
      titleLeft: title,
      titleCenter: subtitle,
      titleRight: RateValue(label: groupLabel, rate: rate, good: goodRate),
      columns: SummaryGridStyle.beforeColumns,
      groupedHeaders: [
        SummaryGridGroupHeader(
          label: groupLabel,
          startCol: 1,
          colSpan: 6,
          backgroundColor: headerColor,
          borderColor: borderColor,
        ),
      ],
      columnGroups: [
        ColumnGroupStyle(
          startCol: 1,
          endCol: 6,
          cellBg: bodyColor,
          borderColor: borderColor,
        ),
      ],
      rows: [
        for (final (:row, :isTotal) in fac.displayRows)
          SummaryGridRow(
            isTotal: isTotal,
            cells: [
              row.pic,
              valueOf(row).total,
              valueOf(row).i,
              valueOf(row).ii,
              valueOf(row).iii,
              valueOf(row).iv,
              valueOf(row).v,
            ],
          ),
      ],
    );
  }
}

class _PicMobileDeadlineTable extends StatelessWidget {
  final FacPicSummaryDto fac;

  const _PicMobileDeadlineTable({required this.fac});

  @override
  Widget build(BuildContext context) {
    return SummaryGridTable(
      titleLeft: SummaryGridStyle.groupAfter,
      titleCenter: 'Remain due',
      columns: SummaryGridStyle.deadlineColumns,
      groupedHeaders: const [
        SummaryGridGroupHeader(
          label: 'Deadline',
          startCol: 1,
          colSpan: 3,
          backgroundColor: SummaryGridStyle.deadlineBg,
          borderColor: SummaryGridStyle.deadlineBorder,
        ),
      ],
      rows: [
        for (final (:row, :isTotal) in fac.displayRows)
          SummaryGridRow(
            isTotal: isTotal,
            cells: [row.pic, row.stillTimeTtl, row.threeDaysTtl, row.lateTtl],
          ),
      ],
    );
  }
}
