import 'package:chuphinh/features/patrol/summary/core/patrol_report_fac_group.dart';
import 'package:chuphinh/features/patrol/summary/core/patrol_report_table_query.dart';
import 'package:chuphinh/features/patrol/summary/widgets/group/patrol_report_fac_group_picker.dart';
import 'package:chuphinh/features/patrol/summary/widgets/group/patrol_report_fac_segment.dart';
import 'package:chuphinh/features/patrol/summary/widgets/group/patrol_report_group_strip.dart';
import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';
import 'package:chuphinh/shared/widgets/glass_action_button.dart';
import 'package:flutter/material.dart';

typedef _T = PatrolReportTokens;
typedef _F = PatrolReportFilterBarTokens;

/// Hàng trên cùng: [Fac] [dải Group (Expanded)] [From/To/FY/Show/Report].
///
/// Hẹp hơn [PatrolReportFilterBarTokens.collapseBreakpoint]: Fac + Group gộp
/// thành 1 nút dropdown.
class PatrolReportGroupBar extends StatelessWidget {
  final PatrolReportFacGroups facGroups;
  final String? selectedFac;
  final String? selectedGroup;
  final DateTime? fromDate;
  final DateTime? toDate;
  final int? selectedFy;
  final List<int> fiscalYears;
  final bool showSummary;

  /// Ẩn dải Fac/Group (khi đang mở popup filter cột).
  final bool showGroups;
  final ValueChanged<String?> onSelectFac;
  final PatrolReportGroupSelect onSelectGroup;
  final PatrolReportFacGroupPick onPickFacGroup;

  /// Khoảng ngày khác mặc định: viền accent ô From/To + hiện nút reset.
  final bool dateRangeChanged;
  final VoidCallback onResetDateRange;
  final VoidCallback onPickFromDate;
  final VoidCallback onPickToDate;
  final ValueChanged<int> onFySelected;
  final VoidCallback onToggleSummary;
  final VoidCallback onOpenReport;

  const PatrolReportGroupBar({
    super.key,
    required this.facGroups,
    required this.selectedFac,
    required this.selectedGroup,
    required this.fromDate,
    required this.toDate,
    required this.selectedFy,
    required this.fiscalYears,
    required this.showSummary,
    required this.showGroups,
    required this.onSelectFac,
    required this.onSelectGroup,
    required this.onPickFacGroup,
    required this.dateRangeChanged,
    required this.onResetDateRange,
    required this.onPickFromDate,
    required this.onPickToDate,
    required this.onFySelected,
    required this.onToggleSummary,
    required this.onOpenReport,
  });

  Widget _picker() => PatrolReportFacGroupPicker(
    data: facGroups,
    selectedFac: selectedFac,
    selectedGroup: selectedGroup,
    onPick: onPickFacGroup,
  );

  /// Fac segment (cuộn nếu quá dài) + dải Group lấp phần còn lại.
  Widget _facAndGroups() {
    final strip = PatrolReportGroupStrip(
      data: facGroups,
      selectedFac: selectedFac,
      selectedGroup: selectedGroup,
      onSelect: onSelectGroup,
    );
    // Chỉ có 1 Fac: ẩn segment.
    if (facGroups.facs.length <= 1) return strip;

    return LayoutBuilder(
      builder: (context, c) => Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: c.maxWidth * _F.segmentMaxShare,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: PatrolReportFacSegment(
                data: facGroups,
                selectedFac: selectedFac,
                onSelect: onSelectFac,
              ),
            ),
          ),
          const SizedBox(width: _T.s8),
          Expanded(child: strip),
        ],
      ),
    );
  }

  /// From / To (+ nút reset khi khoảng ngày khác mặc định).
  /// [expand]: mobile, 2 ô chia đều bề rộng.
  List<Widget> _dateChips({bool expand = false}) {
    Widget fit(Widget w) => expand ? Expanded(child: w) : w;
    return [
      fit(
        _dateChip(
          label: 'From',
          value: fromDate == null
              ? '--'
              : PatrolReportTableQuery.fmtDate(fromDate!),
          onTap: onPickFromDate,
        ),
      ),
      const SizedBox(width: _T.s8),
      fit(
        _dateChip(
          label: 'To',
          value: toDate == null
              ? '--'
              : PatrolReportTableQuery.fmtDate(toDate!),
          onTap: onPickToDate,
        ),
      ),
      if (dateRangeChanged) ...[
        const SizedBox(width: _T.s4),
        IconButton(
          tooltip: 'Reset date range',
          onPressed: onResetDateRange,
          icon: const Icon(Icons.restart_alt_rounded, size: 18),
          color: _T.accent,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(
            width: _F.resetButtonSize,
            height: _F.resetButtonSize,
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    // Mobile: picker / ngày / FY + nút, mỗi thứ 1 hàng.
    if (width < _T.mobileBreakpoint) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          _T.s8,
          _F.rowTopPadding,
          _T.s8,
          _F.rowBottomGap,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showGroups) ...[
              Align(alignment: Alignment.centerLeft, child: _picker()),
              const SizedBox(height: _F.stackedRowGap),
            ],
            Row(children: _dateChips(expand: true)),
            const SizedBox(height: _F.stackedRowGap),
            Row(children: [_fyDropdown(), const Spacer(), ..._actions()]),
          ],
        ),
      );
    }

    final collapsed = width < _F.collapseBreakpoint;

    // Hàng cao cố định, căn giữa dọc; padding dưới = khoảng cách tới Summary.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _T.s12,
        _F.rowTopPadding,
        _T.s12,
        _F.rowBottomGap,
      ),
      child: SizedBox(
        height: _F.rowHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Vùng Fac/Group co giãn; cụm bên phải luôn đủ, không bị đè.
            Expanded(
              child: !showGroups
                  ? const SizedBox.shrink()
                  : collapsed
                  ? Align(alignment: Alignment.centerLeft, child: _picker())
                  : _facAndGroups(),
            ),
            const SizedBox(width: _T.s12),
            ..._dateChips(),
            const SizedBox(width: _T.s8),
            _fyDropdown(),
            const SizedBox(width: _T.s8),
            ..._actions(),
          ],
        ),
      ),
    );
  }

  /// Bỏ padding dọc mặc định của GlassActionButton (6) để nút cao 38.
  static const _actionPadding = EdgeInsets.symmetric(horizontal: _T.s4);

  List<Widget> _actions() => [
    Tooltip(
      message: showSummary ? 'Hide summary' : 'Show summary',
      child: GlassActionButton(
        icon: showSummary
            ? Icons.expand_less_rounded
            : Icons.expand_more_rounded,
        label: showSummary ? 'Hide' : 'Show',
        onTap: onToggleSummary,
        padding: _actionPadding,
      ),
    ),
    Tooltip(
      message: 'Before / After summary report',
      child: GlassActionButton(
        icon: Icons.analytics_outlined,
        label: 'Report',
        onTap: onOpenReport,
        padding: _actionPadding,
      ),
    ),
  ];

  Widget _fyDropdown() {
    return Tooltip(
      message: 'Fiscal year (Apr - Mar)',
      child: Container(
        height: _T.tapTarget,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _T.glass,
          borderRadius: BorderRadius.circular(_T.r10),
          border: Border.all(color: _T.glassBorder),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: selectedFy,
            hint: const Text(
              'FY',
              style: TextStyle(
                color: _T.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            dropdownColor: _T.surfaceRaised,
            iconEnabledColor: _T.textSecondary,
            style: const TextStyle(
              color: _T.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            items: fiscalYears
                .map(
                  (fy) =>
                      DropdownMenuItem<int>(value: fy, child: Text('FY$fy')),
                )
                .toList(),
            isDense: true,
            borderRadius: BorderRadius.circular(_T.r14),
            onChanged: (fy) {
              if (fy != null) onFySelected(fy);
            },
          ),
        ),
      ),
    );
  }

  Widget _dateChip({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: 'Pick $label date',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_T.r10),
        child: Container(
          height: _T.tapTarget,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _T.surface,
            borderRadius: BorderRadius.circular(_T.r10),
            // Viền accent: đang lọc theo khoảng ngày khác mặc định.
            border: dateRangeChanged
                ? Border.all(color: _T.accent, width: _F.dateActiveBorderWidth)
                : Border.all(color: _T.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month, size: 16, color: Colors.grey.shade300),
              const SizedBox(width: 6),
              Text(
                '$label: $value',
                style: const TextStyle(
                  color: _T.textPrimary,
                  fontSize: _T.fsSm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
