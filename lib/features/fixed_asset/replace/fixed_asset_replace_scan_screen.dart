import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:chuphinh/core/models/patrol_group.dart';
import 'package:chuphinh/shared/camera/camera_preview_box.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_qr_parser.dart'
    show fixedAssetPickFrameQr, normalizeMachineCode, parseFixedAssetQr;
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_controller.dart'
    show FixedAssetReplaceScanError, FixedAssetReplaceScanOutcome;
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_strings.dart';
import 'package:chuphinh/features/fixed_asset/reprint/widgets/fixed_asset_reprint_card.dart'
    show FixedAssetReprintColors;

/// Kết quả màn quét (pop): [done] = quét đúng; [error] = lỗi lưu, camera
/// đã đóng. Người dùng tự đóng camera: pop null.
class FixedAssetReplaceScanResult {
  final bool done;
  final String? error;

  const FixedAssetReplaceScanResult.done() : done = true, error = null;
  const FixedAssetReplaceScanResult.failed(String this.error) : done = false;
}

/// Kiểm một QR quét được; [photo] = JPEG chụp đúng lúc đọc được QR (null =
/// bước này không chụp).
typedef FixedAssetReplaceOnScan =
    Future<FixedAssetReplaceScanOutcome> Function(
      String rawQr,
      Future<Uint8List?>? photo,
    );

/// Loại QR đang quét: nhãn + màu chung cho badge header, thanh bước, viền
/// khung, hướng dẫn; [guide] = dòng giải thích trên thẻ thông tin.
enum FixedAssetReplaceQrKind {
  newQr(
    FixedAssetReplaceStrings.qrNew,
    Color(0xFF43A047),
    FixedAssetReplaceStrings.newQrGuide,
  ),
  oldQr(
    FixedAssetReplaceStrings.qrOld,
    Color(0xFFFB8C00),
    FixedAssetReplaceStrings.oldQrGuide,
  );

  final String label;
  final Color color;
  final String guide;

  const FixedAssetReplaceQrKind(this.label, this.color, this.guide);
}

/// Camera quét toàn màn hình cho một bước thay QR (dùng [CameraPreviewBox]).
/// Từ trên xuống: header "Quét [badge]" · thanh bước ① QR CŨ ── ② QR MỚI
/// ([showSteps]) · khung vuông (≤ 55% chiều cao) · thẻ thông tin máy ·
/// hướng dẫn. Viền khung + hướng dẫn theo màu [kind].
///
/// [onScan] kiểm QR: error null = đúng (rung + tick, tự đóng, pop
/// [FixedAssetReplaceScanResult.done]); QR sai: báo lỗi trên camera, camera
/// vẫn mở để quét tiếp; lỗi lưu ([FixedAssetReplaceScanError.apiFailed]):
/// đóng camera, pop [FixedAssetReplaceScanResult.failed]. Cùng QR còn trong
/// khung không xử lý lặp; đưa QR ra khỏi khung rồi quét lại thì kiểm lại.
///
/// [capturePhoto] (bước QR mới): chụp frame lúc đọc được QR, gửi kèm qua
/// [onScan]. Lưu được ảnh: thumbnail + "Đã chụp ảnh" trên thẻ thông tin
/// ~1.5 s rồi đóng; không lưu được: snackbar "Không lưu được ảnh", vẫn đi tiếp.
class FixedAssetReplaceScanScreen extends StatefulWidget {
  final FixedAssetReplaceQrKind kind;
  final String machineCode;

  /// Sau mã máy trên thẻ thông tin, vd "· đang dán tại A6-3".
  final String place;

  /// Luồng 2 bước (Sai QR): hiện thanh bước; Mất QR (chỉ QR mới): ẩn.
  final bool showSteps;

  /// Bước QR mới sau khi đã quét QR cũ: mã cũ rút gọn; null = không hiện.
  final String? oldQrScanned;

  /// Chụp ảnh lúc đọc được QR, gửi qua [onScan] (QR cũ: upload ngầm
  /// type=before; QR mới: gửi kèm save).
  final bool capturePhoto;
  final FixedAssetReplaceOnScan onScan;

  const FixedAssetReplaceScanScreen({
    super.key,
    required this.kind,
    required this.machineCode,
    required this.place,
    this.showSteps = false,
    this.oldQrScanned,
    this.capturePhoto = false,
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

  /// Thời gian giữ tick xong trước khi đóng; có ảnh (hoặc báo lỗi ảnh) thì
  /// giữ lâu hơn để kịp thấy.
  static const Duration _successHold = Duration(milliseconds: 700);
  static const Duration _photoHold = Duration(milliseconds: 1500);

  String? _lastQr;
  DateTime? _lastAt;

  bool _busy = false;
  bool _success = false;
  String? _error;
  bool _torchOn = false;

  /// Ảnh đã lưu (bước QR mới), hiện thumbnail trên thẻ thông tin.
  String? _photoUrl;

  /// Lần đầu thấy từng mã (log thời gian tới lúc nhận).
  final Map<String, DateTime> _firstSeenAt = <String, DateTime>{};

  Future<void> _onQr(String raw) async {
    var qr = raw.trim();
    if (qr.isEmpty || _success || !mounted) return;

    final now = DateTime.now();
    final camera = _cameraKey.currentState;
    final expected = normalizeMachineCode(widget.machineCode);
    bool isKnown(String code) => code.isNotEmpty && code == expected;

    // Frame nhiều mã: ưu tiên mã máy đang thay gần tâm nhất.
    final pick = fixedAssetPickFrameQr(
      qr,
      camera?.lastQrCandidates ?? const [],
      isKnown,
    );
    if (pick.ambiguous) {
      HapticFeedback.heavyImpact();
      setState(() => _error = FixedAssetReplaceStrings.multipleQr);
      return;
    }
    qr = pick.rawQr.trim();
    final code = parseFixedAssetQr(qr).machineCode;

    // Mọi mã nhận ngay ở lần đọc đầu (kiểm đúng máy / QR ở onScan).
    _firstSeenAt.removeWhere(
      (_, at) => now.difference(at) > const Duration(seconds: 10),
    );
    if (code.isNotEmpty) _firstSeenAt.putIfAbsent(code, () => now);

    final lastAt = _lastAt;
    final repeat =
        qr == _lastQr && lastAt != null && now.difference(lastAt) < _repeatWindow;
    _lastQr = qr;
    _lastAt = now;
    if (repeat || _busy) return;

    final firstSeen = _firstSeenAt.remove(code) ?? now;
    final engine = camera?.lastQrEngine ?? '';
    debugPrint(
      '[FA-REPLACE] accepted ${code.isEmpty ? qr : code} after '
      '${now.difference(firstSeen).inMilliseconds} ms '
      '(${isKnown(code) ? 'expected machine' : 'other machine'}, '
      'decoder=${engine.isEmpty ? 'unknown' : engine})',
    );

    // Vẽ frame ra canvas ngay (đồng bộ, trước await đầu tiên) = frame vừa
    // đọc được QR; encode JPEG chạy song song với kiểm QR.
    final photo = widget.capturePhoto
        ? _cameraKey.currentState?.captureFrameJpeg() ??
              Future<Uint8List?>.value(null)
        : null;

    setState(() {
      _busy = true;
      _error = null;
    });
    FixedAssetReplaceScanOutcome outcome;
    try {
      outcome = await widget.onScan(qr, photo);
    } catch (e) {
      outcome = FixedAssetReplaceScanOutcome(
        FixedAssetReplaceScanError('$e', apiFailed: true),
      );
    }
    if (!mounted) return;
    final error = outcome.error;
    // Cửa sổ chống lặp tính từ lúc kiểm xong (POST có thể lâu).
    _lastAt = DateTime.now();

    if (error != null) {
      HapticFeedback.heavyImpact();
      if (error.apiFailed) {
        // Lỗi lưu: đóng camera, màn "Việc cần làm" báo lỗi + cho quét lại.
        _success = true; // chặn QR đến trong lúc đóng
        await _close(FixedAssetReplaceScanResult.failed(error.message));
        return;
      }
      final message = error.message;
      setState(() {
        _busy = false;
        _error = message;
      });
      return;
    }

    HapticFeedback.vibrate();
    SystemSound.play(SystemSoundType.click);
    if (outcome.photoFailed) _showPhotoFailed();
    setState(() {
      _busy = false;
      _success = true;
      _photoUrl = outcome.photoUrl;
    });
    await Future<void>.delayed(
      outcome.photoUrl != null || outcome.photoFailed
          ? _photoHold
          : _successHold,
    );
    await _close(const FixedAssetReplaceScanResult.done());
  }

  /// Không chặn luồng: chỉ báo, máy vẫn tính đã thay QR.
  void _showPhotoFailed() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(FixedAssetReplaceStrings.photoFailed),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
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

  /// [result] null = người dùng tự đóng.
  Future<void> _close([FixedAssetReplaceScanResult? result]) async {
    await _cameraKey.currentState?.sleepCamera();
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Nền xám tối để thẻ thông tin (đen mờ) nổi là "tối hơn nền".
      backgroundColor: FixedAssetReprintColors.appBar,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Khung vuông, cao tối đa ~55% vùng màn; phần còn lại cho thanh
            // bước + thẻ thông tin + hướng dẫn (iPhone 16 không cần cuộn).
            final size = math.min(
              constraints.maxWidth,
              constraints.maxHeight * .55,
            );
            return Column(
              children: [
                _buildTopBar(),
                if (widget.showSteps) _buildStepBar(),
                SizedBox.square(
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
                      // Viền khung quét theo màu loại QR.
                      IgnorePointer(
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.kind.color,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      if (_success) _buildSuccess(),
                    ],
                  ),
                ),
                // Màn thấp hơn dự kiến thì cuộn thẻ, không tràn.
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: _buildInfoCard(),
                  ),
                ),
                _buildMessage(),
              ],
            );
          },
        ),
      ),
    );
  }

  /// "① QR CŨ ── ② QR MỚI": bước hiện tại tô màu loại QR + chữ đậm; bước
  /// xong check xám sáng; bước chưa tới viền mờ.
  Widget _buildStepBar() {
    const doneColor = Color(0xFFCBD5E1);
    Widget step(int number, FixedAssetReplaceQrKind kind) {
      final active = kind == widget.kind;
      final done =
          kind == FixedAssetReplaceQrKind.oldQr &&
          widget.kind == FixedAssetReplaceQrKind.newQr;
      final color = active
          ? kind.color
          : done
          ? doneColor
          : Colors.white.withValues(alpha: .35);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? kind.color : Colors.transparent,
              border: Border.all(color: color, width: 1.5),
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 14, color: doneColor)
                : Text(
                    '$number',
                    style: TextStyle(
                      color: active ? Colors.white : color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Text(
            kind.label,
            style: TextStyle(
              color: color,
              fontSize: 13.5,
              fontWeight: active ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          step(1, FixedAssetReplaceQrKind.oldQr),
          Container(
            width: 32,
            height: 1.5,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.white.withValues(alpha: .25),
          ),
          step(2, FixedAssetReplaceQrKind.newQr),
        ],
      ),
    );
  }

  /// Thẻ máy: "A-077 · đang dán tại A6-3", giải thích theo bước, (bước
  /// QR mới) "Đã quét QR cũ: …", và sau khi lưu ảnh: thumbnail "Đã chụp ảnh".
  Widget _buildInfoCard() {
    final scanned = widget.oldQrScanned;
    final photoUrl = _photoUrl;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.precision_manufacturing_rounded,
                size: 20,
                color: Colors.white.withValues(alpha: .75),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: widget.machineCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(
                        text: ' ${widget.place}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .75),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.kind.guide,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .6),
              fontSize: 14,
              height: 1.35,
            ),
          ),
          if (scanned != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: FixedAssetReplaceQrKind.newQr.color,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    FixedAssetReplaceStrings.oldQrScanned(scanned),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (photoUrl != null) ...[
            const SizedBox(height: 10),
            _buildPhoto(photoUrl),
          ],
        ],
      ),
    );
  }

  /// Thumbnail ảnh vừa lưu + "Đã chụp ảnh".
  Widget _buildPhoto(String url) {
    const size = 56.0;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox.square(
            dimension: size,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              cacheWidth: (size * dpr * 1.5).round(),
              frameBuilder: (context, child, frame, sync) {
                if (sync || frame != null) return child;
                return ColoredBox(
                  color: Colors.white.withValues(alpha: .08),
                  child: Icon(
                    Icons.image_outlined,
                    size: 22,
                    color: Colors.white.withValues(alpha: .4),
                  ),
                );
              },
              errorBuilder: (_, _, _) => ColoredBox(
                color: Colors.white.withValues(alpha: .08),
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 22,
                  color: Colors.white.withValues(alpha: .4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(
          Icons.photo_camera_rounded,
          size: 18,
          color: FixedAssetReplaceQrKind.newQr.color,
        ),
        const SizedBox(width: 6),
        const Text(
          FixedAssetReplaceStrings.photoSaved,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
            child: Row(
              children: [
                const Text(
                  FixedAssetReplaceStrings.scan,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                _QrKindBadge(kind: widget.kind),
              ],
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
      child = Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: FixedAssetReplaceStrings.scanHintPrefix),
            TextSpan(
              text: widget.kind.label,
              style: TextStyle(
                color: widget.kind.color,
                fontWeight: FontWeight.w900,
              ),
            ),
            const TextSpan(text: FixedAssetReplaceStrings.scanHintSuffix),
          ],
        ),
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

/// Badge "QR MỚI" / "QR CŨ": nền màu [kind], icon QR + chữ trắng đậm. Khi
/// mở màn hoặc đổi [kind]: pulse 3 lần trong 2 s (scale 1.0↔1.08 + glow
/// cùng màu) rồi đứng yên; bỏ animation nếu hệ thống tắt animation.
class _QrKindBadge extends StatefulWidget {
  final FixedAssetReplaceQrKind kind;

  const _QrKindBadge({required this.kind});

  @override
  State<_QrKindBadge> createState() => _QrKindBadgeState();
}

class _QrKindBadgeState extends State<_QrKindBadge>
    with SingleTickerProviderStateMixin {
  static const int _pulses = 3;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  bool _started = false;

  void _play() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.value = 0;
      return;
    }
    _pulse.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _play();
  }

  @override
  void didUpdateWidget(_QrKindBadge old) {
    super.didUpdateWidget(old);
    if (old.kind != widget.kind) _play();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.kind.color;
    final badge = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.qr_code_2_rounded, size: 16, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          widget.kind.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            height: 1.2,
          ),
        ),
      ],
    );
    final animate = !MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _pulse,
      child: badge,
      builder: (context, child) {
        // 0 → 1 → 0, lặp [_pulses] lần trong suốt animation.
        final t = animate && _pulse.isAnimating
            ? (1 - math.cos(_pulse.value * _pulses * 2 * math.pi)) / 2
            : 0.0;
        return Transform.scale(
          scale: 1 + .08 * t,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                if (t > 0)
                  BoxShadow(
                    color: color.withValues(alpha: .7 * t),
                    blurRadius: 14 * t,
                    spreadRadius: 2 * t,
                  ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
}
