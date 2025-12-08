import 'dart:typed_data';
import 'package:chuphinh/take_picture_screen.dart';
import 'package:dio/dio.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'model/machine_model.dart';
import 'model/reason_model.dart';

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

  String? _freq;
  String? _prob;
  String? _sev;

  int get totalScore {
    int f = frequencyOptions
        .firstWhere(
          (e) => e.label == _freq,
          orElse: () => RiskOption(label: "", score: 0),
        )
        .score;
    int p = probabilityOptions
        .firstWhere(
          (e) => e.label == _prob,
          orElse: () => RiskOption(label: "", score: 0),
        )
        .score;
    int s = severityOptions
        .firstWhere(
          (e) => e.label == _sev,
          orElse: () => RiskOption(label: "", score: 0),
        )
        .score;

    return f + p + s; // 👉 Có thể đổi thành f + p + s tuỳ yêu cầu
  }

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
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: imageCount == 0 ? null : _sendReport,
            icon: const Icon(Icons.send_rounded),
            tooltip: imageCount == 0 ? "Chụp ảnh để gửi" : "Gửi báo cáo",
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // CAMERA + GRID ẢNH
            CameraPreviewBox(
              key: _cameraKey,
              size: 340,
              onImagesChanged: (_) => setState(() {}), // cập nhật số lượng ảnh
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildSearchableDropdown(
                    label: 'Div',
                    selectedValue: _selectedDiv,
                    items: divs,
                    onChanged: (v) {
                      setState(() {
                        _selectedDiv = v;
                        _selectedGroup = null;
                        _selectedMachine = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSearchableDropdown(
                    label: 'Group',
                    selectedValue: _selectedGroup,
                    items: groupList,
                    onChanged: (v) {
                      setState(() {
                        _selectedGroup = v;
                        _selectedMachine = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSearchableDropdown(
                    label: 'Machine',
                    selectedValue: _selectedMachine,
                    items: machineList,
                    onChanged: (v) {
                      setState(() => _selectedMachine = v);
                    },
                  ),
                ),
              ],
            ),

            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildRiskDropdown(
                        label: "Tần suất phát sinh",
                        value: _freq,
                        items: frequencyOptions,
                        onChanged: (v) => _freq = v,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildRiskDropdown(
                        label: "Khả năng phát sinh",
                        value: _prob,
                        items: probabilityOptions,
                        onChanged: (v) => _prob = v,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildRiskDropdown(
                        label: "Mức độ chấn thương",
                        value: _sev,
                        items: severityOptions,
                        onChanged: (v) => _sev = v,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        enabled: false,
                        controller: TextEditingController(text: "$totalScore"),
                        decoration: InputDecoration(
                          labelText: "Tổng điểm",
                          filled: true,
                          fillColor: Colors.pink.shade200,
                          labelStyle: TextStyle(
                            fontSize: 18,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            TextField(
              onChanged: (v) => _comment = v,
              maxLines: 2,
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
                  Expanded(
                    child: Text(
                      "Cần rà soát lại vấn đề tương tự ở ${_selectedGroup}",
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

            // NÚT GỬI
            // SizedBox(
            //   height: 56,
            //   width: double.infinity,
            //   child: ElevatedButton.icon(
            //     onPressed: imageCount == 0 ? null : _sendReport,
            //     icon: const Icon(Icons.send_rounded),
            //     label: Text(
            //       imageCount == 0
            //           ? 'CHỤP ẢNH ĐỂ GỬI'
            //           : 'GỬI BÁO CÁO ($imageCount ảnh)',
            //       style: const TextStyle(
            //         fontSize: 18,
            //         fontWeight: FontWeight.bold,
            //       ),
            //     ),
            //     style: ElevatedButton.styleFrom(
            //       backgroundColor: imageCount == 0
            //           ? Colors.grey
            //           : Colors.green.shade700,
            //       foregroundColor: Colors.white,
            //       elevation: 8,
            //       shape: RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(16),
            //       ),
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchableDropdown({
    required String label,
    required String? selectedValue,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // THÊM DÒNG NÀY → ĐẶT CHIỀU CAO CỐ ĐỊNH CHO CẢ 3 Ô
        SizedBox(
          height: 64, // hoặc 68 nếu muốn cao hơn chút
          child: DropdownSearch<String>(
            popupProps: const PopupProps.menu(
              showSearchBox: true,
              isFilterOnline: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  hintText: "Tìm kiếm hoặc nhập mới...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
            ),

            asyncItems: (String filter) async {
              var result = items
                  .where((e) => e.toLowerCase().contains(filter.toLowerCase()))
                  .toList();

              if (filter.isNotEmpty && !items.contains(filter.trim())) {
                result.insert(0, filter.trim());
              }
              return result;
            },

            compareFn: (item, selectedItem) =>
                item.trim() == selectedItem.trim(),

            selectedItem: selectedValue,

            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                hintText: label, // hint vẫn giữ nhưng giới hạn 1 dòng
                hintMaxLines: 1,
                floatingLabelBehavior: FloatingLabelBehavior
                    .never, // không đổi vị trí hint khi focus
                isDense: true, // giảm chiều cao mặc định
                filled: true,
                fillColor: Colors.blue.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.blue.shade300,
                    width: 1.5,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ), // height cố định
              ),
            ),

            dropdownBuilder: (context, selectedItem) {
              return Text(
                selectedItem?.isNotEmpty == true ? selectedItem! : "$label",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: selectedItem?.isNotEmpty == true
                      ? Colors.black87
                      : Colors.grey[600],
                ),
              );
            },
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildRiskDropdown({
    required String label,
    required String? value,
    required List<RiskOption> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.blue.shade50,
      ),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e.label,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "(${e.score})",
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        setState(() {
          onChanged(v);
        });
      },
    );
  }
}
