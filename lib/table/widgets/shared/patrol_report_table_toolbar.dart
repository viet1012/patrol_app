import 'package:flutter/material.dart';

import '../../../widget/glass_action_button.dart';

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

  /// Mobile: nút 36x36, bỏ ô đếm (hiển thị ở pagination).
  final bool compact;

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
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact();

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
          icon: const Icon(Icons.cleaning_services, color: Colors.greenAccent),
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

  Widget _buildCompact() {
    const glassPadding = EdgeInsets.symmetric(horizontal: 2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          GlassActionButton(
            icon: Icons.arrow_back_rounded,
            onTap: onBack,
            size: 18,
            padding: glassPadding,
          ),
          GlassActionButton(
            icon: Icons.refresh,
            onTap: onReload,
            size: 18,
            padding: glassPadding,
          ),
          _compactIconButton(
            tooltip: 'Download Excel',
            icon: Icons.download_rounded,
            onPressed: downloading ? null : onDownload,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: searchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search (stt, type, group, comment, PIC...)',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 36,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          _compactIconButton(
            tooltip: 'Clear filters',
            icon: Icons.cleaning_services,
            onPressed: canClear ? onClear : null,
          ),
        ],
      ),
    );
  }

  Widget _compactIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      icon: Icon(icon, size: 20, color: Colors.greenAccent),
    );
  }
}
