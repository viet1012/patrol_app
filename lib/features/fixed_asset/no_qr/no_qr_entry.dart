import 'package:flutter/material.dart';

import 'package:chuphinh/features/fixed_asset/no_qr/no_qr_strings.dart';

const Color _amber = Color(0xFFF59E0B);

/// Dòng "Máy không có QR" ngay dưới status card: cả dòng là nút (ripple,
/// cursor click, hover sáng hơn), bên phải pill "+ Ghi nhận". Badge cạnh
/// tiêu đề = số case đã ghi trong phiên (ẩn khi 0).
class NoQrEntryTile extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const NoQrEntryTile({super.key, required this.count, required this.onTap});

  static final BorderRadius _radius = BorderRadius.circular(14);

  @override
  Widget build(BuildContext context) {
    // Nền amber 12%; hover phủ thêm amber 8% (~20% tổng) trên chính Material.
    return Material(
      color: _amber.withValues(alpha: .12),
      shape: RoundedRectangleBorder(
        borderRadius: _radius,
        side: const BorderSide(color: _amber),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        hoverColor: _amber.withValues(alpha: .08),
        highlightColor: _amber.withValues(alpha: .1),
        splashColor: _amber.withValues(alpha: .22),
        child: ConstrainedBox(
          // Đủ cao để bấm trên điện thoại.
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: _amber, size: 24),
                const SizedBox(width: 10),
                Expanded(child: _texts()),
                const SizedBox(width: 8),
                _actionPill(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _texts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Flexible(
              child: Text(
                NoQrStrings.entryTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (count > 0) ...[const SizedBox(width: 6), _countBadge()],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          NoQrStrings.entrySubtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .6),
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }

  Widget _countBadge() {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: _amber,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  /// Chỉ là phần nhìn: cả dòng nhận tap.
  Widget _actionPill() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        color: _amber,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, color: Colors.black87, size: 18),
          SizedBox(width: 2),
          Text(
            NoQrStrings.entryAction,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Link nhỏ dưới khung quét trong camera. Thấp (~18px) để lọt giữa đáy khung
/// quét và zoom control của camera.
class NoQrCameraLink extends StatelessWidget {
  final VoidCallback onTap;

  const NoQrCameraLink({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC111827),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, color: _amber, size: 13),
              SizedBox(width: 4),
              Text(
                NoQrStrings.cameraLink,
                style: TextStyle(
                  color: _amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: _amber,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nhãn vàng "Thiếu QR" trên dòng máy đã ghi thiếu QR.
class NoQrTag extends StatelessWidget {
  const NoQrTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _amber.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _amber.withValues(alpha: .6)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: _amber, size: 12),
          SizedBox(width: 4),
          Text(
            NoQrStrings.tag,
            style: TextStyle(
              color: _amber,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
