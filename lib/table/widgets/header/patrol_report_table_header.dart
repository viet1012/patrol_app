import 'package:flutter/material.dart';

import '../../core/patrol_report_table_columns.dart';
import '../filters/patrol_report_filter_popup.dart';
import 'patrol_report_header_filter_cell.dart';

class PatrolReportTableHeader extends StatelessWidget {
  final List<PatrolReportColumnSpec> columns;
  final Map<String, LayerLink> filterLinks;
  final Map<String, Set<String>> filterValues;
  final String? activeFilterColumn;
  final List<String> popupValues;
  final ScrollController popupScrollController;
  final OverlayPortalController overlayController;
  final ValueChanged<String> onOpenFilter;
  final VoidCallback onCloseFilter;
  final ValueChanged<String> onFilterSearchChanged;
  final void Function(String value, bool checked) onFilterValueChanged;
  final VoidCallback onClearFilter;

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
  });

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: overlayController,
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
      child: Container(
        height: 44,
        color: Colors.grey.shade200,
        child: Row(
          children: columns.map((column) {
            return PatrolReportHeaderFilterCell(
              label: column.label,
              width: column.width,
              align: column.align,
              hasFilter: filterValues[column.label]?.isNotEmpty == true,
              layerLink: filterLinks[column.label]!,
              onFilterTap: () => onOpenFilter(column.label),
            );
          }).toList(),
        ),
      ),
    );
  }
}
