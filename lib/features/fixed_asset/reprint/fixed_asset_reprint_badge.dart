import 'package:flutter/material.dart';

import 'package:chuphinh/core/api/fixed_asset_backend.dart';

/// Badge số máy cần in lại QR (mọi xưởng) ở menu home. Tải một lần mỗi khi
/// được tạo (đổi `key` để tải lại); đang tải / lỗi / 0 thì ẩn.
class FixedAssetReprintBadge extends StatefulWidget {
  final Color color;
  final FixedAssetBackend api;

  const FixedAssetReprintBadge({
    super.key,
    required this.color,
    this.api = const FixedAssetBackend(),
  });

  @override
  State<FixedAssetReprintBadge> createState() => _FixedAssetReprintBadgeState();
}

class _FixedAssetReprintBadgeState extends State<FixedAssetReprintBadge> {
  int? _count;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.api.fetchQrMismatch();
      if (mounted) setState(() => _count = rows.length);
    } catch (_) {
      // Lỗi: ẩn badge.
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _count;
    if (count == null || count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      constraints: const BoxConstraints(minWidth: 26),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
