// import 'package:chuphinh/qrCode/qr_code_camera.dart';
// import 'package:flutter/material.dart';
//
// class QrScannerDialog extends StatefulWidget {
//   final ValueChanged<String> onDetected;
//   const QrScannerDialog({super.key, required this.onDetected});
//
//   @override
//   State<QrScannerDialog> createState() => _QrScannerDialogState();
// }
//
// class _QrScannerDialogState extends State<QrScannerDialog> {
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: const Color(0xFF121826).withOpacity(0.92),
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(color: Colors.white.withOpacity(0.15)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.35),
//             blurRadius: 22,
//             offset: const Offset(0, 10),
//           ),
//         ],
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Row(
//             children: [
//               const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
//               const SizedBox(width: 8),
//               const Expanded(
//                 child: Text(
//                   'Scan QR Code',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.w800,
//                     fontSize: 14,
//                   ),
//                 ),
//               ),
//               IconButton(
//                 onPressed: () => Navigator.pop(context),
//                 icon: const Icon(Icons.close_rounded, color: Colors.white70),
//               ),
//             ],
//           ),
//           const SizedBox(height: 10),
//
//           QrCodeCamera(
//             size: 340,
//             onQrDetected: (qr) {
//               if (qr.trim().isEmpty) return;
//               widget.onDetected(qr.trim());
//             },
//           ),
//
//           const SizedBox(height: 10),
//           Text(
//             'Point the camera at the QR code',
//             style: TextStyle(color: Colors.white.withOpacity(0.75)),
//           ),
//         ],
//       ),
//     );
//   }
// }
import 'package:chuphinh/qrCode/qr_code_camera.dart';
import 'package:flutter/material.dart';

class QrScannerDialog extends StatefulWidget {
  final ValueChanged<String> onDetected;
  const QrScannerDialog({super.key, required this.onDetected});

  @override
  State<QrScannerDialog> createState() => QrScannerDialogState();
}

class QrScannerDialogState extends State<QrScannerDialog> {
  final _camKey = GlobalKey<QrCodeCameraState>();

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
    super.dispose();
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
                onPressed: _close, // ✅ stop trước khi pop
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 10),

          QrCodeCamera(
            key: _camKey,
            size: 340,
            onQrDetected: (qr) {
              final t = qr.trim();
              if (t.isEmpty) return;
              widget.onDetected(t);
            },
          ),

          const SizedBox(height: 10),
          Text(
            'Point the camera at the QR code',
            style: TextStyle(color: Colors.white.withOpacity(0.75)),
          ),
        ],
      ),
    );
  }
}
