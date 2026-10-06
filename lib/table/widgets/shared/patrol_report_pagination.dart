import 'package:flutter/material.dart';

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

  static const _controlBg = Color(0xFF172A33);

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact();

    const controlBg = _controlBg;

    return Container(
      color: const Color(0xFF0F2027),
      child: Row(
        children: [
          Text(
            'Rows: $totalItems',
            style: const TextStyle(color: Colors.white70),
          ),
          const Spacer(),
          Text(
            'Page ${page + 1} / $totalPages',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
            color: Colors.white,
            disabledColor: Colors.white38,
          ),
          IconButton(
            onPressed: page + 1 < totalPages
                ? () => onPageChanged(page + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
            color: Colors.white,
            disabledColor: Colors.white38,
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: controlBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: DropdownButton<int>(
              value: rowsPerPage,
              underline: const SizedBox(),
              dropdownColor: controlBg,
              iconEnabledColor: Colors.white,
              style: const TextStyle(color: Colors.white),
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
        ],
      ),
    );
  }

  Widget _buildCompact() {
    const small = TextStyle(color: Colors.white70, fontSize: 12);
    final rowsText = grandTotal == null
        ? 'Rows: $totalItems'
        : 'Rows: $totalItems / $grandTotal';

    return Container(
      color: const Color(0xFF0F2027),
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          _compactNavButton(
            icon: Icons.chevron_left,
            onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
          ),
          _compactNavButton(
            icon: Icons.chevron_right,
            onPressed: page + 1 < totalPages
                ? () => onPageChanged(page + 1)
                : null,
          ),
          const SizedBox(width: 4),
          Container(
            height: 30,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: _controlBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: DropdownButton<int>(
              value: rowsPerPage,
              isDense: true,
              iconSize: 18,
              underline: const SizedBox(),
              dropdownColor: _controlBg,
              iconEnabledColor: Colors.white,
              style: const TextStyle(color: Colors.white, fontSize: 12),
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
        ],
      ),
    );
  }

  Widget _compactNavButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 36),
      color: Colors.white,
      disabledColor: Colors.white38,
    );
  }
}
