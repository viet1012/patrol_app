import 'package:auto_size_text/auto_size_text.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/patrol_report_api.dart';
import '../common/common_ui_helper.dart';
import '../common/due_date_utils.dart';
import '../homeScreen/patrol_home_screen.dart';
import '../model/machine_model.dart';
import '../model/patrol_report_model.dart';
import '../translator.dart';
import '../widget/error_display.dart';
import '../widget/glass_action_button.dart';
import 'after_detail_page.dart';

class AfterDetailScreen extends StatefulWidget {
  final String accountCode;
  final List<MachineModel> machines;
  final String? selectedPlant;
  final String titleScreen;
  final PatrolGroup patrolGroup;

  const AfterDetailScreen({
    super.key,
    required this.machines,
    required this.selectedPlant,
    required this.titleScreen,
    required this.patrolGroup,
    required this.accountCode,
  });

  @override
  State<AfterDetailScreen> createState() => _AfterDetailScreenState();
}

class _AfterDetailScreenState extends State<AfterDetailScreen> {
  String? _selectedPlant;
  String? selectedPIC;

  String? _filterArea;
  String? _filterRisk;

  Future<List<PatrolReportModel>>? _futureReport;
  Future<List<String>>? _futurePics;

  // List<String> findPicsByPlant(String plant) {
  //   final Set<String> unique = {};
  //
  //   return widget.machines
  //       .where((m) => m.plant.toString() == plant)
  //       .map((m) => m.pic.toString())
  //       .where((f) => f.isNotEmpty)
  //       .where((f) => unique.add(f))
  //       .toList();
  // }

  // Future<List<String>> findPicsByPlantFromApi(String plant) async {
  //   final reports = await PatrolReportApi.fetchReports(plant: plant);
  //   print("Count: ${reports.length}");
  //   final Set<String> uniquePics = {};
  //
  //   final pics = reports
  //       .map(
  //         (r) => r.pic?.trim() ?? '',
  //       ) // giả sử PatrolReportModel có trường pic
  //       .where((pic) => pic.isNotEmpty)
  //       .where((pic) => uniquePics.add(pic))
  //       .toList();
  //
  //   return pics;
  // }
  Future<List<String>> findPicsByPlantFromApi(String plant) async {
    debugPrint('🔍 Fetch reports for plant = [$plant]');

    final reports = await PatrolReportApi.fetchReports(plant: plant);
    debugPrint('📦 Total reports: ${reports.length}');

    const emptyLabel = 'UNKNOWN'; // 👈 nhãn cho PIC rỗng

    final Set<String> uniquePics = {};
    final List<String> pics = [];

    for (final r in reports) {
      final rawPic = r.pic?.trim();
      final pic = (rawPic == null || rawPic.isEmpty) ? emptyLabel : rawPic;

      if (uniquePics.add(pic)) {
        pics.add(pic);
      }
    }

    debugPrint('🎯 Unique PIC count: ${pics.length}');
    debugPrint('📋 PIC LIST: $pics');

    return pics;
  }

  int _riskToScore(String risk) {
    switch (risk) {
      case 'V':
        return 5;
      case 'IV':
        return 4;
      case 'III':
        return 3;
      case 'II':
        return 2;
      case 'I':
        return 1;
      default:
        return 0;
    }
  }

  Color _riskColor(String risk) {
    switch (risk) {
      case 'V':
        return Colors.red;
      case 'IV':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  void _loadReport() {
    if (selectedPIC == null || widget.selectedPlant == null) return;

    const emptyLabel = 'UNKNOWN';
    final picFilter = (selectedPIC == emptyLabel) ? '' : selectedPIC!.trim();

    debugPrint('?? SELECTED PIC UI="$selectedPIC" | API pic="$picFilter"');

    setState(() {
      _futureReport = PatrolReportApi.fetchReports(
        plant: widget.selectedPlant!,
        type: widget.patrolGroup.name,
        pic: picFilter,
        afStatus: 'Wait,Redo',
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedPlant = widget.selectedPlant;

    if (_selectedPlant != null) {
      _futurePics = findPicsByPlantFromApi(_selectedPlant!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121826),
        centerTitle: false,
        titleSpacing: 4, // 👈 kéo sát về leading
        leading: GlassActionButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            SizedBox(
              width: 140,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '[After] ${widget.titleScreen}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.selectedPlant}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Spacer(),
            Expanded(
              child: _selectedPlant == null
                  ? _buildSearchableDropdown(
                      label: "PIC",
                      selectedValue: selectedPIC,
                      items: const [],
                      onChanged: (v) {
                        setState(() {
                          selectedPIC = v;
                        });
                        _loadReport();
                      },
                    )
                  : FutureBuilder<List<String>>(
                      future: _futurePics,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Text(
                            'Server error',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          );
                        }

                        final picList = snapshot.data ?? [];
                        return _buildSearchableDropdown(
                          label: "PIC",
                          selectedValue: selectedPIC,
                          items: picList,
                          onChanged: (v) {
                            setState(() => selectedPIC = v);
                            _loadReport();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF121826), Color(0xFF1F2937), Color(0xFF374151)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: _futureReport == null
                ? ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height,
                    ),
                    child: Center(
                      child: Text(
                        'Please select PIC!',
                        style: TextStyle(color: Colors.grey, fontSize: 25),
                      ),
                    ),
                  )
                : FutureBuilder<List<PatrolReportModel>>(
                    future: _futureReport,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return ErrorDisplay(
                          errorMessage: snapshot.error.toString(),
                          onRetry: () {
                            _loadReport();
                          },
                        );
                      }

                      /// ❗ API OK nhưng không có data
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            textAlign: TextAlign.center,
                            'No data available',
                            style: TextStyle(color: Colors.grey, fontSize: 25),
                          ),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, c) {
                          return Column(
                            children: [
                              _buildFilterHeader(
                                snapshot.data!
                                    .map((e) => e.area)
                                    .toSet()
                                    .toList(),
                              ),
                              const SizedBox(height: 8),
                              _buildReportTable(snapshot.data!, c.maxWidth),
                            ],
                          );
                        },
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterHeader(List<String> areas) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSearchableDropdown(
              label: "area".tr(context),
              selectedValue: _filterArea,
              items: areas,
              onChanged: (v) => setState(() => _filterArea = v),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: _buildSearchableDropdown(
              label: "label_risk".tr(context),
              selectedValue: _filterRisk,
              items: const ['V', 'IV', 'III', 'II', 'I'],
              onChanged: (v) {
                setState(() {
                  _filterRisk = v?.isEmpty == true ? null : v;
                });
              },
            ),
          ),
          const SizedBox(width: 12),

          GlassActionButton(
            icon: Icons.filter_alt_off,
            onTap: () {
              setState(() {
                _filterArea = null;
                _filterRisk = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReportTable(List<PatrolReportModel> list, double maxWidth) {
    final filtered =
        list.where((r) {
          if (_filterArea != null && r.area != _filterArea) return false;
          if (_filterRisk != null && r.riskTotal != _filterRisk) return false;
          return true;
        }).toList()..sort((a, b) {
          // 1️⃣ So sánh risk trước
          final riskCompare = _riskToScore(
            b.riskTotal,
          ).compareTo(_riskToScore(a.riskTotal));
          if (riskCompare != 0) return riskCompare;

          // 2️⃣ Cùng risk → so sánh dueDate
          final now = DateTime.now();

          final aDue = a.dueDate;
          final bDue = b.dueDate;

          // null xuống cuối
          if (aDue == null && bDue == null) return 0;
          if (aDue == null) return 1;
          if (bDue == null) return -1;

          final aOverdue = aDue.isBefore(now);
          final bOverdue = bDue.isBefore(now);

          // Trễ hạn lên trước
          if (aOverdue && !bOverdue) return -1;
          if (!aOverdue && bOverdue) return 1;

          // Cùng trạng thái → cái nào gần hôm nay hơn thì lên
          final aDiff = (aDue.difference(now)).abs();
          final bDiff = (bDue.difference(now)).abs();

          return aDiff.compareTo(bDiff);
        });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: maxWidth),
        child: DataTable(
          columnSpacing: 16,
          headingRowHeight: 46,
          dataRowHeight: 52,
          headingRowColor: MaterialStateProperty.all(
            Colors.white.withOpacity(0.10),
          ),
          headingTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),

          columns: const [
            DataColumn(label: Text('No')),
            DataColumn(label: Text('Area')),
            DataColumn(label: Text('Machine')),
            DataColumn(label: Text('Risk')),
            DataColumn(label: Text('Deadline')),
            DataColumn(label: Text('Details')),
          ],
          rows: filtered.map((r) {
            final color = _riskColor(r.riskTotal);
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    r.stt.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                DataCell(
                  Text(
                    r.area,
                    style: TextStyle(color: Colors.white.withOpacity(0.85)),
                  ),
                ),
                DataCell(
                  Text(
                    r.machine,
                    style: TextStyle(color: Colors.white.withOpacity(0.85)),
                  ),
                ),
                DataCell(
                  Center(
                    child: Text(
                      r.riskTotal,
                      style: TextStyle(
                        color: color.withOpacity(0.85),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                DataCell(
                  Text(
                    r.dueDate == null
                        ? '-'
                        : DateFormat('M/d/yy').format(r.dueDate!),
                    style: TextStyle(
                      color: DueDateUtils.getDueDateColor(r.dueDate),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                DataCell(
                  Row(
                    children: [
                      GlassActionButton(
                        icon: Icons.visibility_rounded,
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AfterDetailPage(
                                accountCode: widget.accountCode,
                                report: r,
                                patrolGroup: widget.patrolGroup,
                              ),
                            ),
                          );
                          if (result == true) {
                            _loadReport();
                          }
                        },
                      ),
                      Text(
                        r.atStatus.toString(),
                        style: TextStyle(
                          color: DueDateUtils.getDueDateColor(r.dueDate),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
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
        SizedBox(
          child: DropdownSearch<String>(
            popupProps: PopupProps.menu(
              showSearchBox: true,
              isFilterOnline: true,
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
                style: TextStyle(
                  color: Colors.white, // <-- set màu chữ nhập thành trắng
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
                    maxLines: 1,
                    minFontSize: 11,
                    stepGranularity: 0.5,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
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

              // // Nếu filter không rỗng và chưa có trong items thì thêm vào đầu danh sách
              // if (filter.isNotEmpty && !items.contains(filter.trim())) {
              //   result.insert(0, filter.trim());
              // }
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
                maxLines: 1,
                minFontSize: 11,
                maxFontSize: 14,
                stepGranularity: 0.5,
                overflow: TextOverflow.visible,
                style: TextStyle(
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
}
