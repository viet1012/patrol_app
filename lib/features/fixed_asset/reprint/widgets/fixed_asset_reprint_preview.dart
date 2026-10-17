import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:chuphinh/features/fixed_asset/reprint/fixed_asset_reprint_controller.dart';
import 'package:chuphinh/features/fixed_asset/reprint/fixed_asset_reprint_strings.dart';
import 'package:chuphinh/features/fixed_asset/reprint/widgets/fixed_asset_reprint_card.dart';

/// Xem lớn QR mới (~240 px) + mã máy / vị trí, nút "Tải PNG" và "In".
Future<void> showFixedAssetReprintPreview(
  BuildContext context, {
  required FixedAssetReprintItem item,
  required Future<void> Function() onDownload,
  required Future<void> Function() onPrint,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FixedAssetReprintColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: item.qrContent,
                    version: QrVersions.auto,
                    size: 240,
                    padding: const EdgeInsets.all(12),
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    gapless: true,
                  ),
                  // Đúng chuỗi đã mã hóa trong QR (tên máy nằm trong chuỗi).
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 264),
                    child: Text(
                      item.qrContent,
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text(FixedAssetReprintStrings.downloadPng),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: .3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onPrint,
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text(FixedAssetReprintStrings.print),
                    style: FilledButton.styleFrom(
                      backgroundColor: FixedAssetReprintColors.coral,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
