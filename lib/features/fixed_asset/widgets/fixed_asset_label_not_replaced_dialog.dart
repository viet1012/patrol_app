import 'package:flutter/material.dart';

import 'package:chuphinh/features/fixed_asset/fixed_asset_audit_flow.dart';

/// Popup "QR chưa được thay": máy chờ in lại QR vừa được quét bằng QR cũ.
/// Pop [FixedAssetLabelNotReplacedAction]: "Quét QR mới" (chính), "Để sau".
class FixedAssetLabelNotReplacedDialog extends StatelessWidget {
  final FixedAssetLabelNotReplacedPrompt prompt;

  const FixedAssetLabelNotReplacedDialog({super.key, required this.prompt});

  static const Color _amber = Color(0xFFF59E0B);

  void _pop(BuildContext context, FixedAssetLabelNotReplacedAction action) =>
      Navigator.of(context).pop(action);

  @override
  Widget build(BuildContext context) {
    final reprint = prompt.reprint;
    final hasAct = reprint != null && reprint.hasAct;
    final actual = hasAct ? reprint.actLabel : '(không rõ)';
    final String label;
    if (reprint == null || reprint.labelUnknown) {
      label = '(không rõ)';
    } else if (!reprint.hasLabel) {
      label = 'Chưa có QR';
    } else {
      label = '${reprint.qrLabel} (cũ)';
    }

    const valueStyle = TextStyle(color: _amber, fontWeight: FontWeight.w900);
    final textStyle = TextStyle(
      color: Colors.white.withOpacity(.9),
      fontSize: 14,
      height: 1.4,
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
                  Icon(Icons.print_rounded, color: _amber, size: 22),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'QR chưa được thay',
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
                  style: textStyle,
                  children: [
                    const TextSpan(text: 'Vị trí thực tế: '),
                    TextSpan(text: actual, style: valueStyle),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  style: textStyle,
                  children: [
                    const TextSpan(text: 'QR đang dán: '),
                    TextSpan(
                      text: label,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.75),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'In QR mới cho $actual, dán lên máy rồi bấm Quét QR mới',
                style: TextStyle(
                  color: Colors.white.withOpacity(.6),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _pop(
                  context,
                  FixedAssetLabelNotReplacedAction.scanNewLabel,
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                label: const Text(
                  'Quét QR mới',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _amber,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () =>
                    _pop(context, FixedAssetLabelNotReplacedAction.later),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(.3)),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Để sau',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
