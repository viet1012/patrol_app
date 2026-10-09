import 'package:flutter/material.dart';

import 'package:chuphinh/features/patrol/summary/reports/widgets/summary_grid_style.dart';

/// Nhãn nhóm cột vẽ phía trên header.
class SummaryGridGroupHeader {
  final String label;
  final int startCol;
  final int colSpan;
  final Color? backgroundColor;
  final Color? borderColor;

  const SummaryGridGroupHeader({
    required this.label,
    required this.startCol,
    required this.colSpan,
    this.backgroundColor,
    this.borderColor,
  });
}

/// Màu nền + viền đậm 2 bên cho các cột [startCol]..[endCol] (tính cả 2 đầu).
class ColumnGroupStyle {
  final int startCol;
  final int endCol;
  final Color cellBg;
  final Color borderColor;

  const ColumnGroupStyle({
    required this.startCol,
    required this.endCol,
    required this.cellBg,
    required this.borderColor,
  });

  bool contains(int col) => col >= startCol && col <= endCol;
}

class SummaryGridRow {
  final bool isTotal;
  final List<Object?> cells;

  const SummaryGridRow({required this.isTotal, required this.cells});
}

/// Bảng kiểu Excel: title bar, group header, header cột, các dòng dữ liệu.
///
/// Phần dòng dữ liệu nằm trong [Expanded] + cuộn dọc, nên widget cha PHẢI
/// giới hạn chiều cao (vd. bọc trong `SizedBox(height: ...)`).
class SummaryGridTable extends StatelessWidget {
  final String? titleLeft;
  final String? titleCenter;
  final Widget? titleRight;
  final List<String> columns;
  final List<SummaryGridRow> rows;
  final List<SummaryGridGroupHeader> groupedHeaders;
  final List<ColumnGroupStyle> columnGroups;

  const SummaryGridTable({
    super.key,
    this.titleLeft,
    this.titleCenter,
    this.titleRight,
    required this.columns,
    required this.rows,
    this.groupedHeaders = const [],
    this.columnGroups = const [],
  });

  Map<int, TableColumnWidth> _buildColumnWidths() {
    return {
      for (var i = 0; i < columns.length; i++)
        i: FixedColumnWidth(SummaryGridStyle.columnWidth(columns[i])),
    };
  }

  double _columnWidthAt(int index) {
    return SummaryGridStyle.columnWidth(columns[index]);
  }

  double _leftOffsetOfColumn(int startIndex) {
    var offset = 0.0;
    for (var i = 0; i < startIndex; i++) {
      offset += _columnWidthAt(i);
    }
    return offset;
  }

  double _spanWidth(SummaryGridGroupHeader header) {
    var width = 0.0;
    for (var i = 0; i < header.colSpan; i++) {
      width += _columnWidthAt(header.startCol + i);
    }
    return width;
  }

  ColumnGroupStyle? _groupOf(int index) {
    for (final group in columnGroups) {
      if (group.contains(index)) return group;
    }
    return null;
  }

  Color? _cellBackground(int index) {
    if (index == 0) return SummaryGridStyle.firstColumnBg;
    return _groupOf(index)?.cellBg;
  }

  Border _cellBorder(int index) {
    const normal = BorderSide(color: SummaryGridStyle.borderColor);
    const plain = Border(right: normal, bottom: normal);

    if (index == 0) return plain;

    final group = _groupOf(index);
    if (group == null) return plain;

    final strong = BorderSide(color: group.borderColor, width: 2);
    if (index == group.startCol) {
      return Border(left: strong, right: normal, bottom: normal);
    }
    if (index == group.endCol) {
      return Border(right: strong, bottom: normal);
    }
    return plain;
  }

  String _displayValue(Object? cell) {
    if (cell == null) return '-';
    if (cell is num && cell == 0) return '-';

    final text = cell.toString().trim();
    return text.isEmpty ? '-' : text;
  }

  @override
  Widget build(BuildContext context) {
    final columnWidths = _buildColumnWidths();

    return Container(
      decoration: BoxDecoration(
        color: SummaryGridStyle.tableBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SummaryGridStyle.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GridTitleBar(
            titleLeft: titleLeft,
            titleCenter: titleCenter,
            titleRight: titleRight,
          ),
          _buildGroupHeader(columnWidths),
          _buildColumnHeader(columnWidths),
          Expanded(
            child: SingleChildScrollView(child: _buildBody(columnWidths)),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(Map<int, TableColumnWidth> columnWidths) {
    if (groupedHeaders.isEmpty) {
      return Container(
        height: SummaryGridStyle.groupHeaderHeight,
        decoration: const BoxDecoration(
          color: SummaryGridStyle.groupedHeaderBg,
          border: Border(
            bottom: BorderSide(color: SummaryGridStyle.borderColor),
          ),
        ),
      );
    }

    return SizedBox(
      height: SummaryGridStyle.groupHeaderHeight,
      child: Stack(
        children: [
          Table(
            columnWidths: columnWidths,
            border: const TableBorder(
              horizontalInside: BorderSide(
                color: SummaryGridStyle.borderColor,
                width: 1,
              ),
              verticalInside: BorderSide(color: SummaryGridStyle.borderColor),
            ),
            children: [
              TableRow(
                children: List.generate(
                  columns.length,
                  (_) => Container(
                    height: SummaryGridStyle.groupHeaderHeight,
                    color: SummaryGridStyle.groupedHeaderBg,
                  ),
                ),
              ),
            ],
          ),
          for (final header in groupedHeaders)
            Positioned(
              left: _leftOffsetOfColumn(header.startCol),
              top: 0,
              bottom: 0,
              width: _spanWidth(header),
              child: _buildGroupLabel(header),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupLabel(SummaryGridGroupHeader header) {
    final border = BorderSide(
      color: header.borderColor ?? SummaryGridStyle.borderColor,
      width: 2,
    );

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: header.backgroundColor ?? SummaryGridStyle.groupedHeaderBg,
        border: Border(
          left: border,
          right: border,
          bottom: const BorderSide(color: SummaryGridStyle.borderColor),
        ),
      ),
      child: Text(header.label, style: SummaryGridStyle.headerStyle),
    );
  }

  Widget _buildColumnHeader(Map<int, TableColumnWidth> columnWidths) {
    return Table(
      columnWidths: columnWidths,
      border: const TableBorder(
        horizontalInside: BorderSide(
          color: SummaryGridStyle.borderColor,
          width: 1,
        ),
        verticalInside: BorderSide(color: SummaryGridStyle.borderColor),
      ),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: SummaryGridStyle.headerBg),
          children: List.generate(columns.length, (index) {
            return Container(
              height: SummaryGridStyle.headerRowHeight,
              decoration: BoxDecoration(
                color: _cellBackground(index) ?? SummaryGridStyle.headerBg,
                border: _cellBorder(index),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: SummaryGridStyle.cellPaddingH,
              ),
              alignment: Alignment.center,
              child: Text(
                columns[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SummaryGridStyle.headerStyle,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildBody(Map<int, TableColumnWidth> columnWidths) {
    return Table(
      columnWidths: columnWidths,
      border: const TableBorder(
        horizontalInside: BorderSide(color: SummaryGridStyle.borderColor),
        verticalInside: BorderSide(color: SummaryGridStyle.borderColor),
      ),
      children: rows.map(_buildDataRow).toList(),
    );
  }

  TableRow _buildDataRow(SummaryGridRow row) {
    return TableRow(
      decoration: BoxDecoration(
        color: row.isTotal ? SummaryGridStyle.totalRowBg : Colors.white,
      ),
      children: List.generate(row.cells.length, (index) {
        final cell = row.cells[index];

        return Container(
          height: SummaryGridStyle.cellHeight,
          decoration: BoxDecoration(
            color: row.isTotal
                ? SummaryGridStyle.totalRowBg
                : (_cellBackground(index) ?? Colors.white),
            border: _cellBorder(index),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: SummaryGridStyle.cellPaddingH,
          ),
          // Số căn phải, tên căn trái.
          alignment: cell is num ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            _displayValue(cell),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: row.isTotal
                ? SummaryGridStyle.totalCellStyle
                : SummaryGridStyle.cellStyle,
          ),
        );
      }),
    );
  }
}

class _GridTitleBar extends StatelessWidget {
  final String? titleLeft;
  final String? titleCenter;
  final Widget? titleRight;

  const _GridTitleBar({this.titleLeft, this.titleCenter, this.titleRight});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: SummaryGridStyle.titleHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: SummaryGridStyle.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                titleLeft ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SummaryGridStyle.titleStyle,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                titleCenter ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SummaryGridStyle.subtitleStyle,
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              // Bảng hẹp (mobile): thu nhỏ tỉ lệ thay vì tràn.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: titleRight ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
