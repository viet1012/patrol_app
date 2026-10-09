import 'package:chuphinh/shared/widgets/common_ui_helper.dart';
import 'package:chuphinh/core/models/patrol_report_model.dart';
import 'package:chuphinh/features/patrol/summary/widgets/cells/patrol_report_image_thumb.dart';
import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';
import 'package:flutter/material.dart';

class PatrolReportCells {
  const PatrolReportCells._();

  /// Ô text: tối đa 3 dòng rồi ellipsis.
  static const maxTextLines = 3;
  static const _tooltipThreshold = 24;

  static Widget text(
    String text,
    double width, {
    TextAlign align = TextAlign.left,
    bool tooltip = false,
    int maxLines = maxTextLines,
  }) {
    final value = text.trim().isEmpty ? '-' : text.trim();
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        value,
        style: const TextStyle(fontSize: 13),
        textAlign: align,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );

    // Nội dung dài có thể bị cắt (3 dòng) -> luôn có tooltip.
    final showTooltip = tooltip || value.length > _tooltipThreshold;

    return _boxed(
      width: width,
      align: align,
      child: showTooltip
          ? Tooltip(
              message: value,
              waitDuration: const Duration(milliseconds: 350),
              child: content,
            )
          : content,
    );
  }

  static Widget qr(String? qr, double width, {bool compact = false}) {
    final value = (qr ?? '').trim();
    final hasQr = value.isNotEmpty;
    final box = compact ? 40.0 : 50.0;
    return _boxed(
      width: width,
      align: TextAlign.center,
      child: hasQr
          ? Container(
              margin: EdgeInsets.only(bottom: compact ? 0 : 6),
              width: box,
              height: box,
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey.shade200),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_2_rounded,
                    size: compact ? 18 : 24,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 11 : 13,
                      color: Colors.grey.shade800,
                      height: 1,
                    ),
                  ),
                ],
              ),
            )
          : const Text('-'),
    );
  }

  /// Ô ảnh: thumbnail ảnh đầu + badge "+N"; bấm để xem ảnh lớn.
  static Widget image({
    required List<String> names,
    required double width,
    required PatrolReportThumbSize size,
    VoidCallback? onTap,
  }) {
    return _boxed(
      width: width,
      align: TextAlign.center,
      child: PatrolReportImageThumb(
        names: names,
        size: size,
        onTap: names.isEmpty ? null : onTap,
      ),
    );
  }

  static Widget riskBadge(String risk, double width) {
    final color = CommonUI.riskColor(risk);
    return _badgeCell(risk, width, color, fontSize: 18);
  }

  static Widget statusBadge(String? value, double width) {
    final status = (value == null || value.isEmpty) ? 'Doing' : value;
    final color = CommonUI.statusColor(status);
    return _boxed(
      width: width,
      align: TextAlign.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  static Widget dueRevision(int count, double width) {
    final color = count >= 3
        ? Colors.red
        : count >= 1
        ? Colors.orange
        : Colors.green;
    return _badgeCell('$count', width, color, fontSize: 14);
  }

  static Widget dueStatus(PatrolReportModel report, double width) {
    final status = (report.atStatus ?? 'Doing').trim();
    final shouldCheckDue = status == 'Doing' || status == 'Redo';
    String label;
    Color color;
    IconData icon;

    if (!shouldCheckDue) {
      label = '-';
      color = Colors.grey;
      icon = Icons.remove_rounded;
    } else {
      final baseDueDate = report.dueDateUpdatedAt ?? report.dueDate;
      if (baseDueDate == null) {
        label = '-';
        color = Colors.grey;
        icon = Icons.remove_rounded;
      } else {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final due = DateTime(
          baseDueDate.year,
          baseDueDate.month,
          baseDueDate.day,
        );
        final diff = due.difference(today).inDays;
        if (diff < 0) {
          label = 'Late';
          color = Colors.red;
          icon = Icons.error_rounded;
        } else if (diff <= 3) {
          label = '3 Days Ago';
          color = Colors.orange;
          icon = Icons.warning_amber_rounded;
        } else {
          label = 'Still Time';
          color = Colors.green;
          icon = Icons.check_circle_rounded;
        }
      }
    }

    return _boxed(
      width: width,
      align: TextAlign.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _badgeCell(
    String text,
    double width,
    Color color, {
    double fontSize = 13,
  }) {
    return _boxed(
      width: width,
      align: TextAlign.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  static Widget _boxed({
    required double width,
    required TextAlign align,
    required Widget child,
  }) {
    return Container(
      width: width,
      alignment: align == TextAlign.center
          ? Alignment.center
          : Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: child,
    );
  }
}
