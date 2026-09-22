import 'package:chuphinh/common/common_ui_helper.dart';
import 'package:chuphinh/table/core/patrol_report_table_columns.dart';
import 'package:chuphinh/table/core/patrol_report_table_query.dart';
import 'package:chuphinh/table/core/patrol_report_table_state.dart';
import 'package:chuphinh/table/dialogs/edit_report_dialog.dart';
import 'package:chuphinh/table/dialogs/patrol_images_dialog.dart';
import 'package:chuphinh/table/summary/pages/before_after_summary_page.dart';
import 'package:chuphinh/table/summary/pages/patrol_risk_summary_page.dart';
import 'package:chuphinh/table/widgets/group/patrol_report_group_bar.dart';
import 'package:chuphinh/table/widgets/header/patrol_report_table_header.dart';
import 'package:chuphinh/table/widgets/row/patrol_report_row.dart';
import 'package:chuphinh/table/widgets/shared/patrol_report_pagination.dart';
import 'package:chuphinh/table/widgets/shared/patrol_report_table_toolbar.dart';
import 'package:chuphinh/table/widgets/shared/patrol_report_table_viewport.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_config.dart';
import '../api/hse_master_service.dart';
import '../api/patrol_report_api.dart';
import '../api/patrol_report_download_api.dart';
import '../model/auth_me.dart';
import '../model/patrol_report_model.dart';

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

  Future<List<PatrolReportModel>>? _futureReports;
  late final List<PatrolReportColumnSpec> _columns =
      PatrolReportTableColumns.build();

  List<PatrolReportModel> _reports = [];

  late PatrolReportTableViewState _viewState;

  String? _employeeName;
  String? _patrolUser;
  int _reportLoadGeneration = 0;
  int _employeeLoadGeneration = 0;
  bool _editingReport = false;

  final ScrollController _pageScrollCtrl = ScrollController();

  int? _selectedFy;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    debugPrint("ACCOUNT CODE = ${widget.accountCode}");
    _viewState = PatrolReportTableViewState(
      toDate: now,
      fromDate: DateTime(now.year, now.month - 1, 1),
    );

    _reload();

    _loadPatrolUser();

    for (final col in _columns) {
      _filterLinks[col.label] = LayerLink();
    }

    _searchCtrl.addListener(_onSearchChanged);
  }

  void _reload() {
    final generation = ++_reportLoadGeneration;

    setState(() {
      _futureReports = _loadReports(generation);
    });
  }

  Future<void> _loadPatrolUser() async {
    final code = widget.accountCode.trim();

    if (code.isEmpty) return;
    final generation = ++_employeeLoadGeneration;

    try {
      final name = await HseMasterService.fetchEmployeeName(code);

      if (!mounted || generation != _employeeLoadGeneration) return;

      final patrolUser = "${widget.accountCode}_$name";

      setState(() {
        _employeeName = name;
        _patrolUser = patrolUser;
      });

      debugPrint("PATROL USER = $patrolUser");
    } catch (e) {
      debugPrint("LOAD USER ERROR: $e");
    }
  }

  Future<List<PatrolReportModel>> _loadReports(int generation) async {
    final data = await PatrolReportApi.fetchReports(
      type: widget.patrolGroup,
      plant: widget.plant,
    );

    if (!mounted || generation != _reportLoadGeneration) {
      return data;
    }

    _reports = List<PatrolReportModel>.from(data);
    return _reports;
  }

  @override
  void dispose() {
    _reportLoadGeneration++;
    _employeeLoadGeneration++;
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
    final result = PatrolReportTableQuery.applyFilters(
      source: _reports,
      query: _viewState.searchQuery,
      fromDate: _viewState.fromDate,
      toDate: _viewState.toDate,
      filterValues: _viewState.filterValues,
      columns: _columns,
      computedValueGetter: _computedFilterValue,
    );

    result.sort((a, b) {
      final aLate = _isLate(a);
      final bLate = _isLate(b);

      if (aLate && !bLate) return -1;
      if (!aLate && bLate) return 1;

      return b.stt.compareTo(a.stt);
    });

    return result;
  }

  bool _isLate(PatrolReportModel report) {
    final status = (report.atStatus ?? 'Doing').trim();

    if (status != 'Doing' && status != 'Redo') {
      return false;
    }

    final due = report.dueDateUpdatedAt ?? report.dueDate;

    if (due == null) {
      return false;
    }

    final today = DateTime.now();

    final current = DateTime(today.year, today.month, today.day);

    final target = DateTime(due.year, due.month, due.day);

    return target.isBefore(current);
  }

  int _totalPagesFor(int itemCount) {
    final total = (itemCount / _viewState.rowsPerPage).ceil();
    return total <= 0 ? 1 : total;
  }

  List<PatrolReportModel> _pageItems(
    List<PatrolReportModel> filtered,
    int safePage,
  ) {
    if (filtered.isEmpty) return const [];

    final start = safePage * _viewState.rowsPerPage;
    final end = (start + _viewState.rowsPerPage).clamp(0, filtered.length);

    return filtered.sublist(start, end);
  }

  Map<String, int> get _groupCaseCounts {
    final base = PatrolReportTableQuery.applyFilters(
      source: _reports,
      query: _viewState.searchQuery,
      fromDate: _viewState.fromDate,
      toDate: _viewState.toDate,
      filterValues: _viewState.filterValues,
      columns: _columns,
      excludeColumn: 'Group',
      computedValueGetter: _computedFilterValue,
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
    final roles = (widget.auth.role ?? '')
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    return roles.contains('HSE');
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
        query: PatrolReportTableQuery.buildExportQuery(
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

  String? _computedFilterValue(PatrolReportModel row, String columnLabel) {
    if (columnLabel == 'Due Status') {
      return _isLate(row) ? 'Late' : 'Still Time';
    }

    return null;
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

  void _applySummaryDates(DateTime from, DateTime to) {
    setState(() {
      _viewState = _viewState.copyWith(fromDate: from, toDate: to, page: 0);
    });
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
      fromD: PatrolReportTableQuery.fmtDate(from),
      toD: PatrolReportTableQuery.fmtDate(to),
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

  Future<void> _editReport(PatrolReportModel report) async {
    if (_editingReport) return;

    final canEdit =
        report.patrol_user?.trim() == _patrolUser?.trim() ||
        report.atAssign?.trim() == _employeeName?.trim();

    if (!canEdit && !isHse) {
      CommonUI.showWarning(
        context: context,
        title: 'Permission denied',
        message:
            'You are not allowed to edit this report.\n\n'
            'Only the creator can edit this content.',
      );
      return;
    }

    setState(() {
      _viewState = _viewState.copyWith(selectedReportId: report.id);
    });

    _editingReport = true;

    PatrolReportModel? result;

    try {
      result = await EditReportDialog.show(
        context,
        model: report,
        me: widget.auth,
      );
    } finally {
      _editingReport = false;
    }

    if (!mounted || result == null) return;

    final updatedReport = result;

    setState(() {
      final index = _reports.indexWhere((e) => e.id == updatedReport.id);

      if (index != -1) {
        _reports[index] = updatedReport;
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
          future: _futureReports!,
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
            final totalPages = _totalPagesFor(filtered.length);
            final safePage = _viewState.page.clamp(0, totalPages - 1);
            final currentItems = _pageItems(filtered, safePage);
            final tableWidth = _columns.fold<double>(
              0,
              (sum, column) => sum + column.width,
            );

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
                                        child: PatrolRiskSummaryPage(
                                          onSelect: _applySummaryFilter,
                                          onDateChanged: _applySummaryDates,
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

                              PatrolReportTableToolbar(
                                searchController: _searchCtrl,
                                total: _reports.length,
                                shown: filtered.length,
                                canClear:
                                    _viewState.searchQuery.isNotEmpty ||
                                    _viewState.filterValues.isNotEmpty,
                                downloading: _viewState.downloading,
                                onBack: () => context.go('/home'),
                                onReload: _reload,
                                onDownload: _downloadExcel,
                                onClear: _clearAll,
                              ),

                              if (_viewState.downloading)
                                CommonUI.exportLoadingBanner(
                                  accentColor: Colors.amber,
                                  title: 'Exporting Excel',
                                  subtitle:
                                      'Large dataset detected, please waitâ€¦',
                                ),

                              Expanded(
                                child: PatrolReportTableViewport(
                                  horizontalController: _horizontalScrollCtrl,
                                  verticalController: _verticalScrollCtrl,
                                  totalWidth: tableWidth,
                                  header: _buildHeader(),
                                  itemCount: currentItems.length,
                                  rowBuilder: (_, index) =>
                                      _buildRow(currentItems[index], index),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      PatrolReportPagination(
                        page: safePage,
                        rowsPerPage: _viewState.rowsPerPage,
                        totalItems: filtered.length,
                        totalPages: totalPages,
                        pageSizeOptions: _pageSizeOptions,
                        onPageChanged: (page) {
                          setState(() {
                            _viewState = _viewState.copyWith(page: page);
                          });
                        },
                        onRowsPerPageChanged: (rows) {
                          setState(() {
                            _viewState = _viewState.copyWith(
                              rowsPerPage: rows,
                              page: 0,
                            );
                          });
                        },
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
                                          child: PatrolRiskSummaryPage(
                                            onSelect: _applySummaryFilter,
                                            onDateChanged: _applySummaryDates,
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

                                PatrolReportTableToolbar(
                                  searchController: _searchCtrl,
                                  total: _reports.length,
                                  shown: filtered.length,
                                  canClear:
                                      _viewState.searchQuery.isNotEmpty ||
                                      _viewState.filterValues.isNotEmpty,
                                  downloading: _viewState.downloading,
                                  onBack: () => context.go('/home'),
                                  onReload: _reload,
                                  onDownload: _downloadExcel,
                                  onClear: _clearAll,
                                ),

                                if (_viewState.downloading)
                                  CommonUI.exportLoadingBanner(
                                    accentColor: Colors.amber,
                                    title: 'Exporting Excel',
                                    subtitle:
                                        'Large dataset detected, please waitâ€¦',
                                  ),

                                SizedBox(
                                  height: constraints.maxHeight * 0.62,
                                  child: PatrolReportTableViewport(
                                    horizontalController: _horizontalScrollCtrl,
                                    verticalController: _verticalScrollCtrl,
                                    totalWidth: tableWidth,
                                    header: _buildHeader(),
                                    itemCount: currentItems.length,
                                    rowBuilder: (_, index) =>
                                        _buildRow(currentItems[index], index),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    PatrolReportPagination(
                      page: safePage,
                      rowsPerPage: _viewState.rowsPerPage,
                      totalItems: filtered.length,
                      totalPages: totalPages,
                      pageSizeOptions: _pageSizeOptions,
                      onPageChanged: (page) {
                        setState(() {
                          _viewState = _viewState.copyWith(page: page);
                        });
                      },
                      onRowsPerPageChanged: (rows) {
                        setState(() {
                          _viewState = _viewState.copyWith(
                            rowsPerPage: rows,
                            page: 0,
                          );
                        });
                      },
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
    return PatrolReportGroupBar(
      groupCounts: _groupCaseCounts,
      selectedGroup: _selectedGroup,
      fromDate: _viewState.fromDate,
      toDate: _viewState.toDate,
      selectedFy: _selectedFy,
      fiscalYears: _fyList,
      showSummary: _viewState.showSummary,
      showGroups: _viewState.activeFilterColumn == null,
      onGroupSelected: _onTapGroup,
      onPickFromDate: () => _pickTableDate(isFrom: true),
      onPickToDate: () => _pickTableDate(isFrom: false),
      onFySelected: (fy) {
        setState(() {
          _selectedFy = fy;
          _viewState = _viewState.copyWith(
            fromDate: _fyFromDate(fy),
            toDate: _fyToDate(fy),
          );
        });
      },
      onToggleSummary: () {
        setState(() {
          _viewState = _viewState.copyWith(
            showSummary: !_viewState.showSummary,
          );
        });
      },
      onOpenReport: _openBeforeAfterSummary,
    );
  }

  List<int> get _fyList {
    final now = DateTime.now();
    final currentFy = now.month >= 4 ? now.year % 100 : (now.year - 1) % 100;
    const startFy = 25;
    return List.generate(currentFy - startFy + 1, (i) => startFy + i);
  }

  DateTime _fyFromDate(int fy) => DateTime(2000 + fy, 4, 1);

  DateTime _fyToDate(int fy) => DateTime(2000 + fy + 1, 3, 31);

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
    if (picked == null || !mounted) return;

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

  Widget _buildHeader() {
    final column = _viewState.activeFilterColumn;
    var popupValues = const <String>[];
    if (column != null) {
      final base = PatrolReportTableQuery.applyFilters(
        source: _reports,
        query: _viewState.searchQuery,
        fromDate: _viewState.fromDate,
        toDate: _viewState.toDate,
        filterValues: _viewState.filterValues,
        columns: _columns,
        excludeColumn: column,
      );
      final valuesInBase = PatrolReportTableQuery.distinctColumnValues(
        columnLabel: column,
        source: base,
        columns: _columns,
        computedValueGetter: _computedFilterValue,
      );
      final selected = _viewState.filterValues[column] ?? <String>{};
      final merged = <String>[
        ...selected.where((value) => !valuesInBase.contains(value)),
        ...valuesInBase,
      ];
      final search = _viewState.filterSearch.toLowerCase();
      popupValues = merged
          .where((value) => value.toLowerCase().contains(search))
          .toList();
    }

    return PatrolReportTableHeader(
      columns: _columns,
      filterLinks: _filterLinks,
      filterValues: _viewState.filterValues,
      activeFilterColumn: column,
      popupValues: popupValues,
      popupScrollController: _filterListScrollCtrl,
      overlayController: _overlayCtrl,
      onOpenFilter: _openFilterPopup,
      onCloseFilter: _closeFilterPopup,
      onFilterSearchChanged: (value) {
        setState(() {
          _viewState = _viewState.copyWith(filterSearch: value);
        });
      },
      onFilterValueChanged: (value, checked) {
        final activeColumn = _viewState.activeFilterColumn;
        if (activeColumn != null) {
          _toggleFilterValue(
            column: activeColumn,
            value: value,
            checked: checked,
          );
        }
      },
      onClearFilter: () {
        final activeColumn = _viewState.activeFilterColumn;
        if (activeColumn != null) _clearColumnFilter(activeColumn);
      },
    );
  }

  Widget _buildRow(PatrolReportModel report, int pageIndex) {
    return PatrolReportRow(
      report: report,
      pageIndex: pageIndex,
      selected: _viewState.selectedReportId == report.id,
      columns: _columns,
      onEdit: () => _editReport(report),
      onShowBeforeImages: () => PatrolImagesDialog.show(
        context: context,
        title: 'Before',
        e: report,
        names: report.imageNames,
      ),
      onShowAfterImages: () => PatrolImagesDialog.show(
        context: context,
        title: 'After',
        e: report,
        names: report.atImageNames,
      ),
      onShowHseImages: () => PatrolImagesDialog.show(
        context: context,
        title: 'HSE',
        e: report,
        names: report.hseImageNames,
      ),
    );
  }
}
