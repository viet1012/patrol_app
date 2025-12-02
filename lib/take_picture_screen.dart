// import 'package:camera/camera.dart';
// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// class TakePictureScreen extends StatefulWidget {
//   const TakePictureScreen({super.key});
//
//   @override
//   State<TakePictureScreen> createState() => _TakePictureScreenState();
// }
//
// class _TakePictureScreenState extends State<TakePictureScreen> {
//   late CameraController _controller;
//   late Future<void> _initializeControllerFuture;
//   bool isCameraReady = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _initCamera();
//   }
//
//   Future<void> _initCamera() async {
//     var status = await Permission.camera.status;
//     if (!status.isGranted) {
//       status = await Permission.camera.request();
//       if (!status.isGranted) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Cấp quyền camera để sử dụng')),
//           );
//           Navigator.pop(context);
//         }
//         return;
//       }
//     }
//
//     final cameras = await availableCameras();
//
//     if (cameras.isEmpty) {
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(const SnackBar(content: Text('Không tìm thấy camera')));
//         Navigator.pop(context);
//       }
//       return;
//     }
//
//     _controller = CameraController(
//       cameras[1],
//       ResolutionPreset.high,
//       enableAudio: false,
//     );
//
//     _initializeControllerFuture = _controller.initialize();
//
//     _initializeControllerFuture.then((_) {
//       if (mounted) {
//         setState(() {
//           isCameraReady = true;
//         });
//       }
//     });
//   }
//
//   Future<void> _takePicture() async {
//     try {
//       await _initializeControllerFuture;
//       final image = await _controller.takePicture();
//       if (mounted) {
//         Navigator.pop(context, image);
//       }
//     } catch (e) {
//       debugPrint('Error taking picture: $e');
//     }
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Chụp ảnh'),
//         centerTitle: true,
//         backgroundColor: Colors.black87,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.close),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: Stack(
//         children: [
//           // Camera Preview
//           if (isCameraReady)
//             SizedBox.expand(
//               child: RepaintBoundary(child: CameraPreview(_controller)),
//             )
//           else
//             const Center(child: CircularProgressIndicator()),
//
//           // Bottom Controls
//           Positioned(
//             bottom: 0,
//             left: 0,
//             right: 0,
//             child: Container(
//               decoration: BoxDecoration(
//                 color: Colors.black87,
//                 borderRadius: const BorderRadius.only(
//                   topLeft: Radius.circular(20),
//                   topRight: Radius.circular(20),
//                 ),
//               ),
//               padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
//               child: Column(
//                 children: [
//                   // Capture Button
//                   GestureDetector(
//                     onTap: isCameraReady ? _takePicture : null,
//                     child: Container(
//                       width: 80,
//                       height: 80,
//                       decoration: BoxDecoration(
//                         shape: BoxShape.circle,
//                         color: Colors.white,
//                         border: Border.all(
//                           color: Colors.blue.shade600,
//                           width: 4,
//                         ),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.blue.shade600.withOpacity(0.6),
//                             blurRadius: 20,
//                             spreadRadius: 4,
//                           ),
//                         ],
//                       ),
//                       child: Icon(
//                         Icons.camera_alt,
//                         size: 40,
//                         color: Colors.blue.shade600,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   const Text(
//                     'Nhấn nút để chụp ảnh',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 14,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
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
//   late html.VideoElement _videoElement; // Không nullable
//   Uint8List? _capturedImage;
//   bool _cameraStarted = false;
//   String? _error;
//
//   late final String _viewType; // Thêm dòng này
//
//   @override
//   void initState() {
//     super.initState();
//
//     _viewType =
//         'videoElement_${DateTime.now().millisecondsSinceEpoch}'; // Tạo mới
//
//     _videoElement = html.VideoElement()
//       ..width = 640
//       ..height = 480
//       ..autoplay = true;
//
//     ui_web.platformViewRegistry.registerViewFactory(
//       _viewType, // Dùng _viewType
//       (int viewId) => _videoElement,
//     );
//
//     _startCamera();
//   }
//
//   void _startCamera() async {
//     try {
//       final stream = await html.window.navigator.mediaDevices!.getUserMedia({
//         'video': {'facingMode': 'environment'},
//       });
//       _videoElement.srcObject = stream;
//       setState(() {
//         _cameraStarted = true;
//         _error = null;
//       });
//     } catch (e) {
//       setState(() {
//         _error = "Không thể truy cập camera: $e";
//       });
//     }
//   }
//
//   void _capturePhoto() async {
//     final video = _videoElement;
//
//     // ĐỢI VIDEO SẴN SÀNG (readyState >= 1 = HAVE_METADATA)
//     if (video.videoWidth == 0 || video.videoHeight == 0) {
//       final completer = Completer<void>();
//
//       void onMetadata(html.Event _) {
//         video.removeEventListener('loadedmetadata', onMetadata);
//         if (!completer.isCompleted) completer.complete();
//       }
//
//       video.addEventListener('loadedmetadata', onMetadata);
//
//       // Nếu đã có metadata → complete ngay
//       if (video.readyState >= 1) {
//         // HAVE_METADATA = 1
//         completer.complete();
//       } else {
//         // Timeout an toàn
//         Future.delayed(const Duration(seconds: 3), () {
//           if (!completer.isCompleted) {
//             completer.completeError("Timeout waiting for video metadata");
//           }
//         });
//       }
//
//       try {
//         await completer.future;
//       } catch (e) {
//         print("Lỗi đợi video: $e");
//         _showError("Không thể chụp ảnh. Vui lòng thử lại.");
//         return;
//       }
//     }
//
//     // BÂY GIỜ videoWidth/Height đã có giá trị
//     final canvas = html.CanvasElement(
//       width: video.videoWidth,
//       height: video.videoHeight,
//     );
//     final ctx = canvas.context2D;
//     ctx.drawImage(video, 0, 0);
//
//     canvas
//         .toBlob('image/png')
//         .then((blob) {
//           if (blob == null) {
//             print("Blob rỗng!");
//             _showError("Lỗi xử lý ảnh");
//             return;
//           }
//
//           final reader = html.FileReader();
//           reader.readAsArrayBuffer(blob);
//           reader.onLoadEnd.listen((_) {
//             if (reader.readyState == html.FileReader.DONE) {
//               final bytes = reader.result as Uint8List;
//               setState(() {
//                 _capturedImage = bytes;
//               });
//               Navigator.pop(context, bytes);
//             }
//           });
//         })
//         .catchError((e) {
//           print("Lỗi toBlob: $e");
//           _showError("Lỗi chụp ảnh: $e");
//         });
//   }
//
//   void _showError(String message) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message), backgroundColor: Colors.red),
//     );
//   }
//
//   @override
//   void dispose() {
//     _videoElement.srcObject?.getTracks().forEach((t) => t.stop());
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Chụp ảnh Web')),
//       body: Center(
//         child: _error != null
//             ? Text(_error!, style: const TextStyle(color: Colors.red))
//             : Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   if (_cameraStarted)
//                     SizedBox(
//                       width: 320,
//                       height: 240,
//                       child: HtmlElementView(viewType: _viewType),
//                     )
//                   else
//                     const CircularProgressIndicator(),
//                   const SizedBox(height: 20),
//                   ElevatedButton(
//                     onPressed: _cameraStarted ? _capturePhoto : null,
//                     child: const Text('Chụp ảnh'),
//                   ),
//                   if (_capturedImage != null) ...[
//                     const SizedBox(height: 20),
//                     const Text('Ảnh chụp:'),
//                     Image.memory(_capturedImage!, width: 200),
//                   ],
//                 ],
//               ),
//       ),
//     );
//   }
// }
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'dart:html' as html;

class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({super.key});

  @override
  State<TakePictureScreen> createState() => _TakePictureScreenState();
}

class _TakePictureScreenState extends State<TakePictureScreen> {
  html.MediaStream? _stream;
  html.VideoElement? _videoElement;
  Uint8List? _capturedImage;
  bool _isCapturing = false;
  String? _error;

  late String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'camera_${DateTime.now().millisecondsSinceEpoch}';
    _startCameraPreview();
  }

  @override
  void dispose() {
    if (_stream != null) {
      final tracks = _stream!.getTracks() as List<html.MediaStreamTrack>;
      for (final track in tracks) {
        track.stop();
      }
    }
    super.dispose();
  }

  void _startCameraPreview() async {
    try {
      final newViewType = 'camera_${DateTime.now().millisecondsSinceEpoch}';

      // BƯỚC 1: LẤY CAMERA SAU + ĐỘ PHÂN GIẢI CAO NHẤT
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'facingMode': 'environment',
          'width': {'min': 1080, 'ideal': 4000, 'max': 4000},
          'height': {'min': 1080, 'ideal': 4000, 'max': 4000},
        },
      });

      final video = html.VideoElement()
        ..autoplay = true
        ..srcObject = stream;

      ui_web.platformViewRegistry.registerViewFactory(
        newViewType,
        (int viewId) => video,
      );

      // BƯỚC 2: ÁP DỤNG ĐỘ PHÂN GIẢI CAO NHẤT (sau khi video load)
      video.onLoadedMetadata.listen((_) async {
        final track = stream.getVideoTracks().first;
        final capabilities = track.getCapabilities();
        final maxW = (capabilities['width'] as Map)['max'] as int? ?? 4000;
        final maxH = (capabilities['height'] as Map)['max'] as int? ?? 4000;

        // CẮT VUÔNG: LẤY GIÁ TRỊ NHỎ HƠN
        final size = maxW < maxH ? maxW : maxH;

        await track.applyConstraints({'width': size, 'height': size});

        // Cập nhật lại state để rebuild
        if (mounted) {
          setState(() {
            _stream = stream;
            _videoElement = video;
            _viewType = newViewType;
          });
        }
      });

      // Gán tạm để hiển thị preview
      setState(() {
        _stream = stream;
        _videoElement = video;
        _viewType = newViewType;
      });
    } catch (e) {
      setState(() => _error = "Lỗi camera: $e");
    }
  }

  void _retake() {
    // 1. Stop tracks một cách an toàn (cast đúng kiểu)
    if (_stream != null) {
      // FIX: Cast đúng kiểu JS → Dart
      final tracks = _stream!.getTracks() as List<html.MediaStreamTrack>;
      for (final track in tracks) {
        track.stop();
      }
    }

    // 2. Reset hoàn toàn state
    setState(() {
      _capturedImage = null;
      _videoElement = null;
      _stream = null;
      _viewType =
          'camera_${DateTime.now().millisecondsSinceEpoch}'; // Quan trọng: đổi viewType mới
    });

    // 3. Khởi động lại camera
    _startCameraPreview();
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing || _videoElement == null) return;
    setState(() => _isCapturing = true);

    try {
      final video = _videoElement!;
      final completer = Completer<void>();

      void onMetadata(html.Event _) {
        video.removeEventListener('loadedmetadata', onMetadata);
        if (!completer.isCompleted) completer.complete();
      }

      video.addEventListener('loadedmetadata', onMetadata);

      if (video.readyState >= 1) {
        completer.complete();
      } else {
        Future.delayed(const Duration(seconds: 3), () {
          if (!completer.isCompleted) completer.completeError("Timeout");
        });
      }

      await completer.future;

      final canvas = html.CanvasElement(
        width: video.videoWidth,
        height: video.videoHeight,
      );
      final ctx = canvas.context2D;
      // CẮT VUÔNG TỪ GIỮA
      final size = video.videoWidth < video.videoHeight
          ? video.videoWidth
          : video.videoHeight;
      final offsetX = (video.videoWidth - size) ~/ 2;
      final offsetY = (video.videoHeight - size) ~/ 2;
      ctx.drawImageScaledFromSource(
        video,
        offsetX,
        offsetY,
        size,
        size, // CẮT VUÔNG TỪ GIỮA
        0,
        0,
        size,
        size, // VẼ VÀO CANVAS
      );

      final blob = await canvas.toBlob('image/png');
      if (blob == null) throw "Blob rỗng";

      final reader = html.FileReader();
      reader.readAsArrayBuffer(blob);
      await reader.onLoadEnd.first;

      if (reader.readyState == html.FileReader.DONE) {
        final bytes = reader.result as Uint8List;
        setState(() {
          _capturedImage = bytes;
        });
      }
    } catch (e) {
      _showError("Lỗi chụp ảnh: $e");
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  void _usePhoto() {
    if (_capturedImage != null) {
      Navigator.pop(context, _capturedImage);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chụp ảnh'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Preview / Ảnh tĩnh
          Expanded(
            child: _capturedImage != null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_capturedImage!, fit: BoxFit.contain),
                    ),
                  )
                : _videoElement != null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: HtmlElementView(
                          key: ValueKey(_viewType), // ← THÊM DÒNG NÀY
                          viewType: _viewType,
                        ),
                      ),
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),

          // Nút điều khiển
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_capturedImage != null) ...[
                  ElevatedButton.icon(
                    onPressed: _retake,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Chụp lại'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _usePhoto,
                    icon: const Icon(Icons.check),
                    label: const Text('Dùng ảnh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ] else
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: ElevatedButton(
                      onPressed: _isCapturing ? null : _capturePhoto,
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(20),
                        backgroundColor: Colors.white,
                      ),
                      child: _isCapturing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.blue,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt,
                              size: 36,
                              color: Colors.blue,
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
