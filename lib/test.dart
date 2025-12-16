import 'dart:convert';
import 'dart:typed_data';
import 'package:chuphinh/take_picture_screen.dart';
import 'package:chuphinh/translator.dart';
import 'package:dio/dio.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'LanguageFlagButton.dart';
import 'api/api_config.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'model/machine_model.dart';
import 'model/reason_model.dart';
import 'api/auto_cmp_api.dart';
import 'model/auto_cmp.dart';

class CameraScreen extends StatefulWidget {
  final String selectedPlant;

  CameraScreen({super.key, required this.selectedPlant});

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
  String _counterMeasure = '';
  bool _needRecheck = false;
  String? _freq;
  String? _prob;
  String? _sev;

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  final TextEditingController _counterController = TextEditingController();
  final FocusNode _counterFocusNode = FocusNode();

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _counterController.dispose();
    _counterFocusNode.dispose();
    super.dispose();
  }

  int get totalScore {
    int f = frequencyOptions
        .firstWhere(
          (e) => e.labelKey == _freq,
          orElse: () => const RiskOption(labelKey: "", score: 0),
        )
        .score;

    int p = probabilityOptions
        .firstWhere(
          (e) => e.labelKey == _prob,
          orElse: () => const RiskOption(labelKey: "", score: 0),
        )
        .score;

    int s = severityOptions
        .firstWhere(
          (e) => e.labelKey == _sev,
          orElse: () => const RiskOption(labelKey: "", score: 0),
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
    Duration duration = const Duration(seconds: 10),
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

  String normalizeGroup(String? group) {
    return group == null ? '' : group.replaceAll(' ', '').trim();
  }

  Future<void> _sendReport() async {
    final images = _cameraKey.currentState?.images ?? [];
    if (images.isEmpty) {
      _showSnackBar('Vui lòng chụp ít nhất 1 ảnh!', Colors.orange);
      return;
    }
    if (_selectedArea == null) {
      _showSnackBar('Vui lòng chọn đủ thông tin!', Colors.orange);
      return;
    }

    if (_comment.trim().isEmpty) {
      _showSnackBar('Vui lòng nhập comment!', Colors.orange);
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
        'group': normalizeGroup(_selectedGroup) ?? '',
        'machine': _selectedMachine ?? '',
        'comment': _comment,
        'countermeasure': _counterMeasure,
        'check': _needRecheck
            ? (_selectedArea != null
                  ? ''.combinedViJa(context, 'needRecheck')
                  : ''.combinedViJa(context, 'needSelectArea'))
            : '',
        'riskFreq': ''.combinedViJa(
          context,
          frequencyOptions
              .firstWhere(
                (e) => e.labelKey == _freq,
                orElse: () => RiskOption(labelKey: '', score: 0),
              )
              .labelKey,
        ),
        'riskProb': ''.combinedViJa(
          context,
          probabilityOptions
              .firstWhere(
                (e) => e.labelKey == _prob,
                orElse: () => RiskOption(labelKey: '', score: 0),
              )
              .labelKey,
        ),

        'riskSev': ''.combinedViJa(
          context,
          severityOptions
              .firstWhere(
                (e) => e.labelKey == _sev,
                orElse: () => RiskOption(labelKey: '', score: 0),
              )
              .labelKey,
        ),

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
        "${ApiConfig.baseUrl}/api/report",
        // "https://doctrinally-preambitious-evia.ngrok-free.dev/api/report",
        data: formData,
        options: Options(sendTimeout: const Duration(seconds: 120)),
      );

      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        _showSnackBar(
          'Successfully sent ${images.length} images!',
          Colors.green,
        );
        _resetForm();
      } else {
        _showSnackBar('Server error: ${response.statusCode}', Colors.red);
      }
    } on DioException catch (e) {
      String msg = 'Error: ';
      if (e.response != null) {
        msg += '${e.response?.statusCode} - ${e.response?.data}';
      } else {
        msg += e.message ?? 'Unknown';
      }
      _showSnackBar(msg, Colors.red);
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  void _resetForm() {
    setState(() {
      _selectedPlant = '612K';
      _selectedMachine = null;
      _comment = '';
      _counterMeasure = '';
      _commentController.clear();
      _counterController.clear();
      _freq = null;
      _prob = null;
      _sev = null;
      _needRecheck = false;
    });
    _cameraKey.currentState?.clearAll(); // xóa hết ảnh
  }

  @override
  void initState() {
    _selectedPlant = widget.selectedPlant;
    super.initState();
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
      // ✅ QUAN TRỌNG: Giúp giao diện tự co lên khi bàn phím hiện
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Row(
          children: [const SizedBox(width: 4), const LanguageToggleSwitch()],
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
                    padding: const EdgeInsets.only(right: 4),
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
            padding: const EdgeInsets.only(right: 4, left: 4),
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
        child: Column(
          children: [
            // CAMERA + GRID ẢNH
            CameraPreviewBox(
              key: _cameraKey,
              size: 340,
              plant: _selectedPlant,
              group: _selectedGroup,
              onImagesChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 8),

            // CÁC DROPDOWN PHÍA TRÊN
            // ... (Giữ nguyên code Dropdown của bạn)
            Row(
              children: [
                Expanded(
                  child: _buildSearchableDropdown(
                    label: "group".tr(context),
                    selectedValue: _selectedGroup,
                    items: groupList,
                    onChanged: (v) {
                      setState(() {
                        _selectedGroup = v;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSearchableDropdown(
                    label: "fac".tr(context),
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
                    label: "area".tr(context),
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
                    label: "machine".tr(context),
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

            // CÁC DROPDOWN RISK
            Row(
              children: [
                Expanded(
                  child: _buildRiskDropdown(
                    labelKey: "label_freq",
                    valueKey: _freq,
                    items: frequencyOptions,
                    onChanged: (v) => _freq = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildRiskDropdown(
                    labelKey: "label_prob",
                    valueKey: _prob,
                    items: probabilityOptions,
                    onChanged: (v) => _prob = v,
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
                    labelKey: "label_sev",
                    valueKey: _sev,
                    items: severityOptions,
                    onChanged: (v) => _sev = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 76,
                    child: TextField(
                      enabled: false,
                      controller: TextEditingController(text: displayScore),
                      decoration: InputDecoration(
                        labelText: "label_risk".tr(context),
                        filled: true,
                        fillColor: Colors.deepOrange.shade100,
                        labelStyle: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.fromLTRB(
                          16,
                          12,
                          16,
                          12,
                        ),
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: (displayScore == "V" || displayScore == "IV")
                            ? Colors.red
                            : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ---------------------------------------------------------
            // PHẦN AUTO COMPLETE ĐÃ TỐI ƯU CHO MOBILE
            // ---------------------------------------------------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ô 1: COMMENT
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return RawAutocomplete<AutoCmp>(
                        textEditingController: _commentController,
                        focusNode: _commentFocusNode,
                        optionsBuilder: (TextEditingValue value) async {
                          if (value.text.length < 2)
                            return const Iterable<AutoCmp>.empty();
                          return await AutoCmpApi.search(value.text);
                        },
                        displayStringForOption: (AutoCmp option) =>
                            option.inputText,
                        onSelected: (AutoCmp selection) {
                          _commentController.text = selection.inputText;
                          _comment = selection.inputText;
                          // LINKING: Tự động điền sang ô Countermeasure
                          if (selection.countermeasure.isNotEmpty) {
                            _counterController.text = selection.countermeasure;
                            _counterMeasure = selection.countermeasure;
                          }
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  hintText: "commentHint".tr(context),
                                  filled: true,
                                  fillColor: Colors.yellow.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.all(
                                    12,
                                  ), // ✅ Tối ưu padding
                                ),
                                onChanged: (v) {
                                  _comment = v;
                                  // CLEARING: Xóa comment thì xóa luôn countermeasure
                                  if (v.trim().isEmpty) {
                                    _counterController.clear();
                                    _counterMeasure = '';
                                  }
                                },
                              );
                            },
                        // ✅ Dùng hàm custom builder tối ưu cho mobile, truyền chiều rộng vào
                        optionsViewBuilder: (context, onSelected, options) =>
                            _customOptionsViewBuilder(
                              context,
                              onSelected,
                              options,
                              constraints.maxWidth,
                            ),
                      );
                    },
                  ),
                ),

                const SizedBox(width: 8),

                // Ô 2: COUNTERMEASURE
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return RawAutocomplete<AutoCmp>(
                        textEditingController: _counterController,
                        focusNode: _counterFocusNode,
                        optionsBuilder: (TextEditingValue value) async {
                          if (value.text.isEmpty) {
                            return const Iterable<AutoCmp>.empty();
                          }
                          if (value.text.length < 2) {
                            return const Iterable<AutoCmp>.empty();
                          }
                          return await AutoCmpApi.searchCounter(value.text);
                        },
                        displayStringForOption: (opt) => opt.inputText,
                        onSelected: (AutoCmp selection) {
                          _counterController.text = selection.inputText;
                          _counterMeasure = selection.inputText;
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  hintText: "counterMeasureHint".tr(context),
                                  filled: true,
                                  fillColor: Colors.yellow.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.all(
                                    12,
                                  ), // ✅ Tối ưu padding
                                ),
                                onChanged: (v) {
                                  _counterMeasure = v;
                                },
                              );
                            },
                        // ✅ Dùng hàm custom builder tối ưu cho mobile
                        optionsViewBuilder: (context, onSelected, options) =>
                            _customOptionsViewBuilder(
                              context,
                              onSelected,
                              options,
                              constraints.maxWidth,
                            ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Checkbox và phần cuối
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
                      "needRecheck".tr(context),
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

            const SizedBox(height: 200),
            // ✅ Thêm khoảng trắng lớn để đẩy nội dung lên khi bàn phím hiện
          ],
        ),
      ),
    );
  }

  // --- BẮT ĐẦU CÁC HÀM PHỤ TRỢ (Cần được đặt ngoài hàm build) ---

  // 🔴 HÀM MỚI: Xây dựng giao diện Dropdown tối ưu cho Mobile
  Widget _customOptionsViewBuilder(
    BuildContext context,
    AutocompleteOnSelected<AutoCmp> onSelected,
    Iterable<AutoCmp> options,
    double width, // Chiều rộng chính xác từ LayoutBuilder
  ) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 8.0, // Đổ bóng
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: width, // Rộng bằng đúng ô input
            maxHeight: 200, // ✅ Giới hạn chiều cao quan trọng
          ),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, thickness: 0.5),
            itemBuilder: (BuildContext context, int index) {
              final AutoCmp option = options.elementAt(index);
              return InkWell(
                onTap: () => onSelected(option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ), // Tăng vùng chạm
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.inputText,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Có thể hiển thị thêm thông tin liên quan
                      // if (option.note?.isNotEmpty == true) ...[
                      //   const SizedBox(height: 4),
                      //   Text(
                      //     option.note!,
                      //     style: TextStyle(
                      //       fontSize: 12,
                      //       color: Colors.grey[600],
                      //     ),
                      //     maxLines: 1,
                      //     overflow: TextOverflow.ellipsis,
                      //   ),
                      // ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // 🔴 HÀM PHỤ TRỢ: _buildSearchableDropdown (Giữ nguyên)
  Widget _buildSearchableDropdown({
    required String label,
    required String? selectedValue,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          child: DropdownSearch<String>(
            popupProps: PopupProps.menu(
              showSearchBox: true,
              isFilterOnline: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  hintText: "search_or_add_new".tr(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
            ),
            // ... (các logic asyncItems, compareFn, v.v. giữ nguyên)
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
                hintText: label,
                hintMaxLines: 1,
                floatingLabelBehavior: FloatingLabelBehavior.never,
                isDense: true,
                filled: true,
                fillColor: Colors.blue.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.blue.shade300,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              ),
            ),

            dropdownBuilder: (context, selectedItem) {
              return Text(
                selectedItem?.isNotEmpty == true ? selectedItem! : "$label",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
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

  // 🔴 HÀM PHỤ TRỢ: _buildRiskDropdown (Giữ nguyên)
  Widget _buildRiskDropdown({
    required String labelKey,
    required String? valueKey,
    required List<RiskOption> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: valueKey,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: labelKey.tr(context),
        filled: true,
        fillColor: Colors.deepOrange.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      ),
      selectedItemBuilder: (context) {
        return items.map((e) {
          return Container(
            alignment: Alignment.centerLeft,
            child: Text(
              e.labelKey.tr(context),
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: Colors.black,
              ),
            ),
          );
        }).toList();
      },

      items: items.map((e) {
        return DropdownMenuItem<String>(
          value: e.labelKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.labelKey.tr(context),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "(${e.score})",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      }).toList(),

      onChanged: (v) => setState(() => onChanged(v)),
    );
  }
}
