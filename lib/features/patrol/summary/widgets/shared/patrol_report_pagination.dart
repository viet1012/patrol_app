import 'dart:math' as math;

import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';
import 'package:flutter/material.dart';

typedef _T = PatrolReportTokens;

class PatrolReportPagination extends StatelessWidget {
  final int page;
  final int rowsPerPage;
  final int totalItems;
  final int totalPages;
  final List<int> pageSizeOptions;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onRowsPerPageChanged;

  /// Mobile: thu gọn để vừa 1 dòng ở 360px.
  final bool compact;

  /// Tổng số bản ghi trước khi lọc; có giá trị thì hiển thị "Rows: shown / total".
  final int? grandTotal;

  const PatrolReportPagination({
    super.key,
    required this.page,
    required this.rowsPerPage,
    required this.totalItems,
    required this.totalPages,
    required this.pageSizeOptions,
    required this.onPageChanged,
    required this.onRowsPerPageChanged,
    this.compact = false,
    this.grandTotal,
  });

  bool get _hasPrev => page > 0;
  bool get _hasNext => page + 1 < totalPages;

  /// "1–30 of 87".
  String get _rangeText {
    if (totalItems == 0) return '0 of 0';
    final start = page * rowsPerPage + 1;
    final end = math.min((page + 1) * rowsPerPage, totalItems);
    return '$start–$end of $totalItems';
  }

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact();

    return Container(
      color: _T.pageBg,
      padding: const EdgeInsets.symmetric(horizontal: _T.s12),
      child: Row(
        children: [
          const Spacer(),
          Text(
            _rangeText,
            style: const TextStyle(
              color: _T.textPrimary,
              fontSize: _T.fsLg,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: _T.s8),
          _navButton(
            tooltip: 'Previous page',
            icon: Icons.chevron_left,
            onPressed: _hasPrev ? () => onPageChanged(page - 1) : null,
            size: _T.tapTarget,
          ),
          _navButton(
            tooltip: 'Next page',
            icon: Icons.chevron_right,
            onPressed: _hasNext ? () => onPageChanged(page + 1) : null,
            size: _T.tapTarget,
          ),
          const SizedBox(width: _T.s12),
          _pageSizeDropdown(compact: false),
        ],
      ),
    );
  }

  Widget _buildCompact() {
    const small = TextStyle(color: _T.textSecondary, fontSize: _T.fsSm);
    final rowsText = grandTotal == null
        ? 'Rows: $totalItems'
        : 'Rows: $totalItems / $grandTotal';

    return Container(
      color: _T.pageBg,
      padding: const EdgeInsets.symmetric(horizontal: _T.s8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              rowsText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: small,
            ),
          ),
          Text(
            'Page ${page + 1} / $totalPages',
            style: const TextStyle(
              color: _T.textPrimary,
              fontSize: _T.fsSm,
              fontWeight: FontWeight.w600,
            ),
          ),
          _navButton(
            tooltip: 'Previous page',
            icon: Icons.chevron_left,
            onPressed: _hasPrev ? () => onPageChanged(page - 1) : null,
            size: _T.tapTargetCompact,
          ),
          _navButton(
            tooltip: 'Next page',
            icon: Icons.chevron_right,
            onPressed: _hasNext ? () => onPageChanged(page + 1) : null,
            size: _T.tapTargetCompact,
          ),
          const SizedBox(width: _T.s4),
          _pageSizeDropdown(compact: true),
        ],
      ),
    );
  }

  Widget _pageSizeDropdown({required bool compact}) {
    return Tooltip(
      message: 'Rows per page',
      child: Container(
        height: compact ? 30 : null,
        alignment: compact ? Alignment.center : null,
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : _T.s8),
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(_T.s8),
          border: Border.all(color: _T.border),
        ),
        child: DropdownButton<int>(
          value: rowsPerPage,
          isDense: compact,
          iconSize: compact ? 18 : 24,
          underline: const SizedBox(),
          dropdownColor: _T.surface,
          iconEnabledColor: _T.textPrimary,
          style: TextStyle(
            color: _T.textPrimary,
            fontSize: compact ? _T.fsSm : _T.fsLg,
          ),
          items: pageSizeOptions
              .map(
                (size) => DropdownMenuItem<int>(
                  value: size,
                  child: Text('$size / page'),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onRowsPerPageChanged(value);
          },
        ),
      ),
    );
  }

  Widget _navButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    required double size,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: size >= _T.tapTarget ? 24 : 20),
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      color: _T.textPrimary,
      disabledColor: _T.textMuted,
    );
  }
}
