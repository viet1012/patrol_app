import 'package:chuphinh/features/patrol/summary/core/patrol_report_fac_group.dart';
import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';
import 'package:flutter/material.dart';

typedef _T = PatrolReportTokens;
typedef _F = PatrolReportFilterBarTokens;

/// Badge số lượng dùng chung cho segment Fac, chip Group và dropdown gộp.
class PatrolReportCountBadge extends StatelessWidget {
  final int count;
  final bool selected;

  const PatrolReportCountBadge({
    super.key,
    required this.count,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: _F.badgeMinWidth),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: selected ? Colors.white : _T.glassBorder,
        borderRadius: BorderRadius.circular(_T.rPill),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _T.fsXs,
          fontWeight: FontWeight.w800,
          color: selected ? _T.accentStrong : _T.textSecondary,
        ),
      ),
    );
  }
}

/// Cấp 1: "Tất cả" + từng Fac, mỗi mục có badge số lượng.
class PatrolReportFacSegment extends StatelessWidget {
  final PatrolReportFacGroups data;
  final String? selectedFac;
  final ValueChanged<String?> onSelect;

  const PatrolReportFacSegment({
    super.key,
    required this.data,
    required this.selectedFac,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final items = <(String?, String, int)>[
      (null, _F.allLabel, data.total),
      for (final fac in data.facs) (fac, fac, data.facCount(fac)),
    ];

    return Container(
      height: _F.segmentHeight,
      decoration: BoxDecoration(
        color: _T.glass,
        borderRadius: BorderRadius.circular(_T.r10),
        border: Border.all(color: _T.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: _T.glassBorder,
              ),
            _segment(items[i].$1, items[i].$2, items[i].$3),
          ],
        ],
      ),
    );
  }

  Widget _segment(String? fac, String label, int count) {
    final selected = fac == selectedFac;

    return Opacity(
      opacity: count == 0 && !selected ? _F.zeroCountOpacity : 1,
      child: Material(
        color: selected ? _T.accentStrong : Colors.transparent,
        child: InkWell(
          onTap: () => onSelect(fac),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _F.segmentPaddingH),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : _T.textSecondary,
                    fontSize: _T.fsMd,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                PatrolReportCountBadge(count: count, selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
