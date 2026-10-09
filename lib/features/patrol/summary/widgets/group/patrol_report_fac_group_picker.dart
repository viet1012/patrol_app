import 'package:chuphinh/features/patrol/summary/core/patrol_report_fac_group.dart';
import 'package:chuphinh/features/patrol/summary/widgets/group/patrol_report_fac_segment.dart';
import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';
import 'package:flutter/material.dart';

typedef _T = PatrolReportTokens;
typedef _F = PatrolReportFilterBarTokens;

/// Chọn đúng cặp Fac/Group (null = Tất cả).
typedef PatrolReportFacGroupPick = void Function(String? fac, String? group);

/// Màn hình hẹp: Fac + Group gộp thành 1 nút "Fac_2 · Group 10 ▾".
class PatrolReportFacGroupPicker extends StatelessWidget {
  final PatrolReportFacGroups data;
  final String? selectedFac;
  final String? selectedGroup;
  final PatrolReportFacGroupPick onPick;

  const PatrolReportFacGroupPicker({
    super.key,
    required this.data,
    required this.selectedFac,
    required this.selectedGroup,
    required this.onPick,
  });

  String get _label {
    final fac = selectedFac, group = selectedGroup;
    if (fac == null && group == null) return _F.allLabel;
    if (fac == null) return group!;
    return '$fac · ${group ?? '${_F.allLabel} group'}';
  }

  int get _count {
    final fac = selectedFac, group = selectedGroup;
    if (fac == null) return data.total;
    if (group == null) return data.facCount(fac);
    return data.groupCount(fac, group);
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showDialog<(String?, String?)>(
      context: context,
      builder: (_) => _PickerDialog(
        data: data,
        selectedFac: selectedFac,
        selectedGroup: selectedGroup,
      ),
    );
    if (picked != null) onPick(picked.$1, picked.$2);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _F.pickerButtonMaxWidth),
      child: Tooltip(
        message: 'Choose Fac / Group',
        child: Material(
          color: _T.glass,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_T.r10),
            side: const BorderSide(color: _T.glassBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _open(context),
            child: SizedBox(
              height: _T.tapTarget,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _T.s12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.filter_list_rounded,
                      size: 18,
                      color: _T.accent,
                    ),
                    const SizedBox(width: _T.s8),
                    Flexible(
                      child: Text(
                        _label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _T.textPrimary,
                          fontSize: _T.fsMd,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    PatrolReportCountBadge(count: _count),
                    const Icon(
                      Icons.arrow_drop_down_rounded,
                      color: _T.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerDialog extends StatefulWidget {
  final PatrolReportFacGroups data;
  final String? selectedFac;
  final String? selectedGroup;

  const _PickerDialog({
    required this.data,
    required this.selectedFac,
    required this.selectedGroup,
  });

  @override
  State<_PickerDialog> createState() => _PickerDialogState();
}

class _PickerDialogState extends State<_PickerDialog> {
  String _query = '';

  void _pick(String? fac, String? group) =>
      Navigator.of(context).pop((fac, group));

  Widget _row({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
    bool header = false,
  }) {
    return Opacity(
      opacity: count == 0 && !selected ? _F.zeroCountOpacity : 1,
      child: Material(
        color: selected
            ? _T.accentStrong.withValues(alpha: 0.35)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: _F.pickerRowHeight,
            child: Padding(
              padding: EdgeInsets.only(
                left: header ? _T.s16 : _F.pickerIndent + _T.s8,
                right: _T.s16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _T.textPrimary,
                        fontSize: header ? _T.fsLg : _T.fsMd,
                        fontWeight: header || selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (selected) ...[
                    const Icon(Icons.check_rounded, size: 18, color: _T.accent),
                    const SizedBox(width: _T.s8),
                  ],
                  PatrolReportCountBadge(count: count),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final q = _query.trim().toLowerCase();
    bool matches(String s) => q.isEmpty || s.toLowerCase().contains(q);

    final rows = <Widget>[
      if (q.isEmpty)
        _row(
          label: _F.allLabel,
          count: data.total,
          selected: widget.selectedFac == null && widget.selectedGroup == null,
          onTap: () => _pick(null, null),
          header: true,
        ),
    ];

    for (final fac in data.facs) {
      final facMatches = matches(fac);
      final groups = [
        for (final g in data.groupsByFac[fac] ?? const <String>[])
          if (facMatches || matches(g)) g,
      ];
      if (!facMatches && groups.isEmpty) continue;

      rows
        ..add(const Divider(height: 1, color: _T.glassBorder))
        ..add(
          _row(
            label: '$fac · ${_F.allLabel} group',
            count: data.facCount(fac),
            selected: widget.selectedFac == fac && widget.selectedGroup == null,
            onTap: () => _pick(fac, null),
            header: true,
          ),
        );
      for (final g in groups) {
        rows.add(
          _row(
            label: g,
            count: data.groupCount(fac, g),
            selected:
                widget.selectedGroup == g &&
                (widget.selectedFac == null || widget.selectedFac == fac),
            onTap: () => _pick(fac, g),
          ),
        );
      }
    }

    return Dialog(
      backgroundColor: _T.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(_T.s16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_T.r14),
        side: const BorderSide(color: _T.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _F.pickerMaxWidth,
          maxHeight: _F.pickerMaxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(_T.s12),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: _T.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search Fac / Group',
                  hintStyle: const TextStyle(color: _T.textMuted),
                  prefixIcon: const Icon(Icons.search, color: _T.textSecondary),
                  isDense: true,
                  filled: true,
                  fillColor: _T.glass,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_T.r10),
                    borderSide: const BorderSide(color: _T.glassBorder),
                  ),
                ),
              ),
            ),
            Flexible(
              child: rows.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(_T.s16),
                      child: Text(
                        'No matching Fac / Group',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _T.textSecondary),
                      ),
                    )
                  : ListView(shrinkWrap: true, children: rows),
            ),
            const SizedBox(height: _T.s8),
          ],
        ),
      ),
    );
  }
}
