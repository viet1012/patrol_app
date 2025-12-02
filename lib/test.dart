import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:chuphinh/reason_model.dart';
import 'package:chuphinh/take_picture_screen.dart';
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
  String? _selectedMachine;
  String _comment = '';
  String? _selectedReason1;
  String? _selectedReason2;

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
        .where((g) => g != null && g.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
  }

  Future<void> _openCamera() async {
    final result = await Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(builder: (context) => const TakePictureScreen()),
    );

    if (result != null) {
      setState(() {
        _image = result;
      });
    }
  }

  void _clearImage() {
    setState(() {
      _image = null;
    });
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

  Future<void> sendDataToServer() async {
    if (_image == null) {
      _showSnackBar('Vui lòng chụp ảnh trước!', Colors.orange);
      return;
    }

    if (_selectedMachine == null) {
      _showSnackBar('Vui lòng chọn máy!', Colors.orange);
      return;
    }

    // Hiển thị loading
    _showSnackBar(
      'Đang gửi dữ liệu...',
      Colors.blue,
      duration: const Duration(seconds: 10),
    );

    // final uri = Uri.parse("http://localhost:9299/api/report");
    final uri = Uri.parse("http://192.168.123.108:9299/api/report");

    var request = http.MultipartRequest('POST', uri);

    // Thêm fields
    request.fields.addAll({
      'division': _selectedDiv ?? "",
      'machine': _selectedMachine ?? "",
      'comment': _comment,
      'reason1': _selectedReason1 ?? "",
      'reason2': _selectedReason2 ?? "",
    });

    // Thêm file
    try {
      var file = await http.MultipartFile.fromBytes(
        'image',
        _image!,
        filename: 'image.png',
        contentType: http.MediaType('image', 'png'),
      );
      request.files.add(file);
    } catch (e) {
      _showSnackBar('Lỗi xử lý ảnh: $e', Colors.red);
      return;
    }

    try {
      final response = await request.send().timeout(
        const Duration(seconds: 15),
      );

      // BỎ ĐỌC BODY NẾU KHÔNG CẦN
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSnackBar('Gửi dữ liệu thành công!', Colors.green);
        _resetForm();
        return; // ← THOÁT SỚM, KHÔNG ĐỌC STREAM
      } else {
        _showSnackBar('Lỗi server: ${response.statusCode}', Colors.red);
      }
    } on TimeoutException {
      _showSnackBar('Kết nối timeout. Vui lòng thử lại.', Colors.red);
    } on SocketException {
      _showSnackBar('Không có kết nối mạng hoặc server offline', Colors.red);
    } on http.ClientException catch (e) {
      _showSnackBar('Lỗi kết nối (CORS?): $e', Colors.red);
    }
  }

  Future<void> sendDataToServer1() async {
    if (_image == null) {
      print("No image selected");
      return;
    }

    final uri = Uri.parse("http://localhost:9299/api/report");

    var request = http.MultipartRequest('POST', uri);

    request.fields['division'] = _selectedDiv ?? "";
    request.fields['machine'] = _selectedMachine ?? "";
    request.fields['comment'] = _comment;
    request.fields['reason1'] = _selectedReason1 ?? "";
    request.fields['reason2'] = _selectedReason2 ?? "";

    var file = await http.MultipartFile.fromBytes(
      'image',
      _image!,
      filename: 'image.png',
      contentType: http.MediaType('image', 'png'),
    );

    request.files.add(file);

    print('Sending request with fields: ${request.fields}');
    print('Sending file: ${file.filename}, length: ${file.length}');

    try {
      var response = await request.send();

      final respStr = await response.stream.bytesToString();

      print('Response status: ${response.statusCode}');
      print('Response body: $respStr');

      if (response.statusCode == 200) {
        print("Send data success");
      } else {
        print("Send data failed");
      }
    } catch (e) {
      print("Error sending data: $e");
    }
  }

  void _resetForm() {
    setState(() {
      _image = null;
      _selectedDiv = 'PE';
      _selectedMachine = null;
      _comment = '';
      _selectedReason1 = null;
      _selectedReason2 = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final divs = getDivisions();
    final machineList = _selectedDiv != null
        ? getMachineByDivision(_selectedDiv!)
        : <String>[];
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Responsive sizes
    final imageHeight = isTablet
        ? (isLandscape ? 300.0 : 400.0)
        : (isLandscape ? 200.0 : 300.0);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Inspection'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Preview Section
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: imageHeight,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade300, width: 2),
                  ),
                  child: _image != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Image.memory(
                              _image!,
                              width: 300,
                              height: 300,
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ảnh sẽ hiển thị ở đây',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),

                // Camera Button (Floating)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _openCamera,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.shade600,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade600.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
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
                      _buildLabel('Div Group Machine'),
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
                              _selectedMachine = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

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
            const SizedBox(height: 16),

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
                onPressed:
                    sendDataToServer, // ← Chỉ gọi hàm, KHÔNG show SnackBar ở đây
                child: const Text('Gửi'),
              ),
            ),
            const SizedBox(height: 12),

            if (_image != null)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _clearImage,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade400, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Xóa ảnh',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
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
