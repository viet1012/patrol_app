import 'package:flutter/material.dart';

import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_models.dart';
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_strings.dart';
import 'package:chuphinh/features/fixed_asset/reprint/widgets/fixed_asset_reprint_card.dart'
    show FixedAssetReprintColors;

/// Một máy chờ thay QR: mã, tên, loại việc + cách quét, trạng thái trong
/// phiên (đã quét QR cũ / đã xong). Bấm -> màn "Việc cần làm".
class FixedAssetReplaceTaskTile extends StatelessWidget {
  final FixedAssetReplaceTask task;
  final bool done;
  final bool oldScanned;
  final VoidCallback? onTap;

  const FixedAssetReplaceTaskTile({
    super.key,
    required this.task,
    this.done = false,
    this.oldScanned = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final missing = task.kind == FixedAssetReplaceKind.missingQr;
    final kindText = missing
        ? FixedAssetReplaceStrings.kindMissing
        : FixedAssetReplaceStrings.kindWrong(task.oldQrLabel);
    final stepText = done
        ? FixedAssetReplaceStrings.done
        : oldScanned
        ? FixedAssetReplaceStrings.oldScanned
        : missing
        ? FixedAssetReplaceStrings.stepMissing
        : FixedAssetReplaceStrings.stepWrong;
    final stepColor = done
        ? FixedAssetReprintColors.newQr
        : oldScanned
        ? const Color(0xFF4DD0E1)
        : Colors.white.withValues(alpha: .75);

    return Opacity(
      opacity: done ? .6 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: done
                    ? FixedAssetReprintColors.newQr.withValues(alpha: .5)
                    : Colors.white.withValues(alpha: .14),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  done
                      ? Icons.check_circle_rounded
                      : missing
                      ? Icons.qr_code_2_rounded
                      : Icons.swap_horiz_rounded,
                  size: 22,
                  color: done
                      ? FixedAssetReprintColors.newQr
                      : FixedAssetReprintColors.amber,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task.machineCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          decoration: done ? TextDecoration.lineThrough : null,
                          decorationColor: Colors.white70,
                        ),
                      ),
                      if (task.faName.isNotEmpty)
                        Text(
                          task.faName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .6),
                            fontSize: 12.5,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        kindText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FixedAssetReprintColors.amber,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        stepText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: stepColor,
                          fontSize: 13,
                          fontWeight: done || oldScanned
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_right_rounded, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
