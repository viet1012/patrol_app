import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:chuphinh/camera_preview_box.dart';
import 'package:chuphinh/translator.dart';
import 'package:chuphinh/widget/glass_action_button.dart';
import 'package:dio/dio.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api/api_config.dart';
import 'homeScreen/patrol_home_screen.dart';
import 'model/hse_patrol_team_model.dart';
import 'model/machine_model.dart';
import 'model/reason_model.dart';
import 'api/auto_cmp_api.dart';
import 'model/auto_cmp.dart';
import 'dart:async';

class CameraScreen extends StatefulWidget {
  final List<MachineModel> machines;
  final List<HsePatrolTeamModel> patrolTeams;

  final String? selectedPlant;
  final String lang;

  final PatrolGroup patrolGroup;
  final String titleScreen;

  const CameraScreen({
    super.key,
    required this.machines,
    required this.patrolTeams,
    required this.selectedPlant,
    required this.titleScreen,
    required this.lang,
    required this.patrolGroup,
  });

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

  TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  TextEditingController _counterController = TextEditingController();
  final FocusNode _counterFocusNode = FocusNode();

  Timer? _commentDebounce;
  Timer? _counterDebounce;

  @override
  void dispose() {
    _commentDebounce?.cancel();
    _counterDebounce?.cancel();
    _commentFocusNode.dispose();
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

  List<String> getGroupsByPlant() {
    return widget.patrolTeams
        .where((e) => e.plant == widget.selectedPlant)
        .map((e) => e.grp)
        .whereType<String>()
        .toSet() // tránh trùng
        .toList();
  }

  List<String> getPlants() {
    final Set<String> unique = {};
    return widget.machines
        .map((m) => m.plant.toString())
        .where((p) => p.isNotEmpty)
        .where((p) => unique.add(p))
        .toList();
  }

  List<String> getFacByPlant(String plant) {
    final Set<String> unique = {};
    return widget.machines
        .where((m) => m.plant.toString() == plant)
        .map((m) => m.fac.toString())
        .where((f) => f.isNotEmpty)
        .where((f) => unique.add(f))
        .toList();
  }

  List<String> getAreaByFac(String plant, String fac) {
    final Set<String> unique = {};
    return widget.machines
        .where((m) => m.plant.toString() == plant)
        .where((m) => m.fac.toString() == fac)
        .map((m) => m.area.toString())
        .where((a) => a.isNotEmpty)
        .where((a) => unique.add(a))
        .toList();
  }

  List<String> getMachineByArea(String plant, String fac, String area) {
    final Set<String> unique = {};
    return widget.machines
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
      _showSnackBar('Please take at least one photo.', Colors.orange);
      return;
    }

    if (_selectedMachine == null) {
      _showSnackBar('Please select all required information.', Colors.orange);
      return;
    }

    if (_comment.trim().isEmpty) {
      _showSnackBar('Please enter a comment.', Colors.orange);
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
        'type': widget.patrolGroup.name,
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

  double _fontSize = 14;

  void _autoFont(String text) {
    setState(() {
      if (text.length > 120) {
        _fontSize = 11;
      } else if (text.length > 80)
        _fontSize = 12;
      else if (text.length > 40)
        _fontSize = 13;
      else
        _fontSize = 14;
    });
    // print("length: ${text.length} +_fontSize: ${_fontSize}");
  }

  void _resetForm() {
    setState(() {
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
    _loadInitialDataComment();
    _loadInitialDataCounter();
  }

  @override
  Widget build(BuildContext context) {
    // print('Lang: ${widget.patrolGroup.name}');
    final plantList = getPlants();
    final groupList = getGroupsByPlant();

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
    final minLength = (widget.lang == 'JP') ? 1 : 2;

    return Scaffold(
      // backgroundColor: Colors.blueGrey.shade200,

      // ✅ QUAN TRỌNG: Giúp giao diện tự co lên khi bàn phím hiện
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Color(0xFF121826), // soft dark blue
        centerTitle: false,
        titleSpacing: 4, // 👈 kéo sát về leading
        leading: GlassActionButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.titleScreen,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.selectedPlant}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
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
                            width: 50,
                            height: 50,
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
          GlassActionButton(
            icon: Icons.send_rounded,
            enabled: hasImages,
            onTap: hasImages ? _sendReport : null,
            backgroundColor: hasImages ? const Color(0xFF22C55E) : null,
            iconColor: hasImages ? Colors.black : Colors.white,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF121826), // soft dark blue
              Color(0xFF1F2937), // slate blue
              Color(0xFF374151), // soft steel
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              // CAMERA + GRID ẢNH
              CameraPreviewBox(
                key: _cameraKey,
                size: 340,
                plant: _selectedPlant,
                type: widget.patrolGroup.name,
                group: _selectedGroup,
                onImagesChanged: (_) => setState(() {}),
                patrolGroup: widget.patrolGroup,
              ),

              const SizedBox(height: 16),

              // CÁC DROPDOWN PHÍA TRÊN
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

                          final areas = getAreaByFac(_selectedPlant!, v!);
                          if (areas.length == 1) {
                            _selectedArea = areas.first;

                            final machines = getMachineByArea(
                              _selectedPlant!,
                              v,
                              areas.first,
                            );
                            if (machines.length == 1) {
                              _selectedMachine = machines.first;
                            }
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

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

                          final machines = getMachineByArea(
                            _selectedPlant!,
                            _selectedFac!,
                            v!,
                          );
                          if (machines.length == 1) {
                            _selectedMachine = machines.first;
                          }
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

              const SizedBox(height: 8),

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
                      child: TextField(
                        enabled: false,
                        controller: TextEditingController(text: displayScore),
                        decoration: InputDecoration(
                          labelText: "label_risk".tr(context),

                          /// 🎨 nền hiển thị
                          filled: true,
                          fillColor: Colors.deepOrange.withOpacity(0.15),

                          /// 🏷️ label
                          labelStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.65),
                            fontWeight: FontWeight.w500,
                          ),

                          floatingLabelStyle: const TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.bold,
                          ),

                          /// 🔲 viền
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.deepOrange.withOpacity(0.6),
                            ),
                          ),

                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: (displayScore == "V" || displayScore == "IV")
                              ? Colors.red
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

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
                        return Autocomplete<AutoCmp>(
                          optionsViewOpenDirection: OptionsViewOpenDirection.up,
                          optionsBuilder: (TextEditingValue value) {
                            if (value.text.length < minLength || isLoading) {
                              return const Iterable<AutoCmp>.empty();
                            }

                            // FILTER TRỰC TIẾP TẠI ĐÂY
                            return allOptionsComment
                                .where((AutoCmp option) {
                                  return option.inputText
                                      .toLowerCase()
                                      .contains(
                                        value.text.toLowerCase(),
                                      ); // Tìm kiếm không phân biệt hoa thường
                                })
                                .take(
                                  5,
                                ); // Chỉ lấy 5 kết quả đầu tiên giống như logic cũ của BE
                          },
                          displayStringForOption: (option) => option.inputText,
                          onSelected: (AutoCmp selection) {
                            // Khi CHỌN gợi ý → điền vào comment

                            _commentController.text = selection.inputText;
                            _commentController
                                .selection = TextSelection.fromPosition(
                              TextPosition(offset: selection.inputText.length),
                            ); // Đưa con trỏ ra cuối
                            _comment = selection.inputText;
                            _autoFont(_comment);

                            // === TỰ ĐỘNG ĐIỀN COUNTERMEASURE NẾU CÓ ===
                            if (selection.countermeasure.isNotEmpty) {
                              _counterController.text =
                                  selection.countermeasure;
                              _counterMeasure = selection.countermeasure;
                            } else {
                              // Nếu không có countermeasure → để trống (tùy yêu cầu)
                              _counterController.clear();
                              _counterMeasure = '';
                            }
                          },
                          fieldViewBuilder:
                              (
                                context,
                                controller,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                _commentController = controller;
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  maxLines: 3,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: _fontSize,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "commentHint".tr(context),
                                    filled: true,
                                    fillColor: Colors.green.withOpacity(0.08),
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(.6),
                                      fontSize: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Colors.white.withOpacity(0.35),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Color(
                                          0xFF90E14D,
                                        ).withOpacity(0.25),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Color(
                                          0xFF90E14D,
                                        ).withOpacity(.45), // cyan
                                      ),
                                    ),

                                    contentPadding: const EdgeInsets.all(12),
                                  ),
                                  onChanged: (v) {
                                    _comment = v;
                                    _autoFont(v);

                                    // Debounce search
                                    if (_commentDebounce?.isActive ?? false) {
                                      _commentDebounce!.cancel();
                                    }

                                    // === KHI XÓA HẾT COMMENT → XÓA LUÔN COUNTERMEASURE ===
                                    if (v.trim().isEmpty) {
                                      _counterController.clear();
                                      _counterMeasure = '';
                                    }
                                  },
                                );
                              },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Transform.translate(
                                offset: const Offset(0, 8), // Sát ô, đẹp đều
                                child: Material(
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.black.withOpacity(.5),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth,
                                      maxHeight: 220,
                                    ),
                                    child: ListView.separated(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(
                                            height: 1,
                                            thickness: 0.5,
                                          ),
                                      itemBuilder: (context, index) {
                                        final option = options.elementAt(index);
                                        return InkWell(
                                          onTap: () => onSelected(option),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            child: Text(
                                              option.inputText,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Ô 2: COUNTERMEASURE (giữ nguyên, không cần linking ngược)
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Autocomplete<AutoCmp>(
                          optionsViewOpenDirection: OptionsViewOpenDirection.up,
                          optionsBuilder: (TextEditingValue value) {
                            if (value.text.length < minLength || isLoading) {
                              return const Iterable<AutoCmp>.empty();
                            }

                            return allOptionsCounter
                                .where((AutoCmp option) {
                                  return option.inputText
                                      .toLowerCase()
                                      .contains(
                                        value.text.toLowerCase(),
                                      ); // Tìm kiếm không phân biệt hoa thường
                                })
                                .take(
                                  5,
                                ); // Chỉ lấy 5 kết quả đầu tiên giống như logic cũ của BE
                          },
                          displayStringForOption: (option) => option.inputText,
                          onSelected: (AutoCmp selection) {
                            _counterController.text = selection.inputText;

                            _counterController
                                .selection = TextSelection.fromPosition(
                              TextPosition(offset: selection.inputText.length),
                            );
                            _counterMeasure = selection.inputText;
                            _autoFont(_counterMeasure);
                          },
                          fieldViewBuilder:
                              (
                                context,
                                controller,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                _counterController = controller;
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  maxLines: 3,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: _fontSize,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "counterMeasureHint".tr(context),
                                    filled: true,
                                    fillColor: Colors.green.withOpacity(0.08),
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(.6),
                                      fontSize: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Colors.white.withOpacity(0.35),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Color(
                                          0xFF90E14D,
                                        ).withOpacity(0.25),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Color(
                                          0xFF90E14D,
                                        ).withOpacity(.45), // cyan
                                      ),
                                    ),

                                    contentPadding: const EdgeInsets.all(12),
                                  ),
                                  onChanged: (v) {
                                    _counterMeasure = v;
                                    _autoFont(v);

                                    if (_counterDebounce?.isActive ?? false) {
                                      _counterDebounce!.cancel();
                                    }
                                  },
                                );
                              },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Transform.translate(
                                offset: const Offset(0, 8),
                                child: Material(
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.black.withOpacity(.5),

                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth,
                                      maxHeight: 220,
                                    ),
                                    child: ListView.separated(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(
                                            height: 1,
                                            thickness: 0.5,
                                          ),
                                      itemBuilder: (context, index) {
                                        final option = options.elementAt(index);
                                        return InkWell(
                                          onTap: () => onSelected(option),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            child: Text(
                                              option.inputText,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
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

              // const SizedBox(height: 200),
              // ✅ Thêm khoảng trắng lớn để đẩy nội dung lên khi bàn phím hiện
            ],
          ),
        ),
      ),
    );
  }

  List<AutoCmp> allOptionsComment = []; // Biến lưu trữ dữ liệu
  List<AutoCmp> allOptionsCounter = []; // Biến lưu trữ dữ liệu
  bool isLoading = true;

  Future<void> _loadInitialDataComment() async {
    try {
      final data = await AutoCmpApi.getAllComment(widget.lang);
      setState(() {
        allOptionsComment = data;
        isLoading = false;
      });
    } catch (e) {
      // Xử lý lỗi
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadInitialDataCounter() async {
    try {
      final data = await AutoCmpApi.getAllCounter(widget.lang);
      setState(() {
        allOptionsCounter = data;
        isLoading = false;
      });
    } catch (e) {
      // Xử lý lỗi
      setState(() => isLoading = false);
    }
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
              fit: FlexFit.loose,
              menuProps: MenuProps(
                backgroundColor: const Color(0xFF161D23),
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),

              /// 🔴 NO DATA FOUND CUSTOM
              emptyBuilder: (context, searchEntry) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 40,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "No data found", // hoặc "No data found"
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  hintText: "search_or_add_new".tr(context),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              itemBuilder: (context, item, isSelected) {
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected
                        ? Colors.white.withOpacity(0.12)
                        : Colors.transparent,
                  ),
                  child: AutoSizeText(
                    item,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                );
              },
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

                /// 🌫️ nền glass
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.35)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: const Color(0xFF4DD0E1).withOpacity(0.45),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFF4DD0E1), // cyan
                    width: 1.6,
                  ),
                ),

                contentPadding: const EdgeInsets.fromLTRB(12, 14, 12, 12),

                /// 📝 hint
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ),

            dropdownBuilder: (context, selectedItem) {
              return AutoSizeText(
                selectedItem?.isNotEmpty == true ? selectedItem! : label,
                maxLines: 2,
                minFontSize: 11,
                stepGranularity: 0.5,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selectedItem?.isNotEmpty == true
                      ? FontWeight.bold
                      : FontWeight.w500,
                  color: selectedItem?.isNotEmpty == true
                      ? Colors.white
                      : Colors.white.withOpacity(0.6),
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
      dropdownColor: const Color(0xFF2A2E32), // nền dropdown

      decoration: InputDecoration(
        labelText: labelKey.tr(context),

        /// 🌫️ nền mờ
        filled: true,
        fillColor: Colors.orange.withOpacity(0.08),

        /// 🔲 viền
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.35),
            width: 1.2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: const Color(0xFF7986CB).withOpacity(0.45),
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7986CB), width: 1.8),
        ),

        contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 14),

        /// 📝 label bình thường
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.65),
          fontSize: 14,
        ),

        /// 🏷️ label khi bay lên
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF7986CB),
          fontWeight: FontWeight.bold,
        ),
      ),

      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
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
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }).toList();
      },

      items: items.map((e) {
        return DropdownMenuItem<String>(
          value: e.labelKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.labelKey.tr(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                "(${e.score})",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }).toList(),

      onChanged: (v) => setState(() => onChanged(v)),
    );
  }
}
