import 'package:flutter/material.dart';

import '../../common/common_ui_helper.dart';
import '../../model/patrol_report_model.dart';

class PatrolReportColumnSpec {
  final String label;
  final double width;
  final TextAlign align;
  final String? queryKey;
  final String Function(PatrolReportModel row) valueGetter;

  const PatrolReportColumnSpec({
    required this.label,
    required this.width,
    required this.align,
    required this.valueGetter,
    this.queryKey,
  });
}

class PatrolReportTableColumns {
  static List<PatrolReportColumnSpec> build() {
    return [
      PatrolReportColumnSpec(
        label: 'STT',
        width: 70,
        align: TextAlign.center,
        valueGetter: (e) => e.stt.toString(),
      ),
      PatrolReportColumnSpec(
        label: 'QR',
        width: 70,
        align: TextAlign.center,
        queryKey: 'qrKey',
        valueGetter: (e) => e.qr_key?.toString() ?? '',
      ),
      PatrolReportColumnSpec(
        label: 'Group',
        width: 70,
        align: TextAlign.left,
        queryKey: 'grp',
        valueGetter: (e) => e.grp,
      ),
      PatrolReportColumnSpec(
        label: 'Plant',
        width: 70,
        align: TextAlign.left,
        queryKey: 'plant',
        valueGetter: (e) => e.plant,
      ),
      PatrolReportColumnSpec(
        label: 'Division',
        width: 90,
        align: TextAlign.left,
        queryKey: 'division',
        valueGetter: (e) => e.division,
      ),
      PatrolReportColumnSpec(
        label: 'Area',
        width: 120,
        align: TextAlign.left,
        queryKey: 'area',
        valueGetter: (e) => e.area,
      ),
      PatrolReportColumnSpec(
        label: 'Machine',
        width: 100,
        align: TextAlign.left,
        queryKey: 'machine',
        valueGetter: (e) => e.machine,
      ),
      PatrolReportColumnSpec(
        label: 'Patrol User',
        width: 110,
        align: TextAlign.left,
        queryKey: 'patrolUser',
        valueGetter: (e) => e.patrol_user ?? '',
      ),
      PatrolReportColumnSpec(
        label: 'Img(B)',
        width: 90,
        align: TextAlign.center,
        valueGetter: (_) => '',
      ),
      PatrolReportColumnSpec(
        label: 'Risk T',
        width: 90,
        align: TextAlign.center,
        valueGetter: (e) => e.riskTotal,
      ),
      PatrolReportColumnSpec(
        label: 'Comment',
        width: 260,
        align: TextAlign.left,
        valueGetter: (e) => e.comment,
      ),
      PatrolReportColumnSpec(
        label: 'Countermeasure',
        width: 260,
        align: TextAlign.left,
        valueGetter: (e) => e.countermeasure,
      ),
      PatrolReportColumnSpec(
        label: 'Created',
        width: 100,
        align: TextAlign.center,
        valueGetter: (e) => CommonUI.fmtDate(e.createdAt),
      ),
      PatrolReportColumnSpec(
        label: 'Due',
        width: 100,
        align: TextAlign.center,
        valueGetter: (e) => CommonUI.fmtDate(e.dueDate),
      ),
      PatrolReportColumnSpec(
        label: 'PIC',
        width: 90,
        align: TextAlign.left,
        queryKey: 'pic',
        valueGetter: (e) => e.pic ?? '',
      ),
      PatrolReportColumnSpec(
        label: 'Check Info',
        width: 120,
        align: TextAlign.left,
        valueGetter: (e) => e.checkInfo,
      ),
      PatrolReportColumnSpec(
        label: 'Risk F',
        width: 120,
        align: TextAlign.center,
        valueGetter: (e) => e.riskFreq,
      ),
      PatrolReportColumnSpec(
        label: 'Risk P',
        width: 100,
        align: TextAlign.center,
        valueGetter: (e) => e.riskProb,
      ),
      PatrolReportColumnSpec(
        label: 'Risk S',
        width: 100,
        align: TextAlign.center,
        valueGetter: (e) => e.riskSev,
      ),
      PatrolReportColumnSpec(
        label: 'AT Stt',
        width: 100,
        align: TextAlign.center,
        queryKey: 'afStatus',
        valueGetter: (e) => e.atStatus ?? '',
      ),
      PatrolReportColumnSpec(
        label: 'AT PIC',
        width: 90,
        align: TextAlign.left,
        valueGetter: (e) => e.atPic ?? '',
      ),
      PatrolReportColumnSpec(
        label: 'AT Date',
        width: 100,
        align: TextAlign.center,
        valueGetter: (e) => CommonUI.fmtDate(e.atDate),
      ),
      PatrolReportColumnSpec(
        label: 'AT Cmt',
        width: 260,
        align: TextAlign.left,
        valueGetter: (e) => e.atComment ?? '',
      ),
      PatrolReportColumnSpec(
        label: 'Img(A)',
        width: 100,
        align: TextAlign.center,
        valueGetter: (_) => '',
      ),
      PatrolReportColumnSpec(
        label: 'HSE J',
        width: 90,
        align: TextAlign.center,
        valueGetter: (e) => e.hseJudge ?? '',
      ),
      PatrolReportColumnSpec(
        label: 'HSE D',
        width: 100,
        align: TextAlign.center,
        valueGetter: (e) => CommonUI.fmtDate(e.hseDate),
      ),
      PatrolReportColumnSpec(
        label: 'HSE C',
        width: 260,
        align: TextAlign.left,
        valueGetter: (e) => e.hseComment ?? '',
      ),
      PatrolReportColumnSpec(
        label: 'Img(H)',
        width: 100,
        align: TextAlign.center,
        valueGetter: (_) => '',
      ),
      PatrolReportColumnSpec(
        label: 'Load',
        width: 100,
        align: TextAlign.center,
        valueGetter: (e) => e.loadStatus ?? '',
      ),
    ];
  }
}
