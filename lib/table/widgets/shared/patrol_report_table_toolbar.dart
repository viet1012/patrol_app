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
}
