import 'package:chuphinh/features/patrol/summary/core/patrol_report_table_columns.dart';
import 'package:chuphinh/features/patrol/summary/core/patrol_report_table_query.dart';
import 'package:chuphinh/features/patrol/summary/core/patrol_report_table_state.dart';

/// Bộ lọc bảng <-> query param, để F5 giữ nguyên trang + bộ lọc.
///
/// Ví dụ: `/home/summary?group=Patrol&plant=SPC&fac=Fac_2&grp=Group%2010
/// &from=2026-09-01&to=2026-10-08&q=pump&f.division=CORE%20PIN&page=2&rows=50`
///
/// - `group`, `plant`: phạm vi dữ liệu của trang (giữ nguyên như cũ).
/// - `from`, `to`: yyyy-MM-dd. `q`: search. `page` (từ 1), `rows`.
/// - `fac`, `grp`: Fac / Group đang chọn ở dải lọc trên cùng (= filter cột
///   Plant / Group đúng 1 giá trị).
/// - `f.<cột>`: filter theo cột, lặp lại cho nhiều giá trị. Tên cột viết
///   thường, bỏ ký tự lạ: `Patrol User` -> `f.patroluser`, `Img(B)` -> `f.imgb`.
///
/// Tham số sai/thiếu -> dùng giá trị mặc định. Giá trị mặc định không ghi lên URL.
abstract final class PatrolReportTableUrl {
  static const path = '/home/summary';

  static const _from = 'from';
  static const _to = 'to';
  static const _q = 'q';
  static const _page = 'page';
  static const _rows = 'rows';
  static const _filterPrefix = 'f.';
  static const _fac = 'fac';
  static const _grp = 'grp';

  /// Tham số ngắn cho các cột lọc nhiều nhất (khi chọn đúng 1 giá trị).
  static const _shortKeys = {'Plant': _fac, 'Group': _grp};

  static String columnKey(String label) =>
      label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
    if (m == null) return null;
    final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    final date = DateTime(y, mo, d);
    // Loại ngày không tồn tại (vd. 2026-02-31 bị DateTime tự dồn sang tháng 3).
    if (date.year != y || date.month != mo || date.day != d) return null;
    return date;
  }

  /// Áp query param lên `defaults`. Bỏ qua mọi giá trị không hợp lệ.
  static PatrolReportTableViewState decode(
    Map<String, List<String>> params, {
    required PatrolReportTableViewState defaults,
    required List<PatrolReportColumnSpec> columns,
    required List<int> pageSizeOptions,
  }) {
    String? first(String key) {
      final v = params[key];
      return (v == null || v.isEmpty) ? null : v.first;
    }

    var from = _parseDate(first(_from)) ?? defaults.fromDate;
    var to = _parseDate(first(_to)) ?? defaults.toDate;
    if (from != null && to != null && from.isAfter(to)) {
      from = defaults.fromDate;
      to = defaults.toDate;
    }

    final rows = int.tryParse(first(_rows) ?? '');
    final page = int.tryParse(first(_page) ?? '');

    final labelsByKey = {for (final c in columns) columnKey(c.label): c.label};
    final filters = <String, Set<String>>{};
    for (final entry in params.entries) {
      if (!entry.key.startsWith(_filterPrefix)) continue;
      final label = labelsByKey[entry.key.substring(_filterPrefix.length)];
      if (label == null) continue;
      final values = {
        for (final v in entry.value)
          if (v.trim().isNotEmpty) v.trim(),
      };
      if (values.isNotEmpty) filters[label] = values;
    }
    for (final e in _shortKeys.entries) {
      final v = first(e.value)?.trim();
      if (v != null && v.isNotEmpty) filters[e.key] = {v};
    }

    return PatrolReportTableViewState(
      fromDate: from,
      toDate: to,
      searchQuery: (first(_q) ?? '').trim().toLowerCase(),
      rowsPerPage: rows != null && pageSizeOptions.contains(rows)
          ? rows
          : defaults.rowsPerPage,
      page: page != null && page >= 1 ? page - 1 : defaults.page,
      filterValues: filters,
    );
  }

  /// Chuỗi search gốc (giữ hoa/thường) để điền lại ô search.
  static String searchText(Map<String, List<String>> params) =>
      (params[_q]?.firstOrNull ?? '').trim();

  static bool _sameDay(DateTime? a, DateTime? b) =>
      (a == null && b == null) ||
      (a != null &&
          b != null &&
          a.year == b.year &&
          a.month == b.month &&
          a.day == b.day);

  /// URL đầy đủ cho trạng thái hiện tại; bỏ các giá trị mặc định.
  static Uri encode({
    required String group,
    required String plant,
    required PatrolReportTableViewState state,
    required PatrolReportTableViewState defaults,
    required String searchText,
  }) {
    final params = <String, List<String>>{
      'group': [group],
      'plant': [plant],
    };

    final datesChanged =
        !_sameDay(state.fromDate, defaults.fromDate) ||
        !_sameDay(state.toDate, defaults.toDate);
    if (datesChanged) {
      final from = state.fromDate, to = state.toDate;
      if (from != null) params[_from] = [PatrolReportTableQuery.fmtDate(from)];
      if (to != null) params[_to] = [PatrolReportTableQuery.fmtDate(to)];
    }

    if (state.searchQuery.isNotEmpty && searchText.isNotEmpty) {
      params[_q] = [searchText];
    }

    final labels = state.filterValues.keys.toList()..sort();
    for (final label in labels) {
      final values = state.filterValues[label]!.toList()..sort();
      final short = _shortKeys[label];
      if (short != null && values.length == 1) {
        params[short] = values;
      } else if (values.isNotEmpty) {
        params['$_filterPrefix${columnKey(label)}'] = values;
      }
    }

    if (state.page > 0) params[_page] = ['${state.page + 1}'];
    if (state.rowsPerPage != defaults.rowsPerPage) {
      params[_rows] = ['${state.rowsPerPage}'];
    }

    return Uri(path: path, queryParameters: params);
  }
}
