import 'package:flutter/material.dart';

import 'package:chuphinh/features/fixed_asset/summary/widgets/fixed_asset_summary_widgets.dart';

/// Một cột của [FixedAssetSummaryTable].
class FixedAssetSummaryTableColumn {
  final String label;

  /// Bề rộng tối thiểu; đủ chỗ thì các cột giãn theo tỉ lệ.
  final double minWidth;

  /// Căn phải (cột số).
  final bool numeric;

  const FixedAssetSummaryTableColumn(
    this.label,
    this.minWidth, {
    this.numeric = false,
  });
}

/// Một dòng: mỗi ô một widget (thường là Text một dòng). [onTap]: bấm cả
/// dòng.
class FixedAssetSummaryTableRow {
  final List<Widget> cells;

  /// Header nhóm: [title] trải hết bề ngang bảng, nền khác dòng thường.
  final Widget? title;
  final VoidCallback? onTap;

  const FixedAssetSummaryTableRow(this.cells, {this.onTap}) : title = null;

  const FixedAssetSummaryTableRow.group(Widget this.title)
    : cells = const <Widget>[],
      onTap = null;

  bool get isGroup => title != null;
}

/// Bảng chỉ xem: header sticky, thân dựng lazy ([ListView.builder] với
/// itemExtent = [rowHeight]; kéo xuống tải lại được khi đặt trong
/// RefreshIndicator). Độ rộng cột tính 1 lần theo bề rộng; bề rộng < tổng
/// [FixedAssetSummaryTableColumn.minWidth] thì cuộn ngang cả bảng (header +
/// thân), không bọc từng dòng.
class FixedAssetSummaryTable extends StatelessWidget {
  final List<FixedAssetSummaryTableColumn> columns;
  final int rowCount;

  /// Chỉ gọi cho dòng đang hiển thị.
  final FixedAssetSummaryTableRow Function(int index) rowBuilder;
  final double rowHeight;
  final double headerHeight;

  const FixedAssetSummaryTable({
    super.key,
    required this.columns,
    required this.rowCount,
    required this.rowBuilder,
    this.rowHeight = 40,
    this.headerHeight = 40,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minTotal = columns.fold<double>(0, (s, c) => s + c.minWidth);
        final available = constraints.maxWidth;
        final fits = available >= minTotal;
        final scale = fits ? available / minTotal : 1.0;
        final widths = [for (final c in columns) c.minWidth * scale];
        final headerStyle = TextStyle(
          color: Colors.white.withValues(alpha: .55),
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        );
        final rowDecoration = BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: .06)),
          ),
        );

        final header = DecoratedBox(
          decoration: BoxDecoration(
            color: FixedAssetSummaryColors.surface,
            border: Border(
              bottom: BorderSide(color: FixedAssetSummaryColors.border),
            ),
          ),
          child: Row(
            children: [
              for (var i = 0; i < columns.length; i++)
                _cell(
                  width: widths[i],
                  numeric: columns[i].numeric,
                  child: Text(
                    columns[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: headerStyle,
                  ),
                  height: headerHeight,
                ),
            ],
          ),
        );

        Widget row(BuildContext context, int index) {
          final row = rowBuilder(index);
          final Widget content = row.isGroup
              ? Container(
                  color: FixedAssetSummaryColors.accent.withValues(alpha: .10),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.centerLeft,
                  child: row.title,
                )
              : Row(
                  children: [
                    for (var i = 0; i < columns.length; i++)
                      _cell(
                        width: widths[i],
                        numeric: columns[i].numeric,
                        child: i < row.cells.length
                            ? row.cells[i]
                            : const SizedBox.shrink(),
                      ),
                  ],
                );
          final decorated = DecoratedBox(
            decoration: rowDecoration,
            child: content,
          );
          if (row.onTap == null) return decorated;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: row.onTap,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: decorated,
            ),
          );
        }

        final table = SizedBox(
          width: fits ? available : minTotal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  itemExtent: rowHeight,
                  itemCount: rowCount,
                  itemBuilder: row,
                ),
              ),
            ],
          ),
        );
        if (fits) return table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: table,
        );
      },
    );
  }

  static Widget _cell({
    required double width,
    required bool numeric,
    required Widget child,
    double? height,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Align(
          alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
          child: child,
        ),
      ),
    );
  }
}
