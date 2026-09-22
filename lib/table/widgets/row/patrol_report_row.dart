import 'package:chuphinh/common/common_ui_helper.dart';
import 'package:chuphinh/model/patrol_report_model.dart';
import 'package:flutter/material.dart';

import '../../core/patrol_report_table_columns.dart';
import '../../core/patrol_report_table_query.dart';
import '../cells/patrol_report_cells.dart';
import 'patrol_report_hoverable_row.dart';

class PatrolReportRow extends StatelessWidget {
  final PatrolReportModel report;
  final int pageIndex;
  final bool selected;
  final List<PatrolReportColumnSpec> columns;
  final VoidCallback onEdit;
  final VoidCallback onShowBeforeImages;
  final VoidCallback onShowAfterImages;
  final VoidCallback onShowHseImages;

  const PatrolReportRow({
    super.key,
    required this.report,
    required this.pageIndex,
    required this.selected,
    required this.columns,
    required this.onEdit,
    required this.onShowBeforeImages,
    required this.onShowAfterImages,
    required this.onShowHseImages,
  });

  double _width(String label) => PatrolReportTableQuery.widthOf(columns, label);

  @override
  Widget build(BuildContext context) {
    final baseColor = pageIndex.isEven ? Colors.white : Colors.grey.shade50;
    return PatrolReportHoverableRow(
      height: 100,
      background: selected ? Colors.lightBlue.shade50 : baseColor,
      onDoubleTap: onEdit,
      child: Row(
        children: [
          PatrolReportCells.text(
            report.stt.toString(),
            _width('STT'),
            align: TextAlign.center,
          ),
          PatrolReportCells.qr(report.qr_key?.toString(), _width('QR')),
          PatrolReportCells.text(report.grp, _width('Group'), tooltip: true),
          PatrolReportCells.text(report.plant, _width('Plant'), tooltip: true),
          PatrolReportCells.text(
            report.division,
            _width('Division'),
            tooltip: true,
          ),
          PatrolReportCells.text(report.area, _width('Area'), tooltip: true),
          PatrolReportCells.text(
            report.machine,
            _width('Machine'),
            tooltip: true,
          ),
          PatrolReportCells.text(
            report.patrol_user ?? '-',
            _width('Patrol User'),
            tooltip: true,
          ),
          PatrolReportCells.image(
            names: report.imageNames,
            width: _width('Img(B)'),
            onTap: onShowBeforeImages,
          ),
          PatrolReportCells.riskBadge(report.riskTotal, _width('Risk T')),
          PatrolReportCells.text(
            report.comment,
            _width('Comment'),
            tooltip: true,
          ),
          PatrolReportCells.text(
            report.countermeasure,
            _width('Countermeasure'),
            tooltip: true,
          ),
          PatrolReportCells.text(
            CommonUI.fmtDate(report.createdAt),
            _width('Created'),
            align: TextAlign.center,
          ),
          PatrolReportCells.text(
            CommonUI.fmtDate(report.dueDate),
            _width('Deadline'),
            align: TextAlign.center,
          ),
          PatrolReportCells.text(
            CommonUI.fmtDate(report.dueDateUpdatedAt),
            _width('Revise Deadline'),
            align: TextAlign.center,
          ),
          PatrolReportCells.dueRevision(
            report.dueDateUpdateCount ?? 0,
            _width('Due Rev'),
          ),
          PatrolReportCells.text(
            report.dueDateUpdatedBy ?? '-',
            _width('Due By'),
            tooltip: true,
          ),
          PatrolReportCells.dueStatus(report, _width('Due Status')),
          PatrolReportCells.text(
            report.pic ?? '-',
            _width('PIC'),
            tooltip: true,
          ),
          PatrolReportCells.text(
            report.checkInfo,
            _width('Check Info'),
            tooltip: true,
          ),
          PatrolReportCells.text(
            report.riskFreq,
            _width('Risk F'),
            align: TextAlign.center,
          ),
          PatrolReportCells.text(
            report.riskProb,
            _width('Risk P'),
            align: TextAlign.center,
          ),
          PatrolReportCells.text(
            report.riskSev,
            _width('Risk S'),
            align: TextAlign.center,
          ),
          PatrolReportCells.statusBadge(report.atStatus, _width('AT Stt')),
          PatrolReportCells.text(
            report.atPic ?? '-',
            _width('AT PIC'),
            tooltip: true,
          ),
          PatrolReportCells.text(
            CommonUI.fmtDate(report.atDate),
            _width('AT Date'),
            align: TextAlign.center,
          ),
          PatrolReportCells.text(
            report.atComment ?? '-',
            _width('AT Cmt'),
            tooltip: true,
          ),
          PatrolReportCells.image(
            names: report.atImageNames,
            width: _width('Img(A)'),
            onTap: onShowAfterImages,
          ),
          PatrolReportCells.text(
            report.hseUser ?? '-',
            _width('HSE User'),
            tooltip: true,
          ),
          PatrolReportCells.text(
            report.hseJudge ?? '-',
            _width('HSE Judge'),
            align: TextAlign.center,
          ),
          PatrolReportCells.text(
            CommonUI.fmtDate(report.hseDate),
            _width('HSE Updated'),
            align: TextAlign.center,
          ),
          PatrolReportCells.text(
            report.hseComment ?? '-',
            _width('HSE Comment'),
            tooltip: true,
          ),
          PatrolReportCells.image(
            names: report.hseImageNames,
            width: _width('Img(H)'),
            onTap: onShowHseImages,
          ),
          PatrolReportCells.text(
            report.loadStatus ?? '-',
            _width('Load'),
            align: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
