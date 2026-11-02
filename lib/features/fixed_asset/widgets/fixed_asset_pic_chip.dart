import 'package:flutter/material.dart';

import 'package:chuphinh/core/models/fixed_asset_pic.dart';

/// Chip PIC của một máy: icon người + "PIC: <phần trước @>", nền cyan nhạt
/// (cùng màu nhấn dropdown PIC). Không có PIC: chip xám "Chưa có PIC".
class FixedAssetPicChip extends StatelessWidget {
  /// Email PIC; null / rỗng = chưa có PIC.
  final String? email;

  const FixedAssetPicChip({super.key, required this.email});

  static const Color _accent = Color(0xFF4DD0E1);

  @override
  Widget build(BuildContext context) {
    final value = email?.trim() ?? '';
    final hasPic = value.isNotEmpty;
    final color = hasPic ? _accent : Colors.white.withValues(alpha: .5);

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 2, 8, 2),
      decoration: BoxDecoration(
        color: hasPic
            ? _accent.withValues(alpha: .14)
            : Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: hasPic
              ? _accent.withValues(alpha: .5)
              : Colors.white.withValues(alpha: .18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              hasPic ? 'PIC: ${FixedAssetPic.nameOf(value)}' : 'Chưa có PIC',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: hasPic ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
