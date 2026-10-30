import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:chuphinh/core/models/patrol_group.dart';
import 'package:chuphinh/shared/camera/camera_preview_box.dart';
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_strings.dart';
import 'package:chuphinh/features/fixed_asset/reprint/widgets/fixed_asset_reprint_card.dart'
    show FixedAssetReprintColors;

/// Camera quét toàn màn hình cho một bước thay QR (dùng [CameraPreviewBox]).
///
/// [onScan] kiểm QR: null = đúng (rung + tick, tự đóng, pop true), còn lại
/// là câu báo lỗi hiện dưới khung, camera vẫn mở. Cùng QR còn trong khung
/// không báo lặp; đưa QR ra khỏi khung rồi quét lại thì kiểm lại.
class FixedAssetReplaceScanScreen extends StatefulWidget {
  /// Đang chờ gì, vd "Quét QR CŨ của A-459 (đang dán A1-2)".
  final String title;
  final Future<String?> Function(String rawQr) onScan;

  const FixedAssetReplaceScanScreen({
    super.key,
    required this.title,
    required this.onScan,
  });

  @override
  State<FixedAssetReplaceScanScreen> createState() =>
      _FixedAssetReplaceScanScreenState();
}

class _FixedAssetReplaceScanScreenState
    extends State<FixedAssetReplaceScanScreen> {
  final GlobalKey<CameraPreviewBoxState> _cameraKey =
      GlobalKey<CameraPreviewBoxState>();

  /// Cùng QR detect lại trong khoảng này (kể từ lần thấy gần nhất) = vẫn
  /// nằm trong khung: bỏ qua.
  static const Duration _repeatWindow = Duration(seconds: 2);

  String? _lastQr;
  DateTime? _lastAt;

  bool _busy = false;
  bool _success = false;
  String? _error;
  bool _torchOn = false;

  Future<void> _onQr(String raw) async {
    final qr = raw.trim();
    if (qr.isEmpty || _success || !mounted) return;

    final now = DateTime.now();
    final lastAt = _lastAt;
    final repeat =
        qr == _lastQr && lastAt != null && now.difference(lastAt) < _repeatWindow;
    _lastQr = qr;
    _lastAt = now;
    if (repeat || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      error = await widget.onScan(qr);
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    // Cửa sổ chống lặp tính từ lúc kiểm xong (POST có thể lâu).
    _lastAt = DateTime.now();

    if (error != null) {
      HapticFeedback.heavyImpact();
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }

    HapticFeedback.vibrate();
    setState(() {
      _busy = false;
      _success = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await _close(true);
  }

  Future<void> _toggleTorch() async {
    final next = !_torchOn;
    final ok = await _cameraKey.currentState?.setTorch(next) ?? false;
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(FixedAssetReplaceStrings.flashUnsupported)),
        );
      return;
    }
    setState(() => _torchOn = next);
  }

  Future<void> _close([bool result = false]) async {
    await _cameraKey.currentState?.sleepCamera();
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = math.min(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return Center(
                    child: SizedBox.square(
                      dimension: size,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CameraPreviewBox(
                            key: _cameraKey,
                            size: size,
                            type: PatrolGroup.AssetUpdate.name,
                            patrolGroup: PatrolGroup.AssetUpdate,
                            qrOnly: true,
                            enableZoomControls: true,
                            enableStt: false,
                            showQrNumber: false,
                            showQrBadge: false,
                            onQrDetected: _onQr,
                          ),
                          if (_success) _buildSuccess(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            _buildMessage(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          _roundButton(
            icon: Icons.close_rounded,
            onTap: _close,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _roundButton(
            icon: _torchOn
                ? Icons.flashlight_on_rounded
                : Icons.flashlight_off_rounded,
            onTap: _toggleTorch,
            color: _torchOn ? FixedAssetReprintColors.amber : Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: .14),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 52,
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: FixedAssetReprintColors.newQr.withValues(alpha: .92),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 84),
    );
  }

  Widget _buildMessage() {
    final error = _error;
    final Widget child;
    if (_busy) {
      child = const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 12),
          Text(
            FixedAssetReplaceStrings.saving,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    } else if (error != null) {
      child = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_rounded, color: Colors.redAccent, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      );
    } else {
      child = Text(
        FixedAssetReplaceStrings.scanHint,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: .8),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 88),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error != null && !_busy
            ? Colors.redAccent.withValues(alpha: .22)
            : Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: error != null && !_busy
              ? Colors.redAccent.withValues(alpha: .8)
              : Colors.white.withValues(alpha: .18),
        ),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
