import 'package:chuphinh/qrCode/qr_code_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QrScannerDialog extends StatefulWidget {
  final ValueChanged<String> onDetected;

  const QrScannerDialog({super.key, required this.onDetected});

  @override
  State<QrScannerDialog> createState() => QrScannerDialogState();
}

class QrScannerDialogState extends State<QrScannerDialog> {
  final _camKey = GlobalKey<QrCodeCameraState>();

  final _manualCtrl = TextEditingController();
  final _manualFocus = FocusNode();

  bool _submitting = false;

  // ✅ expose cho page gọi
  Future<void> stopCamera() async {
    await _camKey.currentState?.stopCamera();
  }

  Future<void> _close() async {
    await stopCamera();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  void dispose() {
    _camKey.currentState?.stopCamera();
    _manualCtrl.dispose();
    _manualFocus.dispose();
    super.dispose();
  }

  Future<void> _submitManual() async {
    if (_submitting) return;
    final t = _manualCtrl.text.trim();
    if (t.isEmpty) {
      // thông báo nhẹ
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Please enter QR code')));
      return;
    }

    setState(() => _submitting = true);

    // optional: stop camera để giảm CPU trước khi callback + pop
    await stopCamera();
    if (!mounted) return;

    widget.onDetected(t);
    // đa số onDetected sẽ tự pop dialog ở ngoài, nhưng nếu không:
    // await _close();

    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121826).withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Scan QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                onPressed: _close,
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualCtrl,
                  focusNode: _manualFocus,
                  enabled: !_submitting,
                  textInputAction: TextInputAction.done,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                    signed: false,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (_) => _submitManual(),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter QR manually',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.18),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.18),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF7CF8D6),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submitManual,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: Colors.white.withOpacity(0.92),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text(
                    'Use',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),
          Text(
            'If scanning fails, type the QR code above.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),

          // Camera
          QrCodeCamera(
            key: _camKey,
            size: 340,
            onQrDetected: (qr) async {
              final t = qr.trim();
              if (t.isEmpty) return;
              if (_submitting) return; // tránh double trigger
              setState(() => _submitting = true);

              // stop camera trước cho chắc
              await stopCamera();
              if (!mounted) return;

              widget.onDetected(t);

              if (mounted) setState(() => _submitting = false);
            },
          ),

          const SizedBox(height: 10),
          Text(
            'Point the camera at the QR code',
            style: TextStyle(color: Colors.white.withOpacity(0.75)),
          ),

          const SizedBox(height: 12),

          // Manual input
        ],
      ),
    );
  }
}
