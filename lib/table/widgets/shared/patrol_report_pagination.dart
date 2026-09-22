import 'package:flutter/material.dart';

class PatrolReportPagination extends StatelessWidget {
  final int page;
  final int rowsPerPage;
  final int totalItems;
  final int totalPages;
  final List<int> pageSizeOptions;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onRowsPerPageChanged;

  const PatrolReportPagination({
    super.key,
    required this.page,
    required this.rowsPerPage,
    required this.totalItems,
    required this.totalPages,
    required this.pageSizeOptions,
    required this.onPageChanged,
    required this.onRowsPerPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    const controlBg = Color(0xFF172A33);

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
}
