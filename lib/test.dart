import 'dart:typed_data';
import 'package:chuphinh/take_picture_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'machine_model.dart';
import 'reason_model.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  String? _selectedDiv = 'PE';
  String? _selectedGroup;
  String? _selectedMachine;
  String _comment = '';
  String? _selectedReason1;
  String? _selectedReason2 = '';
  bool _needRecheck = false;

  final GlobalKey<CameraPreviewBoxState> _cameraKey =
      GlobalKey<CameraPreviewBoxState>();

  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  List<String> getDivisions() {
    final Set<String> unique = {};
    return machines
        .map((m) => m.division.toString())
        .where((d) => d!.isNotEmpty)
        .where((d) => unique.add(d))
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
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _sendReport() async {
    final images = _cameraKey.currentState?.images ?? [];
    if (images.isEmpty) {
      _showSnackBar('Vui lòng chụp ít nhất 1 ảnh!', Colors.orange);
      return;
    }
    if (_selectedGroup == null) {
      _showSnackBar('Vui lòng chọn máy!', Colors.orange);
      return;
    }

    _showSnackBar(
      'Đang gửi ${images.length} ảnh...',
      Colors.blue,
      duration: const Duration(seconds: 60),
    );

    try {
      // Tạo danh sách MultipartFile
      final imageFiles = <MultipartFile>[];
      for (int i = 0; i < images.length; i++) {
        imageFiles.add(
          MultipartFile.fromBytes(
            images[i],
            filename: 'photo_${i + 1}.jpg',
            contentType: http.MediaType('image', 'jpeg'),
          ),
        );
      }

      final formData = FormData.fromMap({
        'division': _selectedDiv ?? '',
        'group': _selectedGroup ?? '',
        'machine': _selectedMachine ?? '',
        'comment': _comment,
        'reason1': _selectedReason1 ?? '',
        'reason2': _selectedReason2 ?? '',
        'check': _needRecheck ? 'Kiểm tra lỗi tương tự' : '',
        'images': imageFiles, // tên field đúng với backend
      });

      // Nếu dùng ngrok
      dio.options.headers['ngrok-skip-browser-warning'] = 'true';

      final response = await dio.post(
        // "https://unboundedly-paleozoological-kai.ngrok-free.dev/api/report",
        "http://localhost:9299/api/report",
        data: formData,
        options: Options(sendTimeout: const Duration(seconds: 120)),
      );

      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        _showSnackBar('Gửi thành công ${images.length} ảnh!', Colors.green);
        _resetForm();
      } else {
        _showSnackBar('Lỗi server: ${response.statusCode}', Colors.red);
      }
    } on DioException catch (e) {
      String msg = 'Lỗi: ';
      if (e.response != null) {
        msg += '${e.response?.statusCode} - ${e.response?.data}';
      } else {
        msg += e.message ?? 'Unknown';
      }
      _showSnackBar(msg, Colors.red);
    } catch (e) {
      _showSnackBar('Lỗi: $e', Colors.red);
    }
  }

  void _resetForm() {
    setState(() {
      _selectedDiv = 'PE';
      _selectedGroup = null;
      _selectedMachine = null;
      _comment = '';
      _selectedReason1 = null;
      _selectedReason2 = null;
      _needRecheck = false;
    });
    _cameraKey.currentState?.clearAll(); // xóa hết ảnh
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
    final imageCount = _cameraKey.currentState?.images.length ?? 0;
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // CAMERA + GRID ẢNH
            CameraPreviewBox(
              key: _cameraKey,
              size: 340,
              onImagesChanged: (_) => setState(() {}), // cập nhật số lượng ảnh
            ),

            const SizedBox(height: 8),

            // FORM
            Row(
              children: [
                Expanded(
                  child: _buildDropdown('Div', _selectedDiv, divs, (v) {
                    setState(() {
                      _selectedDiv = v;
                      _selectedGroup = null;
                      _selectedMachine = null;
                    });
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDropdown('Group', _selectedGroup, groupList, (
                    v,
                  ) {
                    setState(() {
                      _selectedGroup = v;
                      _selectedMachine = null;
                    });
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDropdown(
                    'Machine',
                    _selectedMachine,
                    machineList,
                    (v) {
                      setState(() => _selectedMachine = v);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            _buildLabel('Comment'),
            TextField(
              onChanged: (v) => _comment = v,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Ghi chú...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildReasonDropdown(
                    'Tiêu chuẩn 1',
                    _selectedReason1,
                    (v) {
                      setState(() => _selectedReason1 = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildReasonDropdown(
                    'Tiêu chuẩn 2',
                    _selectedReason2,
                    (v) => setState(() => _selectedReason2 = v),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: _needRecheck,
                      onChanged: (v) =>
                          setState(() => _needRecheck = v ?? false),
                      activeColor: Colors.orange.shade700,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Cần rà soát lại vấn đề tương tự",
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // NÚT GỬI
            SizedBox(
              height: 56,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: imageCount == 0 ? null : _sendReport,
                icon: const Icon(Icons.send_rounded),
                label: Text(
                  imageCount == 0
                      ? 'CHỤP ẢNH ĐỂ GỬI'
                      : 'GỬI BÁO CÁO ($imageCount ảnh)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: imageCount == 0
                      ? Colors.grey
                      : Colors.green.shade700,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    // Fix: Nếu value không nằm trong items → tự động reset về null (tránh assert)
    final String? safeValue = value != null && items.contains(value)
        ? value
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border.all(color: Colors.blue.shade300, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButton<String>(
            value: safeValue,
            isExpanded: true,
            underline: const SizedBox(),
            hint: Text(
              "Chọn $label",
              style: TextStyle(color: Colors.grey[600]),
            ),
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (newValue) {
              onChanged(newValue);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReasonDropdown(
    String label,
    String? value,
    Function(String?) onChanged,
  ) {
    // LẤY CẢ reason1 VÀ reason2 để tránh lỗi khi chọn Tiêu chuẩn 2
    final Set<String> reasonSet = {};
    for (var r in reasonList) {
      if (r.reason1?.isNotEmpty == true) reasonSet.add(r.reason1!);
      if (r.reason2?.isNotEmpty == true) reasonSet.add(r.reason2!);
    }
    final List<String> reasonItems = reasonSet.toList()..sort();

    // Fix assert: nếu value không có trong danh sách → reset về null
    final String? safeValue = value != null && reasonItems.contains(value)
        ? value
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            border: Border.all(color: Colors.green.shade400, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButton<String>(
            value: safeValue,
            isExpanded: true,
            underline: const SizedBox(),
            hint: const Text(
              "Chọn mức độ",
              style: TextStyle(color: Colors.grey),
            ),
            items: reasonItems
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}
