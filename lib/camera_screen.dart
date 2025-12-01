import 'dart:io';
import 'dart:typed_data';

import 'package:chuphinh/reason_model.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'machine_model.dart';

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'machine_model.dart';
import 'reason_model.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  List<CameraDescription>? cameras;
  CameraController? controller;
  XFile? _image;

  String? _selectedDiv = 'PE';
  String? _selectedMachine;
  String _comment = '';
  String _standard1 = '';
  String _standard2 = '';
  String _standard3 = '';

  String? _selectedReason1;
  String? _selectedReason2;

  bool isCameraReady = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có quyền truy cập camera')),
        );
        return;
      }
    }

    cameras = await availableCameras();

    if (cameras == null || cameras!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy camera nào')),
      );
      return;
    }

    controller = CameraController(
      cameras![0],
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await controller!.initialize();

    if (!mounted) return;

    setState(() {
      isCameraReady = true;
    });
  }

  Future<void> _takePicture() async {
    if (!isCameraReady || controller == null) return;

    try {
      final photo = await controller!.takePicture();
      setState(() {
        _image = photo;
      });
    } catch (e) {
      debugPrint('Lỗi chụp ảnh: $e');
    }
  }

  List<String> getDivisions() {
    return machines
        .map((m) => m.division?.toString())
        .where((d) => d != null && d!.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
  }

  List<String> getMachineByDivision(String division) {
    return machines
        .where((m) => m.division?.toString() == division)
        .map((m) => m.machineType?.toString())
        .where((g) => g != null && g!.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
  }

  void _showSubmitDialog() {
    if (_image == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chụp hình trước')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận thông tin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(_image!.path)),
              ),
            const SizedBox(height: 12),
            Text('Division: $_selectedDiv'),
            Text('Machine: $_selectedMachine'),
            Text('Comment: $_comment'),
            Text('Standard 1: $_standard1'),
            Text('Standard 2: $_standard2'),
            Text('Standard 3: $_standard3'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dữ liệu đã được gửi')),
              );
              // Xử lý gửi dữ liệu hoặc ảnh tại đây
            },
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final divs = getDivisions();
    final machineList = _selectedDiv != null
        ? getMachineByDivision(_selectedDiv!)
        : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Inspection'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Camera preview hoặc ảnh chụp
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade400, width: 2),
              ),
              child: GestureDetector(
                onTap: _takePicture,
                child: _image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(_image!.path),
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      )
                    : isCameraReady && controller != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CameraPreview(controller!),
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
            const SizedBox(height: 24),

            // Phần dropdown, comment, tiêu chuẩn giữ nguyên
            _buildLabel('Div Group Machine'),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green.shade400, width: 2),
                borderRadius: BorderRadius.circular(8),
                color: Colors.green.shade50,
              ),
              child: DropdownButton<String>(
                value: _selectedDiv,
                isExpanded: true,
                items: divs.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(value),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedDiv = newValue;
                    _selectedMachine = null;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            _buildLabel('Machine'),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green.shade400, width: 2),
                borderRadius: BorderRadius.circular(8),
                color: Colors.green.shade50,
              ),
              child: DropdownButton<String>(
                value: _selectedMachine,
                isExpanded: true,
                underline: const SizedBox(),
                hint: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text("Select Machine"),
                ),
                items: machineList.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(value),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedMachine = newValue;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            _buildLabel('Comment'),
            TextField(
              onChanged: (value) => setState(() => _comment = value),
              decoration: InputDecoration(
                hintText: 'Enter comment',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
              ),
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Tiêu chuẩn 1'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.green.shade400,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.green.shade50,
                        ),
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: const Text("Chọn mức độ"),
                          underline: const SizedBox(),
                          value: _selectedReason1,
                          items: reasonList.map((r) {
                            return DropdownMenuItem(
                              value: r.reason1,
                              child: Text(r.reason1),
                            );
                          }).toList(),
                          onChanged: (v) {
                            setState(() => _selectedReason1 = v);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Tiêu chuẩn 2'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.green.shade400,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.green.shade50,
                        ),
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: const Text("Chọn mức độ"),
                          underline: const SizedBox(),
                          value: _selectedReason2,
                          items: reasonList.map((r) {
                            return DropdownMenuItem(
                              value: r.reason2,
                              child: Text(r.reason2),
                            );
                          }).toList(),
                          onChanged: (v) {
                            setState(() => _selectedReason2 = v);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _showSubmitDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Gửi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}

// import 'dart:io';
//
// import 'package:camera/camera.dart';
// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// class CameraScreen extends StatefulWidget {
//   const CameraScreen({Key? key}) : super(key: key);
//
//   @override
//   State<CameraScreen> createState() => _CameraScreenState();
// }
//
// class _CameraScreenState extends State<CameraScreen> {
//   List<CameraDescription>? cameras;
//   CameraController? controller;
//   XFile? imageFile;
//
//   bool isCameraInitialized = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _initCamera();
//   }
//
//   Future<void> _initCamera() async {
//     // Yêu cầu quyền camera
//     var status = await Permission.camera.status;
//     if (!status.isGranted) {
//       status = await Permission.camera.request();
//       if (!status.isGranted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Không có quyền truy cập camera')),
//         );
//         return;
//       }
//     }
//
//     try {
//       cameras = await availableCameras();
//       if (cameras == null || cameras!.isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Không tìm thấy camera nào')),
//         );
//         return;
//       }
//
//       controller = CameraController(
//         cameras![0],
//         ResolutionPreset.medium,
//         enableAudio: false,
//       );
//
//       await controller!.initialize();
//
//       if (!mounted) return;
//
//       setState(() {
//         isCameraInitialized = true;
//       });
//     } catch (e) {
//       debugPrint('Lỗi khởi tạo camera: $e');
//     }
//   }
//
//   Future<void> _takePicture() async {
//     if (!controller!.value.isInitialized) {
//       return;
//     }
//     if (controller!.value.isTakingPicture) {
//       return;
//     }
//
//     try {
//       final XFile file = await controller!.takePicture();
//       setState(() {
//         imageFile = file;
//       });
//     } catch (e) {
//       debugPrint('Lỗi khi chụp ảnh: $e');
//     }
//   }
//
//   void _showSubmitDialog() {
//     if (imageFile == null) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('Vui lòng chụp hình trước')));
//       return;
//     }
//
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Xác nhận gửi ảnh'),
//         content: Image.file(File(imageFile!.path)),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Hủy'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text('Dữ liệu đã được gửi')),
//               );
//               // Xử lý gửi ảnh lên server hoặc lưu ở đây
//             },
//             child: const Text('Gửi'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     controller?.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Camera Inspection'), centerTitle: true),
//       body: Column(
//         children: [
//           Expanded(
//             flex: 4,
//             child: Container(
//               color: Colors.black,
//               child: isCameraInitialized && controller != null
//                   ? CameraPreview(controller!)
//                   : const Center(child: CircularProgressIndicator()),
//             ),
//           ),
//           Expanded(
//             flex: 3,
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 children: [
//                   if (imageFile != null)
//                     ClipRRect(
//                       borderRadius: BorderRadius.circular(12),
//                       child: Image.file(File(imageFile!.path)),
//                     )
//                   else
//                     Container(
//                       height: 150,
//                       color: Colors.grey[300],
//                       alignment: Alignment.center,
//                       child: const Text('Chưa có ảnh nào'),
//                     ),
//                   const SizedBox(height: 16),
//                   ElevatedButton.icon(
//                     onPressed: _takePicture,
//                     icon: const Icon(Icons.camera_alt),
//                     label: const Text('Chụp ảnh'),
//                     style: ElevatedButton.styleFrom(
//                       minimumSize: const Size(double.infinity, 48),
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   ElevatedButton(
//                     onPressed: _showSubmitDialog,
//                     child: const Text('Gửi dữ liệu'),
//                     style: ElevatedButton.styleFrom(
//                       minimumSize: const Size(double.infinity, 48),
//                       backgroundColor: Colors.green,
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
