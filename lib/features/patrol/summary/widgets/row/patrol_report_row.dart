import 'package:chuphinh/shared/widgets/common_ui_helper.dart';
import 'package:chuphinh/core/models/patrol_report_model.dart';
import 'package:flutter/material.dart';

import 'package:chuphinh/features/patrol/summary/core/patrol_report_table_columns.dart';
import 'package:chuphinh/features/patrol/summary/widgets/cells/patrol_report_cells.dart';
import 'package:chuphinh/features/patrol/summary/widgets/row/patrol_report_hoverable_row.dart';
import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';

/// Một dòng (hoặc một phần dòng: pinned / cuộn) của bảng.
/// Ô được dựng theo đúng thứ tự + width của `columns` (cùng nguồn với header).
class PatrolReportRow extends StatelessWidget {
  /// Đủ chứa thumbnail Img(B) (PatrolReportThumbSize.large) + lề.
  static const double defaultRowHeight = PatrolReportThumbSize.largeHeight + 20;
  static const double mobileRowHeight = 60;

  final PatrolReportModel report;
  final int pageIndex;
  final bool selected;
  final List<PatrolReportColumnSpec> columns;
  final VoidCallback onEdit;
  final VoidCallback onShowBeforeImages;
  final VoidCallback onShowAfterImages;
  final VoidCallback onShowHseImages;
  final double rowHeight;

  /// Vẽ viền trái đỏ nhạt (chỉ phần đầu dòng mới truyền true).
  final bool showLateMarker;

  /// Desktop: highlight khi hover; dùng chung giữa phần pinned và phần cuộn.
  final ValueNotifier<int?>? hoverIndex;

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
    this.rowHeight = defaultRowHeight,
    this.showLateMarker = false,
    this.hoverIndex,
  });

  bool get _compact => rowHeight < defaultRowHeight;

  Widget _cell(PatrolReportColumnSpec column) {
    final w = column.width;
    final r = report;

    Widget text(String? v, {bool center = false}) => PatrolReportCells.text(
      v ?? '-',
      w,
      align: center ? TextAlign.center : TextAlign.left,
      tooltip: !center,
    );

    switch (column.label) {
      case 'STT':
        return PatrolReportCells.text(
          r.stt.toString(),
          w,
          align: TextAlign.center,
        );
      case 'QR':
        return PatrolReportCells.qr(r.qr_key?.toString(), w, compact: _compact);
      case 'Group':
        return text(r.grp);
      case 'Plant':
        return text(r.plant);
      case 'Division':
        return text(r.division);
      case 'Area':
        return text(r.area);
      case 'Machine':
        return text(r.machine);
      case 'Patrol User':
        return text(r.patrol_user);
      case 'Img(B)':
        return PatrolReportCells.image(
          names: r.imageNames,
          width: w,
          size: _compact
              ? PatrolReportThumbSize.compactLarge
              : PatrolReportThumbSize.large,
          onTap: onShowBeforeImages,
        );
      case 'Risk T':
        return PatrolReportCells.riskBadge(r.riskTotal, w);
      case 'Comment':
        return text(r.comment);
      case 'Countermeasure':
        return text(r.countermeasure);
      case 'Created':
        return text(CommonUI.fmtDate(r.createdAt), center: true);
      case 'Deadline':
        return text(CommonUI.fmtDate(r.dueDate), center: true);
      case 'Revise Deadline':
        return text(CommonUI.fmtDate(r.dueDateUpdatedAt), center: true);
      case 'Due Rev':
        return PatrolReportCells.dueRevision(r.dueDateUpdateCount ?? 0, w);
      case 'Due By':
        return text(r.dueDateUpdatedBy);
      case 'Due Status':
        return PatrolReportCells.dueStatus(r, w);
      case 'PIC':
        return text(r.pic);
      case 'Check Info':
        return text(r.checkInfo);
      case 'Risk F':
        return text(r.riskFreq, center: true);
      case 'Risk P':
        return text(r.riskProb, center: true);
      case 'Risk S':
        return text(r.riskSev, center: true);
      case 'AT Stt':
        return PatrolReportCells.statusBadge(r.atStatus, w);
      case 'AT PIC':
        return text(r.atPic);
      case 'AT Date':
        return text(CommonUI.fmtDate(r.atDate), center: true);
      case 'AT Cmt':
        return text(r.atComment);
      case 'Img(A)':
        return PatrolReportCells.image(
          names: r.atImageNames,
          width: w,
          size: _compact
              ? PatrolReportThumbSize.compact
              : PatrolReportThumbSize.regular,
          onTap: onShowAfterImages,
        );
      case 'HSE User':
        return text(r.hseUser);
      case 'HSE Judge':
        return text(r.hseJudge, center: true);
      case 'HSE Updated':
        return text(CommonUI.fmtDate(r.hseDate), center: true);
      case 'HSE Comment':
        return text(r.hseComment);
      case 'Img(H)':
        return PatrolReportCells.image(
          names: r.hseImageNames,
          width: w,
          size: _compact
              ? PatrolReportThumbSize.compact
              : PatrolReportThumbSize.regular,
          onTap: onShowHseImages,
        );
      case 'Load':
        return text(r.loadStatus, center: true);
      default:
        return text(column.valueGetter(r));
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = pageIndex.isEven
        ? PatrolReportTokens.rowEven
        : PatrolReportTokens.rowOdd;
    return PatrolReportHoverableRow(
      index: pageIndex,
      hoverIndex: hoverIndex,
      height: rowHeight,
      background: selected ? PatrolReportTokens.rowSelected : baseColor,
      onDoubleTap: onEdit,
      leftMarker: showLateMarker ? PatrolReportTokens.rowLateMarker : null,
      child: Row(children: [for (final c in columns) _cell(c)]),
    );
  }
}
