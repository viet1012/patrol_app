import 'dart:async';

import 'package:chuphinh/core/models/auth_me.dart';
import 'package:chuphinh/core/models/patrol_report_model.dart';
import 'package:chuphinh/features/patrol/summary/core/patrol_report_table_columns.dart';
import 'package:chuphinh/features/patrol/summary/core/patrol_report_table_controller.dart';
import 'package:chuphinh/features/patrol/summary/core/patrol_report_table_query.dart';
import 'package:chuphinh/features/patrol/summary/core/patrol_report_table_url.dart';
import 'package:chuphinh/features/patrol/summary/dialogs/edit_report_dialog.dart';
import 'package:chuphinh/features/patrol/summary/dialogs/patrol_report_columns_dialog.dart';
import 'package:chuphinh/features/patrol/summary/dialogs/patrol_images_dialog.dart';
import 'package:chuphinh/features/patrol/summary/reports/pages/before_after_summary_dialog.dart';
import 'package:chuphinh/features/patrol/summary/reports/pages/patrol_risk_summary_page.dart';
import 'package:chuphinh/features/patrol/summary/widgets/filters/patrol_report_active_filters_bar.dart';
import 'package:chuphinh/features/patrol/summary/widgets/group/patrol_report_group_bar.dart';
import 'package:chuphinh/features/patrol/summary/widgets/header/patrol_report_table_header.dart';
import 'package:chuphinh/features/patrol/summary/widgets/layout/patrol_report_desktop_layout.dart';
import 'package:chuphinh/features/patrol/summary/widgets/layout/patrol_report_layout_parts.dart';
import 'package:chuphinh/features/patrol/summary/widgets/layout/patrol_report_mobile_layout.dart';
import 'package:chuphinh/features/patrol/summary/widgets/row/patrol_report_row.dart';
import 'package:chuphinh/features/patrol/summary/widgets/shared/patrol_report_pagination.dart';
import 'package:chuphinh/features/patrol/summary/widgets/shared/patrol_report_table_toolbar.dart';
import 'package:chuphinh/features/patrol/summary/widgets/shared/patrol_report_table_viewport.dart';
import 'package:chuphinh/features/patrol/summary/widgets/states/patrol_report_states.dart';
import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';
import 'package:chuphinh/shared/widgets/common_ui_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class PatrolReportTable extends StatefulWidget {
  final String patrolGroup;
  final String plant;
  final String accountCode;
  final AuthMe auth;

  /// Query param của URL (bộ lọc khôi phục khi F5); xem PatrolReportTableUrl.
  final Map<String, List<String>> queryParameters;

  const PatrolReportTable({
    super.key,
    required this.patrolGroup,
    required this.plant,
    required this.accountCode,
    required this.auth,
    this.queryParameters = const {},
  });

  @override
  State<PatrolReportTable> createState() => _PatrolReportTableState();
}

class _PatrolReportTableState extends State<PatrolReportTable> {
  static const _searchDebounce = Duration(milliseconds: 300);

  late final PatrolReportTableController _ctrl = PatrolReportTableController(
    patrolGroup: widget.patrolGroup,
    plant: widget.plant,
    accountCode: widget.accountCode,
    auth: widget.auth,
    initialState: PatrolReportTableUrl.decode(
      widget.queryParameters,
      defaults: PatrolReportTableController.defaultViewState(),
      columns: PatrolReportTableColumns.build(),
      pageSizeOptions: PatrolReportTableController.pageSizeOptions,
    ),
  );

  String? _lastUrl;

  final ScrollController _horizontalScrollCtrl = ScrollController();
  final ScrollController _verticalScrollCtrl = ScrollController();
  final ScrollController _filterListScrollCtrl = ScrollController();
  final ScrollController _pageScrollCtrl = ScrollController();
  final ScrollController _summaryScrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode(debugLabel: 'patrolSearch');

  final OverlayPortalController _overlayCtrl = OverlayPortalController();
  late final Map<String, LayerLink> _filterLinks = {
    for (final col in _ctrl.columns) col.label: LayerLink(),
  };

  Timer? _searchTimer;

  /// Dòng đang hover (dùng chung cho phần pinned và phần cuộn).
  final ValueNotifier<int?> _hoverRow = ValueNotifier<int?>(null);
  bool _editingReport = false;

  @override
  void initState() {
    super.initState();
    _ctrl.reload();
    _ctrl.loadPatrolUser();
    _ctrl.loadColumnLayout();
    _searchCtrl.text = PatrolReportTableUrl.searchText(widget.queryParameters);
    _searchCtrl.addListener(_onSearchChanged);
    _ctrl.addListener(_syncUrl);
  }

  /// Ghi bộ lọc lên URL (thay entry hiện tại, không thêm history) để F5
  /// giữ nguyên. Search đã debounce trước khi vào controller.
  void _syncUrl() {
    if (!kIsWeb || !mounted) return;

    final view = _ctrl.viewState;
    final typed = _searchCtrl.text.trim();
    final uri = PatrolReportTableUrl.encode(
      group: widget.patrolGroup,
      plant: widget.plant,
      state: view,
      defaults: PatrolReportTableController.defaultViewState(),
      // Giữ hoa/thường như người dùng gõ nếu khớp query đang áp dụng.
      searchText: typed.toLowerCase() == view.searchQuery
          ? typed
          : view.searchQuery,
    );

    final url = uri.toString();
    if (url == _lastUrl) return;
    _lastUrl = url;
    SystemNavigator.routeInformationUpdated(uri: uri, replace: true);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _ctrl.dispose();
    _pageScrollCtrl.dispose();
    _summaryScrollCtrl.dispose();
    _horizontalScrollCtrl.dispose();
    _verticalScrollCtrl.dispose();
    _filterListScrollCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _hoverRow.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDebounce, () {
      if (!mounted) return;
      if (_ctrl.setSearch(_searchCtrl.text)) _jumpVerticalToTop();
    });
  }

  void _jumpVerticalToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_verticalScrollCtrl.hasClients) _verticalScrollCtrl.jumpTo(0);
    });
  }

  void _jumpBothScrollsToStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_verticalScrollCtrl.hasClients) _verticalScrollCtrl.jumpTo(0);
      if (_horizontalScrollCtrl.hasClients) _horizontalScrollCtrl.jumpTo(0);
    });
  }

  void _selectFac(String? fac) {
    _ctrl.selectFac(fac);
    _jumpVerticalToTop();
  }

  void _selectGroup(String? group, {String? fac}) {
    _ctrl.selectGroup(group, fac: fac);
    _jumpVerticalToTop();
  }

  void _pickFacGroup(String? fac, String? group) {
    _ctrl.selectFacGroup(fac, group);
    _jumpVerticalToTop();
  }

  Future<void> _downloadExcel() async {
    if (_ctrl.viewState.downloading) return;

    try {
      await _ctrl.downloadExcel();
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
    }
  }

  void _applySummaryFilter(String group, String division, String plant) {
    final byPlant = _ctrl.applySummaryFilter(group, division, plant);
    _jumpVerticalToTop();

    CommonUI.showSuccessSnack(
      context,
      message: byPlant
          ? 'Filtered by $plant / $group / $division'
          : 'Filtered by $group / $division',
    );
  }

  void _applySummaryDates(DateTime from, DateTime to) {
    _ctrl.setDateRange(from, to);
    _jumpVerticalToTop();
  }

  /// Clear (toolbar), "Clear all" (thanh chip), "Clear filters" (empty state):
  /// chỉ xoá search + filter, GIỮ khoảng ngày (reset ngày có nút riêng).
  void _clearAll() {
    _searchCtrl.clear();
    _searchTimer?.cancel();
    _ctrl.clearAll();
    _overlayCtrl.hide();
    _jumpBothScrollsToStart();
  }

  void _resetDateRange() {
    _ctrl.resetDateRange();
    _jumpVerticalToTop();
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _searchTimer
        ?.cancel(); // clear() đã kích hoạt debounce; huỷ để áp dụng ngay.
    if (_ctrl.setSearch('')) _jumpVerticalToTop();
  }

  void _focusSearch() {
    _searchFocus.requestFocus();
    _searchCtrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchCtrl.text.length,
    );
  }

  /// Esc: đóng popup filter nếu đang mở, không thì xoá search.
  void _onEscape() {
    if (_ctrl.viewState.activeFilterColumn != null) {
      _closeFilterPopup();
    } else if (_searchCtrl.text.isNotEmpty) {
      _clearSearch();
    }
  }

  List<PatrolReportActiveFilter> _activeFilters() {
    final view = _ctrl.viewState;
    return [
      if (view.searchQuery.isNotEmpty)
        PatrolReportActiveFilter(
          label: 'Search',
          values: ['"${_searchCtrl.text.trim()}"'],
          icon: Icons.search_rounded,
          onRemove: _clearSearch,
        ),
      for (final entry in view.filterValues.entries)
        if (entry.value.isNotEmpty)
          PatrolReportActiveFilter(
            label: entry.key,
            values: entry.value.toList(),
            onRemove: () {
              _ctrl.clearColumnFilter(entry.key);
              _jumpVerticalToTop();
            },
          ),
      // Khoảng ngày không thành chip: đã hiện ở ô From/To (+ nút reset).
    ];
  }

  Future<void> _openBeforeAfterSummary() async {
    final (from, to) = _ctrl.ensureDateRange();

    await BeforeAfterSummaryDialog.show(
      context,
      fromD: PatrolReportTableQuery.fmtDate(from),
      toD: PatrolReportTableQuery.fmtDate(to),
      fac: widget.plant,
      type: widget.patrolGroup,
    );
  }

  void _openFilterPopup(String columnLabel) {
    _ctrl.openFilter(columnLabel);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_filterListScrollCtrl.hasClients) _filterListScrollCtrl.jumpTo(0);
    });

    _overlayCtrl.show();
  }

  void _closeFilterPopup() {
    _ctrl.closeFilter();
    _overlayCtrl.hide();
  }

  Future<void> _pickTableDate({required bool isFrom}) async {
    final now = DateTime.now();
    final view = _ctrl.viewState;
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (view.fromDate ?? now) : (view.toDate ?? now),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null || !mounted) return;

    final normalized = DateTime(picked.year, picked.month, picked.day);
    final newFrom = isFrom ? normalized : _ctrl.viewState.fromDate;
    final newTo = isFrom ? _ctrl.viewState.toDate : normalized;

    if (newFrom != null && newTo != null && newFrom.isAfter(newTo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('From date must be <= To date')),
      );
      return;
    }

    _ctrl.setDateRange(newFrom, newTo);
    _jumpVerticalToTop();
  }

  Future<void> _editReport(PatrolReportModel report) async {
    if (_editingReport) return;

    if (!_ctrl.canEdit(report)) {
      CommonUI.showWarning(
        context: context,
        title: 'Permission denied',
        message:
            'You are not allowed to edit this report.\n\n'
            'Only the creator can edit this content.',
      );
      return;
    }

    _ctrl.selectReport(report.id);
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
    _ctrl.replaceReport(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PatrolReportTokens.pageBg,
      body: SafeArea(
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyF, control: true):
                _focusSearch,
            const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
                _focusSearch,
            const SingleActivator(LogicalKeyboardKey.escape): _onEscape,
          },
          child: Focus(
            autofocus: true,
            child: ListenableBuilder(
              listenable: _ctrl,
              builder: (context, _) => _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final error = _ctrl.loadError;
    if (error != null) {
      return PatrolReportErrorView(
        message: error.toString(),
        onRetry: _ctrl.reload,
        onBack: () => context.go('/home'),
      );
    }

    // Lần tải đầu: skeleton. Reload sau đó giữ dữ liệu cũ + thanh tiến trình.
    if (!_ctrl.hasLoaded) return const PatrolReportSkeleton();

    if (_ctrl.reports.isEmpty) {
      return CommonUI.emptyState(
        context: context,
        title: 'No reports',
        message: 'There are no patrol reports yet.',
        icon: Icons.assignment_outlined,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final parts = _buildParts();

        if (constraints.maxWidth < PatrolReportTokens.mobileBreakpoint) {
          return PatrolReportMobileLayout(
            parts: parts,
            maxHeight: constraints.maxHeight,
            pageScrollController: _pageScrollCtrl,
          );
        }

        return PatrolReportDesktopLayout(
          parts: parts,
          maxHeight: constraints.maxHeight,
          summaryScrollController: _summaryScrollCtrl,
        );
      },
    );
  }

  PatrolReportLayoutParts _buildParts() {
    final view = _ctrl.viewState;
    final filtered = _ctrl.filteredReports;
    final totalPages = _ctrl.totalPagesFor(filtered.length);
    final safePage = view.page.clamp(0, totalPages - 1);
    final currentItems = _ctrl.pageItems(filtered, safePage);

    return PatrolReportLayoutParts(
      showSummary: view.showSummary,
      groupBar: _buildGroupBar(),
      summaryPage: PatrolRiskSummaryPage(
        onSelect: _applySummaryFilter,
        onDateChanged: _applySummaryDates,
        fromD: view.fromDate,
        toD: view.toDate,
        plant: widget.plant,
        patrolGroup: widget.patrolGroup,
      ),
      exportBanner: view.downloading
          ? CommonUI.exportLoadingBanner(
              accentColor: Colors.amber,
              title: 'Exporting Excel',
              subtitle: 'Large dataset detected, please wait…',
            )
          : null,
      reloadIndicator: _ctrl.isLoading
          ? const LinearProgressIndicator(
              minHeight: 2,
              color: PatrolReportTokens.accent,
              backgroundColor: Colors.transparent,
            )
          : null,
      onRefresh: _ctrl.reload,
      activeFilters: ({required compact}) => PatrolReportActiveFiltersBar(
        filters: _activeFilters(),
        onClearAll: _clearAll,
        compact: compact,
      ),
      toolbar: ({required compact}) => PatrolReportTableToolbar(
        searchController: _searchCtrl,
        searchFocusNode: _searchFocus,
        total: _ctrl.reports.length,
        shown: filtered.length,
        canClear: _ctrl.canClear,
        downloading: view.downloading,
        onBack: () => context.go('/home'),
        onReload: _ctrl.reload,
        onDownload: _downloadExcel,
        onClear: _clearAll,
        onColumns: () => PatrolReportColumnsDialog.show(context, _ctrl),
        compact: compact,
      ),
      pagination: ({required compact}) => PatrolReportPagination(
        page: safePage,
        rowsPerPage: view.rowsPerPage,
        totalItems: filtered.length,
        totalPages: totalPages,
        pageSizeOptions: PatrolReportTableController.pageSizeOptions,
        onPageChanged: _ctrl.setPage,
        onRowsPerPageChanged: _ctrl.setRowsPerPage,
        compact: compact,
        grandTotal: compact ? _ctrl.reports.length : null,
      ),
      table: ({required compact}) {
        final (pinned, scrolling) = _ctrl.visibleColumns(compact: compact);
        return PatrolReportTableViewport(
          horizontalController: _horizontalScrollCtrl,
          verticalController: _verticalScrollCtrl,
          pinnedWidth: _sumWidth(pinned),
          scrollWidth: _sumWidth(scrolling),
          pinnedHeader: pinned.isEmpty
              ? null
              : _buildHeader(pinned, compact: compact, hostsOverlay: false),
          header: _buildHeader(scrolling, compact: compact, hostsOverlay: true),
          itemCount: currentItems.length,
          pinnedRowBuilder: pinned.isEmpty
              ? null
              : (_, index) => _buildRow(
                  currentItems[index],
                  index,
                  columns: pinned,
                  compact: compact,
                  isFirstPart: true,
                ),
          rowBuilder: (_, index) => _buildRow(
            currentItems[index],
            index,
            columns: scrolling,
            compact: compact,
            isFirstPart: pinned.isEmpty,
          ),
          emptyPlaceholder: PatrolReportNoMatchView(onClearFilters: _clearAll),
        );
      },
    );
  }

  static double _sumWidth(List<PatrolReportColumnSpec> cols) =>
      cols.fold<double>(0, (sum, c) => sum + c.width);

  Widget _buildGroupBar() {
    final view = _ctrl.viewState;
    return PatrolReportGroupBar(
      facGroups: _ctrl.facGroups,
      selectedFac: _ctrl.selectedFac,
      selectedGroup: _ctrl.selectedGroup,
      fromDate: view.fromDate,
      toDate: view.toDate,
      selectedFy: _ctrl.selectedFy,
      fiscalYears: _ctrl.fyList,
      showSummary: view.showSummary,
      showGroups: view.activeFilterColumn == null,
      onSelectFac: _selectFac,
      onSelectGroup: _selectGroup,
      onPickFacGroup: _pickFacGroup,
      dateRangeChanged: !_ctrl.isDefaultDateRange,
      onResetDateRange: _resetDateRange,
      onPickFromDate: () => _pickTableDate(isFrom: true),
      onPickToDate: () => _pickTableDate(isFrom: false),
      onFySelected: _ctrl.selectFy,
      onToggleSummary: _ctrl.toggleSummary,
      onOpenReport: _openBeforeAfterSummary,
    );
  }

  Widget _buildHeader(
    List<PatrolReportColumnSpec> columns, {
    required bool compact,
    required bool hostsOverlay,
  }) {
    return PatrolReportTableHeader(
      columns: columns,
      filterLinks: _filterLinks,
      filterValues: _ctrl.viewState.filterValues,
      activeFilterColumn: _ctrl.viewState.activeFilterColumn,
      popupValues: _ctrl.popupValues,
      popupScrollController: _filterListScrollCtrl,
      overlayController: hostsOverlay ? _overlayCtrl : null,
      // Mobile: không resize.
      onResize: compact ? null : _ctrl.resizeColumn,
      onResizeEnd: compact ? null : _ctrl.commitColumnResize,
      onResetWidth: compact ? null : _ctrl.resetColumnWidth,
      onOpenFilter: _openFilterPopup,
      onCloseFilter: _closeFilterPopup,
      onFilterSearchChanged: _ctrl.setFilterSearch,
      onFilterValueChanged: (value, checked) {
        final column = _ctrl.viewState.activeFilterColumn;
        if (column == null) return;
        _ctrl.toggleFilterValue(column: column, value: value, checked: checked);
        _jumpVerticalToTop();
      },
      onClearFilter: () {
        final column = _ctrl.viewState.activeFilterColumn;
        if (column == null) return;
        _ctrl.clearColumnFilter(column);
        _jumpVerticalToTop();
      },
    );
  }

  Widget _buildRow(
    PatrolReportModel report,
    int pageIndex, {
    required List<PatrolReportColumnSpec> columns,
    required bool compact,
    required bool isFirstPart,
  }) {
    return PatrolReportRow(
      report: report,
      pageIndex: pageIndex,
      rowHeight: compact
          ? PatrolReportRow.mobileRowHeight
          : PatrolReportRow.defaultRowHeight,
      hoverIndex: compact ? null : _hoverRow,
      showLateMarker: isFirstPart && _ctrl.isLate(report),
      selected: _ctrl.viewState.selectedReportId == report.id,
      columns: columns,
      onEdit: () => _editReport(report),
      onShowBeforeImages: () =>
          _openImages(report, 'Before', report.imageNames),
      onShowAfterImages: () =>
          _openImages(report, 'After', report.atImageNames),
      onShowHseImages: () => _openImages(report, 'HSE', report.hseImageNames),
    );
  }

  /// Dialog chi tiết: lưới ảnh + thông tin report.
  void _openImages(PatrolReportModel report, String title, List<String> names) {
    PatrolImagesDialog.show(
      context: context,
      title: title,
      e: report,
      names: names,
    );
  }
}
