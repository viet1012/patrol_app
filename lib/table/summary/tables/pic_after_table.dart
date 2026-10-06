import 'package:flutter/material.dart';

import '../../../model/pic_summary_response_dto.dart';
import '../widgets/rate_pair.dart';
import '../widgets/summary_grid_style.dart';
import '../widgets/summary_grid_table.dart';

class PicAfterTable extends StatelessWidget {
  final FacPicSummaryDto fac;

  const PicAfterTable({super.key, required this.fac});

  static const _groupHeaders = [
    SummaryGridGroupHeader(
      label: 'Finished',
      startCol: 1,
      colSpan: 6,
      backgroundColor: SummaryGridStyle.finishedHeaderBg,
      borderColor: SummaryGridStyle.finishedBorder,
    ),
    SummaryGridGroupHeader(
      label: 'Remain',
      startCol: 7,
      colSpan: 6,
      backgroundColor: SummaryGridStyle.remainHeaderBg,
      borderColor: SummaryGridStyle.remainBorder,
    ),
    SummaryGridGroupHeader(
      label: 'Deadline',
      startCol: 13,
      colSpan: 3,
      backgroundColor: SummaryGridStyle.deadlineHeaderBg,
      borderColor: SummaryGridStyle.deadlineBorder,
    ),
  ];

  static const _columnGroups = [
    ColumnGroupStyle(
      startCol: 1,
      endCol: 6,
      cellBg: SummaryGridStyle.finishedBg,
      borderColor: SummaryGridStyle.finishedBorder,
    ),
    ColumnGroupStyle(
      startCol: 7,
      endCol: 12,
      cellBg: SummaryGridStyle.remainBg,
      borderColor: SummaryGridStyle.remainBorder,
    ),
    ColumnGroupStyle(
      startCol: 13,
      endCol: 15,
      cellBg: SummaryGridStyle.deadlineBg,
      borderColor: SummaryGridStyle.deadlineBorder,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SummaryGridTable(
      titleLeft: 'AFTER TOTAL',
      titleCenter: 'Pro action (All)',
      titleRight: RatePair(
        goodLabel: 'Finished',
        goodRate: fac.finishedRate,
        badLabel: 'Remain',
        badRate: fac.remainRate,
      ),
      columns: SummaryGridStyle.afterColumns,
      groupedHeaders: _groupHeaders,
      columnGroups: _columnGroups,
      rows: [
        for (final (:row, :isTotal) in fac.displayRows)
          SummaryGridRow(
            isTotal: isTotal,
            cells: [
              row.pic,
              row.finished.total,
              row.finished.i,
              row.finished.ii,
              row.finished.iii,
              row.finished.iv,
              row.finished.v,
              row.remain.total,
              row.remain.i,
              row.remain.ii,
              row.remain.iii,
              row.remain.iv,
              row.remain.v,
              row.stillTimeTtl,
              row.threeDaysTtl,
              row.lateTtl,
            ],
          ),
      ],
    );
  }
}
