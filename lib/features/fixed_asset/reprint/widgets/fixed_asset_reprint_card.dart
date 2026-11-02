import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:chuphinh/features/fixed_asset/widgets/fixed_asset_pic_chip.dart';

import 'package:chuphinh/features/fixed_asset/reprint/fixed_asset_reprint_controller.dart';
import 'package:chuphinh/features/fixed_asset/reprint/fixed_asset_reprint_strings.dart';

/// Màu chung của màn "In lại QR" (theme tối + đỏ san hô của Fixed Asset).
abstract final class FixedAssetReprintColors {
  /// Màu nhấn Fixed Asset: chỉ dùng đặc cho nút "In" (nút chính duy nhất);
  /// chỗ khác dùng ở opacity thấp.
  static const coral = Color(0xFFF77368);

  /// Màu nhấn dịu (~20% pha xám) cho checkbox / "Chọn tất cả" / viền focus.
  static const coralSoft = Color(0xFFE57D76);

  /// Viền xám nhạt + chữ phụ trên nền tối (giữ tương phản đủ đọc).
  static const Color border = Color(0x33FFFFFF); // trắng 0.2
  static const Color textMuted = Color(0xCCFFFFFF); // trắng 0.8
  static const Color textDisabled = Color(0x66FFFFFF); // trắng 0.4
  static const newQr = Color(0xFF22C55E);
  static const amber = Color(0xFFF59E0B);

  /// Chip lý do: "Sai vị trí" cam, "Mất QR" vàng.
  static const orange = Color(0xFFFB923C);
  static const yellow = Color(0xFFFACC15);
  static const surface = Color(0xFF1F2937);
  static const appBar = Color(0xFF121826);
}

/// Thẻ một máy (mobile, 1 tay): bấm cả thẻ = chọn / bỏ chọn; bấm ảnh QR =
/// xem phóng to.
/// - Hàng đầu: checkbox + mã / tên máy + chip lý do ("Sai vị trí" cam /
///   "Mất QR" vàng).
/// - Dòng nổi bật: "In cho vị trí: Fac / Floor / A / AA" (nội dung QR in ra).
/// - "QR đang dán: …" chữ nhỏ, mờ (Mất QR: "Chưa có QR").
/// - Dòng phụ: PIC · người kiểm kê · thời gian.
class FixedAssetReprintCard extends StatelessWidget {
  final FixedAssetReprintItem item;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onPreview;

  const FixedAssetReprintCard({
    super.key,
    required this.item,
    required this.selected,
    required this.onToggle,
    required this.onPreview,
  });

  static final DateFormat _time = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final row = item.row;
    final meta = [
      if (row.userName.isNotEmpty) row.userName,
      if (row.updatedAt != null) _time.format(row.updatedAt!),
    ].join(' · ');

    final String printValue;
    final Color printColor;
    switch (item.state) {
      case FixedAssetReprintQrState.ready:
        printValue = item.newLocationLabel;
        printColor = FixedAssetReprintColors.newQr;
      case FixedAssetReprintQrState.resolving:
        printValue = FixedAssetReprintStrings.resolvingLocation;
        printColor = Colors.white70;
      case FixedAssetReprintQrState.missing:
        printValue = FixedAssetReprintStrings.missingLocation;
        printColor = FixedAssetReprintColors.amber;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: item.isReady ? onToggle : null,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(4, 8, 10, 10),
          // Chọn: viền màu nhấn + nền nhấn rất nhạt.
          decoration: BoxDecoration(
            color: selected
                ? FixedAssetReprintColors.coral.withValues(alpha: .07)
                : Colors.white.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? FixedAssetReprintColors.coral.withValues(alpha: .6)
                  : Colors.white.withValues(alpha: .14),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chỉ hiển thị trạng thái: bấm đâu trên thẻ cũng chọn.
              IgnorePointer(
                child: Checkbox(
                  value: selected,
                  onChanged: item.isReady ? (_) {} : null,
                  fillColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? FixedAssetReprintColors.coralSoft
                        : Colors.transparent,
                  ),
                  checkColor: const Color(0xFF111827),
                  side: WidgetStateBorderSide.resolveWith(
                    (states) => BorderSide(
                      color: states.contains(WidgetState.disabled)
                          ? Colors.white.withValues(alpha: .2)
                          : Colors.white.withValues(alpha: .55),
                      width: 1.5,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.machineCode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _reasonChip(),
                      ],
                    ),
                    if (row.faName.isNotEmpty)
                      Text(
                        row.faName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .6),
                          fontSize: 12.5,
                        ),
                      ),
                    const SizedBox(height: 5),
                    FixedAssetPicChip(email: row.pic),
                    const SizedBox(height: 8),
                    Text(
                      '${FixedAssetReprintStrings.printFor}:',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .55),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      printValue,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: printColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${FixedAssetReprintStrings.currentQr}: '
                      '${item.isMissingQr ? FixedAssetReprintStrings.noQrYet : item.oldLocationLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .45),
                        fontSize: 11.5,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .45),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: FixedAssetQrThumb(item: item, onTap: onPreview),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Sai vị trí" cam / "Mất QR" vàng.
  Widget _reasonChip() {
    final color = item.isMissingQr
        ? FixedAssetReprintColors.yellow
        : FixedAssetReprintColors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .6)),
      ),
      child: Text(
        item.reasonLabel,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Ảnh QR mới ~72 px, nền trắng + viền trắng an toàn để quét được.
class FixedAssetQrThumb extends StatelessWidget {
  final FixedAssetReprintItem item;
  final VoidCallback onTap;

  const FixedAssetQrThumb({super.key, required this.item, required this.onTap});

  static const double size = 72;

  @override
  Widget build(BuildContext context) {
    switch (item.state) {
      case FixedAssetReprintQrState.ready:
        return Tooltip(
          message: item.qrContent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: QrImageView(
                data: item.qrContent,
                version: QrVersions.auto,
                size: size,
                padding: const EdgeInsets.all(7),
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                gapless: true,
              ),
            ),
          ),
        );
      case FixedAssetReprintQrState.resolving:
        return _box(
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: FixedAssetReprintColors.coralSoft,
            ),
          ),
        );
      case FixedAssetReprintQrState.missing:
        return _box(
          const Text(
            FixedAssetReprintStrings.missingLocation,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: FixedAssetReprintColors.amber,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        );
    }
  }

  Widget _box(Widget child) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: child,
    );
  }
}
