import 'package:chuphinh/table/core/patrol_report_table_query.dart';
import 'package:chuphinh/widget/glass_action_button.dart';
import 'package:flutter/material.dart';

class PatrolReportGroupBar extends StatelessWidget {
  final Map<String, int> groupCounts;
  final String? selectedGroup;
  final DateTime? fromDate;
  final DateTime? toDate;
  final int? selectedFy;
  final List<int> fiscalYears;
  final bool showSummary;
  final bool showGroups;
  final ValueChanged<String> onGroupSelected;
  final VoidCallback onPickFromDate;
  final VoidCallback onPickToDate;
  final ValueChanged<int> onFySelected;
  final VoidCallback onToggleSummary;
  final VoidCallback onOpenReport;

  const PatrolReportGroupBar({
    super.key,
    required this.groupCounts,
    required this.selectedGroup,
    required this.fromDate,
    required this.toDate,
    required this.selectedFy,
    required this.fiscalYears,
    required this.showSummary,
    required this.showGroups,
    required this.onGroupSelected,
    required this.onPickFromDate,
    required this.onPickToDate,
    required this.onFySelected,
    required this.onToggleSummary,
    required this.onOpenReport,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    final controls = Row(
      children: [
        _fyDropdown(),
        const Spacer(),
        GlassActionButton(
          icon: showSummary
              ? Icons.expand_less_rounded
              : Icons.expand_more_rounded,
          label: showSummary ? 'Hide' : 'Show',
          onTap: onToggleSummary,
        ),
        GlassActionButton(
          icon: Icons.analytics_outlined,
          label: 'Report',
          onTap: onOpenReport,
        ),
      ],
    );

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showGroups) _groupAndDateControls(isMobile: true),
            const SizedBox(height: 6),
            controls,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Row(
        children: [
          if (showGroups)
            Expanded(child: _groupAndDateControls(isMobile: false)),
          const SizedBox(width: 8),
          _fyDropdown(),
          const SizedBox(width: 8),
          GlassActionButton(
            icon: showSummary
                ? Icons.expand_less_rounded
                : Icons.expand_more_rounded,
            label: showSummary ? 'Hide' : 'Show',
            onTap: onToggleSummary,
          ),
          GlassActionButton(
            icon: Icons.analytics_outlined,
            label: 'Report',
            onTap: onOpenReport,
          ),
        ],
      ),
    );
  }

  Widget _fyDropdown() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedFy,
          hint: const Text(
            'FY',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          dropdownColor: const Color(0xFF1E293B),
          iconEnabledColor: Colors.white70,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          items: fiscalYears
              .map(
                (fy) => DropdownMenuItem<int>(value: fy, child: Text('FY$fy')),
              )
              .toList(),
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          onChanged: (fy) {
            if (fy != null) onFySelected(fy);
          },
        ),
      ),
    );
  }

  Widget _groupAndDateControls({required bool isMobile}) {
    final chips = groupCounts.entries.map((entry) {
      final selected = entry.key == selectedGroup;
      return FilterChip(
        visualDensity: isMobile
            ? VisualDensity.compact
            : VisualDensity.standard,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        label: Text(
          '${entry.key} (${entry.value})',
          overflow: TextOverflow.ellipsis,
        ),
        selected: selected,
        onSelected: (_) => onGroupSelected(entry.key),
        selectedColor: Colors.blue.withOpacity(0.22),
        backgroundColor: Colors.white,
        checkmarkColor: Colors.blue,
        labelStyle: TextStyle(
          fontSize: isMobile ? 12 : 13,
          color: selected ? Colors.blue.shade900 : Colors.black87,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        side: BorderSide(color: selected ? Colors.blue : Colors.grey.shade300),
      );
    }).toList();
    final hasDateFilter = fromDate != null || toDate != null;
    if (chips.isEmpty && !hasDateFilter) return const SizedBox.shrink();

    final fromChip = _dateChip(
      label: 'From',
      value: fromDate == null
          ? '--'
          : PatrolReportTableQuery.fmtDate(fromDate!),
      onTap: onPickFromDate,
    );
    final toChip = _dateChip(
      label: 'To',
      value: toDate == null ? '--' : PatrolReportTableQuery.fmtDate(toDate!),
      onTap: onPickToDate,
    );

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(spacing: 6, runSpacing: 6, children: chips),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: fromChip),
                const SizedBox(width: 8),
                Expanded(child: toChip),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [...chips, fromChip, toChip],
      ),
    );
  }

  Widget _dateChip({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF172A33),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, size: 16, color: Colors.grey.shade300),
            const SizedBox(width: 6),
            Text(
              '$label: $value',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
