import 'package:flutter/material.dart';

import 'package:chuphinh/core/models/pic_summary_response_dto.dart';
import 'package:chuphinh/features/patrol/summary/reports/widgets/summary_grid_style.dart';
import 'package:chuphinh/features/patrol/summary/reports/widgets/summary_grid_table.dart';

class PicBeforeTable extends StatelessWidget {
  final FacPicSummaryDto fac;

  const PicBeforeTable({super.key, required this.fac});

  @override
  Widget build(BuildContext context) {
    return SummaryGridTable(
      titleLeft: 'BEFORE',
      titleCenter: 'NG points',
      columns: SummaryGridStyle.beforeColumns,
      rows: [
        for (final (:row, :isTotal) in fac.displayRows)
          SummaryGridRow(
            isTotal: isTotal,
            cells: [
              row.pic,
              row.before.total,
              row.before.i,
              row.before.ii,
              row.before.iii,
              row.before.iv,
              row.before.v,
            ],
          ),
      ],
    );
  }
}
