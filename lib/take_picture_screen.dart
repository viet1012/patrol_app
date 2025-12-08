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
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class CameraPreviewBox extends StatefulWidget {
  final double size;
  final Function(List<Uint8List> images)?
  onImagesChanged; // callback khi danh sách thay đổi

  const CameraPreviewBox({super.key, this.size = 320, this.onImagesChanged});

  @override
  State<CameraPreviewBox> createState() => CameraPreviewBoxState();
}

class CameraPreviewBoxState extends State<CameraPreviewBox>
    with TickerProviderStateMixin {
  html.MediaStream? _stream;
  html.VideoElement? _videoElement;
  String _viewType = 'camera_${DateTime.now().millisecondsSinceEpoch}';
  bool _isCapturing = false;
  late AnimationController _flashController;

  // DANH SÁCH ẢNH ĐÃ CHỤP
  final List<Uint8List> _capturedImages = [];

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
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
      _stream?.getTracks().forEach((track) => track.stop());
    } catch (_) {}
  }

  Future<void> _startCamera() async {
    try {
      final newViewType = 'camera_${DateTime.now().millisecondsSinceEpoch}';

      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'facingMode': 'environment',
          'width': {'ideal': 4096, 'min': 1080},
          'height': {'ideal': 4096, 'min': 1080},
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
    _flashController.forward().then((_) => _flashController.reverse());

    try {
      final video = _videoElement!;
      final videoWidth = video.videoWidth.toDouble();
      final videoHeight = video.videoHeight.toDouble();

      if (videoWidth == 0 || videoHeight == 0) return;

      // Chụp ảnh vuông chất lượng cao (tối đa 2048px)
      final int outputSize = math
          .min(math.max(videoWidth, videoHeight), 2048)
          .toInt();

      final canvas = html.CanvasElement(width: outputSize, height: outputSize);
      final ctx = canvas.context2D;

      final srcSize = math.min(videoWidth, videoHeight);
      final sx = (videoWidth - srcSize) / 2;
      final sy = (videoHeight - srcSize) / 2;

      ctx.drawImageScaledFromSource(
        video,
        sx,
        sy,
        srcSize,
        srcSize,
        0,
        0,
        outputSize,
        outputSize,
      );

      final blob = await canvas.toBlob('image/jpeg', 0.88); // ~800KB–1.5MB
      final reader = html.FileReader();
      reader.readAsArrayBuffer(blob!);
      await reader.onLoadEnd.first;

      final bytes = reader.result as Uint8List;

      setState(() {
        _capturedImages.add(bytes);
      });

      widget.onImagesChanged?.call(_capturedImages);
    } catch (e) {
      debugPrint('Capture error: $e');
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  void removeImage(int index) {
    setState(() {
      _capturedImages.removeAt(index);
    });
    widget.onImagesChanged?.call(_capturedImages);
  }

  void clearAll() {
    setState(() {
      _capturedImages.clear();
    });
    widget.onImagesChanged?.call(_capturedImages);
  }

  // Getter để lấy danh sách ảnh từ bên ngoài
  List<Uint8List> get images => List.unmodifiable(_capturedImages);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // === CAMERA BOX ===
        Stack(
          children: [
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
                child: _videoElement != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          HtmlElementView(
                            key: ValueKey(_viewType),
                            viewType: _viewType,
                          ),
                          IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.7),
                                  width: 30,
                                ),
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _flashController,
                            builder: (context, child) => Container(
                              color: Colors.white.withOpacity(
                                0.8 * _flashController.value,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Container(
                        color: Colors.grey[300],
                        child: Center(child: CircularProgressIndicator()),
                      ),
              ),
            ),

            // Nút chụp
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
        ),

        const SizedBox(height: 8),

        // === GRID ẢNH ĐÃ CHỤP ===

        // if (_capturedImages.isNotEmpty) ...[
        //   Padding(
        //     padding: const EdgeInsets.symmetric(horizontal: 8),
        //     child: Row(
        //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //       children: [
        //         Text(
        //           "${_capturedImages.length} ảnh",
        //           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        //         ),
        //         TextButton.icon(
        //           onPressed: clearAll,
        //           icon: Icon(Icons.delete_sweep, color: Colors.red),
        //           label: Text("Xóa hết", style: TextStyle(color: Colors.red)),
        //         ),
        //       ],
        //     ),
        //   ),
        //   GridView.builder(
        //     shrinkWrap: true,
        //     physics: NeverScrollableScrollPhysics(),
        //     gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        //       crossAxisCount: 5,
        //       crossAxisSpacing: 8,
        //       mainAxisSpacing: 8,
        //       childAspectRatio: 1,
        //     ),
        //     itemCount: _capturedImages.length,
        //     itemBuilder: (context, index) {
        //       return Stack(
        //         children: [
        //           ClipRRect(
        //             borderRadius: BorderRadius.circular(12),
        //             child: Image.memory(
        //               _capturedImages[index],
        //               fit: BoxFit.cover,
        //               width: double.infinity,
        //             ),
        //           ),
        //           Positioned(
        //             top: -8,
        //             right: -8,
        //             child: IconButton(
        //               icon: Icon(
        //                 Icons.cancel,
        //                 color: Colors.redAccent,
        //                 size: 28,
        //                 shadows: [Shadow(blurRadius: 6)],
        //               ),
        //               onPressed: () => removeImage(index),
        //             ),
        //           ),
        //         ],
        //       );
        //     },
        //   ),
        // ],
      ],
    );
  }
}
