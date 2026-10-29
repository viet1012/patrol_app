import 'package:flutter/material.dart';

import 'package:chuphinh/features/fixed_asset/fixed_asset_audit_flow.dart';

/// Banner trên camera ở chế độ chờ QR mới:
/// "Đang chờ QR mới {mã máy} → {AA thực tế}" + nút thoát.
class FixedAssetAwaitingLabelBanner extends StatelessWidget {
  final FixedAssetAwaitingLabel awaiting;
  final VoidCallback onExit;

  const FixedAssetAwaitingLabelBanner({
    super.key,
    required this.awaiting,
    required this.onExit,
  });

  static const Color _violet = Color(0xFFA78BFA);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 2, 4),
      decoration: BoxDecoration(
        color: const Color(0xE6111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _violet.withValues(alpha: .8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: _violet, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Đang chờ QR mới ${awaiting.machineCode} → '
              '${awaiting.actualPositionAA}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Thoát chế độ chờ',
            onPressed: onExit,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

/// "Không phải {mã máy}. Thoát chế độ chờ?" Pop true = thoát.
class FixedAssetExitAwaitingDialog extends StatelessWidget {
  final String machineCode;

  const FixedAssetExitAwaitingDialog({super.key, required this.machineCode});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: Text(
        'Không phải $machineCode. Thoát chế độ chờ?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: Colors.white70),
          child: const Text('Tiếp tục chờ'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFA78BFA),
            foregroundColor: Colors.black,
          ),
          child: const Text(
            'Thoát',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
