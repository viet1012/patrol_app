import 'package:flutter/material.dart';

import 'package:chuphinh/shared/utils/formatters.dart';
import 'package:chuphinh/core/models/pic_summary_response_dto.dart';
import 'package:chuphinh/features/patrol/summary/reports/tables/pic_before_table.dart';
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
            title: 'FINISHED',
            groupLabel: 'Finished',
            rate: fac.finishedRate,
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
            title: 'REMAIN',
            groupLabel: 'Remain',
            rate: fac.remainRate,
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
            title: 'OK',
            groupLabel: 'OK',
            rate: fac.okRate,
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
            title: 'NG',
            groupLabel: 'NG',
            rate: fac.ngRate,
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
  final String groupLabel;
  final double? rate;
  final Color headerColor;
  final Color bodyColor;
  final Color borderColor;
  final FacPicSummaryDto fac;
  final RiskCountDto Function(PicSummaryRowDto row) valueOf;

  const _PicMobileRiskTable({
    required this.title,
    required this.groupLabel,
    required this.rate,
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
      titleCenter: fmtRate(rate),
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
      titleLeft: 'DEADLINE',
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
