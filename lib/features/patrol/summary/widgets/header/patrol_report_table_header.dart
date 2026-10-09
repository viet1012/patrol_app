import 'package:flutter/material.dart';

import 'package:chuphinh/features/patrol/summary/core/patrol_report_table_columns.dart';
import 'package:chuphinh/features/patrol/summary/widgets/filters/patrol_report_filter_popup.dart';
import 'package:chuphinh/features/patrol/summary/widgets/header/patrol_report_header_filter_cell.dart';
import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';

class PatrolReportTableHeader extends StatelessWidget {
  final List<PatrolReportColumnSpec> columns;
  final Map<String, LayerLink> filterLinks;
  final Map<String, Set<String>> filterValues;
  final String? activeFilterColumn;
  final List<String> popupValues;
  final ScrollController popupScrollController;

  /// Chỉ 1 header (phần cuộn) giữ OverlayPortal; header pinned truyền null.
  final OverlayPortalController? overlayController;
  final ValueChanged<String> onOpenFilter;
  final VoidCallback onCloseFilter;
  final ValueChanged<String> onFilterSearchChanged;
  final void Function(String value, bool checked) onFilterValueChanged;
  final VoidCallback onClearFilter;

  /// null = tắt resize (mobile).
  final void Function(String label, double delta)? onResize;
  final VoidCallback? onResizeEnd;
  final ValueChanged<String>? onResetWidth;

  const PatrolReportTableHeader({
    super.key,
    required this.columns,
    required this.filterLinks,
    required this.filterValues,
    required this.activeFilterColumn,
    required this.popupValues,
    required this.popupScrollController,
    required this.overlayController,
    required this.onOpenFilter,
    required this.onCloseFilter,
    required this.onFilterSearchChanged,
    required this.onFilterValueChanged,
    required this.onClearFilter,
    this.onResize,
    this.onResizeEnd,
    this.onResetWidth,
  });

  @override
  Widget build(BuildContext context) {
    final resize = onResize;
    final reset = onResetWidth;

    final row = Container(
      height: PatrolReportHeaderFilterCell.height,
      color: PatrolReportTokens.tableHeaderBg,
      child: Row(
        children: columns.map((column) {
          return PatrolReportHeaderFilterCell(
            label: column.label,
            tooltip: column.tooltip,
            width: column.width,
            align: column.align,
            hasFilter: filterValues[column.label]?.isNotEmpty == true,
            layerLink: filterLinks[column.label]!,
            onFilterTap: () => onOpenFilter(column.label),
            onResize: resize == null ? null : (d) => resize(column.label, d),
            onResizeEnd: onResizeEnd,
            onResetWidth: reset == null ? null : () => reset(column.label),
          );
        }).toList(),
      ),
    );

    final controller = overlayController;
    if (controller == null) return row;

    return OverlayPortal(
      controller: controller,
      overlayChildBuilder: (_) {
        final column = activeFilterColumn;
        if (column == null) return const SizedBox();
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: onCloseFilter,
              ),
            ),
            PatrolReportFilterPopup(
              column: column,
              layerLink: filterLinks[column]!,
              values: popupValues,
              selectedValues: filterValues[column] ?? const <String>{},
              scrollController: popupScrollController,
              onSearchChanged: onFilterSearchChanged,
              onValueChanged: onFilterValueChanged,
              onClear: onClearFilter,
              onClose: onCloseFilter,
            ),
          ],
        );
      },
      child: row,
    );
  }
}
