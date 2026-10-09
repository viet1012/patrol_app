import 'package:flutter/material.dart';

import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';
import 'package:chuphinh/shared/widgets/glass_action_button.dart';

typedef _T = PatrolReportTokens;

class PatrolReportTableToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode? searchFocusNode;
  final int total;
  final int shown;
  final bool canClear;
  final bool downloading;
  final VoidCallback onBack;
  final VoidCallback onReload;
  final VoidCallback onDownload;
  final VoidCallback onClear;
  final VoidCallback onColumns;

  /// Mobile: nút 36x36, bỏ ô đếm (hiển thị ở pagination).
  final bool compact;

  const PatrolReportTableToolbar({
    super.key,
    required this.searchController,
    this.searchFocusNode,
    required this.total,
    required this.shown,
    required this.canClear,
    required this.downloading,
    required this.onBack,
    required this.onReload,
    required this.onDownload,
    required this.onClear,
    required this.onColumns,
    this.compact = false,
  });

  static const _hint = 'Search (stt, type, group, comment, PIC...)';
  static const double _searchMaxWidth = 520;

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _T.s4),
      child: Row(
        children: [
          Tooltip(
            message: 'Back to home',
            child: GlassActionButton(
              icon: Icons.arrow_back_rounded,
              onTap: onBack,
            ),
          ),
          Tooltip(
            message: 'Reload',
            child: GlassActionButton(icon: Icons.refresh, onTap: onReload),
          ),
          _iconButton(
            tooltip: 'Download Excel',
            icon: Icons.download_rounded,
            onPressed: downloading ? null : onDownload,
            size: _T.tapTarget,
          ),
          _columnsButton(compact: false),
          const SizedBox(width: _T.s4),
          // Co giãn theo chỗ trống nhưng không quá 520.
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _searchMaxWidth),
                child: TextField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  decoration: InputDecoration(
                    hintText: '$_hint  ·  Ctrl+F',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(_T.r10),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: _T.s4),
          _iconButton(
            tooltip: 'Clear filters',
            icon: Icons.cleaning_services,
            onPressed: canClear ? onClear : null,
            size: _T.tapTarget,
          ),
          const SizedBox(width: _T.s8),
          Tooltip(
            message: 'Shown / total reports',
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: _T.s12,
                vertical: _T.s8,
              ),
              decoration: BoxDecoration(
                color: _T.glass,
                borderRadius: BorderRadius.circular(_T.rPill),
                border: Border.all(color: _T.glassBorder),
              ),
              child: Text(
                '$shown / $total',
                style: const TextStyle(
                  color: _T.textPrimary,
                  fontSize: _T.fsMd,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: _T.s8),
        ],
      ),
    );
  }

  Widget _buildCompact() {
    const glassPadding = EdgeInsets.symmetric(horizontal: 2);

    return Padding(
      padding: const EdgeInsets.all(_T.s4),
      child: Row(
        children: [
          Tooltip(
            message: 'Back to home',
            child: GlassActionButton(
              icon: Icons.arrow_back_rounded,
              onTap: onBack,
              size: 18,
              padding: glassPadding,
            ),
          ),
          Tooltip(
            message: 'Reload',
            child: GlassActionButton(
              icon: Icons.refresh,
              onTap: onReload,
              size: 18,
              padding: glassPadding,
            ),
          ),
          _iconButton(
            tooltip: 'Download Excel',
            icon: Icons.download_rounded,
            onPressed: downloading ? null : onDownload,
            size: _T.tapTargetCompact,
          ),
          _columnsButton(compact: true),
          const SizedBox(width: _T.s4),
          Expanded(
            child: TextField(
              controller: searchController,
              focusNode: searchFocusNode,
              style: const TextStyle(fontSize: _T.fsMd),
              decoration: InputDecoration(
                hintText: _hint,
                hintStyle: const TextStyle(fontSize: _T.fsMd),
                prefixIcon: const Icon(Icons.search, size: 18),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: _T.tapTargetCompact,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_T.r10),
                ),
              ),
            ),
          ),
          _iconButton(
            tooltip: 'Clear filters',
            icon: Icons.cleaning_services,
            onPressed: canClear ? onClear : null,
            size: _T.tapTargetCompact,
          ),
        ],
      ),
    );
  }

  Widget _columnsButton({required bool compact}) {
    if (compact) {
      return _iconButton(
        tooltip: 'Columns: show / hide / reorder',
        icon: Icons.view_column_outlined,
        onPressed: onColumns,
        size: _T.tapTargetCompact,
      );
    }
    return Tooltip(
      message: 'Show / hide / reorder columns',
      child: TextButton.icon(
        onPressed: onColumns,
        icon: const Icon(Icons.view_column_outlined, size: 20),
        label: const Text('Columns'),
        style: TextButton.styleFrom(
          foregroundColor: _T.iconMuted,
          minimumSize: const Size(0, _T.tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: _T.s8),
          textStyle: const TextStyle(
            fontSize: _T.fsMd,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _iconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    required double size,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      icon: Icon(icon, size: size >= _T.tapTarget ? 22 : 20),
      color: _T.action,
      disabledColor: _T.textMuted,
    );
  }
}
