// import 'dart:async';
// import 'dart:html' as html;
// import 'dart:math' as math;
// import 'dart:typed_data';
// import 'dart:ui';
// import 'dart:ui_web' as ui_web;
//
// import 'package:chuphinh/socket/SttWebSocket.dart';
// import 'package:chuphinh/widget/glass_circle_button.dart';
// import 'package:chuphinh/widget/glass_zoom_control.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:js/js.dart';
//
// import 'api/api_config.dart';
// import 'api/stt_api.dart';
// import 'homeScreen/patrol_home_screen.dart';
//
// @JS('startQrLoop')
// external void startQrLoop();
//
// @JS('stopQrLoop')
// external void stopQrLoop();
//
// @JS('decodeQrFromImageBytes')
// external void _decodeQrFromImageBytesJs(String objectUrl);
//
// class CameraPreviewBox extends StatefulWidget {
//   final double size;
//   final Function(List<Uint8List> images)? onImagesChanged;
//
//   final String? plant;
//   final String? group;
//   final String type;
//   final String? wsUrl;
//   final PatrolGroup patrolGroup;
//
//   /// ✅ Gửi QR về class cha
//   final ValueChanged<String>? onQrDetected;
//
//   const CameraPreviewBox({
//     super.key,
//     this.size = 320,
//     this.onImagesChanged,
//     this.plant,
//     this.group,
//     required this.type,
//     this.wsUrl,
//     required this.patrolGroup,
//     this.onQrDetected,
//   });
//
//   @override
//   State<CameraPreviewBox> createState() => CameraPreviewBoxState();
// }
//
// class CameraPreviewBoxState extends State<CameraPreviewBox>
//     with TickerProviderStateMixin {
//   // =========================
//   // Config
//   // =========================
//   static const int _maxImages = 3;
//
//   static const Duration _qrDedupe = Duration(milliseconds: 1200);
//   static const Duration _qrWarmup = Duration(milliseconds: 250);
//
//   static const double _minZoom = 1.0;
//   static const double _maxZoom = 10.0;
//
//   // =========================
//   // Camera / View
//   // =========================
//   html.MediaStream? _stream;
//   html.VideoElement? _video;
//   late String _viewType;
//
//   double _zoom = 1.0;
//
//   // =========================
//   // QR scanning (JS ZXing)
//   // =========================
//   StreamSubscription? _qrSub;
//   bool _qrScanning = false;
//   bool _qrLoading = false;
//
//   // String? _lastQr;
//   // DateTime? _lastQrAt;
//   /// QR Patrol dạng số đang hiển thị trên UI.
//   String? _lastQr;
//
//   /// QR raw gần nhất, có thể là QR Patrol hoặc QR máy.
//   String? _lastDetectedQr;
//   DateTime? _lastDetectedQrAt;
//
//   /// points from JS (video pixel coords)
//   List<Offset>? _qrPoints;
//   Size? _videoSize;
//
//   // =========================
//   // Capture
//   // =========================
//   bool _isCapturing = false;
//   final List<Uint8List> _capturedImages = [];
//   late final AnimationController _flashController;
//
//   bool get canUpload => _capturedImages.length < _maxImages;
//
//   List<Uint8List> get images => List.unmodifiable(_capturedImages);
//
//   // =========================
//   // STT / Socket
//   // =========================
//   late String _fac;
//   late String _group;
//   late String _wsUrl;
//
//   int stt = 0;
//   bool _sttLoading = true;
//   SttWebSocket? sttSocket;
//
//   // =========================
//   // Lifecycle
//   // =========================
//   late final AnimationController _qrFlashCtrl;
//   late final Animation<double> _qrScaleAnim;
//   late final Animation<double> _qrShakeAnim;
//
//   int _qrChangeCount = 0;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _viewType = 'camera_${DateTime.now().millisecondsSinceEpoch}';
//     _fac = (widget.plant ?? '').trim();
//     _group = (widget.group ?? '').trim();
//     _wsUrl = widget.wsUrl ?? '${ApiConfig.wsBaseUrl}/ws-stt/websocket';
//
//     _flashController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 200),
//     );
//
//     _startCamera();
//     _loadStt();
//     _connectSocket();
//
//     _qrFlashCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 220),
//     );
//
//     _qrScaleAnim = Tween<double>(
//       begin: 1.0,
//       end: 1.06,
//     ).animate(CurvedAnimation(parent: _qrFlashCtrl, curve: Curves.easeOut));
//
//     _qrShakeAnim = Tween<double>(
//       begin: 0.0,
//       end: 3.0,
//     ).animate(CurvedAnimation(parent: _qrFlashCtrl, curve: Curves.easeInOut));
//   }
//
//   @override
//   void didUpdateWidget(covariant CameraPreviewBox oldWidget) {
//     super.didUpdateWidget(oldWidget);
//
//     final newFac = (widget.plant ?? '').trim();
//     final newGroup = (widget.group ?? '').trim();
//
//     if (newFac != _fac || newGroup != _group) {
//       _fac = newFac;
//       _group = newGroup;
//       // Nếu cần reload STT/socket theo group/fac thì bật lại:
//       // _loadStt();
//       // _connectSocket();
//     }
//   }
//
//   @override
//   void dispose() {
//     _qrFlashCtrl.dispose();
//     _stopQrScan();
//     _flashController.dispose();
//     _stopCamera();
//     try {
//       sttSocket?.dispose();
//     } catch (_) {}
//     super.dispose();
//   }
//
//   bool _isQrNumber(String value) {
//     return RegExp(r'^\d+$').hasMatch(value.trim());
//   }
//
//   // =========================
//   // Camera
//   // =========================
//
//   //function nhập QR tay
//
//   Future<void> _inputQrManually() async {
//     final controller = TextEditingController();
//
//     final value = await showDialog<String>(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           backgroundColor: const Color(0xFF1F2937),
//           title: const Text(
//             "Enter QR Code",
//             style: TextStyle(color: Colors.white),
//           ),
//           content: TextField(
//             controller: controller,
//             autofocus: true,
//             style: const TextStyle(color: Colors.white),
//             decoration: const InputDecoration(
//               hintText: "Input QR code manually",
//               hintStyle: TextStyle(color: Colors.white54),
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text("Cancel"),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.pop(context, controller.text.trim());
//               },
//               child: const Text("OK"),
//             ),
//           ],
//         );
//       },
//     );
//
//     // if (value != null && value.isNotEmpty) {
//     //   setState(() {
//     //     _lastQr = value;
//     //     _lastQrAt = DateTime.now();
//     //   });
//     //
//     //   widget.onQrDetected?.call(value);
//     //
//     //   HapticFeedback.mediumImpact();
//     //   _playQrChangedFx();
//     // }
//
//     if (value != null && value.isNotEmpty) {
//       // Nếu type là Patrol thì chỉ nhận đúng 4 số
//
//       // if (widget.type == 'Patrol' && !RegExp(r'^\d{4}$').hasMatch(value)) {
//       //   ScaffoldMessenger.of(context).showSnackBar(
//       //     const SnackBar(
//       //       content: Text('QR Patrol chỉ được đúng 4 số'),
//       //       backgroundColor: Colors.redAccent,
//       //       behavior: SnackBarBehavior.floating,
//       //     ),
//       //   );
//       //   return;
//       // }
//
//       final now = DateTime.now();
//
//       setState(() {
//         _lastDetectedQr = value;
//         _lastDetectedQrAt = now;
//
//         // Nhập QR máy thì không xóa QR Patrol đang hiển thị.
//         if (_isQrNumber(value)) {
//           _lastQr = value;
//         }
//       });
//
//       widget.onQrDetected?.call(value);
//     }
//   }
//
//   Future<void> _startCamera() async {
//     try {
//       final stream = await html.window.navigator.mediaDevices!.getUserMedia({
//         'video': {
//           'facingMode': 'environment',
//           // ✅ đừng xin 4K (nặng + decode chậm)
//           'width': {'ideal': 1280, 'min': 640},
//           'height': {'ideal': 720, 'min': 480},
//         },
//       });
//
//       final video = html.VideoElement()
//         ..id = 'qr-video'
//         ..setAttribute('autoplay', 'true')
//         ..setAttribute('playsinline', 'true')
//         ..setAttribute('muted', 'true')
//         ..style.objectFit = 'cover'
//         ..style.pointerEvents = 'none'
//         ..style.position = 'absolute'
//         ..style.top = '0'
//         ..style.left = '0'
//         ..style.width = '100%'
//         ..style.height = '100%'
//         ..style.zIndex = '0'
//         ..srcObject = stream;
//
//       ui_web.platformViewRegistry.registerViewFactory(_viewType, (id) => video);
//
//       setState(() {
//         _stream = stream;
//         _video = video;
//       });
//
//       // ✅ đợi video ready rồi auto scan
//       await _waitVideoReady(timeout: const Duration(seconds: 3));
//       if (!mounted) return;
//       await Future.delayed(_qrWarmup);
//       _startAutoQrScan();
//     } catch (e) {
//       debugPrint('Camera error: $e');
//     }
//   }
//
//   Future<void> _waitVideoReady({required Duration timeout}) async {
//     final start = DateTime.now();
//     while (mounted) {
//       final v = _video;
//       if (v != null && v.videoWidth > 0 && v.videoHeight > 0) return;
//       if (DateTime.now().difference(start) > timeout) return;
//       await Future.delayed(const Duration(milliseconds: 50));
//     }
//   }
//
//   void _stopCamera() {
//     try {
//       _stream?.getTracks().forEach((t) => t.stop());
//     } catch (_) {}
//   }
//
//   // =========================
//   // QR (ZXing JS) start/stop
//   // =========================
//   Future<void> _startAutoQrScan() async {
//     if (_qrScanning) return;
//
//     setState(() {
//       _qrScanning = true;
//       _qrLoading = true;
//     });
//
//     // ✅ listener trước rồi mới start loop
//     await _qrSub?.cancel();
//     _qrSub = html.window.on['qr-from-image'].listen(_onQrEvent);
//
//     // start JS loop
//     try {
//       startQrLoop();
//     } catch (e) {
//       debugPrint('startQrLoop error: $e');
//     }
//
//     if (mounted) setState(() => _qrLoading = false);
//   }
//
//   Future<void> _stopQrScan() async {
//     try {
//       stopQrLoop();
//     } catch (_) {}
//
//     try {
//       await _qrSub?.cancel();
//     } catch (_) {}
//     _qrSub = null;
//
//     if (mounted) {
//       setState(() {
//         _qrScanning = false;
//         _qrLoading = false;
//         _qrPoints = null;
//         _videoSize = null;
//       });
//     }
//   }
//
//   void _onQrEvent(dynamic event) {
//     if (!mounted) return;
//
//     final e = event as html.CustomEvent;
//     final detail = e.detail;
//
//     final text = detail['text']?.toString().trim() ?? '';
//     final err = detail['error']?.toString() ?? '';
//
//     if (err.isNotEmpty || text.isEmpty) return;
//
//     final now = DateTime.now();
//
//     // Chống cùng một QR gọi liên tục.
//     // Dùng raw QR, không dùng QR đang hiển thị.
//     if (_lastDetectedQr == text &&
//         _lastDetectedQrAt != null &&
//         now.difference(_lastDetectedQrAt!) < _qrDedupe) {
//       return;
//     }
//
//     _lastDetectedQr = text;
//     _lastDetectedQrAt = now;
//
//     HapticFeedback.mediumImpact();
//
//     final isPatrolQr = _isQrNumber(text);
//
//     setState(() {
//       // Chỉ cập nhật QR hiển thị khi scanner đọc được QR số.
//       // Khi đọc QR máy, giữ nguyên QR Patrol cũ.
//       if (isPatrolQr) {
//         _lastQr = text;
//       }
//
//       _qrChangeCount++;
//     });
//
//     final pointsRaw = detail['points'];
//     List<Offset>? pts;
//
//     if (pointsRaw is List) {
//       pts = pointsRaw
//           .whereType<Map>()
//           .map(
//             (m) => Offset(
//               (m['x'] as num?)?.toDouble() ?? 0,
//               (m['y'] as num?)?.toDouble() ?? 0,
//             ),
//           )
//           .toList();
//
//       if (pts.isEmpty) {
//         pts = null;
//       }
//     }
//
//     final v = _video;
//
//     final vSize = v == null
//         ? null
//         : Size(v.videoWidth.toDouble(), v.videoHeight.toDouble());
//
//     if (mounted) {
//       setState(() {
//         _qrPoints = pts;
//         _videoSize = vSize;
//       });
//     }
//
//     // QR số hoặc QR máy đều gửi về cha xử lý.
//     widget.onQrDetected?.call(text);
//   }
//
//   // =========================
//   // STT / socket
//   // =========================
//   Future<void> _loadStt() async {
//     if (_fac.isEmpty) return;
//     try {
//       setState(() => _sttLoading = true);
//
//       final value = await SttApi.getCurrentStt(
//         fac: _fac,
//         type: widget.patrolGroup.name,
//       );
//
//       if (!mounted) return;
//       setState(() {
//         stt = value;
//         _sttLoading = false;
//       });
//     } catch (e) {
//       if (mounted) setState(() => _sttLoading = false);
//     }
//   }
//
//   void _connectSocket() {
//     sttSocket?.dispose();
//     sttSocket = SttWebSocket(
//       serverUrl: _wsUrl,
//       fac: _fac,
//       type: widget.patrolGroup.name,
//       onSttUpdate: (value) {
//         if (!mounted) return;
//         setState(() {
//           stt = value;
//           _sttLoading = false;
//         });
//       },
//     );
//     sttSocket!.connect();
//   }
//
//   // =========================
//   // Capture / Upload
//   // =========================
//   Future<String?> _decodeQrFromBytes(Uint8List bytes) async {
//     String? url;
//     StreamSubscription<html.Event>? sub;
//     final completer = Completer<String?>();
//
//     try {
//       debugPrint('[DECODE] start, bytes = ${bytes.length}');
//
//       final blob = html.Blob([bytes], 'image/*');
//       url = html.Url.createObjectUrlFromBlob(blob);
//       debugPrint('[DECODE] objectUrl created = $url');
//
//       sub = html.window.on['qr-from-uploaded-image'].listen((event) {
//         debugPrint('[DECODE] event qr-from-uploaded-image received');
//
//         final e = event as html.CustomEvent;
//         final detail = e.detail;
//
//         final text = detail['text']?.toString().trim();
//         final err = detail['error']?.toString() ?? '';
//
//         debugPrint('[DECODE] text = $text');
//         debugPrint('[DECODE] error = $err');
//
//         if (!completer.isCompleted) {
//           completer.complete((text == null || text.isEmpty) ? null : text);
//         }
//       });
//
//       debugPrint('[DECODE] call JS decodeQrFromImageBytes');
//       _decodeQrFromImageBytesJs(url);
//
//       final result = await completer.future.timeout(
//         const Duration(seconds: 5),
//         onTimeout: () {
//           debugPrint('[DECODE] timeout after 5s');
//           return null;
//         },
//       );
//
//       debugPrint('[DECODE] final result = $result');
//       return result;
//     } catch (e, st) {
//       debugPrint('[DECODE] ERROR = $e');
//       debugPrint('[DECODE] STACK = $st');
//       return null;
//     } finally {
//       await sub?.cancel();
//       debugPrint('[DECODE] listener cancelled');
//
//       if (url != null) {
//         html.Url.revokeObjectUrl(url);
//         debugPrint('[DECODE] objectUrl revoked');
//       }
//     }
//   }
//
//   // Future<void> pickImagesFromDevice(BuildContext context) async {
//   //   final remain = _maxImages - _capturedImages.length;
//   //   if (remain <= 0) {
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       const SnackBar(
//   //         content: Text("You can upload up to 3 images only."),
//   //         backgroundColor: Colors.redAccent,
//   //         behavior: SnackBarBehavior.floating,
//   //       ),
//   //     );
//   //     return;
//   //   }
//   //
//   //   final uploadInput = html.FileUploadInputElement()
//   //     ..accept = 'image/*'
//   //     ..multiple = true;
//   //
//   //   uploadInput.click();
//   //
//   //   uploadInput.onChange.listen((_) async {
//   //     final files = uploadInput.files;
//   //     if (files == null || files.isEmpty) return;
//   //
//   //     final selected = files.take(remain);
//   //
//   //     for (final file in selected) {
//   //       final reader = html.FileReader();
//   //       reader.readAsArrayBuffer(file);
//   //       await reader.onLoadEnd.first;
//   //
//   //       final bytes = reader.result as Uint8List;
//   //
//   //       // decode QR trong chính ảnh upload
//   //       final qrText = await _decodeQrFromBytes(bytes);
//   //
//   //       if (qrText != null && qrText.isNotEmpty) {
//   //         if (widget.type != 'Patrol' || RegExp(r'^\d{4}$').hasMatch(qrText)) {
//   //           setState(() {
//   //             _lastQr = qrText;
//   //             _lastQrAt = DateTime.now();
//   //           });
//   //
//   //           widget.onQrDetected?.call(qrText);
//   //           HapticFeedback.mediumImpact();
//   //           _playQrChangedFx();
//   //         }
//   //       }
//   //
//   //       // add ảnh sau khi đọc QR
//   //       setState(() {
//   //         _capturedImages.add(bytes);
//   //       });
//   //     }
//   //
//   //     widget.onImagesChanged?.call(_capturedImages);
//   //   });
//   // }
//   Future<void> pickImagesFromDevice(BuildContext context) async {
//     final remain = _maxImages - _capturedImages.length;
//     if (remain <= 0) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("You can upload up to 3 images only."),
//           backgroundColor: Colors.redAccent,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//       return;
//     }
//
//     final uploadInput = html.FileUploadInputElement()
//       ..accept = 'image/*'
//       ..multiple = true;
//
//     uploadInput.click();
//
//     uploadInput.onChange.listen((_) async {
//       final files = uploadInput.files;
//       if (files == null || files.isEmpty) return;
//
//       final selected = files.take(remain);
//
//       for (final file in selected) {
//         try {
//           // ✅ tạo object url từ file gốc
//           final objectUrl = html.Url.createObjectUrl(file);
//
//           // ✅ load ảnh vào ImageElement
//           final img = html.ImageElement();
//           final completer = Completer<void>();
//
//           img.onLoad.listen((_) {
//             if (!completer.isCompleted) completer.complete();
//           });
//
//           img.onError.listen((_) {
//             if (!completer.isCompleted) {
//               completer.completeError('Failed to load image');
//             }
//           });
//
//           img.src = objectUrl;
//           await completer.future;
//
//           final w = img.naturalWidth ?? img.width ?? 0;
//           final h = img.naturalHeight ?? img.height ?? 0;
//
//           if (w == 0 || h == 0) {
//             html.Url.revokeObjectUrl(objectUrl);
//             continue;
//           }
//
//           // ✅ vẽ lại qua canvas để chuẩn hóa sang JPEG
//           final canvas = html.CanvasElement(width: w, height: h);
//           final ctx = canvas.context2D;
//           ctx.drawImage(img, 0, 0);
//
//           final blob = await canvas.toBlob('image/jpeg', 0.9);
//           if (blob == null) {
//             html.Url.revokeObjectUrl(objectUrl);
//             continue;
//           }
//
//           final reader = html.FileReader();
//           reader.readAsArrayBuffer(blob);
//           await reader.onLoadEnd.first;
//
//           final result = reader.result;
//           final bytes = result is ByteBuffer
//               ? Uint8List.view(result)
//               : Uint8List.fromList(result as List<int>);
//
//           // ✅ decode QR từ ảnh đã chuẩn hóa
//           final qrText = await _decodeQrFromBytes(bytes);
//
//           // if (qrText != null && qrText.isNotEmpty) {
//           //   if (widget.type != 'Patrol' ||
//           //       RegExp(r'^\d{4}$').hasMatch(qrText)) {
//           //     setState(() {
//           //       _lastQr = qrText;
//           //       _lastQrAt = DateTime.now();
//           //     });
//           //
//           //     widget.onQrDetected?.call(qrText);
//           //     HapticFeedback.mediumImpact();
//           //     _playQrChangedFx();
//           //   }
//           // }
//
//           if (qrText != null && qrText.isNotEmpty) {
//             // setState(() {
//             //   _lastQr = qrText;
//             //   _lastQrAt = DateTime.now();
//             // });
//
//             final now = DateTime.now();
//
//             setState(() {
//               _lastDetectedQr = qrText;
//               _lastDetectedQrAt = now;
//
//               // QR máy không được làm mất QR Patrol.
//               if (_isQrNumber(qrText)) {
//                 _lastQr = qrText;
//               }
//             });
//
//             widget.onQrDetected?.call(qrText);
//           }
//
//           // ✅ add preview bytes
//           setState(() {
//             _capturedImages.add(bytes);
//           });
//
//           html.Url.revokeObjectUrl(objectUrl);
//         } catch (e) {
//           debugPrint('pickImagesFromDevice error: $e');
//         }
//       }
//
//       widget.onImagesChanged?.call(_capturedImages);
//     });
//   }
//
//   void removeImage(int index) {
//     setState(() => _capturedImages.removeAt(index));
//     widget.onImagesChanged?.call(_capturedImages);
//   }
//
//   void clearAll() {
//     setState(() => _capturedImages.clear());
//     widget.onImagesChanged?.call(_capturedImages);
//   }
//
//   void resetQr() {
//     setState(() {
//       _lastQr = null;
//       _lastDetectedQr = null;
//       _lastDetectedQrAt = null;
//       _qrPoints = null;
//     });
//   }
//
//   Future<void> _takePhoto() async {
//     if (_isCapturing || _video == null) return;
//     if (_capturedImages.length >= _maxImages) return;
//
//     setState(() => _isCapturing = true);
//     _flashController.forward().then((_) => _flashController.reverse());
//
//     try {
//       final video = _video!;
//       final vw = video.videoWidth.toDouble();
//       final vh = video.videoHeight.toDouble();
//       if (vw == 0 || vh == 0) return;
//
//       final outputSize = math.min(math.max(vw, vh), 2048).toInt();
//       final canvas = html.CanvasElement(width: outputSize, height: outputSize);
//       final ctx = canvas.context2D;
//
//       final srcSize = math.min(vw, vh) / _zoom;
//       final sx = (vw - srcSize) / 2;
//       final sy = (vh - srcSize) / 2;
//
//       ctx.drawImageScaledFromSource(
//         video,
//         sx,
//         sy,
//         srcSize,
//         srcSize,
//         0,
//         0,
//         outputSize.toDouble(),
//         outputSize.toDouble(),
//       );
//
//       final blob = await canvas.toBlob('image/jpeg', 0.8);
//       final reader = html.FileReader();
//       reader.readAsArrayBuffer(blob);
//       await reader.onLoadEnd.first;
//
//       final bytes = reader.result as Uint8List;
//       setState(() => _capturedImages.add(bytes));
//       widget.onImagesChanged?.call(_capturedImages);
//     } finally {
//       if (mounted) setState(() => _isCapturing = false);
//     }
//   }
//
//   // =========================
//   // UI
//   // =========================
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Stack(
//           children: [
//             Container(
//               width: widget.size,
//               height: widget.size,
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(20),
//                 child: Stack(
//                   fit: StackFit.expand,
//                   children: [
//                     _video != null
//                         ? Transform.scale(
//                             scale: _zoom,
//                             child: HtmlElementView(
//                               key: ValueKey(_viewType),
//                               viewType: _viewType,
//                             ),
//                           )
//                         : Container(
//                             color: Colors.grey[300],
//                             child: const Center(
//                               child: CircularProgressIndicator(),
//                             ),
//                           ),
//
//                     // QR box overlay (if points exist)
//                     if (_qrPoints != null && _videoSize != null)
//                       Positioned.fill(
//                         child: IgnorePointer(
//                           child: CustomPaint(
//                             painter: _QrBoxPainterCoverSquare(
//                               points: _qrPoints!,
//                               videoSize: _videoSize!,
//                               viewSize: Size(widget.size, widget.size),
//                               zoom: _zoom,
//                             ),
//                           ),
//                         ),
//                       ),
//
//                     // glass overlay
//                     BackdropFilter(
//                       filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
//                       child: Container(color: Colors.white.withOpacity(0.08)),
//                     ),
//
//                     // flash
//                     AnimatedBuilder(
//                       animation: _flashController,
//                       builder: (_, __) => Container(
//                         color: Colors.white.withOpacity(
//                           0.85 * _flashController.value,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//
//             // Upload
//             Positioned(
//               bottom: 14,
//               left: 7,
//               child: GestureDetector(
//                 onTap: canUpload ? () => pickImagesFromDevice(context) : null,
//                 child: GlassCircleButton(
//                   size: 50,
//                   child: Icon(
//                     Icons.upload_rounded,
//                     color: canUpload ? Colors.white : Colors.grey,
//                     size: 30,
//                   ),
//                 ),
//               ),
//             ),
//             Positioned(
//               bottom: 14,
//               left: 65,
//               child: GestureDetector(
//                 onTap: _inputQrManually,
//                 child: GlassCircleButton(
//                   size: 50,
//                   child: const Icon(
//                     Icons.keyboard_rounded,
//                     color: Colors.white,
//                     size: 28,
//                   ),
//                 ),
//               ),
//             ),
//             // QR text
//             Positioned(
//               top: 12,
//               left: 12,
//               child: AnimatedBuilder(
//                 animation: _qrFlashCtrl,
//                 builder: (context, child) {
//                   final dx = (_qrFlashCtrl.value < 0.5
//                       ? -_qrShakeAnim.value
//                       : _qrShakeAnim.value);
//
//                   return Transform.translate(
//                     offset: Offset(dx, 0),
//                     child: Transform.scale(
//                       scale: _qrScaleAnim.value,
//                       child: child,
//                     ),
//                   );
//                 },
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(16),
//                   child: BackdropFilter(
//                     filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 8,
//                         vertical: 5,
//                       ),
//                       decoration: BoxDecoration(
//                         color: _qrFlashCtrl.isAnimating
//                             ? Color(0xFF203A43)
//                             : Colors.white.withOpacity(0.18),
//                         borderRadius: BorderRadius.circular(16),
//                         border: Border.all(
//                           color: _qrFlashCtrl.isAnimating
//                               ? Color(0xFF203A43)
//                               : Colors.blueAccent.withOpacity(0.5),
//                           width: 1,
//                         ),
//                       ),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(
//                             Icons.qr_code_rounded,
//                             size: 20,
//                             color: _lastQr != null
//                                 ? Colors.white
//                                 : Colors.red.withOpacity(.6),
//                           ),
//                           const SizedBox(width: 8),
//
//                           // ✅ Text “nhảy” khi đổi QR
//                           AnimatedSwitcher(
//                             duration: const Duration(milliseconds: 300),
//                             switchInCurve: Curves.easeOutBack,
//                             switchOutCurve: Curves.easeIn,
//                             transitionBuilder: (child, anim) {
//                               return SlideTransition(
//                                 position: Tween<Offset>(
//                                   begin: const Offset(0, 0.9),
//                                   end: Offset.zero,
//                                 ).animate(anim),
//                                 child: ScaleTransition(
//                                   scale: Tween<double>(
//                                     begin: 0.75,
//                                     end: 1.08,
//                                   ).animate(anim),
//                                   child: FadeTransition(
//                                     opacity: anim,
//                                     child: child,
//                                   ),
//                                 ),
//                               );
//                             },
//                             child: Text(
//                               _lastQr ?? '',
//                               key: ValueKey(_lastQr),
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 13,
//                                 fontWeight: FontWeight.w700,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//
//             // STT
//             Positioned(
//               top: 12,
//               right: 12,
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(16),
//                 child: BackdropFilter(
//                   filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 8,
//                       vertical: 5,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.18),
//                       borderRadius: BorderRadius.circular(16),
//                       border: Border.all(
//                         color: Colors.white.withOpacity(0.5),
//                         width: 1,
//                       ),
//                     ),
//                     child: _sttLoading
//                         ? const SizedBox(
//                             width: 16,
//                             height: 16,
//                             child: CircularProgressIndicator(
//                               strokeWidth: 2,
//                               color: Colors.white,
//                             ),
//                           )
//                         : Text(
//                             'No. ${stt + 1}',
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontSize: 13,
//                               fontWeight: FontWeight.bold,
//                               letterSpacing: 0.6,
//                             ),
//                           ),
//                   ),
//                 ),
//               ),
//             ),
//
//             // Zoom
//             Positioned(
//               bottom: 14,
//               right: 14,
//               child: GlassZoomControl(
//                 zoom: _zoom,
//                 minZoom: _minZoom,
//                 maxZoom: _maxZoom,
//                 onChanged: (v) => setState(() => _zoom = v),
//               ),
//             ),
//
//             // Capture
//             Positioned(
//               bottom: -18,
//               left: 0,
//               right: 0,
//               child: Center(
//                 child: GestureDetector(
//                   onTap: (!_isCapturing && canUpload) ? _takePhoto : null,
//                   child: GlassCircleButton(
//                     size: 80,
//                     showProgress: _isCapturing,
//                     child: _isCapturing
//                         ? null
//                         : Icon(
//                             Icons.camera_alt_rounded,
//                             color: canUpload ? Colors.white : Colors.grey,
//                             size: 36,
//                           ),
//                   ),
//                 ),
//               ),
//             ),
//
//             // QR status spinner (optional)
//             if (_qrLoading)
//               const Positioned(
//                 top: 12,
//                 left: 120,
//                 child: SizedBox(
//                   width: 14,
//                   height: 14,
//                   child: CircularProgressIndicator(strokeWidth: 2),
//                 ),
//               ),
//           ],
//         ),
//       ],
//     );
//   }
// }
//
// /// Painter: map ZXing points (video coords) -> square widget with objectFit.cover + zoom
// class _QrBoxPainterCoverSquare extends CustomPainter {
//   final List<Offset> points;
//   final Size videoSize;
//   final Size viewSize;
//   final double zoom;
//
//   _QrBoxPainterCoverSquare({
//     required this.points,
//     required this.videoSize,
//     required this.viewSize,
//     required this.zoom,
//   });
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     if (points.isEmpty || videoSize.width <= 0 || videoSize.height <= 0) return;
//
//     // 1) cover crop to square (center crop)
//     final vw = videoSize.width;
//     final vh = videoSize.height;
//
//     double cropX = 0, cropY = 0, cropW = vw, cropH = vh;
//     final aspect = vw / vh;
//     if (aspect > 1) {
//       // landscape -> crop width
//       cropW = vh;
//       cropX = (vw - cropW) / 2;
//     } else if (aspect < 1) {
//       // portrait -> crop height
//       cropH = vw;
//       cropY = (vh - cropH) / 2;
//     }
//
//     // 2) apply zoom (your UI uses Transform.scale)
//     final z = zoom.clamp(
//       _CameraPreviewBoxStateShim.minZoom,
//       _CameraPreviewBoxStateShim.maxZoom,
//     );
//     final zoomedSide = cropW / z; // cropW == cropH == square
//     final zx = cropX + (cropW - zoomedSide) / 2;
//     final zy = cropY + (cropH - zoomedSide) / 2;
//
//     // 3) map to view square
//     final sx = viewSize.width / zoomedSide;
//     final sy = viewSize.height / zoomedSide;
//
//     Offset map(Offset p) {
//       final x = (p.dx - zx) * sx;
//       final y = (p.dy - zy) * sy;
//       return Offset(x, y);
//     }
//
//     final mapped = points.map(map).toList();
//
//     // draw bounding rect (stable)
//     Rect rect = Rect.fromLTWH(mapped.first.dx, mapped.first.dy, 0, 0);
//     for (final p in mapped) {
//       rect = rect.expandToInclude(Rect.fromLTWH(p.dx, p.dy, 0, 0));
//     }
//
//     final paint = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 3
//       ..color = Colors.greenAccent;
//
//     canvas.drawRRect(
//       RRect.fromRectAndRadius(rect.inflate(6), const Radius.circular(12)),
//       paint,
//     );
//   }
//
//   @override
//   bool shouldRepaint(covariant _QrBoxPainterCoverSquare oldDelegate) {
//     return oldDelegate.points != points ||
//         oldDelegate.videoSize != videoSize ||
//         oldDelegate.viewSize != viewSize ||
//         oldDelegate.zoom != zoom;
//   }
// }
//
// /// Hack: painter is outside state; keep constants accessible cleanly.
// class _CameraPreviewBoxStateShim {
//   static const double minZoom = 1.0;
//   static const double maxZoom = 10.0;
// }
// import 'dart:async';
// import 'dart:html' as html;
// import 'dart:math' as math;
// import 'dart:typed_data';
// import 'dart:ui';
// import 'dart:ui_web' as ui_web;
//
// import 'package:chuphinh/socket/SttWebSocket.dart';
// import 'package:chuphinh/widget/glass_circle_button.dart';
// import 'package:chuphinh/widget/glass_zoom_control.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:js/js.dart';
//
// import 'api/api_config.dart';
// import 'api/stt_api.dart';
// import 'homeScreen/patrol_home_screen.dart';
//
// @JS('startQrLoop')
// external void startQrLoop();
//
// @JS('stopQrLoop')
// external void stopQrLoop();
//
// @JS('decodeQrFromImageBytes')
// external void _decodeQrFromImageBytesJs(String objectUrl);
//
// class CameraPreviewBox extends StatefulWidget {
//   final double size;
//   final Function(List<Uint8List> images)? onImagesChanged;
//
//   final String? plant;
//   final String? group;
//   final String type;
//   final String? wsUrl;
//   final PatrolGroup patrolGroup;
//
//   /// ✅ Gửi QR về class cha
//   final ValueChanged<String>? onQrDetected;
//
//   const CameraPreviewBox({
//     super.key,
//     this.size = 320,
//     this.onImagesChanged,
//     this.plant,
//     this.group,
//     required this.type,
//     this.wsUrl,
//     required this.patrolGroup,
//     this.onQrDetected,
//   });
//
//   @override
//   State<CameraPreviewBox> createState() => CameraPreviewBoxState();
// }
//
// class CameraPreviewBoxState extends State<CameraPreviewBox>
//     with TickerProviderStateMixin {
//   // =========================
//   // Config
//   // =========================
//   static const int _maxImages = 3;
//
//   static const Duration _qrDedupe = Duration(milliseconds: 1200);
//   static const Duration _qrWarmup = Duration(milliseconds: 250);
//
//   static const double _minZoom = 1.0;
//   static const double _maxZoom = 10.0;
//
//   // =========================
//   // Camera / View
//   // =========================
//   html.MediaStream? _stream;
//   html.VideoElement? _video;
//   late String _viewType;
//
//   double _zoom = 1.0;
//
//   // =========================
//   // QR scanning (JS ZXing)
//   // =========================
//   StreamSubscription? _qrSub;
//   bool _qrScanning = false;
//   bool _qrLoading = false;
//
//   /// QR Patrol dạng số đang hiển thị trên UI.
//   /// ValueNotifier giúp chỉ rebuild badge QR, không rebuild toàn camera.
//   final ValueNotifier<String?> _patrolQrNotifier = ValueNotifier<String?>(null);
//
//   /// true: hiện khung hướng dẫn căn QR.
//   /// false: đã đọc được QR bất kỳ nên ẩn khung.
//   final ValueNotifier<bool> _showQrGuideNotifier = ValueNotifier<bool>(true);
//
//   /// QR raw gần nhất, dùng chống callback lặp liên tục.
//   String? _lastDetectedQr;
//   DateTime? _lastDetectedQrAt;
//
//   // =========================
//   // Capture
//   // =========================
//   bool _isCapturing = false;
//   final List<Uint8List> _capturedImages = [];
//   late final AnimationController _flashController;
//
//   bool get canUpload => _capturedImages.length < _maxImages;
//
//   List<Uint8List> get images => List.unmodifiable(_capturedImages);
//
//   // =========================
//   // STT / Socket
//   // =========================
//   late String _fac;
//   late String _group;
//   late String _wsUrl;
//
//   int stt = 0;
//   bool _sttLoading = true;
//   SttWebSocket? sttSocket;
//
//   // =========================
//   // Lifecycle
//   // =========================
//
//   @override
//   void initState() {
//     super.initState();
//
//     _viewType = 'camera_${DateTime.now().millisecondsSinceEpoch}';
//     _fac = (widget.plant ?? '').trim();
//     _group = (widget.group ?? '').trim();
//     _wsUrl = widget.wsUrl ?? '${ApiConfig.wsBaseUrl}/ws-stt/websocket';
//
//     _flashController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 200),
//     );
//
//     _startCamera();
//     _loadStt();
//     _connectSocket();
//   }
//
//   @override
//   void didUpdateWidget(covariant CameraPreviewBox oldWidget) {
//     super.didUpdateWidget(oldWidget);
//
//     final newFac = (widget.plant ?? '').trim();
//     final newGroup = (widget.group ?? '').trim();
//
//     if (newFac != _fac || newGroup != _group) {
//       _fac = newFac;
//       _group = newGroup;
//       // Nếu cần reload STT/socket theo group/fac thì bật lại:
//       // _loadStt();
//       // _connectSocket();
//     }
//   }
//
//   @override
//   void dispose() {
//     _patrolQrNotifier.dispose();
//     _showQrGuideNotifier.dispose();
//
//     _stopQrScan();
//     _flashController.dispose();
//     _stopCamera();
//
//     try {
//       sttSocket?.dispose();
//     } catch (_) {}
//
//     super.dispose();
//   }
//
//   bool _isQrNumber(String value) {
//     return RegExp(r'^\d{1,5}$').hasMatch(value.trim());
//   }
//
//   bool _isDuplicateQr(String qr, DateTime now) {
//     return _lastDetectedQr == qr &&
//         _lastDetectedQrAt != null &&
//         now.difference(_lastDetectedQrAt!) < _qrDedupe;
//   }
//
//   /// Nhận QR từ camera, nhập tay hoặc ảnh upload.
//   /// Hàm này không gọi setState nên không rebuild toàn bộ camera.
//   void _acceptDetectedQr(String rawQr, {bool haptic = true}) {
//     if (!mounted) return;
//
//     final qr = rawQr.trim();
//     if (qr.isEmpty) return;
//
//     final now = DateTime.now();
//     if (_isDuplicateQr(qr, now)) return;
//
//     _lastDetectedQr = qr;
//     _lastDetectedQrAt = now;
//
//     if (_showQrGuideNotifier.value) {
//       _showQrGuideNotifier.value = false;
//     }
//
//     // QR máy không được xóa QR Patrol cũ trên UI.
//     if (_isQrNumber(qr) && _patrolQrNotifier.value != qr) {
//       _patrolQrNotifier.value = qr;
//     }
//
//     if (haptic) {
//       HapticFeedback.mediumImpact();
//     }
//
//     widget.onQrDetected?.call(qr);
//   }
//
//   // =========================
//   // Camera
//   // =========================
//
//   Future<void> _inputQrManually() async {
//     final controller = TextEditingController();
//
//     try {
//       final value = await showDialog<String>(
//         context: context,
//         builder: (dialogContext) {
//           return AlertDialog(
//             backgroundColor: const Color(0xFF1F2937),
//             title: const Text(
//               'Enter QR Code',
//               style: TextStyle(color: Colors.white),
//             ),
//             content: TextField(
//               controller: controller,
//               autofocus: true,
//               style: const TextStyle(color: Colors.white),
//               decoration: const InputDecoration(
//                 hintText: 'Input QR code manually',
//                 hintStyle: TextStyle(color: Colors.white54),
//               ),
//               onSubmitted: (text) {
//                 Navigator.pop(dialogContext, text.trim());
//               },
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(dialogContext),
//                 child: const Text('Cancel'),
//               ),
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.pop(dialogContext, controller.text.trim());
//                 },
//                 child: const Text('OK'),
//               ),
//             ],
//           );
//         },
//       );
//
//       if (value == null || value.trim().isEmpty) return;
//
//       _acceptDetectedQr(value, haptic: false);
//     } finally {
//       controller.dispose();
//     }
//   }
//
//   Future<void> _startCamera() async {
//     try {
//       final stream = await html.window.navigator.mediaDevices!.getUserMedia({
//         'video': {
//           'facingMode': 'environment',
//           // ✅ đừng xin 4K (nặng + decode chậm)
//           'width': {'ideal': 1280, 'min': 640},
//           'height': {'ideal': 720, 'min': 480},
//         },
//       });
//
//       final video = html.VideoElement()
//         ..id = 'qr-video'
//         ..setAttribute('autoplay', 'true')
//         ..setAttribute('playsinline', 'true')
//         ..setAttribute('muted', 'true')
//         ..style.objectFit = 'cover'
//         ..style.pointerEvents = 'none'
//         ..style.position = 'absolute'
//         ..style.top = '0'
//         ..style.left = '0'
//         ..style.width = '100%'
//         ..style.height = '100%'
//         ..style.zIndex = '0'
//         ..srcObject = stream;
//
//       ui_web.platformViewRegistry.registerViewFactory(_viewType, (id) => video);
//
//       setState(() {
//         _stream = stream;
//         _video = video;
//       });
//
//       // ✅ đợi video ready rồi auto scan
//       await _waitVideoReady(timeout: const Duration(seconds: 3));
//       if (!mounted) return;
//       await Future.delayed(_qrWarmup);
//       _startAutoQrScan();
//     } catch (e) {
//       debugPrint('Camera error: $e');
//     }
//   }
//
//   Future<void> _waitVideoReady({required Duration timeout}) async {
//     final start = DateTime.now();
//     while (mounted) {
//       final v = _video;
//       if (v != null && v.videoWidth > 0 && v.videoHeight > 0) return;
//       if (DateTime.now().difference(start) > timeout) return;
//       await Future.delayed(const Duration(milliseconds: 50));
//     }
//   }
//
//   void _stopCamera() {
//     try {
//       _stream?.getTracks().forEach((t) => t.stop());
//     } catch (_) {}
//   }
//
//   // =========================
//   // QR (ZXing JS) start/stop
//   // =========================
//   Future<void> _startAutoQrScan() async {
//     if (_qrScanning) return;
//
//     setState(() {
//       _qrScanning = true;
//       _qrLoading = true;
//     });
//
//     // ✅ listener trước rồi mới start loop
//     await _qrSub?.cancel();
//     _qrSub = html.window.on['qr-from-image'].listen(_onQrEvent);
//
//     // start JS loop
//     try {
//       startQrLoop();
//     } catch (e) {
//       debugPrint('startQrLoop error: $e');
//     }
//
//     if (mounted) setState(() => _qrLoading = false);
//   }
//
//   Future<void> _stopQrScan() async {
//     try {
//       stopQrLoop();
//     } catch (_) {}
//
//     try {
//       await _qrSub?.cancel();
//     } catch (_) {}
//     _qrSub = null;
//
//     if (mounted) {
//       setState(() {
//         _qrScanning = false;
//         _qrLoading = false;
//       });
//     }
//   }
//
//   void _onQrEvent(dynamic event) {
//     if (!mounted) return;
//
//     final customEvent = event as html.CustomEvent;
//     final detail = customEvent.detail;
//
//     if (detail == null) return;
//
//     final error = detail['error']?.toString().trim() ?? '';
//     if (error.isNotEmpty) return;
//
//     final text = detail['text']?.toString().trim() ?? '';
//     if (text.isEmpty) return;
//
//     _acceptDetectedQr(text);
//   }
//
//   // =========================
//   // STT / socket
//   // =========================
//   Future<void> _loadStt() async {
//     if (_fac.isEmpty) return;
//     try {
//       setState(() => _sttLoading = true);
//
//       final value = await SttApi.getCurrentStt(
//         fac: _fac,
//         type: widget.patrolGroup.name,
//       );
//
//       if (!mounted) return;
//       setState(() {
//         stt = value;
//         _sttLoading = false;
//       });
//     } catch (e) {
//       if (mounted) setState(() => _sttLoading = false);
//     }
//   }
//
//   void _connectSocket() {
//     sttSocket?.dispose();
//     sttSocket = SttWebSocket(
//       serverUrl: _wsUrl,
//       fac: _fac,
//       type: widget.patrolGroup.name,
//       onSttUpdate: (value) {
//         if (!mounted) return;
//         setState(() {
//           stt = value;
//           _sttLoading = false;
//         });
//       },
//     );
//     sttSocket!.connect();
//   }
//
//   // =========================
//   // Capture / Upload
//   // =========================
//   Future<String?> _decodeQrFromBytes(Uint8List bytes) async {
//     String? url;
//     StreamSubscription<html.Event>? sub;
//     final completer = Completer<String?>();
//
//     try {
//       debugPrint('[DECODE] start, bytes = ${bytes.length}');
//
//       final blob = html.Blob([bytes], 'image/*');
//       url = html.Url.createObjectUrlFromBlob(blob);
//       debugPrint('[DECODE] objectUrl created = $url');
//
//       sub = html.window.on['qr-from-uploaded-image'].listen((event) {
//         debugPrint('[DECODE] event qr-from-uploaded-image received');
//
//         final e = event as html.CustomEvent;
//         final detail = e.detail;
//
//         final text = detail['text']?.toString().trim();
//         final err = detail['error']?.toString() ?? '';
//
//         debugPrint('[DECODE] text = $text');
//         debugPrint('[DECODE] error = $err');
//
//         if (!completer.isCompleted) {
//           completer.complete((text == null || text.isEmpty) ? null : text);
//         }
//       });
//
//       debugPrint('[DECODE] call JS decodeQrFromImageBytes');
//       _decodeQrFromImageBytesJs(url);
//
//       final result = await completer.future.timeout(
//         const Duration(seconds: 5),
//         onTimeout: () {
//           debugPrint('[DECODE] timeout after 5s');
//           return null;
//         },
//       );
//
//       debugPrint('[DECODE] final result = $result');
//       return result;
//     } catch (e, st) {
//       debugPrint('[DECODE] ERROR = $e');
//       debugPrint('[DECODE] STACK = $st');
//       return null;
//     } finally {
//       await sub?.cancel();
//       debugPrint('[DECODE] listener cancelled');
//
//       if (url != null) {
//         html.Url.revokeObjectUrl(url);
//         debugPrint('[DECODE] objectUrl revoked');
//       }
//     }
//   }
//
//   // Future<void> pickImagesFromDevice(BuildContext context) async {
//   //   final remain = _maxImages - _capturedImages.length;
//   //   if (remain <= 0) {
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       const SnackBar(
//   //         content: Text("You can upload up to 3 images only."),
//   //         backgroundColor: Colors.redAccent,
//   //         behavior: SnackBarBehavior.floating,
//   //       ),
//   //     );
//   //     return;
//   //   }
//   //
//   //   final uploadInput = html.FileUploadInputElement()
//   //     ..accept = 'image/*'
//   //     ..multiple = true;
//   //
//   //   uploadInput.click();
//   //
//   //   uploadInput.onChange.listen((_) async {
//   //     final files = uploadInput.files;
//   //     if (files == null || files.isEmpty) return;
//   //
//   //     final selected = files.take(remain);
//   //
//   //     for (final file in selected) {
//   //       final reader = html.FileReader();
//   //       reader.readAsArrayBuffer(file);
//   //       await reader.onLoadEnd.first;
//   //
//   //       final bytes = reader.result as Uint8List;
//   //
//   //       // decode QR trong chính ảnh upload
//   //       final qrText = await _decodeQrFromBytes(bytes);
//   //
//   //       if (qrText != null && qrText.isNotEmpty) {
//   //         if (widget.type != 'Patrol' || RegExp(r'^\d{4}$').hasMatch(qrText)) {
//   //           setState(() {
//   //             _lastQr = qrText;
//   //             _lastQrAt = DateTime.now();
//   //           });
//   //
//   //           widget.onQrDetected?.call(qrText);
//   //           HapticFeedback.mediumImpact();
//   //           _playQrChangedFx();
//   //         }
//   //       }
//   //
//   //       // add ảnh sau khi đọc QR
//   //       setState(() {
//   //         _capturedImages.add(bytes);
//   //       });
//   //     }
//   //
//   //     widget.onImagesChanged?.call(_capturedImages);
//   //   });
//   // }
//   Future<void> pickImagesFromDevice(BuildContext context) async {
//     final remain = _maxImages - _capturedImages.length;
//
//     if (remain <= 0) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('You can upload up to 3 images only.'),
//           backgroundColor: Colors.redAccent,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//       return;
//     }
//
//     final uploadInput = html.FileUploadInputElement()
//       ..accept = 'image/*'
//       ..multiple = true;
//
//     uploadInput.click();
//
//     await uploadInput.onChange.first;
//
//     final files = uploadInput.files;
//     if (files == null || files.isEmpty) return;
//
//     for (final file in files.take(remain)) {
//       String? objectUrl;
//
//       try {
//         objectUrl = html.Url.createObjectUrl(file);
//
//         final image = html.ImageElement();
//         final imageReady = Completer<void>();
//
//         late final StreamSubscription<html.Event> loadSub;
//         late final StreamSubscription<html.Event> errorSub;
//
//         loadSub = image.onLoad.listen((_) {
//           if (!imageReady.isCompleted) imageReady.complete();
//         });
//
//         errorSub = image.onError.listen((_) {
//           if (!imageReady.isCompleted) {
//             imageReady.completeError(StateError('Failed to load image'));
//           }
//         });
//
//         image.src = objectUrl;
//
//         try {
//           await imageReady.future.timeout(const Duration(seconds: 10));
//         } finally {
//           await loadSub.cancel();
//           await errorSub.cancel();
//         }
//
//         final width = image.naturalWidth ?? image.width ?? 0;
//         final height = image.naturalHeight ?? image.height ?? 0;
//
//         if (width <= 0 || height <= 0) continue;
//
//         final canvas = html.CanvasElement(width: width, height: height);
//         canvas.context2D.drawImage(image, 0, 0);
//
//         final blob = await canvas.toBlob('image/jpeg', 0.9);
//         if (blob == null) continue;
//
//         final reader = html.FileReader();
//         reader.readAsArrayBuffer(blob);
//         await reader.onLoadEnd.first;
//
//         final result = reader.result;
//         final bytes = result is ByteBuffer
//             ? Uint8List.view(result)
//             : Uint8List.fromList(result as List<int>);
//
//         final qrText = await _decodeQrFromBytes(bytes);
//         if (qrText != null && qrText.trim().isNotEmpty) {
//           _acceptDetectedQr(qrText, haptic: false);
//         }
//
//         if (!mounted) return;
//
//         setState(() {
//           _capturedImages.add(bytes);
//         });
//
//         widget.onImagesChanged?.call(
//           List<Uint8List>.unmodifiable(_capturedImages),
//         );
//       } catch (error, stackTrace) {
//         debugPrint('pickImagesFromDevice error: $error');
//         debugPrintStack(stackTrace: stackTrace);
//       } finally {
//         if (objectUrl != null) {
//           html.Url.revokeObjectUrl(objectUrl);
//         }
//       }
//     }
//   }
//
//   void removeImage(int index) {
//     setState(() => _capturedImages.removeAt(index));
//     widget.onImagesChanged?.call(_capturedImages);
//   }
//
//   void clearAll() {
//     setState(() => _capturedImages.clear());
//     widget.onImagesChanged?.call(_capturedImages);
//   }
//
//   void resetQr() {
//     _lastDetectedQr = null;
//     _lastDetectedQrAt = null;
//
//     _patrolQrNotifier.value = null;
//     _showQrGuideNotifier.value = true;
//   }
//
//   Future<void> _takePhoto() async {
//     if (_isCapturing || _video == null) return;
//     if (_capturedImages.length >= _maxImages) return;
//
//     setState(() => _isCapturing = true);
//     _flashController.forward().then((_) => _flashController.reverse());
//
//     try {
//       final video = _video!;
//       final vw = video.videoWidth.toDouble();
//       final vh = video.videoHeight.toDouble();
//       if (vw == 0 || vh == 0) return;
//
//       final outputSize = math.min(math.max(vw, vh), 2048).toInt();
//       final canvas = html.CanvasElement(width: outputSize, height: outputSize);
//       final ctx = canvas.context2D;
//
//       final srcSize = math.min(vw, vh) / _zoom;
//       final sx = (vw - srcSize) / 2;
//       final sy = (vh - srcSize) / 2;
//
//       ctx.drawImageScaledFromSource(
//         video,
//         sx,
//         sy,
//         srcSize,
//         srcSize,
//         0,
//         0,
//         outputSize.toDouble(),
//         outputSize.toDouble(),
//       );
//
//       final blob = await canvas.toBlob('image/jpeg', 0.8);
//       final reader = html.FileReader();
//       reader.readAsArrayBuffer(blob);
//       await reader.onLoadEnd.first;
//
//       final bytes = reader.result as Uint8List;
//       setState(() => _capturedImages.add(bytes));
//       widget.onImagesChanged?.call(_capturedImages);
//     } finally {
//       if (mounted) setState(() => _isCapturing = false);
//     }
//   }
//
//   // =========================
//   // UI
//   // =========================
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Stack(
//           clipBehavior: Clip.none,
//           children: [
//             RepaintBoundary(
//               child: Container(
//                 width: widget.size,
//                 height: widget.size,
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(20),
//                   child: Stack(
//                     fit: StackFit.expand,
//                     children: [
//                       _video != null
//                           ? Transform.scale(
//                               scale: _zoom,
//                               child: HtmlElementView(
//                                 key: ValueKey(_viewType),
//                                 viewType: _viewType,
//                               ),
//                             )
//                           : Container(
//                               color: Colors.grey[300],
//                               alignment: Alignment.center,
//                               child: const CircularProgressIndicator(),
//                             ),
//
//                       // Khung căn QR tĩnh: vẽ một lần, không chạy animation.
//                       Positioned.fill(
//                         child: IgnorePointer(
//                           child: ValueListenableBuilder<bool>(
//                             valueListenable: _showQrGuideNotifier,
//                             child: const RepaintBoundary(
//                               child: _QrGuideOverlay(),
//                             ),
//                             builder: (context, showGuide, child) {
//                               return showGuide
//                                   ? child!
//                                   : const SizedBox.shrink();
//                             },
//                           ),
//                         ),
//                       ),
//
//                       // Glass overlay giữ nguyên giao diện.
//                       BackdropFilter(
//                         filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
//                         child: Container(color: Colors.white.withOpacity(0.08)),
//                       ),
//
//                       // Flash chỉ rebuild lớp flash khi chụp ảnh.
//                       AnimatedBuilder(
//                         animation: _flashController,
//                         builder: (_, __) {
//                           return IgnorePointer(
//                             child: Container(
//                               color: Colors.white.withOpacity(
//                                 0.85 * _flashController.value,
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//
//             Positioned(
//               bottom: 14,
//               left: 7,
//               child: GestureDetector(
//                 onTap: canUpload ? () => pickImagesFromDevice(context) : null,
//                 child: GlassCircleButton(
//                   size: 50,
//                   child: Icon(
//                     Icons.upload_rounded,
//                     color: canUpload ? Colors.white : Colors.grey,
//                     size: 30,
//                   ),
//                 ),
//               ),
//             ),
//
//             Positioned(
//               bottom: 14,
//               left: 65,
//               child: GestureDetector(
//                 onTap: _inputQrManually,
//                 child: const GlassCircleButton(
//                   size: 50,
//                   child: Icon(
//                     Icons.keyboard_rounded,
//                     color: Colors.white,
//                     size: 28,
//                   ),
//                 ),
//               ),
//             ),
//
//             // Chỉ badge QR rebuild khi QR Patrol thay đổi.
//             Positioned(
//               top: 12,
//               left: 12,
//               child: RepaintBoundary(
//                 child: ValueListenableBuilder<String?>(
//                   valueListenable: _patrolQrNotifier,
//                   builder: (context, qr, _) {
//                     return _QrStatusBadge(qr: qr);
//                   },
//                 ),
//               ),
//             ),
//
//             Positioned(
//               top: 12,
//               right: 12,
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(16),
//                 child: BackdropFilter(
//                   filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 8,
//                       vertical: 5,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.18),
//                       borderRadius: BorderRadius.circular(16),
//                       border: Border.all(color: Colors.white.withOpacity(0.5)),
//                     ),
//                     child: _sttLoading
//                         ? const SizedBox(
//                             width: 16,
//                             height: 16,
//                             child: CircularProgressIndicator(
//                               strokeWidth: 2,
//                               color: Colors.white,
//                             ),
//                           )
//                         : Text(
//                             'No. ${stt + 1}',
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontSize: 13,
//                               fontWeight: FontWeight.bold,
//                               letterSpacing: 0.6,
//                             ),
//                           ),
//                   ),
//                 ),
//               ),
//             ),
//
//             Positioned(
//               bottom: 14,
//               right: 14,
//               child: GlassZoomControl(
//                 zoom: _zoom,
//                 minZoom: _minZoom,
//                 maxZoom: _maxZoom,
//                 onChanged: (value) {
//                   if ((value - _zoom).abs() < 0.001) return;
//                   setState(() => _zoom = value);
//                 },
//               ),
//             ),
//
//             Positioned(
//               bottom: -18,
//               left: 0,
//               right: 0,
//               child: Center(
//                 child: GestureDetector(
//                   onTap: (!_isCapturing && canUpload) ? _takePhoto : null,
//                   child: GlassCircleButton(
//                     size: 80,
//                     showProgress: _isCapturing,
//                     child: _isCapturing
//                         ? null
//                         : Icon(
//                             Icons.camera_alt_rounded,
//                             color: canUpload ? Colors.white : Colors.grey,
//                             size: 36,
//                           ),
//                   ),
//                 ),
//               ),
//             ),
//
//             if (_qrLoading)
//               const Positioned(
//                 top: 12,
//                 left: 150,
//                 child: SizedBox(
//                   width: 14,
//                   height: 14,
//                   child: CircularProgressIndicator(strokeWidth: 2),
//                 ),
//               ),
//           ],
//         ),
//       ],
//     );
//   }
// }
//
// class _QrStatusBadge extends StatelessWidget {
//   final String? qr;
//
//   const _QrStatusBadge({required this.qr});
//
//   @override
//   Widget build(BuildContext context) {
//     final value = qr?.trim() ?? '';
//     final hasQr = value.isNotEmpty;
//
//     return ClipRRect(
//       borderRadius: BorderRadius.circular(16),
//       child: BackdropFilter(
//         filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
//         child: Container(
//           constraints: const BoxConstraints(minHeight: 34),
//           padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
//           decoration: BoxDecoration(
//             color: Colors.black.withOpacity(0.30),
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(
//               color: hasQr
//                   ? const Color(0xFF22C55E).withOpacity(0.75)
//                   : Colors.redAccent.withOpacity(0.50),
//             ),
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Icon(
//                 hasQr ? Icons.qr_code_2_rounded : Icons.qr_code_scanner_rounded,
//                 size: 19,
//                 color: hasQr ? const Color(0xFF22C55E) : Colors.redAccent,
//               ),
//               const SizedBox(width: 7),
//               Text(
//                 hasQr ? value : 'Scan Patrol QR',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 13,
//                   fontWeight: hasQr ? FontWeight.w800 : FontWeight.w600,
//                   letterSpacing: hasQr ? 0.8 : 0,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class _QrGuideOverlay extends StatelessWidget {
//   const _QrGuideOverlay();
//
//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: SizedBox(
//         width: 205,
//         height: 205,
//         child: CustomPaint(
//           painter: const _QrGuidePainter(),
//           child: const Align(
//             alignment: Alignment.bottomCenter,
//             child: Padding(
//               padding: EdgeInsets.only(bottom: 12),
//               child: Text(
//                 'Place QR inside frame',
//                 style: TextStyle(
//                   color: Colors.white70,
//                   fontSize: 11,
//                   fontWeight: FontWeight.w600,
//                   shadows: [Shadow(color: Colors.black, blurRadius: 5)],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class _QrGuidePainter extends CustomPainter {
//   const _QrGuidePainter();
//
//   static const double _cornerLength = 38;
//   static const double _radius = 13;
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
//
//     final paint = Paint()
//       ..color = const Color(0xFF22C55E)
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 3
//       ..strokeCap = StrokeCap.round
//       ..strokeJoin = StrokeJoin.round;
//
//     final path = Path()
//       // Top left
//       ..moveTo(rect.left, rect.top + _cornerLength)
//       ..lineTo(rect.left, rect.top + _radius)
//       ..quadraticBezierTo(rect.left, rect.top, rect.left + _radius, rect.top)
//       ..lineTo(rect.left + _cornerLength, rect.top)
//       // Top right
//       ..moveTo(rect.right - _cornerLength, rect.top)
//       ..lineTo(rect.right - _radius, rect.top)
//       ..quadraticBezierTo(rect.right, rect.top, rect.right, rect.top + _radius)
//       ..lineTo(rect.right, rect.top + _cornerLength)
//       // Bottom right
//       ..moveTo(rect.right, rect.bottom - _cornerLength)
//       ..lineTo(rect.right, rect.bottom - _radius)
//       ..quadraticBezierTo(
//         rect.right,
//         rect.bottom,
//         rect.right - _radius,
//         rect.bottom,
//       )
//       ..lineTo(rect.right - _cornerLength, rect.bottom)
//       // Bottom left
//       ..moveTo(rect.left + _cornerLength, rect.bottom)
//       ..lineTo(rect.left + _radius, rect.bottom)
//       ..quadraticBezierTo(
//         rect.left,
//         rect.bottom,
//         rect.left,
//         rect.bottom - _radius,
//       )
//       ..lineTo(rect.left, rect.bottom - _cornerLength);
//
//     canvas.drawPath(path, paint);
//   }
//
//   @override
//   bool shouldRepaint(covariant _QrGuidePainter oldDelegate) => false;
// }
// import 'dart:async';
// import 'dart:html' as html;
// import 'dart:math' as math;
// import 'dart:typed_data';
// import 'dart:ui';
// import 'dart:ui_web' as ui_web;
//
// import 'package:chuphinh/socket/SttWebSocket.dart';
// import 'package:chuphinh/widget/glass_circle_button.dart';
// import 'package:chuphinh/widget/glass_zoom_control.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:js/js.dart';
//
// import 'api/api_config.dart';
// import 'api/stt_api.dart';
// import 'homeScreen/patrol_home_screen.dart';
//
// @JS('startQrLoop')
// external void startQrLoop();
//
// @JS('stopQrLoop')
// external void stopQrLoop();
//
// @JS('decodeQrFromImageBytes')
// external void _decodeQrFromImageBytesJs(String objectUrl);
//
// class CameraPreviewBox extends StatefulWidget {
//   final double size;
//   final Function(List<Uint8List> images)? onImagesChanged;
//
//   final String? plant;
//   final String? group;
//   final String type;
//   final String? wsUrl;
//   final PatrolGroup patrolGroup;
//
//   /// ✅ Gửi QR về class cha
//   final ValueChanged<String>? onQrDetected;
//
//   const CameraPreviewBox({
//     super.key,
//     this.size = 320,
//     this.onImagesChanged,
//     this.plant,
//     this.group,
//     required this.type,
//     this.wsUrl,
//     required this.patrolGroup,
//     this.onQrDetected,
//   });
//
//   @override
//   State<CameraPreviewBox> createState() => CameraPreviewBoxState();
// }
//
// class CameraPreviewBoxState extends State<CameraPreviewBox>
//     with TickerProviderStateMixin {
//   // =========================
//   // Config
//   // =========================
//   static const int _maxImages = 3;
//
//   static const Duration _qrDedupe = Duration(milliseconds: 1200);
//   static const Duration _qrWarmup = Duration(milliseconds: 250);
//
//   static const double _minZoom = 1.0;
//   static const double _maxZoom = 10.0;
//
//   // =========================
//   // Camera / View
//   // =========================
//   html.MediaStream? _stream;
//   html.VideoElement? _video;
//   late String _viewType;
//   int _viewGeneration = 0;
//
//   bool _cameraSleeping = false;
//   bool _cameraStarting = false;
//   bool _cameraStopping = false;
//
//   double _zoom = 1.0;
//
//   bool get isCameraSleeping => _cameraSleeping;
//
//   bool get isCameraStarting => _cameraStarting;
//
//   // =========================
//   // QR scanning (JS ZXing)
//   // =========================
//   StreamSubscription? _qrSub;
//   bool _qrScanning = false;
//   bool _qrLoading = false;
//
//   /// QR Patrol dạng số đang hiển thị trên UI.
//   /// ValueNotifier giúp chỉ rebuild badge QR, không rebuild toàn camera.
//   final ValueNotifier<String?> _patrolQrNotifier = ValueNotifier<String?>(null);
//
//   /// true: hiện khung hướng dẫn căn QR.
//   /// false: đã đọc được QR bất kỳ nên ẩn khung.
//   final ValueNotifier<bool> _showQrGuideNotifier = ValueNotifier<bool>(true);
//
//   /// QR raw gần nhất, dùng chống callback lặp liên tục.
//   String? _lastDetectedQr;
//   DateTime? _lastDetectedQrAt;
//
//   // =========================
//   // Capture
//   // =========================
//   bool _isCapturing = false;
//   final List<Uint8List> _capturedImages = [];
//   late final AnimationController _flashController;
//
//   bool get canUpload => _capturedImages.length < _maxImages;
//
//   List<Uint8List> get images => List.unmodifiable(_capturedImages);
//
//   // =========================
//   // STT / Socket
//   // =========================
//   late String _fac;
//   late String _group;
//   late String _wsUrl;
//
//   int stt = 0;
//   bool _sttLoading = true;
//   SttWebSocket? sttSocket;
//
//   // =========================
//   // Lifecycle
//   // =========================
//
//   @override
//   void initState() {
//     super.initState();
//
//     _viewType = _nextViewType();
//     _fac = (widget.plant ?? '').trim();
//     _group = (widget.group ?? '').trim();
//     _wsUrl = widget.wsUrl ?? '${ApiConfig.wsBaseUrl}/ws-stt/websocket';
//
//     _flashController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 200),
//     );
//
//     _startCamera();
//     _loadStt();
//     _connectSocket();
//   }
//
//   @override
//   void didUpdateWidget(covariant CameraPreviewBox oldWidget) {
//     super.didUpdateWidget(oldWidget);
//
//     final newFac = (widget.plant ?? '').trim();
//     final newGroup = (widget.group ?? '').trim();
//
//     if (newFac != _fac || newGroup != _group) {
//       _fac = newFac;
//       _group = newGroup;
//       // Nếu cần reload STT/socket theo group/fac thì bật lại:
//       // _loadStt();
//       // _connectSocket();
//     }
//   }
//
//   @override
//   void dispose() {
//     _patrolQrNotifier.dispose();
//     _showQrGuideNotifier.dispose();
//
//     _stopQrScan();
//     _flashController.dispose();
//     _stopCamera();
//
//     try {
//       sttSocket?.dispose();
//     } catch (_) {}
//
//     super.dispose();
//   }
//
//   String _nextViewType() {
//     _viewGeneration++;
//     return 'camera_${DateTime.now().microsecondsSinceEpoch}_$_viewGeneration';
//   }
//
//   /// Tắt camera thật trên Web nhưng giữ state widget, ảnh đã chụp và QR Patrol.
//   Future<void> sleepCamera() async {
//     if (_cameraSleeping || _cameraStopping) return;
//
//     _cameraStopping = true;
//
//     try {
//       // 1. Dừng QR trước.
//       await _stopQrScan(updateUi: false);
//
//       final oldStream = _stream;
//       final oldVideo = _video;
//
//       // 2. Dừng toàn bộ camera track trước.
//       if (oldStream != null) {
//         try {
//           for (final track in oldStream.getTracks()) {
//             track.enabled = false;
//             track.stop();
//           }
//         } catch (error) {
//           debugPrint('Stop camera tracks error: $error');
//         }
//       }
//
//       // 3. Dừng và xóa video HTML khỏi DOM.
//       if (oldVideo != null) {
//         try {
//           oldVideo.pause();
//           oldVideo.srcObject = null;
//
//           oldVideo.style.display = 'none';
//           oldVideo.style.visibility = 'hidden';
//           oldVideo.style.opacity = '0';
//
//           oldVideo.removeAttribute('src');
//           oldVideo.load();
//
//           // Quan trọng với HtmlElementView trên Web.
//           oldVideo.remove();
//         } catch (error) {
//           debugPrint('Remove camera video error: $error');
//         }
//       }
//
//       if (!mounted) return;
//
//       setState(() {
//         _stream = null;
//         _video = null;
//
//         _qrScanning = false;
//         _qrLoading = false;
//
//         _cameraSleeping = true;
//         _cameraStarting = false;
//
//         /*
//        * Đổi key để Flutter không tiếp tục giữ lại
//        * HtmlElementView cũ trong lần rebuild sau.
//        */
//         _viewType = _nextViewType();
//       });
//
//       debugPrint('Camera is sleeping: stream and video removed.');
//     } finally {
//       _cameraStopping = false;
//     }
//   }
//
//   /// Khởi động lại camera sau khi sleep. Chống gọi lặp khi người dùng bấm nhanh.
//   Future<bool> wakeCamera() async {
//     if (_cameraStarting || _cameraStopping) {
//       return false;
//     }
//
//     if (!_cameraSleeping && _stream != null && _video != null) {
//       return true;
//     }
//
//     if (mounted) {
//       setState(() {
//         _cameraSleeping = false;
//       });
//     }
//
//     await _startCamera();
//
//     final started =
//         mounted && _stream != null && _video != null && !_cameraSleeping;
//
//     debugPrint('Wake camera result: $started');
//
//     return started;
//   }
//
//   bool _isQrNumber(String value) {
//     return RegExp(r'^\d{1,5}$').hasMatch(value.trim());
//   }
//
//   bool _isDuplicateQr(String qr, DateTime now) {
//     return _lastDetectedQr == qr &&
//         _lastDetectedQrAt != null &&
//         now.difference(_lastDetectedQrAt!) < _qrDedupe;
//   }
//
//   /// Nhận QR từ camera, nhập tay hoặc ảnh upload.
//   /// Hàm này không gọi setState nên không rebuild toàn bộ camera.
//   void _acceptDetectedQr(String rawQr, {bool haptic = true}) {
//     if (!mounted) return;
//
//     final qr = rawQr.trim();
//     if (qr.isEmpty) return;
//
//     final now = DateTime.now();
//     if (_isDuplicateQr(qr, now)) return;
//
//     _lastDetectedQr = qr;
//     _lastDetectedQrAt = now;
//
//     if (_showQrGuideNotifier.value) {
//       _showQrGuideNotifier.value = false;
//     }
//
//     // QR máy không được xóa QR Patrol cũ trên UI.
//     if (_isQrNumber(qr) && _patrolQrNotifier.value != qr) {
//       _patrolQrNotifier.value = qr;
//     }
//
//     if (haptic) {
//       HapticFeedback.mediumImpact();
//     }
//
//     widget.onQrDetected?.call(qr);
//   }
//
//   // =========================
//   // Camera
//   // =========================
//
//   Future<void> _inputQrManually() async {
//     final controller = TextEditingController();
//
//     try {
//       final value = await showDialog<String>(
//         context: context,
//         builder: (dialogContext) {
//           return AlertDialog(
//             backgroundColor: const Color(0xFF1F2937),
//             title: const Text(
//               'Enter QR Code',
//               style: TextStyle(color: Colors.white),
//             ),
//             content: TextField(
//               controller: controller,
//               autofocus: true,
//               style: const TextStyle(color: Colors.white),
//               decoration: const InputDecoration(
//                 hintText: 'Input QR code manually',
//                 hintStyle: TextStyle(color: Colors.white54),
//               ),
//               onSubmitted: (text) {
//                 Navigator.pop(dialogContext, text.trim());
//               },
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(dialogContext),
//                 child: const Text('Cancel'),
//               ),
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.pop(dialogContext, controller.text.trim());
//                 },
//                 child: const Text('OK'),
//               ),
//             ],
//           );
//         },
//       );
//
//       if (value == null || value.trim().isEmpty) return;
//
//       _acceptDetectedQr(value, haptic: false);
//     } finally {
//       controller.dispose();
//     }
//   }
//
//   Future<void> _startCamera() async {
//     if (_cameraStopping || _cameraStarting) return;
//
//     _cameraStarting = true;
//
//     try {
//       final mediaDevices = html.window.navigator.mediaDevices;
//
//       if (mediaDevices == null) {
//         throw StateError('Camera API is not available in this browser.');
//       }
//
//       final stream = await mediaDevices.getUserMedia({
//         'video': {
//           'facingMode': 'environment',
//           'width': {'ideal': 1280, 'min': 640},
//           'height': {'ideal': 720, 'min': 480},
//           'frameRate': {'ideal': 24, 'max': 30},
//         },
//       });
//
//       if (!mounted || _cameraStopping) {
//         for (final track in stream.getTracks()) {
//           track.stop();
//         }
//         return;
//       }
//
//       final viewType = _nextViewType();
//
//       final video = html.VideoElement()
//         ..id = 'qr-video'
//         ..autoplay = true
//         ..muted = true
//         ..setAttribute('playsinline', 'true')
//         ..style.display = 'block'
//         ..style.visibility = 'visible'
//         ..style.opacity = '1'
//         ..style.objectFit = 'cover'
//         ..style.pointerEvents = 'none'
//         ..style.position = 'absolute'
//         ..style.top = '0'
//         ..style.right = '0'
//         ..style.bottom = '0'
//         ..style.left = '0'
//         ..style.width = '100%'
//         ..style.height = '100%'
//         ..srcObject = stream;
//
//       ui_web.platformViewRegistry.registerViewFactory(viewType, (_) => video);
//
//       if (!mounted) {
//         for (final track in stream.getTracks()) {
//           track.stop();
//         }
//         return;
//       }
//
//       setState(() {
//         _viewType = viewType;
//         _stream = stream;
//         _video = video;
//         _cameraSleeping = false;
//       });
//
//       // Gọi play rõ ràng để chắc chắn video chạy trên web.
//       try {
//         await video.play();
//       } catch (error) {
//         debugPrint('Video play warning: $error');
//       }
//
//       await _waitVideoReady(timeout: const Duration(seconds: 4));
//
//       if (!mounted || _cameraSleeping || _stream == null || _video == null) {
//         return;
//       }
//
//       await Future.delayed(_qrWarmup);
//
//       if (!mounted || _cameraSleeping || _stream == null || _video == null) {
//         return;
//       }
//
//       await _startAutoQrScan();
//     } catch (error, stackTrace) {
//       debugPrint('Camera start error: $error');
//       debugPrintStack(stackTrace: stackTrace);
//
//       if (!mounted) return;
//
//       setState(() {
//         _stream = null;
//         _video = null;
//         _qrScanning = false;
//         _qrLoading = false;
//         _cameraSleeping = true;
//       });
//     } finally {
//       _cameraStarting = false;
//
//       if (mounted) {
//         setState(() {});
//       }
//     }
//   }
//
//   Future<void> _waitVideoReady({required Duration timeout}) async {
//     final start = DateTime.now();
//     while (mounted) {
//       final v = _video;
//       if (v != null && v.videoWidth > 0 && v.videoHeight > 0) return;
//       if (DateTime.now().difference(start) > timeout) return;
//       await Future.delayed(const Duration(milliseconds: 50));
//     }
//   }
//
//   void _stopCameraTracks() {
//     final stream = _stream;
//     if (stream == null) return;
//
//     try {
//       for (final track in stream.getTracks()) {
//         track.stop();
//       }
//     } catch (error) {
//       debugPrint('Stop camera tracks error: $error');
//     }
//   }
//
//   void _stopCamera() {
//     final oldStream = _stream;
//     final oldVideo = _video;
//
//     if (oldStream != null) {
//       try {
//         for (final track in oldStream.getTracks()) {
//           track.enabled = false;
//           track.stop();
//         }
//       } catch (error) {
//         debugPrint('Stop camera error: $error');
//       }
//     }
//
//     if (oldVideo != null) {
//       try {
//         oldVideo.pause();
//         oldVideo.srcObject = null;
//         oldVideo.remove();
//       } catch (error) {
//         debugPrint('Remove video error: $error');
//       }
//     }
//
//     _stream = null;
//     _video = null;
//   }
//
//   // =========================
//   // QR (ZXing JS) start/stop
//   // =========================
//   Future<void> _startAutoQrScan() async {
//     if (_qrScanning || _cameraSleeping || _stream == null || _video == null) {
//       return;
//     }
//
//     final video = _video!;
//
//     if (video.videoWidth <= 0 || video.videoHeight <= 0) {
//       debugPrint('QR scan not started: video is not ready.');
//       return;
//     }
//
//     await _qrSub?.cancel();
//
//     _qrSub = html.window.on['qr-from-image'].listen(_onQrEvent);
//
//     if (mounted) {
//       setState(() {
//         _qrScanning = true;
//         _qrLoading = true;
//       });
//     }
//
//     try {
//       startQrLoop();
//
//       debugPrint(
//         'QR loop started: '
//         '${video.videoWidth}x${video.videoHeight}',
//       );
//     } catch (error) {
//       debugPrint('startQrLoop error: $error');
//
//       await _qrSub?.cancel();
//       _qrSub = null;
//       _qrScanning = false;
//     } finally {
//       if (mounted) {
//         setState(() {
//           _qrLoading = false;
//         });
//       }
//     }
//   }
//
//   Future<void> _stopQrScan({bool updateUi = true}) async {
//     try {
//       stopQrLoop();
//     } catch (_) {}
//
//     try {
//       await _qrSub?.cancel();
//     } catch (_) {}
//     _qrSub = null;
//
//     if (mounted && updateUi) {
//       setState(() {
//         _qrScanning = false;
//         _qrLoading = false;
//       });
//     } else {
//       _qrScanning = false;
//       _qrLoading = false;
//     }
//   }
//
//   void _onQrEvent(dynamic event) {
//     if (!mounted) return;
//
//     final customEvent = event as html.CustomEvent;
//     final detail = customEvent.detail;
//
//     if (detail == null) return;
//
//     final error = detail['error']?.toString().trim() ?? '';
//     if (error.isNotEmpty) return;
//
//     final text = detail['text']?.toString().trim() ?? '';
//     if (text.isEmpty) return;
//
//     _acceptDetectedQr(text);
//   }
//
//   // =========================
//   // STT / socket
//   // =========================
//   Future<void> _loadStt() async {
//     if (_fac.isEmpty) return;
//     try {
//       setState(() => _sttLoading = true);
//
//       final value = await SttApi.getCurrentStt(
//         fac: _fac,
//         type: widget.patrolGroup.name,
//       );
//
//       if (!mounted) return;
//       setState(() {
//         stt = value;
//         _sttLoading = false;
//       });
//     } catch (e) {
//       if (mounted) setState(() => _sttLoading = false);
//     }
//   }
//
//   void _connectSocket() {
//     sttSocket?.dispose();
//     sttSocket = SttWebSocket(
//       serverUrl: _wsUrl,
//       fac: _fac,
//       type: widget.patrolGroup.name,
//       onSttUpdate: (value) {
//         if (!mounted) return;
//         setState(() {
//           stt = value;
//           _sttLoading = false;
//         });
//       },
//     );
//     sttSocket!.connect();
//   }
//
//   // =========================
//   // Capture / Upload
//   // =========================
//   Future<String?> _decodeQrFromBytes(Uint8List bytes) async {
//     String? url;
//     StreamSubscription<html.Event>? sub;
//     final completer = Completer<String?>();
//
//     try {
//       debugPrint('[DECODE] start, bytes = ${bytes.length}');
//
//       final blob = html.Blob([bytes], 'image/*');
//       url = html.Url.createObjectUrlFromBlob(blob);
//       debugPrint('[DECODE] objectUrl created = $url');
//
//       sub = html.window.on['qr-from-uploaded-image'].listen((event) {
//         debugPrint('[DECODE] event qr-from-uploaded-image received');
//
//         final e = event as html.CustomEvent;
//         final detail = e.detail;
//
//         final text = detail['text']?.toString().trim();
//         final err = detail['error']?.toString() ?? '';
//
//         debugPrint('[DECODE] text = $text');
//         debugPrint('[DECODE] error = $err');
//
//         if (!completer.isCompleted) {
//           completer.complete((text == null || text.isEmpty) ? null : text);
//         }
//       });
//
//       debugPrint('[DECODE] call JS decodeQrFromImageBytes');
//       _decodeQrFromImageBytesJs(url);
//
//       final result = await completer.future.timeout(
//         const Duration(seconds: 5),
//         onTimeout: () {
//           debugPrint('[DECODE] timeout after 5s');
//           return null;
//         },
//       );
//
//       debugPrint('[DECODE] final result = $result');
//       return result;
//     } catch (e, st) {
//       debugPrint('[DECODE] ERROR = $e');
//       debugPrint('[DECODE] STACK = $st');
//       return null;
//     } finally {
//       await sub?.cancel();
//       debugPrint('[DECODE] listener cancelled');
//
//       if (url != null) {
//         html.Url.revokeObjectUrl(url);
//         debugPrint('[DECODE] objectUrl revoked');
//       }
//     }
//   }
//
//   // Future<void> pickImagesFromDevice(BuildContext context) async {
//   //   final remain = _maxImages - _capturedImages.length;
//   //   if (remain <= 0) {
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       const SnackBar(
//   //         content: Text("You can upload up to 3 images only."),
//   //         backgroundColor: Colors.redAccent,
//   //         behavior: SnackBarBehavior.floating,
//   //       ),
//   //     );
//   //     return;
//   //   }
//   //
//   //   final uploadInput = html.FileUploadInputElement()
//   //     ..accept = 'image/*'
//   //     ..multiple = true;
//   //
//   //   uploadInput.click();
//   //
//   //   uploadInput.onChange.listen((_) async {
//   //     final files = uploadInput.files;
//   //     if (files == null || files.isEmpty) return;
//   //
//   //     final selected = files.take(remain);
//   //
//   //     for (final file in selected) {
//   //       final reader = html.FileReader();
//   //       reader.readAsArrayBuffer(file);
//   //       await reader.onLoadEnd.first;
//   //
//   //       final bytes = reader.result as Uint8List;
//   //
//   //       // decode QR trong chính ảnh upload
//   //       final qrText = await _decodeQrFromBytes(bytes);
//   //
//   //       if (qrText != null && qrText.isNotEmpty) {
//   //         if (widget.type != 'Patrol' || RegExp(r'^\d{4}$').hasMatch(qrText)) {
//   //           setState(() {
//   //             _lastQr = qrText;
//   //             _lastQrAt = DateTime.now();
//   //           });
//   //
//   //           widget.onQrDetected?.call(qrText);
//   //           HapticFeedback.mediumImpact();
//   //           _playQrChangedFx();
//   //         }
//   //       }
//   //
//   //       // add ảnh sau khi đọc QR
//   //       setState(() {
//   //         _capturedImages.add(bytes);
//   //       });
//   //     }
//   //
//   //     widget.onImagesChanged?.call(_capturedImages);
//   //   });
//   // }
//   Future<void> pickImagesFromDevice(BuildContext context) async {
//     final remain = _maxImages - _capturedImages.length;
//
//     if (remain <= 0) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('You can upload up to 3 images only.'),
//           backgroundColor: Colors.redAccent,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//       return;
//     }
//
//     final uploadInput = html.FileUploadInputElement()
//       ..accept = 'image/*'
//       ..multiple = true;
//
//     uploadInput.click();
//
//     await uploadInput.onChange.first;
//
//     final files = uploadInput.files;
//     if (files == null || files.isEmpty) return;
//
//     for (final file in files.take(remain)) {
//       String? objectUrl;
//
//       try {
//         objectUrl = html.Url.createObjectUrl(file);
//
//         final image = html.ImageElement();
//         final imageReady = Completer<void>();
//
//         late final StreamSubscription<html.Event> loadSub;
//         late final StreamSubscription<html.Event> errorSub;
//
//         loadSub = image.onLoad.listen((_) {
//           if (!imageReady.isCompleted) imageReady.complete();
//         });
//
//         errorSub = image.onError.listen((_) {
//           if (!imageReady.isCompleted) {
//             imageReady.completeError(StateError('Failed to load image'));
//           }
//         });
//
//         image.src = objectUrl;
//
//         try {
//           await imageReady.future.timeout(const Duration(seconds: 10));
//         } finally {
//           await loadSub.cancel();
//           await errorSub.cancel();
//         }
//
//         final width = image.naturalWidth ?? image.width ?? 0;
//         final height = image.naturalHeight ?? image.height ?? 0;
//
//         if (width <= 0 || height <= 0) continue;
//
//         final canvas = html.CanvasElement(width: width, height: height);
//         canvas.context2D.drawImage(image, 0, 0);
//
//         final blob = await canvas.toBlob('image/jpeg', 0.9);
//         if (blob == null) continue;
//
//         final reader = html.FileReader();
//         reader.readAsArrayBuffer(blob);
//         await reader.onLoadEnd.first;
//
//         final result = reader.result;
//         final bytes = result is ByteBuffer
//             ? Uint8List.view(result)
//             : Uint8List.fromList(result as List<int>);
//
//         final qrText = await _decodeQrFromBytes(bytes);
//         if (qrText != null && qrText.trim().isNotEmpty) {
//           _acceptDetectedQr(qrText, haptic: false);
//         }
//
//         if (!mounted) return;
//
//         setState(() {
//           _capturedImages.add(bytes);
//         });
//
//         widget.onImagesChanged?.call(
//           List<Uint8List>.unmodifiable(_capturedImages),
//         );
//       } catch (error, stackTrace) {
//         debugPrint('pickImagesFromDevice error: $error');
//         debugPrintStack(stackTrace: stackTrace);
//       } finally {
//         if (objectUrl != null) {
//           html.Url.revokeObjectUrl(objectUrl);
//         }
//       }
//     }
//   }
//
//   void removeImage(int index) {
//     setState(() => _capturedImages.removeAt(index));
//     widget.onImagesChanged?.call(_capturedImages);
//   }
//
//   void clearAll() {
//     setState(() => _capturedImages.clear());
//     widget.onImagesChanged?.call(_capturedImages);
//   }
//
//   void resetQr() {
//     _lastDetectedQr = null;
//     _lastDetectedQrAt = null;
//
//     _patrolQrNotifier.value = null;
//     _showQrGuideNotifier.value = true;
//   }
//
//   Future<void> _takePhoto() async {
//     if (_cameraSleeping || _cameraStarting) return;
//     if (_isCapturing || _video == null) return;
//     if (_capturedImages.length >= _maxImages) return;
//
//     setState(() => _isCapturing = true);
//     _flashController.forward().then((_) => _flashController.reverse());
//
//     try {
//       final video = _video!;
//       final vw = video.videoWidth.toDouble();
//       final vh = video.videoHeight.toDouble();
//       if (vw == 0 || vh == 0) return;
//
//       final outputSize = math.min(math.max(vw, vh), 2048).toInt();
//       final canvas = html.CanvasElement(width: outputSize, height: outputSize);
//       final ctx = canvas.context2D;
//
//       final srcSize = math.min(vw, vh) / _zoom;
//       final sx = (vw - srcSize) / 2;
//       final sy = (vh - srcSize) / 2;
//
//       ctx.drawImageScaledFromSource(
//         video,
//         sx,
//         sy,
//         srcSize,
//         srcSize,
//         0,
//         0,
//         outputSize.toDouble(),
//         outputSize.toDouble(),
//       );
//
//       final blob = await canvas.toBlob('image/jpeg', 0.8);
//       final reader = html.FileReader();
//       reader.readAsArrayBuffer(blob);
//       await reader.onLoadEnd.first;
//
//       final bytes = reader.result as Uint8List;
//       setState(() => _capturedImages.add(bytes));
//       widget.onImagesChanged?.call(_capturedImages);
//     } finally {
//       if (mounted) setState(() => _isCapturing = false);
//     }
//   }
//
//   // =========================
//   // UI
//   // =========================
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Stack(
//           clipBehavior: Clip.none,
//           children: [
//             RepaintBoundary(
//               child: Container(
//                 width: widget.size,
//                 height: widget.size,
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(20),
//                   child: Stack(
//                     fit: StackFit.expand,
//                     children: [
//                       _video != null && !_cameraSleeping
//                           ? Transform.scale(
//                               scale: _zoom,
//                               child: HtmlElementView(
//                                 key: ValueKey(_viewType),
//                                 viewType: _viewType,
//                               ),
//                             )
//                           : Container(
//                               color: const Color(0xFF111827),
//                               alignment: Alignment.center,
//                               child: _cameraStarting
//                                   ? const SizedBox(
//                                       width: 26,
//                                       height: 26,
//                                       child: CircularProgressIndicator(
//                                         strokeWidth: 2.4,
//                                         color: Color(0xFF22C55E),
//                                       ),
//                                     )
//                                   : const Icon(
//                                       Icons.videocam_off_rounded,
//                                       color: Colors.white38,
//                                       size: 42,
//                                     ),
//                             ),
//
//                       // Khung căn QR tĩnh: vẽ một lần, không chạy animation.
//                       Positioned.fill(
//                         child: IgnorePointer(
//                           child: ValueListenableBuilder<bool>(
//                             valueListenable: _showQrGuideNotifier,
//                             child: const RepaintBoundary(
//                               child: _QrGuideOverlay(),
//                             ),
//                             builder: (context, showGuide, child) {
//                               return showGuide
//                                   ? child!
//                                   : const SizedBox.shrink();
//                             },
//                           ),
//                         ),
//                       ),
//
//                       // Glass overlay giữ nguyên giao diện.
//                       BackdropFilter(
//                         filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
//                         child: Container(color: Colors.white.withOpacity(0.08)),
//                       ),
//
//                       // Flash chỉ rebuild lớp flash khi chụp ảnh.
//                       AnimatedBuilder(
//                         animation: _flashController,
//                         builder: (_, __) {
//                           return IgnorePointer(
//                             child: Container(
//                               color: Colors.white.withOpacity(
//                                 0.85 * _flashController.value,
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//
//             Positioned(
//               bottom: 14,
//               left: 7,
//               child: GestureDetector(
//                 onTap: canUpload ? () => pickImagesFromDevice(context) : null,
//                 child: GlassCircleButton(
//                   size: 50,
//                   child: Icon(
//                     Icons.upload_rounded,
//                     color: canUpload ? Colors.white : Colors.grey,
//                     size: 30,
//                   ),
//                 ),
//               ),
//             ),
//
//             Positioned(
//               bottom: 14,
//               left: 65,
//               child: GestureDetector(
//                 onTap: _inputQrManually,
//                 child: const GlassCircleButton(
//                   size: 50,
//                   child: Icon(
//                     Icons.keyboard_rounded,
//                     color: Colors.white,
//                     size: 28,
//                   ),
//                 ),
//               ),
//             ),
//
//             // Chỉ badge QR rebuild khi QR Patrol thay đổi.
//             Positioned(
//               top: 12,
//               left: 12,
//               child: RepaintBoundary(
//                 child: ValueListenableBuilder<String?>(
//                   valueListenable: _patrolQrNotifier,
//                   builder: (context, qr, _) {
//                     return _QrStatusBadge(qr: qr);
//                   },
//                 ),
//               ),
//             ),
//
//             Positioned(
//               top: 12,
//               right: 12,
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(16),
//                 child: BackdropFilter(
//                   filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 8,
//                       vertical: 5,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.18),
//                       borderRadius: BorderRadius.circular(16),
//                       border: Border.all(color: Colors.white.withOpacity(0.5)),
//                     ),
//                     child: _sttLoading
//                         ? const SizedBox(
//                             width: 16,
//                             height: 16,
//                             child: CircularProgressIndicator(
//                               strokeWidth: 2,
//                               color: Colors.white,
//                             ),
//                           )
//                         : Text(
//                             'No. ${stt + 1}',
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontSize: 13,
//                               fontWeight: FontWeight.bold,
//                               letterSpacing: 0.6,
//                             ),
//                           ),
//                   ),
//                 ),
//               ),
//             ),
//
//             Positioned(
//               bottom: 14,
//               right: 14,
//               child: GlassZoomControl(
//                 zoom: _zoom,
//                 minZoom: _minZoom,
//                 maxZoom: _maxZoom,
//                 onChanged: (value) {
//                   if ((value - _zoom).abs() < 0.001) return;
//                   setState(() => _zoom = value);
//                 },
//               ),
//             ),
//
//             Positioned(
//               bottom: -18,
//               left: 0,
//               right: 0,
//               child: Center(
//                 child: GestureDetector(
//                   onTap: (!_isCapturing && canUpload) ? _takePhoto : null,
//                   child: GlassCircleButton(
//                     size: 80,
//                     showProgress: _isCapturing,
//                     child: _isCapturing
//                         ? null
//                         : Icon(
//                             Icons.camera_alt_rounded,
//                             color: canUpload ? Colors.white : Colors.grey,
//                             size: 36,
//                           ),
//                   ),
//                 ),
//               ),
//             ),
//
//             if (_qrLoading)
//               const Positioned(
//                 top: 12,
//                 left: 150,
//                 child: SizedBox(
//                   width: 14,
//                   height: 14,
//                   child: CircularProgressIndicator(strokeWidth: 2),
//                 ),
//               ),
//           ],
//         ),
//       ],
//     );
//   }
// }
//
// class _QrStatusBadge extends StatelessWidget {
//   final String? qr;
//
//   const _QrStatusBadge({required this.qr});
//
//   @override
//   Widget build(BuildContext context) {
//     final value = qr?.trim() ?? '';
//     final hasQr = value.isNotEmpty;
//
//     return ClipRRect(
//       borderRadius: BorderRadius.circular(16),
//       child: BackdropFilter(
//         filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
//         child: Container(
//           constraints: const BoxConstraints(minHeight: 34),
//           padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
//           decoration: BoxDecoration(
//             color: Colors.black.withOpacity(0.30),
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(
//               color: hasQr
//                   ? const Color(0xFF22C55E).withOpacity(0.75)
//                   : Colors.redAccent.withOpacity(0.50),
//             ),
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Icon(
//                 hasQr ? Icons.qr_code_2_rounded : Icons.qr_code_scanner_rounded,
//                 size: 19,
//                 color: hasQr ? const Color(0xFF22C55E) : Colors.redAccent,
//               ),
//               const SizedBox(width: 7),
//               Text(
//                 hasQr ? value : 'Scan Patrol QR',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 13,
//                   fontWeight: hasQr ? FontWeight.w800 : FontWeight.w600,
//                   letterSpacing: hasQr ? 0.8 : 0,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class _QrGuideOverlay extends StatelessWidget {
//   const _QrGuideOverlay();
//
//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: SizedBox(
//         width: 205,
//         height: 205,
//         child: CustomPaint(
//           painter: const _QrGuidePainter(),
//           child: const Align(
//             alignment: Alignment.bottomCenter,
//             child: Padding(
//               padding: EdgeInsets.only(bottom: 12),
//               child: Text(
//                 'Place QR inside frame',
//                 style: TextStyle(
//                   color: Colors.white70,
//                   fontSize: 11,
//                   fontWeight: FontWeight.w600,
//                   shadows: [Shadow(color: Colors.black, blurRadius: 5)],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class _QrGuidePainter extends CustomPainter {
//   const _QrGuidePainter();
//
//   static const double _cornerLength = 38;
//   static const double _radius = 13;
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
//
//     final paint = Paint()
//       ..color = const Color(0xFF22C55E)
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 3
//       ..strokeCap = StrokeCap.round
//       ..strokeJoin = StrokeJoin.round;
//
//     final path = Path()
//       // Top left
//       ..moveTo(rect.left, rect.top + _cornerLength)
//       ..lineTo(rect.left, rect.top + _radius)
//       ..quadraticBezierTo(rect.left, rect.top, rect.left + _radius, rect.top)
//       ..lineTo(rect.left + _cornerLength, rect.top)
//       // Top right
//       ..moveTo(rect.right - _cornerLength, rect.top)
//       ..lineTo(rect.right - _radius, rect.top)
//       ..quadraticBezierTo(rect.right, rect.top, rect.right, rect.top + _radius)
//       ..lineTo(rect.right, rect.top + _cornerLength)
//       // Bottom right
//       ..moveTo(rect.right, rect.bottom - _cornerLength)
//       ..lineTo(rect.right, rect.bottom - _radius)
//       ..quadraticBezierTo(
//         rect.right,
//         rect.bottom,
//         rect.right - _radius,
//         rect.bottom,
//       )
//       ..lineTo(rect.right - _cornerLength, rect.bottom)
//       // Bottom left
//       ..moveTo(rect.left + _cornerLength, rect.bottom)
//       ..lineTo(rect.left + _radius, rect.bottom)
//       ..quadraticBezierTo(
//         rect.left,
//         rect.bottom,
//         rect.left,
//         rect.bottom - _radius,
//       )
//       ..lineTo(rect.left, rect.bottom - _cornerLength);
//
//     canvas.drawPath(path, paint);
//   }
//
//   @override
//   bool shouldRepaint(covariant _QrGuidePainter oldDelegate) => false;
// }
import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:chuphinh/socket/SttWebSocket.dart';
import 'package:chuphinh/widget/glass_circle_button.dart';
import 'package:chuphinh/widget/glass_zoom_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:js/js.dart';

import 'api/api_config.dart';
import 'api/stt_api.dart';
import 'homeScreen/patrol_home_screen.dart';

// Giữ nguyên các import project hiện tại của bạn:
// import 'package:chuphinh/socket/SttWebSocket.dart';
// import 'package:chuphinh/widget/glass_circle_button.dart';
// import 'package:chuphinh/widget/glass_zoom_control.dart';
// import 'api/api_config.dart';
// import 'api/stt_api.dart';
// import 'homeScreen/patrol_home_screen.dart';

@JS('startQrLoop')
external void startQrLoop();

@JS('stopQrLoop')
external void stopQrLoop();

@JS('decodeQrFromImageBytes')
external void _decodeQrFromImageBytesJs(String objectUrl);

class CameraPreviewBox extends StatefulWidget {
  final double size;
  final Function(List<Uint8List> images)? onImagesChanged;

  final String? plant;
  final String? group;
  final String type;
  final String? wsUrl;
  final PatrolGroup patrolGroup;

  /// Gửi QR về màn hình cha.
  final ValueChanged<String>? onQrDetected;

  /// Chỉ thông báo trạng thái để màn hình cha cập nhật UI.
  /// CameraPreviewBoxState vẫn là nguồn trạng thái thật duy nhất.
  final ValueChanged<bool>? onCameraSleepingChanged;

  const CameraPreviewBox({
    super.key,
    this.size = 320,
    this.onImagesChanged,
    this.plant,
    this.group,
    required this.type,
    this.wsUrl,
    required this.patrolGroup,
    this.onQrDetected,
    this.onCameraSleepingChanged,
  });

  @override
  State<CameraPreviewBox> createState() => CameraPreviewBoxState();
}

class CameraPreviewBoxState extends State<CameraPreviewBox>
    with TickerProviderStateMixin {
  // =========================
  // Config
  // =========================
  static const int _maxImages = 3;

  static const int _maxCaptureEdge = 2048;
  static const int _maxImportedEdge = 1600;

  static const int _idealCameraFps = 20;
  static const int _maxCameraFps = 24;

  static const Duration _qrDedupe = Duration(milliseconds: 1200);
  static const Duration _qrWarmup = Duration(milliseconds: 250);

  static const double _minZoom = 1.0;
  static const double _maxZoom = 10.0;

  // =========================
  // Camera / View
  // =========================
  html.MediaStream? _stream;
  html.VideoElement? _video;
  late String _viewType;
  int _viewGeneration = 0;

  bool _cameraSleeping = false;
  bool _cameraStarting = false;
  bool _cameraStopping = false;

  /// Mỗi lần start/wake tạo một session mới.
  /// Khi OFF, tăng session để vô hiệu hóa getUserMedia đang chạy dở.
  int _cameraSession = 0;

  double _zoom = 1.0;

  bool get isCameraSleeping => _cameraSleeping;

  bool get isCameraStarting => _cameraStarting;

  void _setCameraSleeping(bool value, {bool notifyParent = true}) {
    final changed = _cameraSleeping != value;
    _cameraSleeping = value;

    if (changed && notifyParent) {
      widget.onCameraSleepingChanged?.call(value);
    }
  }

  // =========================
  // QR scanning (JS ZXing)
  // =========================
  StreamSubscription? _qrSub;
  bool _qrScanning = false;
  bool _qrLoading = false;

  /// QR Patrol dạng số đang hiển thị trên UI.
  /// ValueNotifier giúp chỉ rebuild badge QR, không rebuild toàn camera.
  final ValueNotifier<String?> _patrolQrNotifier = ValueNotifier<String?>(null);

  /// true: hiện khung hướng dẫn căn QR.
  /// false: đã đọc được QR bất kỳ nên ẩn khung.
  final ValueNotifier<bool> _showQrGuideNotifier = ValueNotifier<bool>(true);

  /// QR raw gần nhất, dùng chống callback lặp liên tục.
  String? _lastDetectedQr;
  DateTime? _lastDetectedQrAt;

  // =========================
  // Capture
  // =========================
  bool _isCapturing = false;
  final List<Uint8List> _capturedImages = [];
  late final AnimationController _flashController;

  bool get canUpload => _capturedImages.length < _maxImages;

  List<Uint8List> get images => List<Uint8List>.unmodifiable(_capturedImages);

  void _notifyImagesChanged() {
    widget.onImagesChanged?.call(List<Uint8List>.unmodifiable(_capturedImages));
  }

  // =========================
  // STT / Socket
  // =========================
  late String _fac;
  late String _group;
  late String _wsUrl;

  int stt = 0;
  bool _sttLoading = true;
  SttWebSocket? sttSocket;

  // =========================
  // Lifecycle
  // =========================

  @override
  void initState() {
    super.initState();

    _viewType = _nextViewType();
    _fac = (widget.plant ?? '').trim();
    _group = (widget.group ?? '').trim();
    _wsUrl = widget.wsUrl ?? '${ApiConfig.wsBaseUrl}/ws-stt/websocket';

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _startCamera();
    _loadStt();
    _connectSocket();
  }

  @override
  void didUpdateWidget(covariant CameraPreviewBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newFac = (widget.plant ?? '').trim();
    final newGroup = (widget.group ?? '').trim();

    if (newFac != _fac || newGroup != _group) {
      _fac = newFac;
      _group = newGroup;
      // Nếu cần reload STT/socket theo group/fac thì bật lại:
      // _loadStt();
      // _connectSocket();
    }
  }

  @override
  void dispose() {
    _patrolQrNotifier.dispose();
    _showQrGuideNotifier.dispose();

    _stopQrScan();
    _flashController.dispose();
    _stopCamera();

    try {
      sttSocket?.dispose();
    } catch (_) {}

    super.dispose();
  }

  String _nextViewType() {
    _viewGeneration++;
    return 'camera_${DateTime.now().microsecondsSinceEpoch}_$_viewGeneration';
  }

  /// Tắt camera thật trên Web nhưng giữ state widget, ảnh đã chụp và QR Patrol.
  Future<void> sleepCamera() async {
    if (_cameraSleeping || _cameraStopping) return;

    // Vô hiệu hóa mọi request getUserMedia đang chạy dở.
    _cameraSession++;
    _cameraStopping = true;
    _setCameraSleeping(true);

    if (mounted) {
      setState(() {
        _cameraStarting = false;
      });
    }

    try {
      await _stopQrScan(updateUi: false);

      final oldStream = _stream;
      final oldVideo = _video;

      // Bỏ reference trước để build không dùng Platform View cũ.
      _stream = null;
      _video = null;

      _disposeVideoElement(oldVideo);
      _stopStream(oldStream);

      // Phòng trường hợp video cũ vẫn còn trong DOM.
      final domVideo = html.document.getElementById('qr-video');
      if (domVideo is html.VideoElement) {
        final domStream = domVideo.srcObject;
        if (domStream is html.MediaStream) {
          _stopStream(domStream);
        }
        _disposeVideoElement(domVideo);
      }

      if (!mounted) return;

      setState(() {
        _qrScanning = false;
        _qrLoading = false;
        _cameraStarting = false;

        // Buộc Flutter bỏ HtmlElementView cũ.
        _viewType = _nextViewType();
      });

      debugPrint('Camera completely stopped.');
    } finally {
      _cameraStopping = false;
    }
  }

  /// Khởi động lại camera sau khi sleep.
  Future<bool> wakeCamera() async {
    if (_cameraStarting || _cameraStopping) return false;

    if (!_cameraSleeping && _stream != null && _video != null) {
      return true;
    }

    /*
     * QUAN TRỌNG:
     * Phải chuyển sleeping=false trước khi gọi _startCamera().
     * Nếu vẫn true, điều kiện bảo vệ trong _startCamera() sẽ stop
     * stream mới ngay sau khi getUserMedia trả về.
     */
    _setCameraSleeping(false);

    if (mounted) {
      setState(() {});
    }

    await _startCamera();

    final started =
        mounted && _stream != null && _video != null && !_cameraSleeping;

    if (!started) {
      _setCameraSleeping(true);
      if (mounted) setState(() {});
    }

    debugPrint('Wake camera result: started=$started, qrScanning=$_qrScanning');

    return started;
  }

  bool _isQrNumber(String value) {
    return RegExp(r'^\d{1,5}$').hasMatch(value.trim());
  }

  bool _isDuplicateQr(String qr, DateTime now) {
    return _lastDetectedQr == qr &&
        _lastDetectedQrAt != null &&
        now.difference(_lastDetectedQrAt!) < _qrDedupe;
  }

  /// Nhận QR từ camera, nhập tay hoặc ảnh upload.
  /// Hàm này không gọi setState nên không rebuild toàn bộ camera.
  void _acceptDetectedQr(String rawQr, {bool haptic = true}) {
    if (!mounted) return;

    final qr = rawQr.trim();
    if (qr.isEmpty) return;

    final now = DateTime.now();
    if (_isDuplicateQr(qr, now)) return;

    _lastDetectedQr = qr;
    _lastDetectedQrAt = now;

    if (_showQrGuideNotifier.value) {
      _showQrGuideNotifier.value = false;
    }

    // QR máy không được xóa QR Patrol cũ trên UI.
    if (_isQrNumber(qr) && _patrolQrNotifier.value != qr) {
      _patrolQrNotifier.value = qr;
    }

    if (haptic) {
      HapticFeedback.mediumImpact();
    }

    widget.onQrDetected?.call(qr);
  }

  // =========================
  // Camera
  // =========================

  Future<void> _inputQrManually() async {
    final controller = TextEditingController();

    try {
      final value = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1F2937),
            title: const Text(
              'Enter QR Code',
              style: TextStyle(color: Colors.white),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Input QR code manually',
                hintStyle: TextStyle(color: Colors.white54),
              ),
              onSubmitted: (text) {
                Navigator.pop(dialogContext, text.trim());
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext, controller.text.trim());
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (value == null || value.trim().isEmpty) return;

      _acceptDetectedQr(value, haptic: false);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _startCamera() async {
    if (_cameraStopping || _cameraStarting) return;

    _cameraStarting = true;
    final session = ++_cameraSession;

    if (mounted) setState(() {});

    html.MediaStream? createdStream;
    html.VideoElement? createdVideo;

    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        throw StateError('Camera API is not available in this browser.');
      }

      createdStream = await mediaDevices.getUserMedia({
        'video': {
          'facingMode': {'ideal': 'environment'},
          'width': {'ideal': 1920, 'min': 1280},
          'height': {'ideal': 1080, 'min': 720},
          'frameRate': {'ideal': _idealCameraFps, 'max': _maxCameraFps},
        },
      });

      if (!mounted ||
          _cameraStopping ||
          _cameraSleeping ||
          session != _cameraSession) {
        _stopStream(createdStream);
        return;
      }

      final viewType = _nextViewType();

      createdVideo = html.VideoElement()
        // JS startQrLoop() tìm đúng phần tử này.
        ..id = 'qr-video'
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.display = 'block'
        ..style.visibility = 'visible'
        ..style.opacity = '1'
        ..style.objectFit = 'cover'
        ..style.pointerEvents = 'none'
        ..style.position = 'absolute'
        ..style.top = '0'
        ..style.right = '0'
        ..style.bottom = '0'
        ..style.left = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.zIndex = '0'
        ..srcObject = createdStream;

      ui_web.platformViewRegistry.registerViewFactory(
        viewType,
        (_) => createdVideo!,
      );

      if (!mounted ||
          _cameraStopping ||
          _cameraSleeping ||
          session != _cameraSession) {
        _disposeVideoElement(createdVideo);
        _stopStream(createdStream);
        return;
      }

      setState(() {
        _viewType = viewType;
        _stream = createdStream;
        _video = createdVideo;
      });

      _setCameraSleeping(false);

      try {
        await createdVideo.play();
      } catch (error) {
        debugPrint('Video play warning: $error');
      }

      await _waitVideoReady(timeout: const Duration(seconds: 4));

      if (!mounted ||
          _cameraSleeping ||
          session != _cameraSession ||
          _stream == null ||
          _video == null) {
        return;
      }

      await Future.delayed(const Duration(milliseconds: 350));

      if (!mounted ||
          _cameraSleeping ||
          session != _cameraSession ||
          _stream == null ||
          _video == null) {
        return;
      }

      await _startAutoQrScan();
    } catch (error, stackTrace) {
      debugPrint('Camera start error: $error');
      debugPrintStack(stackTrace: stackTrace);

      _disposeVideoElement(createdVideo);
      _stopStream(createdStream);

      if (!mounted || session != _cameraSession) return;

      setState(() {
        _stream = null;
        _video = null;
        _qrScanning = false;
        _qrLoading = false;
      });

      _setCameraSleeping(true);
    } finally {
      if (session == _cameraSession) {
        _cameraStarting = false;
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _waitVideoReady({required Duration timeout}) async {
    final start = DateTime.now();
    while (mounted) {
      final v = _video;
      if (v != null && v.videoWidth > 0 && v.videoHeight > 0) return;
      if (DateTime.now().difference(start) > timeout) return;
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  void _stopStream(html.MediaStream? stream) {
    if (stream == null) return;

    try {
      for (final track in stream.getTracks()) {
        track.enabled = false;
        track.stop();
        debugPrint(
          'Stopped camera track: kind=${track.kind}, readyState=${track.readyState}',
        );
      }
    } catch (error) {
      debugPrint('Stop stream error: $error');
    }
  }

  void _disposeVideoElement(html.VideoElement? video) {
    if (video == null) return;

    try {
      video.pause();
      video.srcObject = null;
      video.style.display = 'none';
      video.style.visibility = 'hidden';
      video.style.opacity = '0';
      video.removeAttribute('src');
      video.load();
      video.remove();
    } catch (error) {
      debugPrint('Dispose video element error: $error');
    }
  }

  void _stopCameraTracks() {
    _stopStream(_stream);
  }

  void _stopCamera() {
    _cameraSession++;

    final oldStream = _stream;
    final oldVideo = _video;

    _stream = null;
    _video = null;

    _disposeVideoElement(oldVideo);
    _stopStream(oldStream);

    final domVideo = html.document.getElementById('qr-video');
    if (domVideo is html.VideoElement) {
      final domStream = domVideo.srcObject;
      if (domStream is html.MediaStream) {
        _stopStream(domStream);
      }
      _disposeVideoElement(domVideo);
    }
  }

  // =========================
  // QR (ZXing JS) start/stop
  // =========================
  Future<void> _startAutoQrScan() async {
    if (_qrScanning || _cameraSleeping || _stream == null || _video == null) {
      return;
    }

    final video = _video!;
    if (video.videoWidth <= 0 || video.videoHeight <= 0) {
      debugPrint('QR scan not started: video is not ready.');
      return;
    }

    await _qrSub?.cancel();
    _qrSub = html.window.on['qr-from-image'].listen(_onQrEvent);

    if (mounted) {
      setState(() {
        _qrScanning = true;
        _qrLoading = true;
      });
    }

    try {
      startQrLoop();
      debugPrint(
        'QR loop started: id=${video.id}, ${video.videoWidth}x${video.videoHeight}',
      );
    } catch (error, stackTrace) {
      debugPrint('startQrLoop error: $error');
      debugPrintStack(stackTrace: stackTrace);

      await _qrSub?.cancel();
      _qrSub = null;
      _qrScanning = false;
    } finally {
      if (mounted) {
        setState(() {
          _qrLoading = false;
        });
      }
    }
  }

  Future<void> _stopQrScan({bool updateUi = true}) async {
    try {
      stopQrLoop();
    } catch (_) {}

    try {
      await _qrSub?.cancel();
    } catch (_) {}
    _qrSub = null;

    if (mounted && updateUi) {
      setState(() {
        _qrScanning = false;
        _qrLoading = false;
      });
    } else {
      _qrScanning = false;
      _qrLoading = false;
    }
  }

  void _onQrEvent(dynamic event) {
    if (!mounted || _cameraSleeping || !_qrScanning) return;
    if (event is! html.CustomEvent) return;

    final detail = event.detail;
    if (detail == null) return;

    final error = detail['error']?.toString().trim() ?? '';
    if (error.isNotEmpty) return;

    final text = detail['text']?.toString().trim() ?? '';
    if (text.isEmpty) return;

    debugPrint('QR detected from camera: $text');
    _acceptDetectedQr(text);
  }

  // =========================
  // STT / socket
  // =========================
  Future<void> _loadStt() async {
    if (_fac.isEmpty) return;
    try {
      setState(() => _sttLoading = true);

      final value = await SttApi.getCurrentStt(
        fac: _fac,
        type: widget.patrolGroup.name,
      );

      if (!mounted) return;
      setState(() {
        stt = value;
        _sttLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _sttLoading = false);
    }
  }

  void _connectSocket() {
    sttSocket?.dispose();
    sttSocket = SttWebSocket(
      serverUrl: _wsUrl,
      fac: _fac,
      type: widget.patrolGroup.name,
      onSttUpdate: (value) {
        if (!mounted) return;
        setState(() {
          stt = value;
          _sttLoading = false;
        });
      },
    );
    sttSocket!.connect();
  }

  // =========================
  // Capture / Upload
  // =========================
  Future<String?> _decodeQrFromBytes(Uint8List bytes) async {
    String? url;
    StreamSubscription<html.Event>? sub;
    final completer = Completer<String?>();

    try {
      debugPrint('[DECODE] start, bytes = ${bytes.length}');

      final blob = html.Blob([bytes], 'image/*');
      url = html.Url.createObjectUrlFromBlob(blob);
      debugPrint('[DECODE] objectUrl created = $url');

      sub = html.window.on['qr-from-uploaded-image'].listen((event) {
        debugPrint('[DECODE] event qr-from-uploaded-image received');

        final e = event as html.CustomEvent;
        final detail = e.detail;

        final text = detail['text']?.toString().trim();
        final err = detail['error']?.toString() ?? '';

        debugPrint('[DECODE] text = $text');
        debugPrint('[DECODE] error = $err');

        if (!completer.isCompleted) {
          completer.complete((text == null || text.isEmpty) ? null : text);
        }
      });

      debugPrint('[DECODE] call JS decodeQrFromImageBytes');
      _decodeQrFromImageBytesJs(url);

      final result = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[DECODE] timeout after 5s');
          return null;
        },
      );

      debugPrint('[DECODE] final result = $result');
      return result;
    } catch (e, st) {
      debugPrint('[DECODE] ERROR = $e');
      debugPrint('[DECODE] STACK = $st');
      return null;
    } finally {
      await sub?.cancel();
      debugPrint('[DECODE] listener cancelled');

      if (url != null) {
        html.Url.revokeObjectUrl(url);
        debugPrint('[DECODE] objectUrl revoked');
      }
    }
  }

  // Future<void> pickImagesFromDevice(BuildContext context) async {
  //   final remain = _maxImages - _capturedImages.length;
  //   if (remain <= 0) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text("You can upload up to 3 images only."),
  //         backgroundColor: Colors.redAccent,
  //         behavior: SnackBarBehavior.floating,
  //       ),
  //     );
  //     return;
  //   }
  //
  //   final uploadInput = html.FileUploadInputElement()
  //     ..accept = 'image/*'
  //     ..multiple = true;
  //
  //   uploadInput.click();
  //
  //   uploadInput.onChange.listen((_) async {
  //     final files = uploadInput.files;
  //     if (files == null || files.isEmpty) return;
  //
  //     final selected = files.take(remain);
  //
  //     for (final file in selected) {
  //       final reader = html.FileReader();
  //       reader.readAsArrayBuffer(file);
  //       await reader.onLoadEnd.first;
  //
  //       final bytes = reader.result as Uint8List;
  //
  //       // decode QR trong chính ảnh upload
  //       final qrText = await _decodeQrFromBytes(bytes);
  //
  //       if (qrText != null && qrText.isNotEmpty) {
  //         if (widget.type != 'Patrol' || RegExp(r'^\d{4}$').hasMatch(qrText)) {
  //           setState(() {
  //             _lastQr = qrText;
  //             _lastQrAt = DateTime.now();
  //           });
  //
  //           widget.onQrDetected?.call(qrText);
  //           HapticFeedback.mediumImpact();
  //           _playQrChangedFx();
  //         }
  //       }
  //
  //       // add ảnh sau khi đọc QR
  //       setState(() {
  //         _capturedImages.add(bytes);
  //       });
  //     }
  //
  //     widget.onImagesChanged?.call(_capturedImages);
  //   });
  // }
  ({int width, int height}) _fitInsideMaxEdge({
    required int sourceWidth,
    required int sourceHeight,
    required int maxEdge,
  }) {
    if (sourceWidth <= 0 || sourceHeight <= 0) {
      return (width: 0, height: 0);
    }

    final longestEdge = math.max(sourceWidth, sourceHeight);

    if (longestEdge <= maxEdge) {
      return (width: sourceWidth, height: sourceHeight);
    }

    final scale = maxEdge / longestEdge;

    return (
      width: math.max(1, (sourceWidth * scale).round()),
      height: math.max(1, (sourceHeight * scale).round()),
    );
  }

  Future<Uint8List?> _canvasToJpegBytes(
    html.CanvasElement canvas, {
    double quality = 0.82,
  }) async {
    final blob = await canvas.toBlob('image/jpeg', quality);
    if (blob == null) return null;

    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    await reader.onLoadEnd.first;

    final result = reader.result;

    if (result is ByteBuffer) {
      return Uint8List.view(result);
    }

    if (result is Uint8List) {
      return result;
    }

    if (result is List<int>) {
      return Uint8List.fromList(result);
    }

    return null;
  }

  Future<void> pickImagesFromDevice(BuildContext context) async {
    final remain = _maxImages - _capturedImages.length;

    if (remain <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can upload up to 3 images only.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final uploadInput = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = true;

    uploadInput.click();

    await uploadInput.onChange.first;

    final files = uploadInput.files;
    if (files == null || files.isEmpty) return;

    for (final file in files.take(remain)) {
      String? objectUrl;

      try {
        objectUrl = html.Url.createObjectUrl(file);

        final image = html.ImageElement();
        final imageReady = Completer<void>();

        late final StreamSubscription<html.Event> loadSub;
        late final StreamSubscription<html.Event> errorSub;

        loadSub = image.onLoad.listen((_) {
          if (!imageReady.isCompleted) imageReady.complete();
        });

        errorSub = image.onError.listen((_) {
          if (!imageReady.isCompleted) {
            imageReady.completeError(StateError('Failed to load image'));
          }
        });

        image.src = objectUrl;

        try {
          await imageReady.future.timeout(const Duration(seconds: 10));
        } finally {
          await loadSub.cancel();
          await errorSub.cancel();
        }

        final width = image.naturalWidth ?? image.width ?? 0;
        final height = image.naturalHeight ?? image.height ?? 0;

        if (width <= 0 || height <= 0) continue;

        final target = _fitInsideMaxEdge(
          sourceWidth: width,
          sourceHeight: height,
          maxEdge: _maxImportedEdge,
        );

        if (target.width <= 0 || target.height <= 0) continue;

        final canvas = html.CanvasElement(
          width: target.width,
          height: target.height,
        );

        canvas.context2D.drawImageScaled(
          image,
          0,
          0,
          target.width.toDouble(),
          target.height.toDouble(),
        );

        final bytes = await _canvasToJpegBytes(canvas, quality: 0.82);

        if (bytes == null || bytes.isEmpty) continue;

        final qrText = await _decodeQrFromBytes(bytes);
        if (qrText != null && qrText.trim().isNotEmpty) {
          _acceptDetectedQr(qrText, haptic: false);
        }

        if (!mounted) return;

        setState(() {
          _capturedImages.add(bytes);
        });

        _notifyImagesChanged();
      } catch (error, stackTrace) {
        debugPrint('pickImagesFromDevice error: $error');
        debugPrintStack(stackTrace: stackTrace);
      } finally {
        if (objectUrl != null) {
          html.Url.revokeObjectUrl(objectUrl);
        }
      }
    }
  }

  void removeImage(int index) {
    if (index < 0 || index >= _capturedImages.length) return;

    setState(() {
      _capturedImages.removeAt(index);
    });

    _notifyImagesChanged();
  }

  void clearAll() {
    if (_capturedImages.isEmpty) return;

    setState(() {
      _capturedImages.clear();
    });

    _notifyImagesChanged();
  }

  void resetQr() {
    _lastDetectedQr = null;
    _lastDetectedQrAt = null;

    _patrolQrNotifier.value = null;
    _showQrGuideNotifier.value = true;
  }

  Future<void> _takePhoto() async {
    if (_cameraSleeping || _cameraStarting) return;
    if (_isCapturing || _video == null) return;
    if (_capturedImages.length >= _maxImages) return;

    setState(() => _isCapturing = true);
    _flashController.forward().then((_) => _flashController.reverse());

    try {
      final video = _video!;
      final vw = video.videoWidth.toDouble();
      final vh = video.videoHeight.toDouble();
      if (vw == 0 || vh == 0) return;

      final outputSize = math.min(math.max(vw, vh), _maxCaptureEdge).toInt();
      final canvas = html.CanvasElement(width: outputSize, height: outputSize);
      final ctx = canvas.context2D;

      final srcSize = math.min(vw, vh) / _zoom;
      final sx = (vw - srcSize) / 2;
      final sy = (vh - srcSize) / 2;

      ctx.drawImageScaledFromSource(
        video,
        sx,
        sy,
        srcSize,
        srcSize,
        0,
        0,
        outputSize.toDouble(),
        outputSize.toDouble(),
      );

      final bytes = await _canvasToJpegBytes(canvas, quality: 0.88);

      if (bytes == null || bytes.isEmpty || !mounted) return;

      setState(() {
        _capturedImages.add(bytes);
      });

      _notifyImagesChanged();
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            RepaintBoundary(
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _video != null && !_cameraSleeping
                          ? Transform.scale(
                              scale: _zoom,
                              child: HtmlElementView(
                                key: ValueKey(_viewType),
                                viewType: _viewType,
                              ),
                            )
                          : Container(
                              color: const Color(0xFF111827),
                              alignment: Alignment.center,
                              child: _cameraStarting
                                  ? const SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Color(0xFF22C55E),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.videocam_off_rounded,
                                      color: Colors.white38,
                                      size: 42,
                                    ),
                            ),

                      // Khung căn QR tĩnh: vẽ một lần, không chạy animation.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _showQrGuideNotifier,
                            child: const RepaintBoundary(
                              child: _QrGuideOverlay(),
                            ),
                            builder: (context, showGuide, child) {
                              return showGuide
                                  ? child!
                                  : const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),

                      // Tint nhẹ thay cho BackdropFilter.
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(.035),
                                Colors.transparent,
                                Colors.black.withOpacity(.08),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Flash chỉ rebuild lớp flash khi chụp ảnh.
                      AnimatedBuilder(
                        animation: _flashController,
                        builder: (_, __) {
                          return IgnorePointer(
                            child: Container(
                              color: Colors.white.withOpacity(
                                0.85 * _flashController.value,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 14,
              left: 7,
              child: GestureDetector(
                onTap: canUpload ? () => pickImagesFromDevice(context) : null,
                child: GlassCircleButton(
                  size: 50,
                  child: Icon(
                    Icons.upload_rounded,
                    color: canUpload ? Colors.white : Colors.grey,
                    size: 30,
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 14,
              left: 65,
              child: GestureDetector(
                onTap: _inputQrManually,
                child: const GlassCircleButton(
                  size: 50,
                  child: Icon(
                    Icons.keyboard_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),

            // Chỉ badge QR rebuild khi QR Patrol thay đổi.
            Positioned(
              top: 12,
              left: 12,
              child: RepaintBoundary(
                child: ValueListenableBuilder<String?>(
                  valueListenable: _patrolQrNotifier,
                  builder: (context, qr, _) {
                    return _QrStatusBadge(qr: qr);
                  },
                ),
              ),
            ),

            Positioned(
              top: 12,
              right: 12,
              child: RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCC111827),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(.30)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.18),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _sttLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'No. ${stt + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                ),
              ),
            ),

            Positioned(
              bottom: 14,
              right: 14,
              child: GlassZoomControl(
                zoom: _zoom,
                minZoom: _minZoom,
                maxZoom: _maxZoom,
                onChanged: (value) {
                  if ((value - _zoom).abs() < 0.001) return;
                  setState(() => _zoom = value);
                },
              ),
            ),

            Positioned(
              bottom: -18,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: (!_isCapturing && canUpload) ? _takePhoto : null,
                  child: GlassCircleButton(
                    size: 80,
                    showProgress: _isCapturing,
                    child: _isCapturing
                        ? null
                        : Icon(
                            Icons.camera_alt_rounded,
                            color: canUpload ? Colors.white : Colors.grey,
                            size: 36,
                          ),
                  ),
                ),
              ),
            ),

            if (_qrLoading)
              const Positioned(
                top: 12,
                left: 150,
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _QrStatusBadge extends StatelessWidget {
  final String? qr;

  const _QrStatusBadge({required this.qr});

  @override
  Widget build(BuildContext context) {
    final value = qr?.trim() ?? '';
    final hasQr = value.isNotEmpty;

    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xD9111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasQr
              ? const Color(0xFF22C55E).withOpacity(0.75)
              : Colors.redAccent.withOpacity(0.50),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.20),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasQr ? Icons.qr_code_2_rounded : Icons.qr_code_scanner_rounded,
            size: 19,
            color: hasQr ? const Color(0xFF22C55E) : Colors.redAccent,
          ),
          const SizedBox(width: 7),
          Text(
            hasQr ? value : 'Scan Patrol QR',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: hasQr ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: hasQr ? 0.8 : 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _QrGuideOverlay extends StatelessWidget {
  const _QrGuideOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 205,
        height: 205,
        child: CustomPaint(
          painter: const _QrGuidePainter(),
          child: const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Place QR inside frame',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QrGuidePainter extends CustomPainter {
  const _QrGuidePainter();

  static const double _cornerLength = 38;
  static const double _radius = 13;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);

    final paint = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      // Top left
      ..moveTo(rect.left, rect.top + _cornerLength)
      ..lineTo(rect.left, rect.top + _radius)
      ..quadraticBezierTo(rect.left, rect.top, rect.left + _radius, rect.top)
      ..lineTo(rect.left + _cornerLength, rect.top)
      // Top right
      ..moveTo(rect.right - _cornerLength, rect.top)
      ..lineTo(rect.right - _radius, rect.top)
      ..quadraticBezierTo(rect.right, rect.top, rect.right, rect.top + _radius)
      ..lineTo(rect.right, rect.top + _cornerLength)
      // Bottom right
      ..moveTo(rect.right, rect.bottom - _cornerLength)
      ..lineTo(rect.right, rect.bottom - _radius)
      ..quadraticBezierTo(
        rect.right,
        rect.bottom,
        rect.right - _radius,
        rect.bottom,
      )
      ..lineTo(rect.right - _cornerLength, rect.bottom)
      // Bottom left
      ..moveTo(rect.left + _cornerLength, rect.bottom)
      ..lineTo(rect.left + _radius, rect.bottom)
      ..quadraticBezierTo(
        rect.left,
        rect.bottom,
        rect.left,
        rect.bottom - _radius,
      )
      ..lineTo(rect.left, rect.bottom - _cornerLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _QrGuidePainter oldDelegate) => false;
}
