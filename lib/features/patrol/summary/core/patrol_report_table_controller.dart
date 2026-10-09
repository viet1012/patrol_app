import 'package:chuphinh/core/api/api_config.dart';
import 'package:chuphinh/core/api/hse_master_service.dart';
import 'package:chuphinh/core/api/patrol_report_api.dart';
import 'package:chuphinh/core/api/patrol_report_download_api.dart';
import 'package:chuphinh/core/models/auth_me.dart';
import 'package:chuphinh/core/models/patrol_report_model.dart';
import 'package:chuphinh/core/session/session_store.dart';
import 'package:chuphinh/features/patrol/summary/core/patrol_report_column_layout.dart';
import 'package:chuphinh/features/patrol/summary/core/patrol_report_fac_group.dart';
import 'package:chuphinh/features/patrol/summary/core/patrol_report_table_columns.dart';
import 'package:chuphinh/features/patrol/summary/core/patrol_report_table_query.dart';
import 'package:chuphinh/features/patrol/summary/core/patrol_report_table_state.dart';
import 'package:chuphinh/shared/utils/plant_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Giữ dữ liệu + trạng thái lọc/sort/phân trang của bảng patrol report.
/// Các kết quả tính toán (filtered, group counts, popup values) được cache
/// và chỉ tính lại khi dữ liệu hoặc điều kiện lọc thay đổi.
class PatrolReportTableController extends ChangeNotifier {
  static const pageSizeOptions = [15, 30, 50, 100];
  static const _startFy = 25;

  final String patrolGroup;
  final String plant;
  final String accountCode;
  final AuthMe auth;

  PatrolReportTableController({
    required this.patrolGroup,
    required this.plant,
    required this.accountCode,
    required this.auth,
    PatrolReportTableViewState? initialState,
  }) {
    _viewState = initialState ?? defaultViewState();
  }

  /// Trạng thái mặc định khi mở màn hình (không có tham số URL).
  static PatrolReportTableViewState defaultViewState() {
    final (from, to) = defaultDateRange();
    return PatrolReportTableViewState(fromDate: from, toDate: to);
  }

  final List<PatrolReportColumnSpec> columns = PatrolReportTableColumns.build();

  late final PatrolReportDownloadService _downloader =
      PatrolReportDownloadService(dio: Dio(), baseUrl: ApiConfig.baseUrl);

  late PatrolReportTableViewState _viewState;
  PatrolReportTableViewState get viewState => _viewState;

  List<PatrolReportModel> _reports = [];
  List<PatrolReportModel> get reports => _reports;

  bool _loading = false;
  bool get isLoading => _loading;

  /// `true` sau lần tải thành công đầu tiên; reload sau đó giữ dữ liệu cũ.
  bool _hasLoaded = false;
  bool get hasLoaded => _hasLoaded;

  Object? _loadError;
  Object? get loadError => _loadError;

  String? _employeeName;
  String? _patrolUser;
  int? _selectedFy;
  int? get selectedFy => _selectedFy;

  int _reportLoadGeneration = 0;
  int _employeeLoadGeneration = 0;
  bool _disposed = false;

  /// Tăng mỗi khi `_reports` thay đổi, dùng làm khoá cache.
  int _dataVersion = 0;

  _FilterKey? _filteredKey;
  List<PatrolReportModel> _filteredCache = const [];

  _FilterKey? _facGroupsKey;
  PatrolReportFacGroups _facGroupsCache = PatrolReportFacGroups.empty;
  int _catalogVersion = -1;
  Map<String, List<String>> _catalog = const {};

  _PopupKey? _popupKey;
  List<String> _popupCache = const [];

  late final bool isHse = auth.role
      .split(',')
      .map((e) => e.trim().toUpperCase())
      .where((e) => e.isNotEmpty)
      .contains('HSE');

  // ---------------------------------------------------------------- loading

  Future<void> reload() async {
    final generation = ++_reportLoadGeneration;
    _loading = true;
    _loadError = null;
    _notify();

    try {
      final data = await PatrolReportApi.fetchReports(
        type: patrolGroup,
        plant: plant,
      );
      if (_disposed || generation != _reportLoadGeneration) return;

      _reports = List<PatrolReportModel>.from(data);
      _dataVersion++;
      _hasLoaded = true;
    } catch (e) {
      if (_disposed || generation != _reportLoadGeneration) return;
      _loadError = e;
    }

    _loading = false;
    _notify();
  }

  Future<void> loadPatrolUser() async {
    final code = accountCode.trim();
    if (code.isEmpty) return;

    final generation = ++_employeeLoadGeneration;

    try {
      final name = await HseMasterService.fetchEmployeeName(code);
      if (_disposed || generation != _employeeLoadGeneration) return;

      _employeeName = name;
      _patrolUser = '${accountCode}_$name';
      _notify();
    } catch (e) {
      debugPrint('LOAD USER ERROR: $e');
    }
  }

  // ---------------------------------------------------------- derived data

  bool _isLate(PatrolReportModel report, DateTime today) {
    final status = (report.atStatus ?? 'Doing').trim();
    if (status != 'Doing' && status != 'Redo') return false;

    final due = report.dueDateUpdatedAt ?? report.dueDate;
    if (due == null) return false;

    return DateTime(due.year, due.month, due.day).isBefore(today);
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Dòng Late (dùng để tô viền trái trong bảng).
  bool isLate(PatrolReportModel report) => _isLate(report, _today());

  ComputedValueGetter _computedGetter(DateTime today) {
    return (row, columnLabel) {
      if (columnLabel == 'Due Status') {
        return _isLate(row, today) ? 'Late' : 'Still Time';
      }
      return null;
    };
  }

  /// Gồm ngày hiện tại (yyyy-MM-dd) để Late/Still Time tự đúng khi qua ngày.
  _FilterKey get _currentFilterKey => _FilterKey(
    _dataVersion,
    PatrolReportTableQuery.fmtDate(DateTime.now()),
    _viewState.searchQuery,
    _viewState.fromDate,
    _viewState.toDate,
    _viewState.filterValues,
  );

  List<PatrolReportModel> get filteredReports {
    final key = _currentFilterKey;
    if (key == _filteredKey) return _filteredCache;

    final today = _today();
    final result = PatrolReportTableQuery.applyFilters(
      source: _reports,
      query: _viewState.searchQuery,
      fromDate: _viewState.fromDate,
      toDate: _viewState.toDate,
      filterValues: _viewState.filterValues,
      columns: columns,
      computedValueGetter: _computedGetter(today),
    );

    final decorated = [for (final r in result) (r, _isLate(r, today))];
    decorated.sort((a, b) {
      if (a.$2 && !b.$2) return -1;
      if (!a.$2 && b.$2) return 1;
      return b.$1.stt.compareTo(a.$1.stt);
    });

    _filteredKey = key;
    return _filteredCache = [for (final d in decorated) d.$1];
  }

  /// Fac / Group cho dải lọc trên cùng. Số lượng theo bộ lọc hiện tại,
  /// bỏ qua lựa chọn Fac (cột Plant) và Group.
  PatrolReportFacGroups get facGroups {
    final key = _currentFilterKey;
    if (key == _facGroupsKey) return _facGroupsCache;

    if (_catalogVersion != _dataVersion) {
      _catalog = PatrolReportFacGroups.catalog(_reports);
      _catalogVersion = _dataVersion;
    }

    final base = PatrolReportTableQuery.applyFilters(
      source: _reports,
      query: _viewState.searchQuery,
      fromDate: _viewState.fromDate,
      toDate: _viewState.toDate,
      filterValues: {..._viewState.filterValues}
        ..remove(_facColumn)
        ..remove(_groupColumn),
      columns: columns,
      computedValueGetter: _computedGetter(_today()),
    );

    _facGroupsKey = key;
    return _facGroupsCache = PatrolReportFacGroups.build(
      catalog: _catalog,
      filtered: base,
    );
  }

  List<String> get popupValues {
    final column = _viewState.activeFilterColumn;
    if (column == null) return const [];

    final key = _PopupKey(_currentFilterKey, column, _viewState.filterSearch);
    if (key == _popupKey) return _popupCache;

    final base = PatrolReportTableQuery.applyFilters(
      source: _reports,
      query: _viewState.searchQuery,
      fromDate: _viewState.fromDate,
      toDate: _viewState.toDate,
      filterValues: _viewState.filterValues,
      columns: columns,
      excludeColumn: column,
    );
    final valuesInBase = PatrolReportTableQuery.distinctColumnValues(
      columnLabel: column,
      source: base,
      columns: columns,
      computedValueGetter: _computedGetter(_today()),
    );
    final selected = _viewState.filterValues[column] ?? <String>{};
    final merged = <String>[
      ...selected.where((value) => !valuesInBase.contains(value)),
      ...valuesInBase,
    ];
    final search = _viewState.filterSearch.toLowerCase();

    _popupKey = key;
    return _popupCache = merged
        .where((value) => value.toLowerCase().contains(search))
        .toList();
  }

  int totalPagesFor(int itemCount) {
    final total = (itemCount / _viewState.rowsPerPage).ceil();
    return total <= 0 ? 1 : total;
  }

  List<PatrolReportModel> pageItems(
    List<PatrolReportModel> filtered,
    int safePage,
  ) {
    if (filtered.isEmpty) return const [];

    final start = safePage * _viewState.rowsPerPage;
    final end = (start + _viewState.rowsPerPage).clamp(0, filtered.length);

    return filtered.sublist(start, end);
  }

  static const _facColumn = 'Plant';
  static const _groupColumn = 'Group';

  String? _single(String column) {
    final values = _viewState.filterValues[column];
    return values != null && values.length == 1 ? values.first : null;
  }

  /// Fac đang chọn (= filter cột Plant đúng 1 giá trị); null = Tất cả.
  String? get selectedFac => _single(_facColumn);

  /// Group đang chọn (= filter cột Group đúng 1 giá trị); null = Tất cả.
  String? get selectedGroup => _single(_groupColumn);

  bool get canClear =>
      _viewState.searchQuery.isNotEmpty || _viewState.filterValues.isNotEmpty;

  bool canEdit(PatrolReportModel report) {
    final isOwner =
        report.patrol_user?.trim() == _patrolUser?.trim() ||
        report.atAssign?.trim() == _employeeName?.trim();
    return isOwner || isHse;
  }

  // ------------------------------------------------------------- mutations

  void _update(PatrolReportTableViewState next) {
    _viewState = next;
    _notify();
  }

  /// Trả về `true` nếu query thực sự thay đổi.
  bool setSearch(String raw) {
    final query = raw.trim().toLowerCase();
    if (query == _viewState.searchQuery) return false;
    _update(_viewState.copyWith(searchQuery: query, page: 0));
    return true;
  }

  /// Chọn Fac (null = Tất cả). Group đang chọn không có ở Fac mới -> bỏ.
  void selectFac(String? fac) {
    final next = Map<String, Set<String>>.from(_viewState.filterValues);
    if (fac == null) {
      next.remove(_facColumn);
    } else {
      next[_facColumn] = {fac};
      final group = selectedGroup;
      if (group != null && !facGroups.facHasGroup(fac, group)) {
        next.remove(_groupColumn);
      }
    }
    _update(_viewState.copyWith(filterValues: next, page: 0));
  }

  /// Đặt đúng cặp Fac/Group (null = Tất cả), không toggle. Dùng cho dropdown.
  void selectFacGroup(String? fac, String? group) {
    final next = Map<String, Set<String>>.from(_viewState.filterValues);
    fac == null ? next.remove(_facColumn) : next[_facColumn] = {fac};
    group == null ? next.remove(_groupColumn) : next[_groupColumn] = {group};
    _update(_viewState.copyWith(filterValues: next, page: 0));
  }

  /// Chọn Group (null = Tất cả group của Fac đang chọn). Truyền [fac] khi
  /// bấm chip trong chế độ "Tất cả Fac" để chọn đúng cặp Fac/Group.
  /// Bấm lại chip đang chọn -> bỏ chọn.
  void selectGroup(String? group, {String? fac}) {
    final next = Map<String, Set<String>>.from(_viewState.filterValues);
    final alreadySelected =
        group != null &&
        group == selectedGroup &&
        (fac == null || fac == selectedFac);

    if (group == null || alreadySelected) {
      next.remove(_groupColumn);
    } else {
      next[_groupColumn] = {group};
      if (fac != null) next[_facColumn] = {fac};
    }
    _update(_viewState.copyWith(filterValues: next, page: 0));
  }

  /// Trả về `true` nếu đã lọc theo Plant (chế độ SPC/all plant).
  bool applySummaryFilter(String group, String division, String rowPlant) {
    final nextFilters = Map<String, Set<String>>.from(_viewState.filterValues)
      ..['Group'] = {group}
      ..['Division'] = {division};

    // SPC: cùng tên division có thể ở nhiều Fac -> lọc thêm theo Plant của dòng.
    final byPlant = isAllPlant(plant) && rowPlant.isNotEmpty;
    if (byPlant) {
      nextFilters['Plant'] = {rowPlant};
    }

    _update(_viewState.copyWith(filterValues: nextFilters, page: 0));
    return byPlant;
  }

  void setDateRange(DateTime? from, DateTime? to) {
    _update(_viewState.copyWith(fromDate: from, toDate: to, page: 0));
  }

  /// Khoảng ngày mặc định khi mở màn hình: đầu tháng trước -> hôm nay.
  static (DateTime, DateTime) defaultDateRange() {
    final now = DateTime.now();
    return (DateTime(now.year, now.month - 1, 1), now);
  }

  static bool _sameDay(DateTime? a, DateTime? b) =>
      a != null &&
      b != null &&
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;

  bool get isDefaultDateRange {
    final (from, to) = defaultDateRange();
    return _sameDay(_viewState.fromDate, from) &&
        _sameDay(_viewState.toDate, to);
  }

  void resetDateRange() {
    final (from, to) = defaultDateRange();
    _selectedFy = null;
    setDateRange(from, to);
  }

  /// Đảm bảo có from/to (mặc định tháng hiện tại) và trả về khoảng ngày.
  (DateTime, DateTime) ensureDateRange() {
    final now = DateTime.now();
    final from = _viewState.fromDate ?? DateTime(now.year, now.month, 1);
    final to = _viewState.toDate ?? DateTime(now.year, now.month, now.day);
    _update(_viewState.copyWith(fromDate: from, toDate: to));
    return (from, to);
  }

  void clearAll() {
    _update(
      PatrolReportTableViewState(
        fromDate: _viewState.fromDate,
        toDate: _viewState.toDate,
      ),
    );
  }

  void setPage(int page) => _update(_viewState.copyWith(page: page));

  void setRowsPerPage(int rows) =>
      _update(_viewState.copyWith(rowsPerPage: rows, page: 0));

  void toggleSummary() =>
      _update(_viewState.copyWith(showSummary: !_viewState.showSummary));

  void openFilter(String column) => _update(
    _viewState.copyWith(activeFilterColumn: column, filterSearch: ''),
  );

  void closeFilter() =>
      _update(_viewState.copyWith(clearActiveFilterColumn: true));

  void setFilterSearch(String value) =>
      _update(_viewState.copyWith(filterSearch: value));

  void toggleFilterValue({
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
      if (selected.isEmpty) nextFilters.remove(column);
    }

    _update(_viewState.copyWith(filterValues: nextFilters, page: 0));
  }

  void clearColumnFilter(String column) {
    final nextFilters = Map<String, Set<String>>.from(_viewState.filterValues)
      ..remove(column);
    _update(_viewState.copyWith(filterValues: nextFilters, page: 0));
  }

  void selectReport(int? id) =>
      _update(_viewState.copyWith(selectedReportId: id));

  void replaceReport(PatrolReportModel updated) {
    final index = _reports.indexWhere((e) => e.id == updated.id);
    if (index == -1) return;
    _reports[index] = updated;
    _dataVersion++;
    _notify();
  }

  /// Ném lỗi nếu tải thất bại; caller tự hiển thị thông báo.
  Future<void> downloadExcel() async {
    if (_viewState.downloading) return;
    _update(_viewState.copyWith(downloading: true));

    try {
      await _downloader.downloadExportExcel(
        query: PatrolReportTableQuery.buildExportQuery(
          filterValues: _viewState.filterValues,
          columns: columns,
          fromDate: _viewState.fromDate,
          toDate: _viewState.toDate,
          patrolGroup: patrolGroup,
          plant: plant,
        ),
        fileName: 'patrol_reports.xlsx',
      );
    } finally {
      if (!_disposed) _update(_viewState.copyWith(downloading: false));
    }
  }

  // -------------------------------------------------------------- columns

  /// Layout cột (thứ tự / ẩn / width). `columns` giữ nguyên cho lọc & export.
  PatrolReportColumnLayout _layout = const PatrolReportColumnLayout();
  int _layoutVersion = 0;
  (int, bool)? _visibleKey;
  (List<PatrolReportColumnSpec>, List<PatrolReportColumnSpec>) _visibleCache = (
    const [],
    const [],
  );

  String get _layoutPrefKey =>
      'patrol_table_columns_${accountCode.trim().isEmpty ? 'anon' : accountCode.trim()}';

  Future<void> loadColumnLayout() async {
    final saved = PatrolReportColumnLayout.tryParse(
      await SessionStore.getUiPref(_layoutPrefKey),
    );
    if (_disposed) return;
    _setLayout(saved ?? const PatrolReportColumnLayout(), save: false);
  }

  void _setLayout(PatrolReportColumnLayout next, {bool save = true}) {
    _layout = next.normalized(columns);
    _layoutVersion++;
    _notify();
    if (save) _saveLayout();
  }

  void _saveLayout() {
    SessionStore.saveUiPref(
      _layoutPrefKey,
      _layout.toJson(),
    ).catchError((Object e) => debugPrint('SAVE COLUMN LAYOUT ERROR: $e'));
  }

  /// Tất cả cột theo thứ tự hiện tại (cho menu Columns).
  List<PatrolReportColumnSpec> get orderedColumns {
    final order = _layout.normalized(columns).order;
    final byLabel = {for (final c in columns) c.label: c};
    return [for (final l in order) byLabel[l]!];
  }

  bool isColumnHidden(String label) => _layout.hidden.contains(label);

  bool get hasCustomColumns =>
      _layout.hidden.isNotEmpty ||
      _layout.widths.isNotEmpty ||
      !listEquals(
        _layout.normalized(columns).order,
        const PatrolReportColumnLayout().normalized(columns).order,
      );

  /// (pinned, scrolling). Mobile: không pin, width mặc định.
  (List<PatrolReportColumnSpec>, List<PatrolReportColumnSpec>) visibleColumns({
    required bool compact,
  }) {
    final key = (_layoutVersion, compact);
    if (key == _visibleKey) return _visibleCache;

    final pinned = <PatrolReportColumnSpec>[];
    final rest = <PatrolReportColumnSpec>[];
    for (final c in orderedColumns) {
      if (_layout.hidden.contains(c.label)) continue;
      final w = compact ? null : _layout.widths[c.label];
      final spec = w == null ? c : c.withWidth(w);
      if (!compact && PatrolReportColumnLayout.isPinned(c.label)) {
        pinned.add(spec);
      } else {
        rest.add(spec);
      }
    }

    _visibleKey = key;
    return _visibleCache = (pinned, rest);
  }

  double _defaultWidth(String label) =>
      columns.firstWhere((c) => c.label == label).width;

  /// Kéo tay nắm: cập nhật ngay, lưu khi thả (`commitColumnResize`).
  void resizeColumn(String label, double delta) {
    final current = _layout.widths[label] ?? _defaultWidth(label);
    final next = (current + delta).clamp(
      PatrolReportColumnSpec.minWidth,
      PatrolReportColumnSpec.maxWidth,
    );
    if (next == current) return;
    _setLayout(
      _layout.copyWith(widths: {..._layout.widths, label: next}),
      save: false,
    );
  }

  void commitColumnResize() => _saveLayout();

  void resetColumnWidth(String label) {
    if (!_layout.widths.containsKey(label)) return;
    _setLayout(_layout.copyWith(widths: {..._layout.widths}..remove(label)));
  }

  void setColumnVisible(String label, bool visible) {
    if (PatrolReportColumnLayout.lockedLabels.contains(label)) return;
    final hidden = {..._layout.hidden};
    visible ? hidden.remove(label) : hidden.add(label);
    _setLayout(_layout.copyWith(hidden: hidden));
  }

  /// Đổi thứ tự trong danh sách cột KHÔNG pinned (index theo danh sách đó).
  void reorderColumn(int oldIndex, int newIndex) {
    final order = orderedColumns.map((c) => c.label).toList();
    final pinnedCount = order.where(PatrolReportColumnLayout.isPinned).length;
    final movable = order.sublist(pinnedCount);
    if (newIndex > oldIndex) newIndex--;
    final item = movable.removeAt(oldIndex);
    movable.insert(newIndex, item);
    _setLayout(
      _layout.copyWith(order: [...order.take(pinnedCount), ...movable]),
    );
  }

  void resetColumns() {
    _setLayout(const PatrolReportColumnLayout(), save: false);
    SessionStore.removeUiPref(
      _layoutPrefKey,
    ).catchError((Object e) => debugPrint('RESET COLUMN LAYOUT ERROR: $e'));
  }

  // -------------------------------------------------------------- fiscal

  List<int> get fyList {
    final now = DateTime.now();
    final currentFy = now.month >= 4 ? now.year % 100 : (now.year - 1) % 100;
    return List.generate(currentFy - _startFy + 1, (i) => _startFy + i);
  }

  void selectFy(int fy) {
    _selectedFy = fy;
    _update(
      _viewState.copyWith(
        fromDate: DateTime(2000 + fy, 4, 1),
        toDate: DateTime(2000 + fy + 1, 3, 31),
      ),
    );
  }

  // ---------------------------------------------------------------- misc

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reportLoadGeneration++;
    _employeeLoadGeneration++;
    super.dispose();
  }
}

@immutable
class _FilterKey {
  final int version;
  final String day;
  final String query;
  final DateTime? from;
  final DateTime? to;
  final Map<String, Set<String>> filters;

  const _FilterKey(
    this.version,
    this.day,
    this.query,
    this.from,
    this.to,
    this.filters,
  );

  // filterValues luôn được thay bằng Map mới khi đổi -> so sánh identity là đủ.
  @override
  bool operator ==(Object other) =>
      other is _FilterKey &&
      other.version == version &&
      other.day == day &&
      other.query == query &&
      other.from == from &&
      other.to == to &&
      identical(other.filters, filters);

  @override
  int get hashCode =>
      Object.hash(version, day, query, from, to, identityHashCode(filters));
}

@immutable
class _PopupKey {
  final _FilterKey filter;
  final String column;
  final String search;

  const _PopupKey(this.filter, this.column, this.search);

  @override
  bool operator ==(Object other) =>
      other is _PopupKey &&
      other.filter == filter &&
      other.column == column &&
      other.search == search;

  @override
  int get hashCode => Object.hash(filter, column, search);
}
