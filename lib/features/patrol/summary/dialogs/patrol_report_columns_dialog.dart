import 'package:chuphinh/features/patrol/summary/core/patrol_report_column_layout.dart';
import 'package:chuphinh/features/patrol/summary/core/patrol_report_table_controller.dart';
import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';
import 'package:flutter/material.dart';

typedef _T = PatrolReportTokens;

/// Ẩn/hiện + kéo thả thứ tự cột. Thay đổi áp dụng & lưu ngay.
class PatrolReportColumnsDialog extends StatelessWidget {
  final PatrolReportTableController controller;

  const PatrolReportColumnsDialog({super.key, required this.controller});

  static Future<void> show(
    BuildContext context,
    PatrolReportTableController controller,
  ) {
    return showDialog<void>(
      context: context,
      builder: (_) => PatrolReportColumnsDialog(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _T.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(_T.s16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_T.r14),
        side: const BorderSide(color: _T.glassBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 600),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => _content(context),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final all = controller.orderedColumns;
    final pinned = [
      for (final c in all)
        if (PatrolReportColumnLayout.isPinned(c.label)) c,
    ];
    final movable = [
      for (final c in all)
        if (!PatrolReportColumnLayout.isPinned(c.label)) c,
    ];

    Widget tile(String label, String tooltip, {Widget? trailing}) {
      final locked = PatrolReportColumnLayout.lockedLabels.contains(label);
      return Material(
        color: Colors.transparent,
        child: CheckboxListTile(
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.only(left: _T.s8, right: _T.s4),
          value: !controller.isColumnHidden(label),
          onChanged: locked
              ? null
              : (v) => controller.setColumnVisible(label, v ?? true),
          title: Text(
            label,
            style: const TextStyle(
              color: _T.textPrimary,
              fontSize: _T.fsMd,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: tooltip == label
              ? null
              : Text(
                  tooltip,
                  style: const TextStyle(
                    color: _T.textMuted,
                    fontSize: _T.fsXs,
                  ),
                ),
          secondary: trailing,
          activeColor: _T.accentStrong,
          side: const BorderSide(color: _T.textSecondary),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(_T.s16, _T.s16, _T.s8, _T.s4),
          child: Row(
            children: [
              const Icon(Icons.view_column_outlined, color: _T.accent),
              const SizedBox(width: _T.s8),
              const Expanded(
                child: Text(
                  'Columns',
                  style: TextStyle(
                    color: _T.textPrimary,
                    fontSize: _T.fsXl,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                color: _T.textSecondary,
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: _T.s16),
          child: Text(
            'Tick to show/hide. Drag ≡ to reorder. STT and QR stay pinned on the left.',
            style: TextStyle(color: _T.textSecondary, fontSize: _T.fsSm),
          ),
        ),
        const SizedBox(height: _T.s8),
        for (final c in pinned)
          tile(
            c.label,
            c.tooltip,
            trailing: const Tooltip(
              message: 'Pinned',
              child: Icon(
                Icons.push_pin_outlined,
                size: 18,
                color: _T.textMuted,
              ),
            ),
          ),
        const Divider(height: 1, color: _T.glassBorder),
        Flexible(
          child: ReorderableListView.builder(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            itemCount: movable.length,
            onReorder: controller.reorderColumn,
            proxyDecorator: (child, _, _) => Material(
              color: _T.surface,
              elevation: 4,
              borderRadius: BorderRadius.circular(_T.r10),
              child: child,
            ),
            itemBuilder: (context, i) {
              final c = movable[i];
              return KeyedSubtree(
                key: ValueKey(c.label),
                child: tile(
                  c.label,
                  c.tooltip,
                  trailing: ReorderableDragStartListener(
                    index: i,
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Padding(
                        padding: EdgeInsets.all(_T.s8),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: _T.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1, color: _T.glassBorder),
        Padding(
          padding: const EdgeInsets.all(_T.s8),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: controller.hasCustomColumns
                    ? controller.resetColumns
                    : null,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Reset columns'),
                style: TextButton.styleFrom(
                  foregroundColor: _T.accent,
                  disabledForegroundColor: _T.textMuted,
                  minimumSize: const Size(0, _T.tapTarget),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: _T.accentStrong,
                  minimumSize: const Size(0, _T.tapTarget),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
