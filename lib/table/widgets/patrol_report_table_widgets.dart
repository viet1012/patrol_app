import 'package:flutter/material.dart';

import '../../widget/glass_action_button.dart';

class PatrolReportHeaderFilterCell extends StatelessWidget {
  final String label;
  final double width;
  final TextAlign align;
  final bool hasFilter;
  final VoidCallback onFilterTap;
  final LayerLink layerLink;

  const PatrolReportHeaderFilterCell({
    super.key,
    required this.label,
    required this.width,
    required this.onFilterTap,
    required this.layerLink,
    this.align = TextAlign.left,
    this.hasFilter = false,
  });

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: layerLink,
      child: Container(
        width: width,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          border: Border(right: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: align,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            InkWell(
              onTap: onFilterTap,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  hasFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
                  size: 18,
                  color: hasFilter ? Colors.blue : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PatrolReportHoverableRow extends StatefulWidget {
  final double height;
  final Color background;
  final Widget child;
  final VoidCallback? onDoubleTap;

  const PatrolReportHoverableRow({
    super.key,
    required this.height,
    required this.background,
    required this.child,
    this.onDoubleTap,
  });

  @override
  State<PatrolReportHoverableRow> createState() =>
      _PatrolReportHoverableRowState();
}

class _PatrolReportHoverableRowState extends State<PatrolReportHoverableRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final background = _hover
        ? Colors.blueGrey.withOpacity(0.06)
        : widget.background;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onDoubleTap: widget.onDoubleTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: widget.height,
          color: background,
          child: widget.child,
        ),
      ),
    );
  }
}

class PatrolReportTableToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final int total;
  final int shown;
  final bool canClear;
  final bool downloading;
  final VoidCallback onBack;
  final VoidCallback onReload;
  final VoidCallback onDownload;
  final VoidCallback onClear;

  const PatrolReportTableToolbar({
    super.key,
    required this.searchController,
    required this.total,
    required this.shown,
    required this.canClear,
    required this.downloading,
    required this.onBack,
    required this.onReload,
    required this.onDownload,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GlassActionButton(icon: Icons.arrow_back_rounded, onTap: onBack),
        GlassActionButton(icon: Icons.refresh, onTap: onReload),
        IconButton(
          tooltip: 'Download Excel',
          onPressed: downloading ? null : onDownload,
          icon: const Icon(Icons.download_rounded, color: Colors.greenAccent),
        ),
        Expanded(
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search (stt, type, group, comment, PIC...)',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Clear filters',
          onPressed: canClear ? onClear : null,
          icon: const Icon(
            Icons.cleaning_services,
            color: Colors.greenAccent,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            '$shown / $total',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class PatrolReportTableViewport extends StatelessWidget {
  final ScrollController horizontalController;
  final ScrollController verticalController;
  final double totalWidth;
  final Widget header;
  final int itemCount;
  final IndexedWidgetBuilder rowBuilder;

  const PatrolReportTableViewport({
    super.key,
    required this.horizontalController,
    required this.verticalController,
    required this.totalWidth,
    required this.header,
    required this.itemCount,
    required this.rowBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: horizontalController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: horizontalController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: Column(
              children: [
                header,
                const Divider(height: 1, thickness: 1),
                Expanded(
                  child: PrimaryScrollController(
                    controller: verticalController,
                    child: Scrollbar(
                      controller: verticalController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: verticalController,
                        primary: false,
                        itemCount: itemCount,
                        itemBuilder: rowBuilder,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
