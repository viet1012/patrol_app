import 'dart:async';

import 'package:flutter/material.dart';

import 'package:chuphinh/features/fixed_asset/fixed_asset_audit_flow.dart';

/// Chip over the camera for the last received scan: parsed text
/// ("{code} · {floor}/{AA}") coloured by the result — green saved, accent
/// processing, amber warning / needs location / mismatch, red error.
///
/// Every new [tick] (a new scan, or a repeated detection) shows it again
/// with a short flash; once [settled] (final result) it fades out after
/// [hideAfter]. [text] null hides it right away (mode / location change).
class FixedAssetScanChip extends StatefulWidget {
  final String? text;
  final int tick;
  final FixedAssetScanStatus status;
  final bool settled;
  final Duration hideAfter;

  const FixedAssetScanChip({
    super.key,
    required this.text,
    required this.tick,
    required this.status,
    required this.settled,
    this.hideAfter = const Duration(milliseconds: 2500),
  });

  static const Color accent = Color(0xFF4DD0E1);
  static const Color success = Color(0xFF22C55E);
  static const Color amber = Color(0xFFF59E0B);
  static const Color error = Colors.redAccent;

  static Color colorFor(FixedAssetScanStatus status) => switch (status) {
    FixedAssetScanStatus.idle ||
    FixedAssetScanStatus.checking ||
    FixedAssetScanStatus.saving => accent,
    FixedAssetScanStatus.saved => success,
    FixedAssetScanStatus.failed => error,
    FixedAssetScanStatus.alreadyAudited ||
    FixedAssetScanStatus.locationMismatch ||
    FixedAssetScanStatus.mismatchSaved ||
    FixedAssetScanStatus.unknownSaved ||
    FixedAssetScanStatus.zoneLocked ||
    FixedAssetScanStatus.needsLocation => amber,
  };

  @override
  State<FixedAssetScanChip> createState() => _FixedAssetScanChipState();
}

class _FixedAssetScanChipState extends State<FixedAssetScanChip>
    with SingleTickerProviderStateMixin {
  // Tạo trong initState: nếu lazy mà chưa dùng lần nào, dispose() sẽ tạo nó
  // lúc unmount (vsync tra ancestor của widget đã deactivate -> lỗi).
  late final AnimationController _flash;
  Timer? _hideTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _sync(show: widget.text != null);
  }

  @override
  void didUpdateWidget(covariant FixedAssetScanChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newScan =
        widget.tick != oldWidget.tick || widget.text != oldWidget.text;
    _sync(
      show: widget.text != null && (newScan || _visible),
      flash: newScan && widget.text != null,
      restartHide: newScan || widget.settled != oldWidget.settled,
    );
  }

  void _sync({required bool show, bool flash = false, bool restartHide = true}) {
    _visible = show;
    if (flash) _flash.forward(from: 0);
    if (!restartHide) return;
    _hideTimer?.cancel();
    if (show && widget.settled) {
      _hideTimer = Timer(widget.hideAfter, () {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final color = FixedAssetScanChip.colorFor(widget.status);
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _visible && text != null ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: text == null
            ? const SizedBox.shrink()
            : AnimatedBuilder(
                animation: _flash,
                builder: (context, child) {
                  // Brief pop on every received scan (also repeats).
                  final t = Curves.easeOut.transform(1 - _flash.value);
                  return Transform.scale(
                    scale: 1 + 0.06 * (_flash.isAnimating ? t : 0),
                    child: child,
                  );
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 34),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xD9111827),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.85)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_2_rounded, size: 19, color: color),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
