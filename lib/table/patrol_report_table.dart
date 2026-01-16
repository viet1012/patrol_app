import 'package:chuphinh/common/common_ui_helper.dart';
import 'package:chuphinh/homeScreen/patrol_home_screen.dart';
import 'package:chuphinh/table/patrol_images_dialog.dart';
import 'package:flutter/material.dart';
import '../api/api_config.dart';
import '../api/patrol_report_api.dart';
import '../model/patrol_report_model.dart';
import '../widget/glass_action_button.dart';

class PatrolReportTable extends StatefulWidget {
  final PatrolGroup patrolGroup;
  const PatrolReportTable({super.key, required this.patrolGroup});

  @override
  State<PatrolReportTable> createState() => _PatrolReportTableState();
}

class _PatrolReportTableState extends State<PatrolReportTable> {
  late Future<List<PatrolReportModel>> _futureReports;

  final ScrollController _hCtrl = ScrollController();
  final ScrollController _vCtrl = ScrollController();

  // UI state
  List<PatrolReportModel> _allReports = [];

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  int _rowsPerPage = 30;
  int _page = 0;
  int? _selectedIndex;

  //filter
  final Map<String, Set<String>> _filterValues = {};
  String _filterSearch = '';

  final OverlayPortalController _overlayCtrl = OverlayPortalController();
  String? _activeFilterKey;

  final Map<String, LayerLink> _filterLinks = {};

  @override
  void initState() {
    super.initState();
    _futureReports = PatrolReportApi.fetchReports(
      type: widget.patrolGroup.name,
    );

    for (final c in _cols) {
      _filterLinks[c.label] = LayerLink();
    }

    _searchCtrl.addListener(() {
      setState(() {
        _query = _searchCtrl.text.trim().toLowerCase();
        _page = 0;
      });
    });
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _vCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg1 = Colors.grey.shade100;
    final bg = Color(0xFF0F2027);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: FutureBuilder<List<PatrolReportModel>>(
          future: _futureReports,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return CommonUI.errorPage(
                message: snapshot.error.toString(),
                context: context,
              );
            }

            final all = snapshot.data ?? [];
            _allReports = all; // ✅ lưu lại

            if (all.isEmpty) {
              return CommonUI.emptyState(
                context: context,
                title: 'No reports',
                message: 'There are no patrol reports yet.',
                icon: Icons.assignment_outlined,
              );
            }

            final filtered = _applyFilter(all, _query);

            final totalPages = (filtered.length / _rowsPerPage).ceil().clamp(
              1,
              999999,
            );
            _page = _page.clamp(0, totalPages - 1);

            final start = _page * _rowsPerPage;
            final end = (start + _rowsPerPage).clamp(0, filtered.length);
            final pageItems = filtered.sublist(start, end);

            return Column(
              children: [
                _buildTopBar(total: all.length, shown: filtered.length),
                Expanded(child: _buildTable(context, pageItems)),
                _buildPager(
                  totalItems: filtered.length,
                  totalPages: totalPages,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===================== FILTER =====================
  List<String> _getColumnValues(String col, List<PatrolReportModel> all) {
    final set = <String>{};

    for (final e in all) {
      final v = _getCellValue(e, col).trim();
      if (v.isNotEmpty) {
        set.add(v);
      }
    }

    return set.toList()..sort();
  }

  String _getCellValue(PatrolReportModel e, String col) {
    switch (col) {
      case 'STT':
        return e.stt.toString();

      case 'QR':
        return e.qr_key.toString();

      case 'Patrol User':
        return e.patrol_user.toString();

      case 'Group':
        return e.grp;

      case 'Plant':
        return e.plant;

      case 'Division':
        return e.division;

      case 'Area':
        return e.area;

      case 'Machine':
        return e.machine;

      case 'Risk F':
        return e.riskFreq;

      case 'Risk P':
        return e.riskProb;

      case 'Risk S':
        return e.riskSev;

      case 'Risk T':
        return e.riskTotal;

      case 'Comment':
        return e.comment;

      case 'Countermeasure':
        return e.countermeasure;

      case 'Check Info':
        return e.checkInfo;

      case 'Created':
        return CommonUI.fmtDate(e.createdAt);

      case 'Due':
        return CommonUI.fmtDate(e.dueDate);

      case 'PIC':
        return e.pic ?? '';

      case 'AT Stt':
        return e.atStatus ?? '';

      case 'AT PIC':
        return e.atPic ?? '';

      case 'AT Date':
        return CommonUI.fmtDate(e.atDate);

      case 'AT Cmt':
        return e.atComment ?? '';

      case 'HSE J':
        return e.hseJudge ?? '';

      case 'HSE D':
        return CommonUI.fmtDate(e.hseDate);

      case 'HSE C':
        return e.hseComment ?? '';

      case 'Load':
        return e.loadStatus ?? '';

      default:
        return '';
    }
  }

  List<PatrolReportModel> _applyFilter(List<PatrolReportModel> src, String q) {
    return src.where((e) {
      // global search
      if (q.isNotEmpty) {
        final hay = [
          e.stt.toString(),
          e.type ?? '',
          e.grp,
          e.plant,
          e.division,
          e.area,
          e.machine,
          e.comment,
          e.countermeasure,
          e.checkInfo,
          e.pic ?? '',
          e.atPic ?? '',
          e.atStatus ?? '',
          e.atComment ?? '',
          e.hseJudge ?? '',
          e.hseComment ?? '',
          e.loadStatus ?? '',
        ].join(' ').toLowerCase();

        if (!hay.contains(q)) return false;
      }

      // column filters (VALUE based)
      for (final entry in _filterValues.entries) {
        final col = entry.key;
        final allowed = entry.value;

        if (allowed.isEmpty) continue;

        final cellValue = _getCellValue(e, col);

        if (!allowed.contains(cellValue)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // ===================== TOP BAR =====================
  Widget _buildTopBar({required int total, required int shown}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Row(
        children: [
          GlassActionButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context, false),
          ),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search (stt, type, group, comment, PIC...)',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _chip('$shown / $total'),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  // ===================== TABLE =====================
  Widget _buildTable(BuildContext context, List<PatrolReportModel> reports) {
    final totalWidth = _cols.fold<double>(0, (s, c) => s + c.w);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: _hCtrl,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _hCtrl,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: Column(
              children: [
                // sticky header: luôn ở trên, chỉ body cuộn dọc
                _buildHeader(),
                const Divider(height: 1, thickness: 1),
                Expanded(
                  child: Scrollbar(
                    controller: _vCtrl,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _vCtrl,
                      itemCount: reports.length,
                      itemBuilder: (_, i) => _buildRow(reports[i], i),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return OverlayPortal(
      controller: _overlayCtrl,
      overlayChildBuilder: (_) {
        if (_activeFilterKey == null) return const SizedBox();

        return Stack(
          children: [
            // 👇 lớp bắt click ngoài popup
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  setState(() => _activeFilterKey = null);
                  _overlayCtrl.hide();
                },
              ),
            ),

            // 👇 popup filter
            _buildFilterPopup(_allReports),
          ],
        );
      },
      child: Container(
        height: 44,
        color: Colors.grey.shade200,
        child: Row(
          children: _cols.map((c) {
            final hasFilter = _filterValues[c.label]?.isNotEmpty == true;

            return _HCellFilter(
              label: c.label,
              width: c.w,
              align: c.align,
              hasFilter: hasFilter,
              layerLink: _filterLinks[c.label]!,
              onFilterTap: () {
                setState(() {
                  _activeFilterKey = c.label;
                  _filterSearch = '';
                });
                _overlayCtrl.show();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRow(PatrolReportModel e, int index) {
    final isSelected = _selectedIndex == index;
    final base = index.isEven ? Colors.white : Colors.grey.shade50;
    final bg = isSelected ? Colors.lightBlue.shade50 : base;

    return _HoverableRow(
      height: 100,
      background: bg,
      onTap: () => setState(() => _selectedIndex = index),
      child: Row(
        children: [
          // === GIỮ NGUYÊN TẤT CẢ CỘT ===
          _cell(e.stt.toString(), _w('STT'), align: TextAlign.center),
          // _cell(e.qr_key.toString(), _w('QR'), align: TextAlign.center),
          _qrCell(e.qr_key, _w('QR')),

          _cell(e.grp, _w('Group'), tooltip: true),
          _cell(e.plant, _w('Plant'), tooltip: true),
          _cell(e.division, _w('Division'), tooltip: true),
          _cell(e.area, _w('Area'), tooltip: true),
          _cell(e.machine, _w('Machine'), tooltip: true),
          _cell(e.patrol_user!, _w('Patrol User'), tooltip: true),

          _imgCell(
            names: e.imageNames,
            width: _w('Img(B)'),
            onTap: () => PatrolImagesDialog.show(
              context: context,
              title: 'Before',
              e: e,
              names: e.imageNames,
            ),
          ),

          _badgeRisk(e.riskTotal, _w('Risk T')),

          _cell(e.comment, _w('Comment'), tooltip: true),
          _cell(e.countermeasure, _w('Countermeasure'), tooltip: true),

          _cell(
            CommonUI.fmtDate(e.createdAt),
            _w('Created'),
            align: TextAlign.center,
          ),
          _cell(
            CommonUI.fmtDate(e.dueDate),
            _w('Due'),
            align: TextAlign.center,
          ),
          _cell(e.pic ?? '-', _w('PIC'), tooltip: true),
          _cell(e.checkInfo, _w('Check Info'), tooltip: true),
          _cell(e.riskFreq, _w('Risk F'), align: TextAlign.center),
          _cell(e.riskProb, _w('Risk P'), align: TextAlign.center),
          _cell(e.riskSev, _w('Risk S'), align: TextAlign.center),
          _badgeStatus(e.atStatus, _w('AT Stt')),
          _cell(e.atPic ?? '-', _w('AT PIC'), tooltip: true),
          _cell(
            CommonUI.fmtDate(e.atDate),
            _w('AT Date'),
            align: TextAlign.center,
          ),
          _cell(e.atComment ?? '-', _w('AT Cmt'), tooltip: true),
          _imgCell(
            names: e.atImageNames,
            width: _w('Img(A)'),
            // onTap: () => _showImagesDialog('After images', e, e.atImageNames),
            onTap: () => PatrolImagesDialog.show(
              context: context,
              title: 'After',
              e: e,
              names: e.atImageNames,
            ),
          ),

          _cell(e.hseJudge ?? '-', _w('HSE J'), align: TextAlign.center),
          _cell(
            CommonUI.fmtDate(e.hseDate),
            _w('HSE D'),
            align: TextAlign.center,
          ),
          _cell(e.hseComment ?? '-', _w('HSE C'), tooltip: true),
          _imgCell(
            names: e.hseImageNames,
            width: _w('Img(H)'),
            onTap: () => PatrolImagesDialog.show(
              context: context,
              title: 'HSE',
              e: e,
              names: e.hseImageNames,
            ),
          ),

          _cell(e.loadStatus ?? '-', _w('Load'), align: TextAlign.center),
        ],
      ),
    );
  }

  // ===================== CELLS =====================
  Widget _qrCell(String? qr, double w) {
    final value = (qr ?? '').trim();
    final hasQr = value.isNotEmpty;

    return _boxed(
      width: w,
      align: TextAlign.center,
      child: hasQr
          ? Container(
              margin: const EdgeInsets.only(bottom: 6),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey.shade200),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.qr_code_2_rounded,
                    size: 24,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                      height: 1,
                    ),
                  ),
                ],
              ),
            )
          : const Text('-'),
    );
  }

  Widget _cell(
    String text,
    double w, {
    TextAlign align = TextAlign.left,
    bool tooltip = false,
  }) {
    final value = text.trim().isEmpty ? '-' : text.trim();

    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        value,
        // maxLines: 3,
        // overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
        textAlign: align,
      ),
    );

    return _boxed(
      width: w,
      align: align,
      child: tooltip
          ? Tooltip(
              message: value,
              waitDuration: const Duration(milliseconds: 350),
              child: child,
            )
          : child,
    );
  }

  Widget _imageThumb(String imageName, {double size = 40}) {
    if (imageName.isEmpty) {
      return const Icon(
        Icons.image_not_supported,
        size: 20,
        color: Colors.grey,
      );
    }

    final url = '${ApiConfig.imgUrl}/images/$imageName';

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.red),
        loadingBuilder: (c, w, p) {
          if (p == null) return w;
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        },
      ),
    );
  }

  Widget _imgCell({
    required List<String> names,
    required double width,
    VoidCallback? onTap,
  }) {
    final count = names.length;
    final first = count > 0 ? names.first : '';

    return _boxed(
      width: width,
      align: TextAlign.center,
      child: InkWell(
        onTap: (count > 0) ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // thumbnail
            if (count > 0)
              Expanded(child: _imageThumb(first, size: 80))
            else
              const Icon(
                Icons.image_not_supported,
                size: 18,
                color: Colors.grey,
              ),
            // count
            Text(
              '$count',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: count > 0 ? Colors.blueGrey.shade800 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeRisk(String risk, double w) {
    final color = CommonUI.riskColor(risk);

    return _boxed(
      width: w,
      align: TextAlign.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          risk,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _badgeStatus(String? stt, double w) {
    final status = (stt == null || stt.isEmpty) ? 'Wait' : stt;
    final color = CommonUI.statusColor(status);

    return _boxed(
      width: w,
      align: TextAlign.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _boxed({
    required double width,
    required TextAlign align,
    required Widget child,
  }) {
    return Container(
      width: width,
      alignment: align == TextAlign.center
          ? Alignment.center
          : Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: child,
    );
  }

  // ---- helpers ----
  Widget _buildFilterPopup(List<PatrolReportModel> all) {
    if (_activeFilterKey == null) return const SizedBox();

    final values = _getColumnValues(_activeFilterKey!, all);
    final selected = _filterValues[_activeFilterKey!] ?? <String>{};

    final shown = values
        .where((v) => v.toLowerCase().contains(_filterSearch.toLowerCase()))
        .toList();

    return CompositedTransformFollower(
      link: _filterLinks[_activeFilterKey!]!,
      offset: const Offset(0, 44),
      showWhenUnlinked: false,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 260,
          height: 340,
          decoration: BoxDecoration(
            color: const Color(0xFF172A33).withOpacity(.6), // dark panel
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              // ================= HEADER =================
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white24)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _activeFilterKey!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _overlayCtrl.hide,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ================= SEARCH =================
              Padding(
                padding: const EdgeInsets.all(10),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search value',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    prefixIconColor: Colors.white54,
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blueAccent),
                    ),
                  ),
                  onChanged: (v) => setState(() => _filterSearch = v),
                ),
              ),

              // ================= LIST =================
              Expanded(
                child: shown.isEmpty
                    ? const Center(
                        child: Text(
                          'No values',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : Scrollbar(
                        thumbVisibility: true,
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: shown.length,
                          itemBuilder: (_, i) {
                            final v = shown[i];
                            final checked = selected.contains(v);

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  final s = _filterValues.putIfAbsent(
                                    _activeFilterKey!,
                                    () => <String>{},
                                  );
                                  checked ? s.remove(v) : s.add(v);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: checked,
                                      onChanged: (ok) {
                                        setState(() {
                                          final s = _filterValues.putIfAbsent(
                                            _activeFilterKey!,
                                            () => <String>{},
                                          );
                                          ok == true ? s.add(v) : s.remove(v);
                                        });
                                      },
                                      checkColor: Colors.white, // màu dấu ✓
                                      side: const BorderSide(
                                        color: Colors.white54,
                                      ), // viền khi unchecked
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        v,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),

              // ================= FOOTER =================
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white24)),
                ),
                child: Row(
                  children: [
                    GlassActionButton(
                      icon: Icons.cleaning_services,
                      onTap: () {
                        setState(() {
                          _filterValues.remove(_activeFilterKey);
                        });
                      },
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

  // ===================== PAGER =====================
  Widget _buildPager({required int totalItems, required int totalPages}) {
    const controlBg = Color(0xFF172A33);

    return Container(
      color: const Color(0xFF0F2027),
      // padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        children: [
          // rows info
          Text(
            'Rows: $totalItems',
            style: const TextStyle(color: Colors.white70),
          ),

          const Spacer(),

          // page info
          Text(
            'Page ${_page + 1} / $totalPages',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(width: 12),

          // prev
          IconButton(
            onPressed: _page == 0 ? null : () => setState(() => _page--),
            icon: const Icon(Icons.chevron_left),
            color: Colors.white,
            disabledColor: Colors.white38,
          ),

          // next
          IconButton(
            onPressed: (_page + 1 >= totalPages)
                ? null
                : () => setState(() => _page++),
            icon: const Icon(Icons.chevron_right),
            color: Colors.white,
            disabledColor: Colors.white38,
          ),

          const SizedBox(width: 12),

          // rows per page
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: controlBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: DropdownButton<int>(
              value: _rowsPerPage,
              underline: const SizedBox(),
              dropdownColor: controlBg,
              iconEnabledColor: Colors.white,
              style: const TextStyle(color: Colors.white),
              items: const [15, 30, 50, 100]
                  .map(
                    (e) => DropdownMenuItem(value: e, child: Text('$e / page')),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _rowsPerPage = v;
                  _page = 0;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===================== COLUMN DEFINITIONS =====================
  // GIỮ nguyên cột, chỉ gom lại để dễ quản lý width/alignment.
  late final List<_Col> _cols = [
    _Col('STT', 70, TextAlign.center),
    _Col('QR', 70, TextAlign.center),
    _Col('Group', 70, TextAlign.left),
    _Col('Plant', 70, TextAlign.left),
    _Col('Division', 90, TextAlign.left),
    _Col('Area', 120, TextAlign.left),
    _Col('Machine', 100, TextAlign.left),
    _Col('Patrol User', 110, TextAlign.left),

    _Col('Img(B)', 90, TextAlign.center),

    _Col('Risk T', 90, TextAlign.center),

    _Col('Comment', 260, TextAlign.left),
    _Col('Countermeasure', 260, TextAlign.left),

    _Col('Created', 100, TextAlign.center),
    _Col('Due', 100, TextAlign.center),
    _Col('PIC', 90, TextAlign.left),
    _Col('Check Info', 120, TextAlign.left),
    _Col('Risk F', 120, TextAlign.center),
    _Col('Risk P', 100, TextAlign.center),
    _Col('Risk S', 100, TextAlign.center),

    _Col('AT Stt', 70, TextAlign.center),
    _Col('AT PIC', 90, TextAlign.left),
    _Col('AT Date', 100, TextAlign.center),
    _Col('AT Cmt', 260, TextAlign.left),
    _Col('Img(A)', 100, TextAlign.center),

    _Col('HSE J', 90, TextAlign.center),
    _Col('HSE D', 100, TextAlign.center),
    _Col('HSE C', 260, TextAlign.left),
    _Col('Img(H)', 100, TextAlign.center),

    _Col('Load', 100, TextAlign.center),
  ];

  double _w(String label) => _cols.firstWhere((c) => c.label == label).w;
}

// ===================== UTIL =====================

class _Col {
  final String label;
  final double w;
  final TextAlign align;
  const _Col(this.label, this.w, this.align);
}

class _HCellFilter extends StatelessWidget {
  final String label;
  final double width;
  final TextAlign align;
  final bool hasFilter;
  final VoidCallback onFilterTap;
  final LayerLink layerLink;

  const _HCellFilter({
    required this.label,
    required this.width,
    required this.onFilterTap,
    required this.layerLink,
    this.align = TextAlign.left,
    this.hasFilter = false,
  });

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: layerLink,
      child: Container(
        width: width,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          border: Border(right: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: align,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            InkWell(
              onTap: onFilterTap,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  hasFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
                  size: 18,
                  color: hasFilter ? Colors.blue : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Hover row (web/desktop friendly)
class _HoverableRow extends StatefulWidget {
  final double height;
  final Color background;
  final Widget child;
  final VoidCallback? onTap;

  const _HoverableRow({
    required this.height,
    required this.background,
    required this.child,
    this.onTap,
  });

  @override
  State<_HoverableRow> createState() => _HoverableRowState();
}

class _HoverableRowState extends State<_HoverableRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hover ? Colors.blueGrey.withOpacity(0.06) : widget.background;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(height: widget.height, color: bg, child: widget.child),
      ),
    );
  }
}
