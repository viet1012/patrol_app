import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:chuphinh/reason_model.dart';
import 'package:chuphinh/take_picture_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'machine_model.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  Uint8List? _image;
  String? _selectedDiv = 'PE';
  String? _selectedGroup;
  String? _selectedMachine;

  String _comment = '';
  String? _selectedReason1;
  String? _selectedReason2;

  final GlobalKey<CameraPreviewBoxState> _cameraKey =
      GlobalKey<CameraPreviewBoxState>();

  List<String> getDivisions() {
    final Set<String> unique = {};
    return machines
        .map((m) => m.division.toString())
        .where((d) => d != null && d!.isNotEmpty)
        .where((d) => unique.add(d!)) // Chỉ thêm nếu chưa có
        .toList();
  }

  List<String> getGroupByDivision(String division) {
    final Set<String> unique = {};
    return machines
        .where((m) => m.division.toString() == division)
        .map((m) => m.machineType.toString())
        .where((g) => g.isNotEmpty)
        .where((g) => unique.add(g))
        .toList();
  }

  List<String> getMachineByGroup(String group) {
    final Set<String> unique = {};
    return machines
        .where((m) => m.machineType.toString() == group)
        .map((m) => m.code.toString())
        .where((c) => c.isNotEmpty)
        .where((c) => unique.add(c))
        .toList();
  }

  void _showSnackBar(
    String message,
    Color color, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: Duration(seconds: 30),
      receiveTimeout: Duration(seconds: 30),
      sendTimeout: Duration(seconds: 30),
      // Quan trọng: Cho phép mọi header và origin
      validateStatus: (status) => status! < 500,
    ),
  );

  Future<void> sendDataToServer() async {
    if (_image == null) {
      _showSnackBar('Vui lòng chụp ảnh trước!', Colors.orange);
      return;
    }
    if (_selectedGroup == null) {
      _showSnackBar('Vui lòng chọn máy!', Colors.orange);
      return;
    }

    _showSnackBar(
      'Đang gửi dữ liệu...',
      Colors.blue,
      duration: Duration(seconds: 30),
    );

    try {
      FormData formData = FormData.fromMap({
        'division': _selectedDiv ?? "",
        'group': _selectedGroup ?? "",
        'machine': _selectedMachine ?? "",
        'comment': _comment,
        'reason1': _selectedReason1 ?? "",
        'reason2': _selectedReason2 ?? "",
        'image': MultipartFile.fromBytes(
          _image!,
          filename: 'photo.jpg', // QUAN TRỌNG: phải là .jpg
          contentType: http.MediaType('image', 'jpeg'), // iOS chỉ thích jpeg
        ),
      });

      // Nếu bạn dùng ngrok → thêm dòng này
      dio.options.headers['ngrok-skip-browser-warning'] = 'true';

      Response response = await dio.post(
        "https://unboundedly-paleozoological-kai.ngrok-free.dev/api/report",
        data: formData,
        options: Options(
          sendTimeout: Duration(seconds: 120),
          receiveTimeout: Duration(seconds: 120),
          headers: {
            // Bắt buộc thêm 2 header này để iOS không bị block
            'Content-Type': 'multipart/form-data',
            'Accept': '*/*',
          },
        ),
      );

      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        _showSnackBar('Gửi dữ liệu thành công!', Colors.green);
        _resetForm();
      } else {
        _showSnackBar('Lỗi server: ${response.statusCode}', Colors.red);
      }
    } on DioException catch (e) {
      String msg = 'Lỗi kết nối: ';
      if (e.response != null) {
        msg += '${e.response?.statusCode} - ${e.response?.data}';
      } else {
        msg += e.message ?? 'Unknown error';
      }
      _showSnackBar(msg, Colors.red);
    } catch (e) {
      _showSnackBar('Lỗi không xác định: $e', Colors.red);
    }
  }

  void _resetForm() {
    setState(() {
      _image = null;
      _selectedDiv = 'PE';
      _selectedGroup = null;
      _selectedMachine = null;
      _comment = '';
      _selectedReason1 = null;
      _selectedReason2 = null;
    });

    _cameraKey.currentState?.retake();
  }

  @override
  Widget build(BuildContext context) {
    final divs = getDivisions();
    final groupList = _selectedDiv != null
        ? getGroupByDivision(_selectedDiv!)
        : <String>[];

    final machineList = _selectedGroup != null
        ? getMachineByGroup(_selectedGroup!)
        : <String>[];

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Image Preview Section
            // Stack(
            //   children: [
            //     Container(
            //       width: double.infinity,
            //       height: imageHeight,
            //       decoration: BoxDecoration(
            //         color: Colors.grey.shade200,
            //         borderRadius: BorderRadius.circular(12),
            //         border: Border.all(color: Colors.blue.shade300, width: 2),
            //       ),
            //       child:
            //       _image != null
            //           ? ClipRRect(
            //               borderRadius: BorderRadius.circular(10),
            //               child: AspectRatio(
            //                 aspectRatio: 4 / 3,
            //                 child: Image.memory(
            //                   _image!,
            //                   width: 300,
            //                   height: 300,
            //                   fit: BoxFit.contain,
            //                 ),
            //               ),
            //             )
            //           : Center(
            //               child: Column(
            //                 mainAxisAlignment: MainAxisAlignment.center,
            //                 children: [
            //                   Icon(
            //                     Icons.image_not_supported_outlined,
            //                     size: 48,
            //                     color: Colors.grey.shade400,
            //                   ),
            //                   const SizedBox(height: 8),
            //                   Text(
            //                     'Ảnh sẽ hiển thị ở đây',
            //                     style: TextStyle(
            //                       color: Colors.grey.shade600,
            //                       fontSize: 14,
            //                     ),
            //                   ),
            //                 ],
            //               ),
            //             ),
            //     ),
            //
            //     // Camera Button (Floating)
            //     Positioned(
            //       bottom: 8,
            //       right: 8,
            //       child: GestureDetector(
            //         onTap: _openCamera,
            //         child: Container(
            //           width: 56,
            //           height: 56,
            //           decoration: BoxDecoration(
            //             shape: BoxShape.circle,
            //             color: Colors.blue.shade600,
            //             boxShadow: [
            //               BoxShadow(
            //                 color: Colors.blue.shade600.withOpacity(0.4),
            //                 blurRadius: 12,
            //                 spreadRadius: 2,
            //               ),
            //             ],
            //           ),
            //           child: const Icon(
            //             Icons.camera_alt,
            //             color: Colors.white,
            //             size: 28,
            //           ),
            //         ),
            //       ),
            //     ),
            //   ],
            // ),
            Center(
              child: CameraPreviewBox(
                key: _cameraKey,
                size: 300, // kích thước vuông 320x320
                onPhotoTaken: (bytes) {
                  setState(() => _image = bytes);
                  print("Đã chụp ảnh 1:1 thành công!");
                },
              ),
            ),

            const SizedBox(height: 12),

            // Form Section
            Row(
              children: [
                // Dropdown Div Group Machine
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Div'),
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.blue.shade300,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.blue.shade50,
                        ),
                        child: DropdownButton<String>(
                          value: _selectedDiv,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: divs.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  value,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedDiv = newValue;
                              _selectedGroup = null;
                              _selectedMachine = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Dropdown Group (Machine)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Group'),
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.blue.shade300,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.blue.shade50,
                        ),
                        child: DropdownButton<String>(
                          value: _selectedGroup,
                          isExpanded: true,
                          underline: const SizedBox(),
                          hint: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text("Chọn Nhóm"),
                          ),
                          items: groupList.map((String value) {
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
                              _selectedGroup = newValue;
                              _selectedMachine = null; // Reset máy khi đổi nhóm
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Dropdown Group (Machine)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Machine'),
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.blue.shade300,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.blue.shade50,
                        ),
                        child: DropdownButton<String>(
                          value: _selectedMachine,
                          isExpanded: true,
                          underline: const SizedBox(),
                          hint: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text("Chọn máy"),
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
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            _buildLabel('Comment'),
            TextField(
              onChanged: (value) => setState(() => _comment = value),
              decoration: InputDecoration(
                hintText: 'Ghi chú thêm...',
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
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 8),

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

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.shade400, // màu n?n nút
                  side: BorderSide(
                    color: Colors
                        .blueAccent
                        .shade100, // vi?n nút (nên ch?n màu d?m hon)
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: sendDataToServer,
                child: const Text(
                  'Gửi',
                  style: TextStyle(color: Colors.white, fontSize: 18),
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
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }
}
