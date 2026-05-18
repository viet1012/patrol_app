import 'package:chuphinh/common/common_ui_helper.dart';
import 'package:chuphinh/table/patrol_images_dialog.dart';
import 'package:chuphinh/table/patrol_summary_chart_page.dart';
import 'package:chuphinh/table/widgets/patrol_report_table_columns.dart';
import 'package:chuphinh/table/widgets/patrol_report_table_helpers.dart';
import 'package:chuphinh/table/widgets/patrol_report_table_state.dart';
import 'package:chuphinh/table/widgets/patrol_report_table_widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_config.dart';
import '../api/hse_master_service.dart';
import '../api/patrol_report_api.dart';
import '../api/patrol_report_download_api.dart';
import '../model/auth_me.dart';
import '../model/patrol_report_model.dart';
import '../widget/glass_action_button.dart';
import 'before_after_summary_page.dart';
import 'edit_report_dialog.dart';

class PatrolReportTable extends StatefulWidget {
  final String patrolGroup;
  final String plant;
  final String accountCode;
  final AuthMe auth;

  const PatrolReportTable({
    super.key,
    required this.patrolGroup,
    required this.plant,
    required this.accountCode,
    required this.auth,
  });

  @override
  State<PatrolReportTable> createState() => _PatrolReportTableState();
}

class _PatrolReportTableState extends State<PatrolReportTable> {
  static const _pageSizeOptions = [15, 30, 50, 100];

  final ScrollController _horizontalScrollCtrl = ScrollController();
  final ScrollController _verticalScrollCtrl = ScrollController();
  final ScrollController _filterListScrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  final OverlayPortalController _overlayCtrl = OverlayPortalController();
  final Map<String, LayerLink> _filterLinks = {};

  late final Future<List<PatrolReportModel>> _futureReports;
  late final List<PatrolReportColumnSpec> _columns =
      PatrolReportTableColumns.build();

  List<PatrolReportModel> _reports = [];

  late PatrolReportTableViewState _viewState;

  String? _employeeName;
  String? _patrolUser;
  bool _isLoadingName = false;

  final ScrollController _pageScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    debugPrint("ACCOUNT CODE = ${widget.accountCode}");
    _viewState = PatrolReportTableViewState(
      toDate: now,
      fromDate: DateTime(now.year, now.month - 1, 1),
    );

    _futureReports = _loadReports();

    _loadPatrolUser();

    for (final col in _columns) {
      _filterLinks[col.label] = LayerLink();
    }

    _searchCtrl.addListener(_onSearchChanged);
  }

  Future<void> _loadPatrolUser() async {
    final code = widget.accountCode.trim();

    if (code.isEmpty) return;

    try {
      setState(() {
        _isLoadingName = true;
      });

      final name = await HseMasterService.fetchEmployeeName(code);

      if (!mounted) return;

      final patrolUser = "${widget.accountCode}_$name";

      setState(() {
        _employeeName = name;
        _patrolUser = patrolUser;
      });

      debugPrint("PATROL USER = $patrolUser");
    } catch (e) {
      debugPrint("LOAD USER ERROR: $e");
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoadingName = false;
      });
    }
  }

  Future<List<PatrolReportModel>> _loadReports() async {
    final data = await PatrolReportApi.fetchReports(
      type: widget.patrolGroup,
      plant: widget.plant,
    );
    _reports = List<PatrolReportModel>.from(data);
    return _reports;
  }

  @override
  void dispose() {
    _pageScrollCtrl.dispose();
    _horizontalScrollCtrl.dispose();
    _verticalScrollCtrl.dispose();
    _filterListScrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _viewState = _viewState.copyWith(
        searchQuery: _searchCtrl.text.trim().toLowerCase(),
        page: 0,
      );
    });

    _jumpVerticalToTop();
  }

  List<PatrolReportModel> get _filteredReports {
    return PatrolReportTableHelper.applyFilters(
      source: _reports,
      query: _viewState.searchQuery,
      fromDate: _viewState.fromDate,
      toDate: _viewState.toDate,
      filterValues: _viewState.filterValues,
      columns: _columns,
    );
  }

  int get _totalPages {
    final total = (_filteredReports.length / _viewState.rowsPerPage).ceil();
    return total <= 0 ? 1 : total;
  }

  int get _safePage => _viewState.page.clamp(0, _totalPages - 1);

  List<PatrolReportModel> get _currentPageItems {
    final filtered = _filteredReports;
    if (filtered.isEmpty) return const [];

    final start = _safePage * _viewState.rowsPerPage;
    final end = (start + _viewState.rowsPerPage).clamp(0, filtered.length);

    return filtered.sublist(start, end);
  }

  Map<String, int> get _groupCaseCounts {
    final base = PatrolReportTableHelper.applyFilters(
      source: _reports,
      query: _viewState.searchQuery,
      fromDate: _viewState.fromDate,
      toDate: _viewState.toDate,
      filterValues: _viewState.filterValues,
      columns: _columns,
      excludeColumn: 'Group',
    );

    final counts = <String, int>{};

    for (final row in base) {
      final group = row.grp.trim();
      if (group.isEmpty) continue;
      counts[group] = (counts[group] ?? 0) + 1;
    }

    final sortedKeys = counts.keys.toList()..sort();

    return {for (final key in sortedKeys) key: counts[key]!};
  }

  String? get _selectedGroup {
    final values = _viewState.filterValues['Group'];
    if (values == null || values.isEmpty) return null;
    return values.first;
  }

  bool get isHse {
    return widget.auth.role == "HSE";
  }

  void _onTapGroup(String group) {
    final nextFilters = Map<String, Set<String>>.from(_viewState.filterValues);
    final current = _selectedGroup;

    setState(() {
      if (current == group) {
        nextFilters.remove('Group');
      } else {
        nextFilters['Group'] = {group};
      }

      _viewState = _viewState.copyWith(filterValues: nextFilters, page: 0);
    });

    _jumpVerticalToTop();
  }

  void _jumpVerticalToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_verticalScrollCtrl.hasClients) {
        _verticalScrollCtrl.jumpTo(0);
      }
    });
  }

  void _jumpBothScrollsToStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_verticalScrollCtrl.hasClients) {
        _verticalScrollCtrl.jumpTo(0);
      }
      if (_horizontalScrollCtrl.hasClients) {
        _horizontalScrollCtrl.jumpTo(0);
      }
    });
  }

  Future<void> _downloadExcel() async {
    if (_viewState.downloading) return;

    setState(() {
      _viewState = _viewState.copyWith(downloading: true);
    });

    try {
      final downloader = PatrolReportDownloadService(
        dio: Dio(),
        baseUrl: ApiConfig.baseUrl,
      );

      await downloader.downloadExportExcel(
        query: PatrolReportTableHelper.buildExportQuery(
          filterValues: _viewState.filterValues,
          columns: _columns,
          fromDate: _viewState.fromDate,
          toDate: _viewState.toDate,
          patrolGroup: widget.patrolGroup,
          plant: widget.plant,
        ),
        fileName: 'patrol_reports.xlsx',
      );

      if (!mounted) return;
      CommonUI.showSuccessSnack(
        context,
        message: 'Excel file downloaded successfully',
      );
    } catch (e) {
      if (!mounted) return;
      CommonUI.showWarning(
        context: context,
        title: 'Warning',
        message: 'Download failed: $e',
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _viewState = _viewState.copyWith(downloading: false);
      });
    }
  }

  void _applySummaryFilter(String group, String division) {
    final nextFilters = Map<String, Set<String>>.from(_viewState.filterValues)
      ..['Group'] = {group}
      ..['Division'] = {division};

    setState(() {
      _viewState = _viewState.copyWith(filterValues: nextFilters, page: 0);
    });

    _jumpVerticalToTop();

    CommonUI.showSuccessSnack(
      context,
      message: 'Filtered by $group / $division',
    );
  }

  void _clearAll() {
    setState(() {
      _searchCtrl.clear();
      _viewState = PatrolReportTableViewState(
        fromDate: _viewState.fromDate,
        toDate: _viewState.toDate,
      );
    });

    _overlayCtrl.hide();
    _jumpBothScrollsToStart();
  }

  Future<void> _openBeforeAfterSummary() async {
    final now = DateTime.now();
    final from = _viewState.fromDate ?? DateTime(now.year, now.month, 1);
    final to = _viewState.toDate ?? DateTime(now.year, now.month, now.day);

    setState(() {
      _viewState = _viewState.copyWith(fromDate: from, toDate: to);
    });

    await BeforeAfterSummaryDialog.show(
      context,
      fromD: PatrolReportTableHelper.fmtDate(from),
      toD: PatrolReportTableHelper.fmtDate(to),
      fac: widget.plant,
      type: widget.patrolGroup,
    );
  }

  void _openFilterPopup(String columnLabel) {
    setState(() {
      _viewState = _viewState.copyWith(
        activeFilterColumn: columnLabel,
        filterSearch: '',
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_filterListScrollCtrl.hasClients) {
        _filterListScrollCtrl.jumpTo(0);
      }
    });

    _overlayCtrl.show();
  }

  void _closeFilterPopup() {
    setState(() {
      _viewState = _viewState.copyWith(clearActiveFilterColumn: true);
    });
    _overlayCtrl.hide();
  }

  void _toggleFilterValue({
    required String column,
    required String value,
    required bool checked,
  }) {
    final nextFilters = <String, Set<String>>{
      for (final e in _viewState.filterValues.entries) e.key: {...e.value},
    };

    final selected = nextFilters.putIfAbsent(column, () => <String>{});

    if (checked) {
      selected.add(value);
    } else {
      selected.remove(value);
      if (selected.isEmpty) {
        nextFilters.remove(column);
      }
    }

    setState(() {
      _viewState = _viewState.copyWith(filterValues: nextFilters, page: 0);
    });

    _jumpVerticalToTop();
  }

  void _clearColumnFilter(String column) {
    final nextFilters = Map<String, Set<String>>.from(_viewState.filterValues)
      ..remove(column);

    setState(() {
      _viewState = _viewState.copyWith(filterValues: nextFilters, page: 0);
    });

    _jumpVerticalToTop();
  }

  // Future<void> _editReport(PatrolReportModel report) async {
  //   setState(() {
  //     _viewState = _viewState.copyWith(selectedReportId: report.id);
  //   });
  //
  //   final updated = await EditReportDialog.show(context, model: report);
  //   if (updated == null || !mounted) return;
  //
  //   setState(() {
  //     final index = _reports.indexWhere((e) => e.id == updated.id);
  //     if (index != -1) {
  //       _reports[index] = updated;
  //     }
  //   });
  // }

  Future<void> _editReport(PatrolReportModel report) async {
    final canEdit =
        report.patrol_user?.trim() == _patrolUser?.trim() ||
        report.atAssign?.trim() == _employeeName?.trim();

    debugPrint(
      "COMPARE => "
      "report.patrol_user = [${report.patrol_user?.trim()}] | "
      "_patrolUser = [${_patrolUser?.trim()}] | "
      "RESULT = $canEdit",
    );
    if (!canEdit && !isHse) {
      CommonUI.showWarning(
        context: context,
        title: "Permission denied",

        message:
            "You are not allowed to edit this report.\n\n"
            "Only the creator can edit this content.",
      );

      return;
    }

    ////////////////////////////////////////////////////////////
    /// SELECT ROW
    ////////////////////////////////////////////////////////////
    setState(() {
      _viewState = _viewState.copyWith(selectedReportId: report.id);
    });

    ////////////////////////////////////////////////////////////
    /// OPEN EDIT
    ////////////////////////////////////////////////////////////
    final updated = await EditReportDialog.show(
      context,
      model: report,
      me: widget.auth,
    );

    if (updated == null || !mounted) {
      return;
    }

    ////////////////////////////////////////////////////////////
    /// UPDATE TABLE
    ////////////////////////////////////////////////////////////
    setState(() {
      final index = _reports.indexWhere((e) => e.id == updated.id);

      if (index != -1) {
        _reports[index] = updated;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const pageBg = Color(0xFF0F2027);

    return Scaffold(
      backgroundColor: pageBg,
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

            if (_reports.isEmpty) {
              return CommonUI.emptyState(
                context: context,
                title: 'No reports',
                message: 'There are no patrol reports yet.',
                icon: Icons.assignment_outlined,
              );
            }

            final filtered = _filteredReports;
            final currentItems = _currentPageItems;

            return LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 700;

                if (!isMobile) {
                  return Column(
                    children: [
                      Expanded(
                        child: ScrollbarTheme(
                          data: ScrollbarThemeData(
                            thumbColor: WidgetStateProperty.all(
                              Colors.black.withOpacity(0.8),
                            ),

                            trackColor: WidgetStateProperty.all(Colors.grey),

                            trackBorderColor: WidgetStateProperty.all(
                              Colors.transparent,
                            ),

                            radius: const Radius.circular(999),

                            thickness: WidgetStateProperty.all(10),

                            thumbVisibility: WidgetStateProperty.all(true),

                            trackVisibility: WidgetStateProperty.all(true),
                          ),

                          child: Column(
                            children: [
                              _buildSummaryToggle(),

                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                child: _viewState.showSummary
                                    ? Padding(
                                        key: const ValueKey('summary'),
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: PatrolRiskSummarySfPage(
                                          onSelect: _applySummaryFilter,
                                          onDateChanged: (from, to) {
                                            setState(() {
                                              _viewState = _viewState.copyWith(
                                                fromDate: from,
                                                toDate: to,
                                                page: 0,
                                              );
                                            });
                                          },
                                          fromD: _viewState.fromDate,
                                          toD: _viewState.toDate,
                                          plant: widget.plant,
                                          patrolGroup: widget.patrolGroup,
                                        ),
                                      )
                                    : const SizedBox(
                                        key: ValueKey('summary_empty'),
                                      ),
                              ),

                              _buildTopBar(
                                total: _reports.length,
                                shown: filtered.length,
                              ),

                              if (_viewState.downloading)
                                CommonUI.exportLoadingBanner(
                                  accentColor: Colors.amber,
                                  title: 'Exporting Excel',
                                  subtitle:
                                      'Large dataset detected, please wait…',
                                ),

                              Expanded(
                                child: _buildTable(
                                  context: context,
                                  reports: currentItems,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      _buildPager(
                        totalItems: filtered.length,
                        totalPages: _totalPages,
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: ScrollbarTheme(
                        data: ScrollbarThemeData(
                          thumbColor: WidgetStateProperty.all(
                            Colors.black.withOpacity(0.8),
                          ),
                          trackColor: WidgetStateProperty.all(
                            Colors.grey.withOpacity(0.8),
                          ),
                          trackBorderColor: WidgetStateProperty.all(
                            Colors.transparent,
                          ),
                          radius: const Radius.circular(999),
                          thickness: WidgetStateProperty.all(10),
                          thumbVisibility: WidgetStateProperty.all(true),
                          trackVisibility: WidgetStateProperty.all(true),
                        ),

                        child: Scrollbar(
                          controller: _pageScrollCtrl,
                          thumbVisibility: true,
                          trackVisibility: true,
                          thickness: 10,
                          radius: const Radius.circular(999),

                          child: SingleChildScrollView(
                            controller: _pageScrollCtrl,
                            padding: const EdgeInsets.only(bottom: 8),

                            child: Column(
                              children: [
                                _buildSummaryToggle(),

                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  child: _viewState.showSummary
                                      ? Padding(
                                          key: const ValueKey('summary'),
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: PatrolRiskSummarySfPage(
                                            onSelect: _applySummaryFilter,
                                            onDateChanged: (from, to) {
                                              setState(() {
                                                _viewState = _viewState
                                                    .copyWith(
                                                      fromDate: from,
                                                      toDate: to,
                                                      page: 0,
                                                    );
                                              });
                                            },
                                            fromD: _viewState.fromDate,
                                            toD: _viewState.toDate,
                                            plant: widget.plant,
                                            patrolGroup: widget.patrolGroup,
                                          ),
                                        )
                                      : const SizedBox(
                                          key: ValueKey('summary_empty'),
                                        ),
                                ),

                                _buildTopBar(
                                  total: _reports.length,
                                  shown: filtered.length,
                                ),

                                if (_viewState.downloading)
                                  CommonUI.exportLoadingBanner(
                                    accentColor: Colors.amber,
                                    title: 'Exporting Excel',
                                    subtitle:
                                        'Large dataset detected, please wait…',
                                  ),

                                SizedBox(
                                  height: constraints.maxHeight * 0.62,
                                  child: _buildTable(
                                    context: context,
                                    reports: currentItems,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    _buildPager(
                      totalItems: filtered.length,
                      totalPages: _totalPages,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryToggle() {
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_viewState.activeFilterColumn == null) _buildGroupBar(),

            const SizedBox(height: 6),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _viewState = _viewState.copyWith(
                        showSummary: !_viewState.showSummary,
                      );
                    });
                  },
                  icon: Icon(
                    _viewState.showSummary
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.white,
                  ),
                  label: Text(
                    _viewState.showSummary ? 'Hide' : 'Show',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton.icon(
                  onPressed: _openBeforeAfterSummary,
                  icon: const Icon(
                    Icons.analytics_outlined,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Report',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Row(
        children: [
          if (_viewState.activeFilterColumn == null)
            Expanded(child: _buildGroupBar()),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _viewState = _viewState.copyWith(
                  showSummary: !_viewState.showSummary,
                );
              });
            },
            icon: Icon(
              _viewState.showSummary
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              color: Colors.white,
            ),
            label: Text(
              _viewState.showSummary ? 'Hide' : 'Show',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          TextButton.icon(
            onPressed: _openBeforeAfterSummary,
            icon: const Icon(Icons.analytics_outlined, color: Colors.white),
            label: const Text(
              'Report',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar({required int total, required int shown}) {
    final canClear =
        _viewState.searchQuery.isNotEmpty || _viewState.filterValues.isNotEmpty;

    return Row(
      children: [
        GlassActionButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => context.go('/home'),
        ),
        IconButton(
          icon: const Icon(Icons.download_rounded, color: Colors.greenAccent),
          onPressed: _downloadExcel,
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
        IconButton(
          icon: const Icon(Icons.cleaning_services, color: Colors.greenAccent),
          onPressed: canClear ? _clearAll : null,
        ),
        const SizedBox(width: 10),
        _buildChip('$shown / $total'),
      ],
    );
  }

  Widget _buildChip(String text) {
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

  Future<void> _pickTableDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom
        ? (_viewState.fromDate ?? now)
        : (_viewState.toDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );

    if (picked == null) return;

    DateTime? newFrom = _viewState.fromDate;
    DateTime? newTo = _viewState.toDate;

    final normalized = DateTime(picked.year, picked.month, picked.day);

    if (isFrom) {
      newFrom = normalized;
    } else {
      newTo = normalized;
    }

    if (newFrom != null && newTo != null && newFrom.isAfter(newTo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('From date must be <= To date')),
      );
      return;
    }

    setState(() {
      _viewState = _viewState.copyWith(
        fromDate: newFrom,
        toDate: newTo,
        page: 0,
      );
    });

    _jumpVerticalToTop();
  }

  Widget _buildDateChip({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF172A33),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, size: 16, color: Colors.grey.shade300),
            const SizedBox(width: 6),
            Text(
              '$label: $value',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupBar() {
    final isMobile = MediaQuery.of(context).size.width < 700;

    final groupCounts = _groupCaseCounts;
    final groups = groupCounts.keys.toList();
    final selectedGroup = _selectedGroup;

    final fromText = _viewState.fromDate != null
        ? PatrolReportTableHelper.fmtDate(_viewState.fromDate!)
        : '--';

    final toText = _viewState.toDate != null
        ? PatrolReportTableHelper.fmtDate(_viewState.toDate!)
        : '--';

    final hasDateFilter =
        _viewState.fromDate != null || _viewState.toDate != null;

    if (groups.isEmpty && !hasDateFilter) {
      return const SizedBox.shrink();
    }

    final chips = groups.map((group) {
      final selected = group == selectedGroup;
      final count = groupCounts[group] ?? 0;

      return FilterChip(
        visualDensity: isMobile
            ? VisualDensity.compact
            : VisualDensity.standard,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        label: Text('$group ($count)', overflow: TextOverflow.ellipsis),
        selected: selected,
        onSelected: (_) => _onTapGroup(group),
        selectedColor: Colors.blue.withOpacity(0.22),
        backgroundColor: Colors.white,
        checkmarkColor: Colors.blue,
        labelStyle: TextStyle(
          fontSize: isMobile ? 12 : 13,
          color: selected ? Colors.blue.shade900 : Colors.black87,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        side: BorderSide(color: selected ? Colors.blue : Colors.grey.shade300),
      );
    }).toList();

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(spacing: 6, runSpacing: 6, children: chips),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildDateChip(
                    label: 'From',
                    value: fromText,
                    onTap: () => _pickTableDate(isFrom: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDateChip(
                    label: 'To',
                    value: toText,
                    onTap: () => _pickTableDate(isFrom: false),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...chips,
          _buildDateChip(
            label: 'From',
            value: fromText,
            onTap: () => _pickTableDate(isFrom: true),
          ),
          _buildDateChip(
            label: 'To',
            value: toText,
            onTap: () => _pickTableDate(isFrom: false),
          ),
        ],
      ),
    );
  }

  Widget _buildTable({
    required BuildContext context,
    required List<PatrolReportModel> reports,
  }) {
    final totalWidth = _columns.fold<double>(
      0,
      (sum, column) => sum + column.width,
    );

    return Card(
      elevation: 2,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: _horizontalScrollCtrl,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _horizontalScrollCtrl,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: Column(
              children: [
                _buildHeader(),
                const Divider(height: 1, thickness: 1),
                Expanded(
                  child: PrimaryScrollController(
                    controller: _verticalScrollCtrl,
                    child: Scrollbar(
                      controller: _verticalScrollCtrl,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: _verticalScrollCtrl,
                        primary: false,
                        itemCount: reports.length,
                        itemBuilder: (_, index) {
                          final report = reports[index];
                          return _buildRow(report, index);
                        },
                      ),
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
        if (_viewState.activeFilterColumn == null) {
          return const SizedBox();
        }

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeFilterPopup,
              ),
            ),
            _buildFilterPopup(_reports),
          ],
        );
      },
      child: Container(
        height: 44,
        color: Colors.grey.shade200,
        child: Row(
          children: _columns.map((column) {
            final hasFilter =
                _viewState.filterValues[column.label]?.isNotEmpty == true;

            return PatrolReportHeaderFilterCell(
              label: column.label,
              width: column.width,
              align: column.align,
              hasFilter: hasFilter,
              layerLink: _filterLinks[column.label]!,
              onFilterTap: () => _openFilterPopup(column.label),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterPopup(List<PatrolReportModel> allReports) {
    final column = _viewState.activeFilterColumn;
    if (column == null) return const SizedBox();

    final base = PatrolReportTableHelper.applyFilters(
      source: allReports,
      query: _viewState.searchQuery,
      fromDate: _viewState.fromDate,
      toDate: _viewState.toDate,
      filterValues: _viewState.filterValues,
      columns: _columns,
      excludeColumn: column,
    );

    final valuesInBase = PatrolReportTableHelper.distinctColumnValues(
      columnLabel: column,
      source: base,
      columns: _columns,
    );

    final selected = _viewState.filterValues[column] ?? <String>{};

    final mergedValues = <String>[
      ...selected.where((value) => !valuesInBase.contains(value)),
      ...valuesInBase,
    ];

    final shownValues = mergedValues
        .where(
          (value) => value.toLowerCase().contains(
            _viewState.filterSearch.toLowerCase(),
          ),
        )
        .toList();

    return CompositedTransformFollower(
      link: _filterLinks[column]!,
      offset: const Offset(0, 44),
      showWhenUnlinked: false,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 260,
          height: 340,
          decoration: BoxDecoration(
            color: const Color(0xFF172A33).withOpacity(.6),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white24)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        column,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _closeFilterPopup,
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
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blueAccent),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _viewState = _viewState.copyWith(filterSearch: value);
                    });
                  },
                ),
              ),
              Expanded(
                child: shownValues.isEmpty
                    ? const Center(
                        child: Text(
                          'No values',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : Scrollbar(
                        controller: _filterListScrollCtrl,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _filterListScrollCtrl,
                          primary: false,
                          padding: EdgeInsets.zero,
                          itemCount: shownValues.length,
                          itemBuilder: (_, index) {
                            final value = shownValues[index];
                            final checked = selected.contains(value);

                            return InkWell(
                              onTap: () {
                                _toggleFilterValue(
                                  column: column,
                                  value: value,
                                  checked: !checked,
                                );
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
                                        _toggleFilterValue(
                                          column: column,
                                          value: value,
                                          checked: ok == true,
                                        );
                                      },
                                      checkColor: Colors.white,
                                      side: const BorderSide(
                                        color: Colors.white54,
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        value,
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white24)),
                ),
                child: Row(
                  children: [
                    GlassActionButton(
                      icon: Icons.cleaning_services,
                      onTap: () => _clearColumnFilter(column),
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

  Widget _buildRow(PatrolReportModel report, int pageIndex) {
    final isSelected = _viewState.selectedReportId == report.id;
    final baseColor = pageIndex.isEven ? Colors.white : Colors.grey.shade50;
    final background = isSelected ? Colors.lightBlue.shade50 : baseColor;

    return PatrolReportHoverableRow(
      height: 100,
      background: background,
      onDoubleTap: () => _editReport(report),
      child: Row(
        children: [
          _textCell(
            report.stt.toString(),
            PatrolReportTableHelper.widthOf(_columns, 'STT'),
            align: TextAlign.center,
          ),
          _qrCell(
            report.qr_key?.toString(),
            PatrolReportTableHelper.widthOf(_columns, 'QR'),
          ),
          _textCell(
            report.grp,
            PatrolReportTableHelper.widthOf(_columns, 'Group'),
            tooltip: true,
          ),
          _textCell(
            report.plant,
            PatrolReportTableHelper.widthOf(_columns, 'Plant'),
            tooltip: true,
          ),
          _textCell(
            report.division,
            PatrolReportTableHelper.widthOf(_columns, 'Division'),
            tooltip: true,
          ),
          _textCell(
            report.area,
            PatrolReportTableHelper.widthOf(_columns, 'Area'),
            tooltip: true,
          ),
          _textCell(
            report.machine,
            PatrolReportTableHelper.widthOf(_columns, 'Machine'),
            tooltip: true,
          ),
          _textCell(
            report.patrol_user ?? '-',
            PatrolReportTableHelper.widthOf(_columns, 'Patrol User'),
            tooltip: true,
          ),
          _imageCell(
            names: report.imageNames,
            width: PatrolReportTableHelper.widthOf(_columns, 'Img(B)'),
            onTap: () {
              PatrolImagesDialog.show(
                context: context,
                title: 'Before',
                e: report,
                names: report.imageNames,
              );
            },
          ),
          _riskBadgeCell(
            report.riskTotal,
            PatrolReportTableHelper.widthOf(_columns, 'Risk T'),
          ),
          _textCell(
            report.comment,
            PatrolReportTableHelper.widthOf(_columns, 'Comment'),
            tooltip: true,
          ),
          _textCell(
            report.countermeasure,
            PatrolReportTableHelper.widthOf(_columns, 'Countermeasure'),
            tooltip: true,
          ),
          _textCell(
            CommonUI.fmtDate(report.createdAt),
            PatrolReportTableHelper.widthOf(_columns, 'Created'),
            align: TextAlign.center,
          ),
          _textCell(
            CommonUI.fmtDate(report.dueDate),
            PatrolReportTableHelper.widthOf(_columns, 'Due'),
            align: TextAlign.center,
          ),
          _textCell(
            report.pic ?? '-',
            PatrolReportTableHelper.widthOf(_columns, 'PIC'),
            tooltip: true,
          ),
          _textCell(
            report.checkInfo,
            PatrolReportTableHelper.widthOf(_columns, 'Check Info'),
            tooltip: true,
          ),
          _textCell(
            report.riskFreq,
            PatrolReportTableHelper.widthOf(_columns, 'Risk F'),
            align: TextAlign.center,
          ),
          _textCell(
            report.riskProb,
            PatrolReportTableHelper.widthOf(_columns, 'Risk P'),
            align: TextAlign.center,
          ),
          _textCell(
            report.riskSev,
            PatrolReportTableHelper.widthOf(_columns, 'Risk S'),
            align: TextAlign.center,
          ),
          _statusBadgeCell(
            report.atStatus,
            PatrolReportTableHelper.widthOf(_columns, 'AT Stt'),
          ),
          _textCell(
            report.atPic ?? '-',
            PatrolReportTableHelper.widthOf(_columns, 'AT PIC'),
            tooltip: true,
          ),
          _textCell(
            CommonUI.fmtDate(report.atDate),
            PatrolReportTableHelper.widthOf(_columns, 'AT Date'),
            align: TextAlign.center,
          ),
          _textCell(
            report.atComment ?? '-',
            PatrolReportTableHelper.widthOf(_columns, 'AT Cmt'),
            tooltip: true,
          ),
          _imageCell(
            names: report.atImageNames,
            width: PatrolReportTableHelper.widthOf(_columns, 'Img(A)'),
            onTap: () {
              PatrolImagesDialog.show(
                context: context,
                title: 'After',
                e: report,
                names: report.atImageNames,
              );
            },
          ),
          _textCell(
            report.hseJudge ?? '-',
            PatrolReportTableHelper.widthOf(_columns, 'HSE J'),
            align: TextAlign.center,
          ),
          _textCell(
            CommonUI.fmtDate(report.hseDate),
            PatrolReportTableHelper.widthOf(_columns, 'HSE D'),
            align: TextAlign.center,
          ),
          _textCell(
            report.hseComment ?? '-',
            PatrolReportTableHelper.widthOf(_columns, 'HSE C'),
            tooltip: true,
          ),
          _imageCell(
            names: report.hseImageNames,
            width: PatrolReportTableHelper.widthOf(_columns, 'Img(H)'),
            onTap: () {
              PatrolImagesDialog.show(
                context: context,
                title: 'HSE',
                e: report,
                names: report.hseImageNames,
              );
            },
          ),
          _textCell(
            report.loadStatus ?? '-',
            PatrolReportTableHelper.widthOf(_columns, 'Load'),
            align: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _qrCell(String? qr, double width) {
    final value = (qr ?? '').trim();
    final hasQr = value.isNotEmpty;

    return _boxedCell(
      width: width,
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

  Widget _textCell(
    String text,
    double width, {
    TextAlign align = TextAlign.left,
    bool tooltip = false,
  }) {
    final value = text.trim().isEmpty ? '-' : text.trim();

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        value,
        style: const TextStyle(fontSize: 13),
        textAlign: align,
      ),
    );

    return _boxedCell(
      width: width,
      align: align,
      child: tooltip
          ? Tooltip(
              message: value,
              waitDuration: const Duration(milliseconds: 350),
              child: content,
            )
          : content,
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

    final url = '${ApiConfig.baseUrl}/images/$imageName';

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return const Icon(Icons.broken_image, color: Colors.red);
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        },
      ),
    );
  }

  Widget _imageCell({
    required List<String> names,
    required double width,
    VoidCallback? onTap,
  }) {
    final count = names.length;
    final first = count > 0 ? names.first : '';

    return _boxedCell(
      width: width,
      align: TextAlign.center,
      child: InkWell(
        onTap: count > 0 ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (count > 0)
              Expanded(child: _imageThumb(first, size: 80))
            else
              const Icon(
                Icons.image_not_supported,
                size: 18,
                color: Colors.grey,
              ),
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

  Widget _riskBadgeCell(String risk, double width) {
    final color = CommonUI.riskColor(risk);

    return _boxedCell(
      width: width,
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _statusBadgeCell(String? statusValue, double width) {
    final status = (statusValue == null || statusValue.isEmpty)
        ? 'Doing'
        : statusValue;
    final color = CommonUI.statusColor(status);

    return _boxedCell(
      width: width,
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

  Widget _boxedCell({
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

  Widget _buildPager({required int totalItems, required int totalPages}) {
    const controlBg = Color(0xFF172A33);

    return Container(
      color: const Color(0xFF0F2027),
      child: Row(
        children: [
          Text(
            'Rows: $totalItems',
            style: const TextStyle(color: Colors.white70),
          ),
          const Spacer(),
          Text(
            'Page ${_safePage + 1} / $totalPages',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _safePage == 0
                ? null
                : () {
                    setState(() {
                      _viewState = _viewState.copyWith(page: _safePage - 1);
                    });
                  },
            icon: const Icon(Icons.chevron_left),
            color: Colors.white,
            disabledColor: Colors.white38,
          ),
          IconButton(
            onPressed: (_safePage + 1 >= totalPages)
                ? null
                : () {
                    setState(() {
                      _viewState = _viewState.copyWith(page: _safePage + 1);
                    });
                  },
            icon: const Icon(Icons.chevron_right),
            color: Colors.white,
            disabledColor: Colors.white38,
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: controlBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: DropdownButton<int>(
              value: _viewState.rowsPerPage,
              underline: const SizedBox(),
              dropdownColor: controlBg,
              iconEnabledColor: Colors.white,
              style: const TextStyle(color: Colors.white),
              items: _pageSizeOptions
                  .map(
                    (size) => DropdownMenuItem<int>(
                      value: size,
                      child: Text('$size / page'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _viewState = _viewState.copyWith(rowsPerPage: value, page: 0);
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
