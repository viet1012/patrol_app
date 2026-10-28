import 'package:flutter/material.dart';

/// Badge số máy cần in lại QR (mọi xưởng) ở menu home. Chỉ hiển thị, số do
/// màn cha tải; `null` (đang tải / lỗi) hoặc 0 thì ẩn.
class FixedAssetReprintBadge extends StatelessWidget {
  final Color color;
  final int? count;

  const FixedAssetReprintBadge({
    super.key,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final count = this.count;
    if (count == null || count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      constraints: const BoxConstraints(minWidth: 26),
      decoration: BoxDecoration(
        color: color,
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
