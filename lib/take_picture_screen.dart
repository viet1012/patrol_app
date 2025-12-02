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
  late html.VideoElement _videoElement; // Không nullable
  Uint8List? _capturedImage;
  bool _cameraStarted = false;
  String? _error;

  late final String _viewType; // Thêm dòng này

  @override
  void initState() {
    super.initState();

    _viewType =
        'videoElement_${DateTime.now().millisecondsSinceEpoch}'; // Tạo mới

    _videoElement = html.VideoElement()
      ..width = 640
      ..height = 480
      ..autoplay = true;

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType, // Dùng _viewType
      (int viewId) => _videoElement,
    );

    _startCamera();
  }

  void _startCamera() async {
    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {'facingMode': 'environment'},
      });
      _videoElement.srcObject = stream;
      setState(() {
        _cameraStarted = true;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = "Không thể truy cập camera: $e";
      });
    }
  }

  void _capturePhoto() async {
    final video = _videoElement;

    // ĐỢI VIDEO SẴN SÀNG (readyState >= 1 = HAVE_METADATA)
    if (video.videoWidth == 0 || video.videoHeight == 0) {
      final completer = Completer<void>();

      void onMetadata(html.Event _) {
        video.removeEventListener('loadedmetadata', onMetadata);
        if (!completer.isCompleted) completer.complete();
      }

      video.addEventListener('loadedmetadata', onMetadata);

      // Nếu đã có metadata → complete ngay
      if (video.readyState >= 1) {
        // HAVE_METADATA = 1
        completer.complete();
      } else {
        // Timeout an toàn
        Future.delayed(const Duration(seconds: 3), () {
          if (!completer.isCompleted) {
            completer.completeError("Timeout waiting for video metadata");
          }
        });
      }

      try {
        await completer.future;
      } catch (e) {
        print("Lỗi đợi video: $e");
        _showError("Không thể chụp ảnh. Vui lòng thử lại.");
        return;
      }
    }

    // BÂY GIỜ videoWidth/Height đã có giá trị
    final canvas = html.CanvasElement(
      width: video.videoWidth,
      height: video.videoHeight,
    );
    final ctx = canvas.context2D;
    ctx.drawImage(video, 0, 0);

    canvas
        .toBlob('image/png')
        .then((blob) {
          if (blob == null) {
            print("Blob rỗng!");
            _showError("Lỗi xử lý ảnh");
            return;
          }

          final reader = html.FileReader();
          reader.readAsArrayBuffer(blob);
          reader.onLoadEnd.listen((_) {
            if (reader.readyState == html.FileReader.DONE) {
              final bytes = reader.result as Uint8List;
              setState(() {
                _capturedImage = bytes;
              });
              Navigator.pop(context, bytes);
            }
          });
        })
        .catchError((e) {
          print("Lỗi toBlob: $e");
          _showError("Lỗi chụp ảnh: $e");
        });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _videoElement.srcObject?.getTracks().forEach((t) => t.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chụp ảnh Web')),
      body: Center(
        child: _error != null
            ? Text(_error!, style: const TextStyle(color: Colors.red))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_cameraStarted)
                    SizedBox(
                      width: 320,
                      height: 240,
                      child: HtmlElementView(viewType: _viewType),
                    )
                  else
                    const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _cameraStarted ? _capturePhoto : null,
                    child: const Text('Chụp ảnh'),
                  ),
                  if (_capturedImage != null) ...[
                    const SizedBox(height: 20),
                    const Text('Ảnh chụp:'),
                    Image.memory(_capturedImage!, width: 200),
                  ],
                ],
              ),
      ),
    );
  }
}
