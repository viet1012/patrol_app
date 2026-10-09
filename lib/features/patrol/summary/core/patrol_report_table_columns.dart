import 'package:flutter/material.dart';

import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';

import 'package:chuphinh/shared/widgets/common_ui_helper.dart';
import 'package:chuphinh/core/models/patrol_report_model.dart';

class PatrolReportColumnSpec {
  /// Giới hạn khi kéo đổi độ rộng cột.
  static const double minWidth = 60;
  static const double maxWidth = 600;

  final String label;
  final double width;
  final TextAlign align;
  final String? queryKey;
  final String Function(PatrolReportModel row) valueGetter;

  /// Tên đầy đủ cho tooltip header (mặc định = label).
  final String? title;

  const PatrolReportColumnSpec({
    required this.label,
    required this.width,
    required this.align,
    required this.valueGetter,
    this.queryKey,
    this.title,
  });

  String get tooltip => title ?? label;

  PatrolReportColumnSpec withWidth(double width) => PatrolReportColumnSpec(
    label: label,
    width: width,
    align: align,
    valueGetter: valueGetter,
    queryKey: queryKey,
    title: title,
  );
}

class PatrolReportTableColumns {
  // Cột ảnh = thumbnail + lề 2 bên.
  static const double _imgBWidth =
      PatrolReportThumbSize.largeWidth + 2 * PatrolReportThumbSize.cellPadding;
  static const double _imgWidth =
      PatrolReportThumbSize.regularWidth +
      2 * PatrolReportThumbSize.cellPadding;

  static List<PatrolReportColumnSpec> build() {
    return [
      PatrolReportColumnSpec(
        label: 'STT',
        width: 72,
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
        width: 100,
        align: TextAlign.left,
        queryKey: 'grp',
        valueGetter: (e) => e.grp,
      ),
      PatrolReportColumnSpec(
        label: 'Plant',
        width: 88,
        align: TextAlign.left,
        queryKey: 'plant',
        valueGetter: (e) => e.plant,
      ),
      PatrolReportColumnSpec(
        label: 'Division',
        width: 104,
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
        width: 112,
        align: TextAlign.left,
        queryKey: 'machine',
        valueGetter: (e) => e.machine,
      ),
      PatrolReportColumnSpec(
        label: 'Patrol User',
        width: 150,
        align: TextAlign.left,
        queryKey: 'patrolUser',
        valueGetter: (e) => e.patrol_user ?? '',
      ),
      PatrolReportColumnSpec(
        label: 'Img(B)',
        width: _imgBWidth,
        title: 'Before images',
        align: TextAlign.center,
        valueGetter: (_) => '',
      ),
      PatrolReportColumnSpec(
        label: 'Risk T',
        width: 80,
        title: 'Risk Total',
        align: TextAlign.center,
        valueGetter: (e) => e.riskTotal,
      ),
      PatrolReportColumnSpec(
        label: 'Comment',
        width: 320,
        align: TextAlign.left,
        valueGetter: (e) => e.comment,
      ),
      PatrolReportColumnSpec(
        label: 'Countermeasure',
        width: 320,
        align: TextAlign.left,
        valueGetter: (e) => e.countermeasure,
      ),
      PatrolReportColumnSpec(
        label: 'Created',
        width: 104,
        align: TextAlign.center,
        valueGetter: (e) => CommonUI.fmtDate(e.createdAt),
      ),
      PatrolReportColumnSpec(
        label: 'Deadline',
        width: 112,
        align: TextAlign.center,
        valueGetter: (e) => CommonUI.fmtDate(e.dueDate),
      ),
      PatrolReportColumnSpec(
        label: 'Revise Deadline',
        width: 112,
        align: TextAlign.center,
        valueGetter: (e) => CommonUI.fmtDate(e.dueDateUpdatedAt),
      ),
      PatrolReportColumnSpec(
        label: 'Due Rev',
        width: 90,
        title: 'Due date revisions',
        align: TextAlign.center,
        valueGetter: (e) => '${e.dueDateUpdateCount}',
      ),
      PatrolReportColumnSpec(
        label: 'Due By',
        width: 120,
        title: 'Due date updated by',
        align: TextAlign.left,
        valueGetter: (e) => e.dueDateUpdatedBy ?? '',
      ),
      PatrolReportColumnSpec(
        label: 'Due Status',
        width: 120,
        align: TextAlign.center,
        valueGetter: (e) {
          final due = e.dueDateUpdatedAt ?? e.dueDate;
          if (due == null) return '';

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final dueDate = DateTime(due.year, due.month, due.day);

          final diff = dueDate.difference(today).inDays;

          if (diff < 0) return 'Late';
          if (diff <= 3) return '3 Days Ago';
          return 'Still Time';
        },
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
        width: 90,
        title: 'Risk Frequency',
        align: TextAlign.center,
        valueGetter: (e) => e.riskFreq,
      ),
      PatrolReportColumnSpec(
        label: 'Risk P',
        width: 90,
        title: 'Risk Probability',
        align: TextAlign.center,
        valueGetter: (e) => e.riskProb,
      ),
      PatrolReportColumnSpec(
        label: 'Risk S',
        width: 90,
        title: 'Risk Severity',
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
        width: _imgWidth,
        title: 'After images',
        align: TextAlign.center,
        valueGetter: (_) => '',
      ),
      PatrolReportColumnSpec(
        label: 'HSE User',
        width: 150,
        align: TextAlign.left,
        valueGetter: (e) => e.hseUser ?? '',
      ),
      PatrolReportColumnSpec(
        label: 'HSE Judge',
        width: 140,
        align: TextAlign.center,
        valueGetter: (e) => e.hseJudge ?? '',
      ),
      PatrolReportColumnSpec(
        label: 'HSE Updated',
        width: 140,
        align: TextAlign.center,
        valueGetter: (e) => CommonUI.fmtDate(e.hseDate),
      ),
      PatrolReportColumnSpec(
        label: 'HSE Comment',
        width: 260,
        align: TextAlign.left,
        valueGetter: (e) => e.hseComment ?? '',
      ),
      PatrolReportColumnSpec(
        label: 'Img(H)',
        width: _imgWidth,
        title: 'HSE images',
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
