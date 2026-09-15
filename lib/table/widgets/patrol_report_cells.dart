import 'package:chuphinh/api/api_config.dart';
import 'package:chuphinh/common/common_ui_helper.dart';
import 'package:chuphinh/model/patrol_report_model.dart';
import 'package:flutter/material.dart';

class PatrolReportCells {
  const PatrolReportCells._();

  static Widget text(
    String text,
    double width, {
    TextAlign align = TextAlign.left,
    bool tooltip = false,
  }) {
    final value = text.trim().isEmpty ? '-' : text.trim();
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        value,
        style: const TextStyle(fontSize: 13),
        textAlign: align,
      ),
    );

    return _boxed(
      width: width,
      align: align,
      child: tooltip
          ? Tooltip(
              message: value,
              waitDuration: const Duration(milliseconds: 350),
              child: content,
            )
          : content,
    );
  }

  static Widget qr(String? qr, double width) {
    final value = (qr ?? '').trim();
    final hasQr = value.isNotEmpty;
    return _boxed(
      width: width,
      align: TextAlign.center,
      child: hasQr
          ? Container(
              margin: const EdgeInsets.only(bottom: 6),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey.shade200),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.qr_code_2_rounded,
                    size: 24,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
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

  static Widget image({
    required List<String> names,
    required double width,
    VoidCallback? onTap,
  }) {
    final count = names.length;
    final first = count > 0 ? names.first : '';
    return _boxed(
      width: width,
      align: TextAlign.center,
      child: InkWell(
        onTap: count > 0 ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (count > 0)
              Expanded(child: _imageThumb(first, size: 80))
            else
              const Icon(
                Icons.image_not_supported,
                size: 18,
                color: Colors.grey,
              ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: count > 0 ? Colors.blueGrey.shade800 : Colors.grey,
              ),
            ),
          ],
        ),
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

  static Widget _imageThumb(String imageName, {double size = 40}) {
    if (imageName.isEmpty) {
      return const Icon(
        Icons.image_not_supported,
        size: 20,
        color: Colors.grey,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        '${ApiConfig.baseUrl}/images/$imageName',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.red),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        },
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
