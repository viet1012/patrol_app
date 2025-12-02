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
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';

class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({super.key});

  @override
  State<TakePictureScreen> createState() => _TakePictureScreenState();
}

class _TakePictureScreenState extends State<TakePictureScreen> {
  html.VideoElement? _videoElement;
  Uint8List? _capturedImage;
  bool _cameraStarted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  void _startCamera() async {
    _videoElement = html.VideoElement()
      ..width = 640
      ..height = 480
      ..autoplay = true;

    // Đăng ký view factory cho HtmlElementView
    // Chỉ đăng ký 1 lần thôi (nếu bị lỗi đăng ký lại thì xử lý khác)
    // Nếu đã đăng ký rồi, bỏ qua đoạn này
    // ...
    // platformViewRegistry.registerViewFactory(
    //   'videoElement',
    //   (int viewId) => _videoElement!,
    // );

    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': true,
      });
      _videoElement!.srcObject = stream;
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

  void _capturePhoto() {
    if (_videoElement == null) return;

    final canvas = html.CanvasElement(
      width: _videoElement!.videoWidth,
      height: _videoElement!.videoHeight,
    );
    final ctx = canvas.context2D;
    ctx.drawImage(_videoElement!, 0, 0);

    canvas.toBlob('image/png').then((blob) {
      final reader = html.FileReader();
      reader.readAsArrayBuffer(blob!);
      reader.onLoadEnd.listen((event) {
        final bytes = reader.result as Uint8List;
        setState(() {
          _capturedImage = bytes;
        });
        // Trả về ảnh dưới dạng Uint8List về màn hình trước đó
        Navigator.pop(context, bytes);
      });
    });
  }

  @override
  void dispose() {
    _videoElement?.srcObject?.getTracks().forEach((track) {
      track.stop();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chụp ảnh trên Web')),
      body: Center(
        child: _error != null
            ? Text(_error!, style: const TextStyle(color: Colors.red))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_cameraStarted && _videoElement != null)
                    SizedBox(
                      width: 320,
                      height: 240,
                      child: HtmlElementView(viewType: 'videoElement'),
                    )
                  else
                    const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _cameraStarted ? _capturePhoto : null,
                    child: const Text('Chụp ảnh'),
                  ),
                  const SizedBox(height: 20),
                  if (_capturedImage != null) ...[
                    const Text('Ảnh chụp:'),
                    const SizedBox(height: 8),
                    Image.memory(_capturedImage!),
                  ],
                ],
              ),
      ),
    );
  }
}
