import 'package:flutter/material.dart';

import 'package:chuphinh/features/fixed_asset/fixed_asset_audit_flow.dart';

/// Dialog "Máy đã dời?" cho máy đang chờ in lại tem: vị trí tem / vị trí
/// chọn khác vị trí thực tế đã ghi nhận. Pop true = "Xác nhận đã dời"
/// (backend cập nhật vị trí thực tế + vị trí tem, vẫn cần in lại),
/// false = "Hủy".
class FixedAssetReprintMoveDialog extends StatelessWidget {
  final FixedAssetReprintMovePrompt prompt;

  const FixedAssetReprintMoveDialog({super.key, required this.prompt});

  static const Color _amber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    const valueStyle = TextStyle(
      color: _amber,
      fontWeight: FontWeight.w900,
    );

    return Dialog(
      backgroundColor: const Color(0xFF1F2937),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: _amber.withOpacity(.6)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.move_down_rounded, color: _amber, size: 22),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Máy đã dời vị trí?',
                      style: TextStyle(
                        color: _amber,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                prompt.machineCode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (prompt.faName.isNotEmpty)
                Text(
                  prompt.faName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.65),
                    fontSize: 13,
                  ),
                ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    color: Colors.white.withOpacity(.9),
                    fontSize: 14,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'Máy đang ghi nhận ở '),
                    TextSpan(
                      text: prompt.recordedLabel ?? '(không rõ)',
                      style: valueStyle,
                    ),
                    const TextSpan(text: ', bạn đang ở '),
                    TextSpan(text: prompt.selectedLabel, style: valueStyle),
                    const TextSpan(text: '. Xác nhận máy đã dời?'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Xác nhận: cập nhật vị trí thực tế theo vị trí đang ở, máy vẫn '
                'cần in lại QR.',
                style: TextStyle(
                  color: Colors.white.withOpacity(.6),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(.3)),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: _amber,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Xác nhận đã dời',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
