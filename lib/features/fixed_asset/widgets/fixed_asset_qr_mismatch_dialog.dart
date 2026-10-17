import 'package:flutter/material.dart';

import 'package:chuphinh/features/fixed_asset/fixed_asset_audit_flow.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_location.dart';

/// Dialog "QR không khớp vị trí đang chọn" (MANUAL): VỊ TRÍ ĐANG CHỌN vs
/// VỊ TRÍ TRÊN QR. Cùng bố cục với [FixedAssetMismatchDialog] nhưng màu tím
/// + icon QR để không nhầm với "Sai vị trí máy" (MASTER).
/// Pop true = "Vẫn lưu (đánh dấu in lại QR)", false = "Bỏ qua".
class FixedAssetQrMismatchDialog extends StatelessWidget {
  final String machineCode;
  final String faName;
  final FixedAssetAuditLocation selected;
  final FixedAssetQrLocationCheck qr;

  const FixedAssetQrMismatchDialog({
    super.key,
    required this.machineCode,
    required this.faName,
    required this.selected,
    required this.qr,
  });

  static const Color _violet = Color(0xFFA78BFA);

  @override
  Widget build(BuildContext context) {
    final qrPositionA = qr.positionA;
    return Dialog(
      backgroundColor: const Color(0xFF1F2937),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: _violet.withOpacity(.6)),
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
                  Icon(Icons.qr_code_2_rounded, color: _violet, size: 22),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'QR không khớp vị trí đang chọn',
                      style: TextStyle(
                        color: _violet,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                machineCode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (faName.isNotEmpty)
                Text(
                  faName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.65),
                    fontSize: 13,
                  ),
                ),
              const SizedBox(height: 12),
              _locationBlock(
                title: 'VỊ TRÍ ĐANG CHỌN',
                line1:
                    '${fixedAssetDash(selected.fac)} · ${fixedAssetDash(selected.floor)}',
                line2:
                    '${fixedAssetDash(selected.positionA)} / '
                    '${fixedAssetDash(selected.positionAA)}',
                color: Colors.white.withOpacity(.55),
                background: Colors.white.withOpacity(.05),
              ),
              const SizedBox(height: 8),
              _locationBlock(
                title: 'VỊ TRÍ TRÊN QR',
                line1: fixedAssetDash(qr.floor ?? ''),
                line2: qrPositionA == null
                    ? fixedAssetDash(qr.positionAA ?? '')
                    : '${fixedAssetDash(qrPositionA)} / '
                          '${fixedAssetDash(qr.positionAA ?? '')}',
                color: _violet,
                background: _violet.withOpacity(.10),
              ),
              const SizedBox(height: 12),
              Text(
                'Vị trí trên QR khác vị trí đang chọn. Kết quả vẫn được lưu '
                'và máy này sẽ được đánh dấu cần in lại QR.',
                style: TextStyle(
                  color: Colors.white.withOpacity(.8),
                  fontSize: 13,
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
                        'Bỏ qua',
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
                        backgroundColor: _violet,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Vẫn lưu (đánh dấu in lại QR)',
                        textAlign: TextAlign.center,
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

  Widget _locationBlock({
    required String title,
    required String line1,
    String line2 = '',
    required Color color,
    required Color background,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            line1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (line2.isNotEmpty)
            Text(
              line2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
