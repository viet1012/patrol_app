import 'dart:convert';
import 'dart:typed_data';
import 'package:chuphinh/take_picture_screen.dart';
import 'package:dio/dio.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'model/machine_model.dart';
import 'model/reason_model.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  String? _selectedPlant;
  String? _selectedFac;
  String? _selectedArea;
  String? _selectedMachine;
  String? _selectedGroup;
  int numbersGroup = 7;

  String _comment = '';
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

    return f + p + s;
  }

  String getScoreSymbol() {
    // Nếu chưa chọn đủ 3 thì trả về rỗng
    if (_freq == null || _prob == null || _sev == null) {
      return "";
    }

    final score = totalScore;

    if (score >= 16) return "V";
    if (score >= 12) return "IV";
    if (score >= 9) return "III";
    if (score >= 6) return "II";
    if (score >= 3) return "I";
    return "-";
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

  List<String> get groupList =>
      List.generate(numbersGroup, (index) => 'Group ${index + 1}');

  List<String> getPlants() {
    final Set<String> unique = {};
    return machines
        .map((m) => m.plant.toString())
        .where((p) => p.isNotEmpty)
        .where((p) => unique.add(p))
        .toList();
  }

  List<String> getFacByPlant(String plant) {
    final Set<String> unique = {};
    return machines
        .where((m) => m.plant.toString() == plant)
        .map((m) => m.fac.toString())
        .where((f) => f.isNotEmpty)
        .where((f) => unique.add(f))
        .toList();
  }

  List<String> getAreaByFac(String plant, String fac) {
    final Set<String> unique = {};
    return machines
        .where((m) => m.plant.toString() == plant)
        .where((m) => m.fac.toString() == fac)
        .map((m) => m.area.toString())
        .where((a) => a.isNotEmpty)
        .where((a) => unique.add(a))
        .toList();
  }

  List<String> getMachineByArea(String plant, String fac, String area) {
    final Set<String> unique = {};
    return machines
        .where((m) => m.plant.toString() == plant)
        .where((m) => m.fac.toString() == fac)
        .where((m) => m.area.toString() == area)
        .map((m) => m.macId.toString())
        .where((id) => id.isNotEmpty)
        .where((id) => unique.add(id))
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
    if (_selectedArea == null) {
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
      final reportMap = {
        'plant': _selectedPlant ?? '',
        'division': _selectedFac ?? '',
        'area': _selectedArea ?? '',
        'group': _selectedGroup ?? '',
        'machine': _selectedMachine ?? '',
        'comment': _comment,
        'check': _needRecheck ? 'Kiểm tra lỗi tương tự' : '',
        'riskFreq': _freq ?? '',
        'riskProb': _prob ?? '',
        'riskSev': _sev ?? '',
        'riskTotal': getScoreSymbol(),
      };

      // In ra dữ liệu report JSON
      print('Report JSON: ${jsonEncode(reportMap)}');
      print('Số ảnh gửi lên server: ${imageFiles.length}');
      for (int i = 0; i < imageFiles.length; i++) {
        print(
          'Ảnh ${i + 1}: filename=${imageFiles[i].filename}, kích thước=${imageFiles[i].length} bytes',
        );
      }

      final formData = FormData.fromMap({
        'report': jsonEncode(reportMap),
        'images': imageFiles,
      });

      dio.options.headers['ngrok-skip-browser-warning'] = 'true';

      final response = await dio.post(
        // "http://localhost:9299/api/report",
        "https://doctrinally-preambitious-evia.ngrok-free.dev/api/report",
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
      _selectedPlant = '612K';
      _selectedMachine = null;
      _comment = '';
      _freq = null;
      _prob = null;
      _sev = null;
      _needRecheck = false;
    });
    _cameraKey.currentState?.clearAll(); // xóa hết ảnh
  }

  @override
  Widget build(BuildContext context) {
    final plantList = getPlants();

    final facList = _selectedPlant == null
        ? []
        : getFacByPlant(_selectedPlant!);

    final areaList = _selectedPlant == null || _selectedFac == null
        ? []
        : getAreaByFac(_selectedPlant!, _selectedFac!);

    final machineList =
        _selectedPlant == null || _selectedFac == null || _selectedArea == null
        ? []
        : getMachineByArea(_selectedPlant!, _selectedFac!, _selectedArea!);

    final imageCount = _cameraKey.currentState?.images.length ?? 0;
    final hasImages = imageCount > 0;
    final images = _cameraKey.currentState?.images ?? [];

    final symbol = getScoreSymbol();
    final displayScore = symbol.isEmpty ? "" : symbol;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Ô CHỌN GROUP TRÊN APPBAR
            SizedBox(
              width: 130,
              child: _buildSearchableDropdown(
                label: 'Group',
                selectedValue: _selectedGroup,
                items: groupList,
                onChanged: (v) {
                  setState(() {
                    _selectedGroup = v;
                  });
                },
              ),
            ),
          ],
        ),
        actions: [
          // HIỂN THỊ ẢNH THUMBNAIL TRÊN APPBAR
          if (images.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: images.asMap().entries.map((entry) {
                  int idx = entry.key;
                  Uint8List img = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            img,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: GestureDetector(
                            onTap: () =>
                                _cameraKey.currentState?.removeImage(idx),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // NÚT GỬI + BADGE SỐ ẢNH
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: Stack(
              children: [
                FloatingActionButton(
                  mini: true,
                  backgroundColor: hasImages ? Colors.green : Colors.grey,
                  onPressed: hasImages ? _sendReport : null,
                  child: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1D1E26), Color(0xFF23242F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              // CAMERA + GRID ẢNH
              CameraPreviewBox(
                key: _cameraKey,
                size: 340,
                onImagesChanged: (_) =>
                    setState(() {}), // cập nhật số lượng ảnh
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: _buildSearchableDropdown(
                      label: 'Plant',
                      selectedValue: _selectedPlant,
                      items: plantList.cast<String>(),
                      onChanged: (v) {
                        setState(() {
                          _selectedPlant = v;
                          _selectedFac = null;
                          _selectedArea = null;
                          _selectedMachine = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSearchableDropdown(
                      label: 'Fac',
                      selectedValue: _selectedFac,
                      items: _selectedPlant == null
                          ? <String>[]
                          : facList.cast<String>(),
                      onChanged: (v) {
                        setState(() {
                          _selectedFac = v;
                          _selectedArea = null;
                          _selectedMachine = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildSearchableDropdown(
                      label: 'Area',
                      selectedValue: _selectedArea,
                      items: (_selectedPlant == null || _selectedFac == null)
                          ? <String>[]
                          : areaList.cast<String>(),
                      onChanged: (v) {
                        setState(() {
                          _selectedArea = v;
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
                      items:
                          (_selectedPlant == null ||
                              _selectedFac == null ||
                              _selectedArea == null)
                          ? <String>[]
                          : machineList.cast<String>(),
                      onChanged: (v) {
                        setState(() => _selectedMachine = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildRiskDropdown(
                      label: "Tần suất phát sinh",
                      value: _freq,
                      items: frequencyOptions,
                      onChanged: (v) => _freq = v,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      // height: 76,
                      child: _buildRiskDropdown(
                        label: "Khả năng phát sinh",
                        value: _prob,
                        items: probabilityOptions,
                        onChanged: (v) => _prob = v,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    child: SizedBox(
                      height: 76,
                      child: TextField(
                        enabled: false,
                        controller: TextEditingController(text: displayScore),
                        decoration: InputDecoration(
                          labelText: "Mức độ rủi ro",
                          filled: true,
                          fillColor: Colors.deepOrange.shade100,
                          labelStyle: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: EdgeInsets.fromLTRB(
                            16,
                            12,
                            16,
                            12,
                          ), // giữ đều padding
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

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
                        _selectedArea != null
                            ? "Cần rà soát lại vấn đề tương tự ở $_selectedArea"
                            : "Chưa chọn khu vực",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
          // height: 50, // hoặc 68 nếu muốn cao hơn chút
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

            selectedItem: selectedValue ?? '',

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
    return SizedBox(
      // height: 50, // ← CHÌA KHÓA VÀNG: cố định chiều cao 3 ô bằng nhau
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.deepOrange.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue, width: 2),
          ),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        ),

        selectedItemBuilder: (context) {
          return items.map((e) {
            return Container(
              alignment: Alignment.centerLeft,
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13.5, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: e.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.visible,
              ),
            );
          }).toList();
        },

        items: items.map((e) {
          return DropdownMenuItem<String>(
            value: e.label,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.label,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    "(${e.score})",
                    style: TextStyle(
                      color: Colors.blueGrey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),

        onChanged: (v) {
          setState(() {
            onChanged(v);
          });
        },
        isDense: false,
      ),
    );
  }

  Widget _buildRiskDropdown12({
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
        fillColor: Colors.deepOrange.shade50,
      ),

      selectedItemBuilder: (context) {
        return items.map((e) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "${e.label}",
              maxLines: 2,
              overflow: TextOverflow.visible,
              style: const TextStyle(fontSize: 12),
            ),
          );
        }).toList();
      },

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
