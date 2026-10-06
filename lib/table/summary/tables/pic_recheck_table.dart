import 'package:flutter/material.dart';

import '../../../model/pic_summary_response_dto.dart';
import '../widgets/rate_pair.dart';
import '../widgets/summary_grid_style.dart';
import '../widgets/summary_grid_table.dart';

class PicRecheckTable extends StatelessWidget {
  final FacPicSummaryDto fac;

  const PicRecheckTable({super.key, required this.fac});

  static const _groupHeaders = [
    SummaryGridGroupHeader(
      label: 'OK',
      startCol: 2,
      colSpan: 6,
      backgroundColor: SummaryGridStyle.okHeaderBg,
      borderColor: SummaryGridStyle.okBorder,
    ),
    SummaryGridGroupHeader(
      label: 'NG',
      startCol: 8,
      colSpan: 6,
      backgroundColor: SummaryGridStyle.ngHeaderBg,
      borderColor: SummaryGridStyle.ngBorder,
    ),
  ];

  static const _columnGroups = [
    ColumnGroupStyle(
      startCol: 2,
      endCol: 7,
      cellBg: SummaryGridStyle.okBg,
      borderColor: SummaryGridStyle.okBorder,
    ),
    ColumnGroupStyle(
      startCol: 8,
      endCol: 13,
      cellBg: SummaryGridStyle.ngBg,
      borderColor: SummaryGridStyle.ngBorder,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SummaryGridTable(
      titleCenter: 'HSE re-check (All)',
      titleRight: RatePair(
        goodLabel: 'OK',
        goodRate: fac.okRate,
        badLabel: 'NG',
        badRate: fac.ngRate,
      ),
      columns: SummaryGridStyle.recheckColumns,
      groupedHeaders: _groupHeaders,
      columnGroups: _columnGroups,
      rows: [
        for (final (:row, :isTotal) in fac.displayRows)
          SummaryGridRow(
            isTotal: isTotal,
            cells: [
              row.pic,
              row.recheckAllTotal,
              row.recheckOk.total,
              row.recheckOk.i,
              row.recheckOk.ii,
              row.recheckOk.iii,
              row.recheckOk.iv,
              row.recheckOk.v,
              row.recheckNg.total,
              row.recheckNg.i,
              row.recheckNg.ii,
              row.recheckNg.iii,
              row.recheckNg.iv,
              row.recheckNg.v,
            ],
          ),
      ],
    );
  }
}
