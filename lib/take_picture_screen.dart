// import 'dart:async';
// import 'dart:typed_data';
// import 'dart:ui_web' as ui_web;
// import 'package:flutter/material.dart';
// import 'dart:html' as html;
//
// class TakePictureScreen extends StatefulWidget {
//   const TakePictureScreen({super.key});
//
//   @override
//   State<TakePictureScreen> createState() => _TakePictureScreenState();
// }
//
// class _TakePictureScreenState extends State<TakePictureScreen> {
//   html.MediaStream? _stream;
//   html.VideoElement? _videoElement;
//   Uint8List? _capturedImage;
//   bool _isCapturing = false;
//   String? _error;
//
//   late String _viewType;
//
//   @override
//   void initState() {
//     super.initState();
//     _viewType = 'camera_${DateTime.now().millisecondsSinceEpoch}';
//     _startCameraPreview();
//   }
//
//   @override
//   void dispose() {
//     if (_stream != null) {
//       final tracks = _stream!.getTracks() as List<html.MediaStreamTrack>;
//       for (final track in tracks) {
//         track.stop();
//       }
//     }
//     super.dispose();
//   }
//
//   void _startCameraPreview() async {
//     try {
//       final newViewType = 'camera_${DateTime.now().millisecondsSinceEpoch}';
//
//       // BƯỚC 1: LẤY CAMERA SAU + ĐỘ PHÂN GIẢI CAO NHẤT
//       final stream = await html.window.navigator.mediaDevices!.getUserMedia({
//         'video': {
//           'facingMode': 'environment',
//           'width': {'min': 1080, 'ideal': 4000, 'max': 4000},
//           'height': {'min': 1080, 'ideal': 4000, 'max': 4000},
//         },
//       });
//
//       final video = html.VideoElement()
//         ..autoplay = true
//         ..srcObject = stream;
//
//       ui_web.platformViewRegistry.registerViewFactory(
//         newViewType,
//         (int viewId) => video,
//       );
//
//       // BƯỚC 2: ÁP DỤNG ĐỘ PHÂN GIẢI CAO NHẤT (sau khi video load)
//       video.onLoadedMetadata.listen((_) async {
//         final track = stream.getVideoTracks().first;
//         final capabilities = track.getCapabilities();
//         final maxW = (capabilities['width'] as Map)['max'] as int? ?? 4000;
//         final maxH = (capabilities['height'] as Map)['max'] as int? ?? 4000;
//
//         // CẮT VUÔNG: LẤY GIÁ TRỊ NHỎ HƠN
//         final size = maxW < maxH ? maxW : maxH;
//
//         await track.applyConstraints({'width': size, 'height': size});
//
//         // Cập nhật lại state để rebuild
//         if (mounted) {
//           setState(() {
//             _stream = stream;
//             _videoElement = video;
//             _viewType = newViewType;
//           });
//         }
//       });
//
//       // Gán tạm để hiển thị preview
//       setState(() {
//         _stream = stream;
//         _videoElement = video;
//         _viewType = newViewType;
//       });
//     } catch (e) {
//       setState(() => _error = "Lỗi camera: $e");
//     }
//   }
//
//   void _retake() {
//     // 1. Stop tracks một cách an toàn (cast đúng kiểu)
//     if (_stream != null) {
//       // FIX: Cast đúng kiểu JS → Dart
//       final tracks = _stream!.getTracks() as List<html.MediaStreamTrack>;
//       for (final track in tracks) {
//         track.stop();
//       }
//     }
//
//     // 2. Reset hoàn toàn state
//     setState(() {
//       _capturedImage = null;
//       _videoElement = null;
//       _stream = null;
//       _viewType =
//           'camera_${DateTime.now().millisecondsSinceEpoch}'; // Quan trọng: đổi viewType mới
//     });
//
//     // 3. Khởi động lại camera
//     _startCameraPreview();
//   }
//
//   Future<void> _capturePhoto() async {
//     if (_isCapturing || _videoElement == null) return;
//     setState(() => _isCapturing = true);
//
//     try {
//       final video = _videoElement!;
//       final completer = Completer<void>();
//
//       void onMetadata(html.Event _) {
//         video.removeEventListener('loadedmetadata', onMetadata);
//         if (!completer.isCompleted) completer.complete();
//       }
//
//       video.addEventListener('loadedmetadata', onMetadata);
//
//       if (video.readyState >= 1) {
//         completer.complete();
//       } else {
//         Future.delayed(const Duration(seconds: 3), () {
//           if (!completer.isCompleted) completer.completeError("Timeout");
//         });
//       }
//
//       await completer.future;
//
//       final canvas = html.CanvasElement(
//         width: video.videoWidth,
//         height: video.videoHeight,
//       );
//       final ctx = canvas.context2D;
//       // CẮT VUÔNG TỪ GIỮA
//       final size = video.videoWidth < video.videoHeight
//           ? video.videoWidth
//           : video.videoHeight;
//       final offsetX = (video.videoWidth - size) ~/ 2;
//       final offsetY = (video.videoHeight - size) ~/ 2;
//       ctx.drawImageScaledFromSource(
//         video,
//         offsetX,
//         offsetY,
//         size,
//         size, // CẮT VUÔNG TỪ GIỮA
//         0,
//         0,
//         size,
//         size, // VẼ VÀO CANVAS
//       );
//
//       final blob = await canvas.toBlob('image/png');
//       if (blob == null) throw "Blob rỗng";
//
//       final reader = html.FileReader();
//       reader.readAsArrayBuffer(blob);
//       await reader.onLoadEnd.first;
//
//       if (reader.readyState == html.FileReader.DONE) {
//         final bytes = reader.result as Uint8List;
//         setState(() {
//           _capturedImage = bytes;
//         });
//       }
//     } catch (e) {
//       _showError("Lỗi chụp ảnh: $e");
//     } finally {
//       setState(() => _isCapturing = false);
//     }
//   }
//
//   void _usePhoto() {
//     if (_capturedImage != null) {
//       Navigator.pop(context, _capturedImage);
//     }
//   }
//
//   void _showError(String msg) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(
//       context,
//     ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Chụp ảnh'),
//         leading: IconButton(
//           icon: const Icon(Icons.close),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: Column(
//         children: [
//           // Preview / Ảnh tĩnh
//           Expanded(
//             child: _capturedImage != null
//                 ? Padding(
//                     padding: const EdgeInsets.all(16),
//                     child: ClipRRect(
//                       borderRadius: BorderRadius.circular(12),
//                       child: Image.memory(_capturedImage!, fit: BoxFit.contain),
//                     ),
//                   )
//                 : _videoElement != null
//                 ? Padding(
//                     padding: const EdgeInsets.all(16),
//                     child: ClipRRect(
//                       borderRadius: BorderRadius.circular(12),
//                       child: AspectRatio(
//                         aspectRatio: 1.0,
//                         child: HtmlElementView(
//                           key: ValueKey(_viewType), // ← THÊM DÒNG NÀY
//                           viewType: _viewType,
//                         ),
//                       ),
//                     ),
//                   )
//                 : const Center(child: CircularProgressIndicator()),
//           ),
//
//           // Nút điều khiển
//           Container(
//             padding: const EdgeInsets.all(20),
//             decoration: const BoxDecoration(
//               color: Colors.black87,
//               borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 if (_capturedImage != null) ...[
//                   ElevatedButton.icon(
//                     onPressed: _retake,
//                     icon: const Icon(Icons.refresh),
//                     label: const Text('Chụp lại'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.grey,
//                     ),
//                   ),
//                   const SizedBox(width: 16),
//                   ElevatedButton.icon(
//                     onPressed: _usePhoto,
//                     icon: const Icon(Icons.check),
//                     label: const Text('Dùng ảnh'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.green,
//                     ),
//                   ),
//                 ] else
//                   SizedBox(
//                     width: 80,
//                     height: 80,
//                     child: ElevatedButton(
//                       onPressed: _isCapturing ? null : _capturePhoto,
//                       style: ElevatedButton.styleFrom(
//                         shape: const CircleBorder(),
//                         padding: const EdgeInsets.all(20),
//                         backgroundColor: Colors.white,
//                       ),
//                       child: _isCapturing
//                           ? const SizedBox(
//                               width: 24,
//                               height: 24,
//                               child: CircularProgressIndicator(
//                                 strokeWidth: 3,
//                                 color: Colors.blue,
//                               ),
//                             )
//                           : const Icon(
//                               Icons.camera_alt,
//                               size: 36,
//                               color: Colors.blue,
//                             ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class CameraPreviewBox extends StatefulWidget {
  final double size; // Kích thước vuông (width = height)
  final Function(Uint8List imageBytes)? onPhotoTaken;

  const CameraPreviewBox({super.key, this.size = 300, this.onPhotoTaken});

  @override
  State<CameraPreviewBox> createState() => CameraPreviewBoxState();
}

class CameraPreviewBoxState extends State<CameraPreviewBox>
    with TickerProviderStateMixin {
  html.MediaStream? _stream;
  html.VideoElement? _videoElement;
  Uint8List? _capturedImage;
  String _viewType = 'camera_${DateTime.now().millisecondsSinceEpoch}';
  bool _isCapturing = false;
  late AnimationController _flashController;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );
    _startCamera();
  }

  @override
  void dispose() {
    _flashController.dispose();
    _stopCamera();
    super.dispose();
  }

  void _stopCamera() {
    try {
      final tracks = _stream?.getTracks() as List<html.MediaStreamTrack>?;
      tracks?.forEach((t) => t.stop());
    } catch (_) {}
  }

  Future<void> _startCamera() async {
    try {
      final newViewType = 'camera_${DateTime.now().millisecondsSinceEpoch}';

      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'facingMode': 'environment',
          'width': {'max': 4096},
          'height': {'max': 4096},
        },
      });

      final video = html.VideoElement()
        ..setAttribute('autoplay', 'true')
        ..setAttribute('playsinline', 'true')
        ..setAttribute('muted', 'true')
        ..style.objectFit = 'cover'
        ..style.pointerEvents = 'none'
        ..srcObject = stream;

      ui_web.platformViewRegistry.registerViewFactory(
        newViewType,
        (id) => video,
      );

      setState(() {
        _stream = stream;
        _videoElement = video;
        _viewType = newViewType;
      });
    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  Future<void> _takePhoto() async {
    if (_isCapturing || _videoElement == null) return;
    setState(() => _isCapturing = true);

    // Hiệu ứng flash khi chụp
    _flashController.forward().then((_) => _flashController.reverse());

    try {
      final video = _videoElement!;
      final size = widget.size.toInt();
      final canvas = html.CanvasElement(width: size, height: size);
      final ctx = canvas.context2D;

      // Tính toán để cắt giữa khung hình thành 1:1
      // final srcSize = video.videoWidth > video.videoHeight
      //     ? video.videoHeight
      //     : video.videoWidth;

      final srcSize = math.min(video.videoWidth, video.videoHeight);

      final sx = (video.videoWidth - srcSize) / 2;
      final sy = (video.videoHeight - srcSize) / 2;

      ctx.drawImageScaledFromSource(
        video,
        sx,
        sy,
        srcSize,
        srcSize, // crop từ giữa
        0,
        0,
        size,
        size, // vẽ vào canvas vuông
      );

      final blob = await canvas.toBlob('image/jpeg', 0.92);
      final reader = html.FileReader();
      reader.readAsArrayBuffer(blob!);
      await reader.onLoadEnd.first;

      final bytes = reader.result as Uint8List;

      setState(() {
        _capturedImage = bytes;
      });

      widget.onPhotoTaken?.call(bytes);
    } catch (e) {
      debugPrint("Capture error: $e");
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  void retake() {
    _retake(); // gọi lại hàm private cũ
  }

  void _retake() async {
    _stopCamera();
    setState(() {
      _capturedImage = null;
      _stream = null;
      _videoElement = null;
      _viewType = 'camera_${DateTime.now().millisecondsSinceEpoch}';
    });
    await _startCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Khung chính vuông
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade400, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: _capturedImage != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(_capturedImage!, fit: BoxFit.cover),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: _retake,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      // Camera preview
                      if (_videoElement != null)
                        HtmlElementView(
                          key: ValueKey(_viewType),
                          viewType: _viewType,
                        )
                      else
                        Container(
                          color: Colors.grey[300],
                          child: Center(child: CircularProgressIndicator()),
                        ),

                      // Overlay hướng dẫn chụp (4 góc)
                      IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Colors.white.withOpacity(0.7),
                                width: 30,
                              ),
                              bottom: BorderSide(
                                color: Colors.white.withOpacity(0.7),
                                width: 30,
                              ),
                              left: BorderSide(
                                color: Colors.white.withOpacity(0.7),
                                width: 30,
                              ),
                              right: BorderSide(
                                color: Colors.white.withOpacity(0.7),
                                width: 30,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Flash effect
                      AnimatedBuilder(
                        animation: _flashController,
                        builder: (context, child) {
                          return Container(
                            color: Colors.white.withOpacity(
                              0.8 * _flashController.value,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ),

        // Nút chụp (chỉ hiện khi chưa chụp)
        if (_capturedImage == null)
          Positioned(
            bottom: -15,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _isCapturing ? null : _takePhoto,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.blue.shade600, width: 5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isCapturing
                      ? Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            strokeWidth: 5,
                            color: Colors.blue,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
