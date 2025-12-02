import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:chuphinh/reason_model.dart';
import 'package:chuphinh/take_picture_screen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'machine_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

// Thêm 1 biến trạng thái mạng và danh sách lưu offline:
class _CameraScreenState extends State<CameraScreen> {
  // Existing fields...
  XFile? _image;
  String? _selectedDiv = 'PE';
  String? _selectedMachine;
  String _comment = '';
  String? _selectedReason1;
  String? _selectedReason2;

  // Mới:
  bool _isOnline = true;
  List<Map<String, dynamic>> _offlineReports = [];

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then((result) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      bool nowOnline = result != ConnectivityResult.none;
      if (nowOnline && !_isOnline) {
        _uploadOfflineReports();
      }
      setState(() {
        _isOnline = nowOnline;
      });
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
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
        .where((g) => g != null && g.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
  }

  Future<void> _openCamera() async {
    final result = await Navigator.push<XFile?>(
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

  // Hàm lưu offline khi không có mạng
  Future<void> _saveReportOffline() async {
    if (_image == null) return;
    final fileBytes = await File(_image!.path).readAsBytes();
    final base64Image = base64Encode(fileBytes);
    Map<String, dynamic> report = {
      'division': _selectedDiv ?? "",
      'machine': _selectedMachine ?? "",
      'comment': _comment,
      'reason1': _selectedReason1 ?? "",
      'reason2': _selectedReason2 ?? "",
      'imageBase64': base64Image,
      'timestamp': DateTime.now().toIso8601String(),
    };
    setState(() {
      _offlineReports.add(report);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Lưu báo cáo offline thành công')));
    _resetForm();
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

  // Gửi báo cáo (gồm 2 trường hợp: online gửi ngay, offline lưu)
  Future<void> sendDataToServer() async {
    if (_image == null) {
      print("No image selected");
      return;
    }

    if (!_isOnline) {
      // Lưu offline
      await _saveReportOffline();
      return;
    }

    // Gửi online
    final uri = Uri.parse("http://192.168.123.16:9999/api/report");

    var request = http.MultipartRequest('POST', uri);

    request.fields['division'] = _selectedDiv ?? "";
    request.fields['machine'] = _selectedMachine ?? "";
    request.fields['comment'] = _comment;
    request.fields['reason1'] = _selectedReason1 ?? "";
    request.fields['reason2'] = _selectedReason2 ?? "";

    var file = await http.MultipartFile.fromPath('image', _image!.path);

    request.files.add(file);

    try {
      var response = await request.send();

      final respStr = await response.stream.bytesToString();

      print('Response status: ${response.statusCode}');
      print('Response body: $respStr');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✓ Dữ liệu đã được gửi')));
        _resetForm();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gửi dữ liệu thất bại, lưu offline')),
        );
        await _saveReportOffline();
      }
    } catch (e) {
      print("Error sending data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi gửi dữ liệu, lưu offline')),
      );
      await _saveReportOffline();
    }
  }

  // Upload dữ liệu offline khi có mạng
  Future<void> _uploadOfflineReports() async {
    if (_offlineReports.isEmpty) return;

    int successCount = 0;

    // Tạo bản sao để tránh lỗi setState khi xoá trong vòng for
    List<Map<String, dynamic>> copyReports = List.from(_offlineReports);

    for (var report in copyReports) {
      bool success = await _uploadSingleReport(report);
      if (success) {
        setState(() {
          _offlineReports.remove(report);
        });
        successCount++;
      }
    }

    if (successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã gửi $successCount báo cáo offline thành công'),
        ),
      );
    }
  }

  // Upload từng báo cáo offline một
  Future<bool> _uploadSingleReport(Map<String, dynamic> report) async {
    final uri = Uri.parse("http://192.168.123.16:9999/api/report");
    var request = http.MultipartRequest('POST', uri);

    request.fields['division'] = report['division'] ?? "";
    request.fields['machine'] = report['machine'] ?? "";
    request.fields['comment'] = report['comment'] ?? "";
    request.fields['reason1'] = report['reason1'] ?? "";
    request.fields['reason2'] = report['reason2'] ?? "";

    try {
      // Từ base64 tạo MultipartFile tạm
      final bytes = base64Decode(report['imageBase64']);
      final tempDir = await getTemporaryDirectory();
      final tempFile = await File(
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg',
      ).writeAsBytes(bytes);

      var file = await http.MultipartFile.fromPath('image', tempFile.path);

      request.files.add(file);

      var response = await request.send();

      if (response.statusCode == 200) {
        await tempFile.delete();
        return true;
      } else {
        await tempFile.delete();
        return false;
      }
    } catch (e) {
      print('Error uploading offline report: $e');
      return false;
    }
  }

  // Mở màn hình danh sách offline reports
  void _openOfflineReportList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfflineReportListScreen(
          reports: _offlineReports,
          onDelete: (report) {
            setState(() {
              _offlineReports.remove(report);
            });
          },
          onSendNow: (report) async {
            bool success = await _uploadSingleReport(report);
            if (success) {
              setState(() {
                _offlineReports.remove(report);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Gửi báo cáo thành công')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Gửi báo cáo thất bại')),
              );
            }
          },
        ),
      ),
    );
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

    final imageHeight = isTablet
        ? (isLandscape ? 300.0 : 400.0)
        : (isLandscape ? 200.0 : 300.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Inspection'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
        actions: [
          // Hiển thị trạng thái mạng
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 14,
                  color: _isOnline ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isOnline ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Báo cáo offline',
            onPressed: _openOfflineReportList,
          ),
        ],
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
                            child: Image.file(
                              File(_image!.path),
                              fit: BoxFit.contain, // giữ toàn bộ ảnh, không cắt
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
            _buildLabel('Div Group Machine'),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue.shade300, width: 1.5),
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
                        style: const TextStyle(fontWeight: FontWeight.w500),
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
            const SizedBox(height: 16),

            _buildLabel('Machine'),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue.shade300, width: 1.5),
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
                onPressed: () {
                  sendDataToServer(); // <<=== GỌI HÀM LƯU EXCEL
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Dữ liệu đã được gửi')),
                  );
                  _resetForm();
                },
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

// Màn hình danh sách báo cáo offline
class OfflineReportListScreen extends StatelessWidget {
  final List<Map<String, dynamic>> reports;
  final void Function(Map<String, dynamic>) onDelete;
  final Future<void> Function(Map<String, dynamic>) onSendNow;

  const OfflineReportListScreen({
    super.key,
    required this.reports,
    required this.onDelete,
    required this.onSendNow,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo Offline Chưa Gửi'),
        backgroundColor: Colors.blue.shade600,
      ),
      body: reports.isEmpty
          ? const Center(child: Text('Không có báo cáo offline chưa gửi'))
          : ListView.builder(
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                final imageBytes = base64Decode(report['imageBase64']);
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: Image.memory(
                      imageBytes,
                      width: 60,
                      fit: BoxFit.cover,
                    ),
                    title: Text(
                      'Division: ${report['division']} - Machine: ${report['machine']}',
                    ),
                    subtitle: Text(report['comment']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.green),
                          tooltip: 'Gửi ngay',
                          onPressed: () => onSendNow(report),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Xóa',
                          onPressed: () => onDelete(report),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
