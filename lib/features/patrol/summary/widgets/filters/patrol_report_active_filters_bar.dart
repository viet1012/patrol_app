import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';
import 'package:flutter/material.dart';

typedef _T = PatrolReportTokens;

class PatrolReportActiveFilter {
  final String label;
  final List<String> values;
  final IconData? icon;
  final VoidCallback onRemove;

  const PatrolReportActiveFilter({
    required this.label,
    required this.values,
    required this.onRemove,
    this.icon,
  });
}

/// Các chip filter đang áp dụng + "Clear all" cùng hàng, căn trái theo bảng.
/// Ẩn khi không có filter.
class PatrolReportActiveFiltersBar extends StatelessWidget {
  static const double _chipMaxWidth = 260;
  static const int _maxValuesShown = 2;

  final List<PatrolReportActiveFilter> filters;
  final VoidCallback onClearAll;
  final bool compact;

  const PatrolReportActiveFiltersBar({
    super.key,
    required this.filters,
    required this.onClearAll,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (filters.isEmpty) return const SizedBox.shrink();

    final clearAll = TextButton.icon(
      onPressed: onClearAll,
      icon: const Icon(Icons.clear_all_rounded, size: 18),
      label: const Text('Clear all'),
      style: TextButton.styleFrom(
        foregroundColor: _T.accent,
        minimumSize: Size(0, compact ? _T.tapTargetCompact : 32),
        padding: const EdgeInsets.symmetric(horizontal: _T.s8),
        textStyle: const TextStyle(
          fontSize: _T.fsSm,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    // Cùng lề trái với Card của bảng (margin 12 desktop).
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? _T.s8 : _T.s12,
        _T.s4,
        compact ? 0 : _T.s12,
        0,
      ),
      child: Row(
        children: [
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in filters) ...[
                    _chip(f),
                    const SizedBox(width: _T.s8),
                  ],
                ],
              ),
            ),
          ),
          clearAll,
        ],
      ),
    );
  }

  static String _valueText(List<String> values) {
    if (values.length <= _maxValuesShown) return values.join(', ');
    final shown = values.take(_maxValuesShown).join(', ');
    return '$shown +${values.length - _maxValuesShown}';
  }

  Widget _chip(PatrolReportActiveFilter f) {
    final icon = f.icon;

    return Tooltip(
      message: '${f.label}: ${f.values.join(', ')}',
      waitDuration: const Duration(milliseconds: 400),
      child: Container(
        constraints: const BoxConstraints(maxWidth: _chipMaxWidth),
        height: 30,
        padding: const EdgeInsets.only(left: 10, right: 2),
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(_T.rPill),
          border: Border.all(color: _T.accent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: _T.accent),
              const SizedBox(width: _T.s4),
            ],
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${f.label}: ',
                      style: const TextStyle(
                        color: _T.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: _valueText(f.values),
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: _T.fsSm),
              ),
            ),
            const SizedBox(width: 2),
            Tooltip(
              message: 'Remove ${f.label} filter',
              child: InkResponse(
                onTap: f.onRemove,
                radius: 14,
                child: const SizedBox(
                  width: 26,
                  height: 26,
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: _T.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
