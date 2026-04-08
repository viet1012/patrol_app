import '../../model/patrol_export_query.dart';
import '../../model/patrol_report_model.dart';
import 'patrol_report_table_columns.dart';

class PatrolReportTableHelper {
  static String fmtDate(DateTime d) {
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$month-$day';
  }

  static PatrolReportColumnSpec columnByLabel(
    List<PatrolReportColumnSpec> columns,
    String label,
  ) {
    return columns.firstWhere((c) => c.label == label);
  }

  static double widthOf(List<PatrolReportColumnSpec> columns, String label) {
    return columnByLabel(columns, label).width;
  }

  static String cellValue(
    List<PatrolReportColumnSpec> columns,
    PatrolReportModel row,
    String columnLabel,
  ) {
    return columnByLabel(columns, columnLabel).valueGetter(row).trim();
  }

  static List<PatrolReportModel> applyFilters({
    required List<PatrolReportModel> source,
    required String query,
    required DateTime? fromDate,
    required DateTime? toDate,
    required Map<String, Set<String>> filterValues,
    required List<PatrolReportColumnSpec> columns,
    String? excludeColumn,
  }) {
    return source.where((row) {
      if (query.isNotEmpty) {
        final haystack = [
          row.stt.toString(),
          row.type ?? '',
          row.grp,
          row.plant,
          row.division,
          row.area,
          row.machine,
          row.comment,
          row.countermeasure,
          row.checkInfo,
          row.pic ?? '',
          row.atPic ?? '',
          row.atStatus ?? '',
          row.atComment ?? '',
          row.hseJudge ?? '',
          row.hseComment ?? '',
          row.loadStatus ?? '',
        ].join(' ').toLowerCase();

        if (!haystack.contains(query.toLowerCase())) return false;
      }

      if (fromDate != null) {
        final created = row.createdAt;
        final startDate = DateTime(fromDate.year, fromDate.month, fromDate.day);
        if (created == null || created.isBefore(startDate)) {
          return false;
        }
      }

      if (toDate != null) {
        final created = row.createdAt;
        final endExclusive = DateTime(
          toDate.year,
          toDate.month,
          toDate.day,
        ).add(const Duration(days: 1));

        if (created == null || !created.isBefore(endExclusive)) {
          return false;
        }
      }

      for (final entry in filterValues.entries) {
        if (entry.key == excludeColumn) continue;
        if (entry.value.isEmpty) continue;

        final value = cellValue(columns, row, entry.key);
        if (!entry.value.contains(value)) return false;
      }

      return true;
    }).toList();
  }

  static List<String> distinctColumnValues({
    required String columnLabel,
    required List<PatrolReportModel> source,
    required List<PatrolReportColumnSpec> columns,
  }) {
    final values = <String>{};

    for (final row in source) {
      final value = cellValue(columns, row, columnLabel);
      if (value.isNotEmpty) {
        values.add(value);
      }
    }

    return values.toList()..sort();
  }

  static PatrolExportQuery buildExportQuery({
    required Map<String, Set<String>> filterValues,
    required List<PatrolReportColumnSpec> columns,
    required DateTime? fromDate,
    required DateTime? toDate,
    required String patrolGroup,
    required String plant,
  }) {
    final params = <String, String>{};

    for (final entry in filterValues.entries) {
      if (entry.value.isEmpty) continue;

      final column = columnByLabel(columns, entry.key);
      final queryKey = column.queryKey;
      if (queryKey == null) continue;

      params[queryKey] = entry.value.join(',');
    }

    final now = DateTime.now();
    final from = fromDate ?? DateTime(now.year, now.month, 1);
    final to = toDate ?? DateTime(now.year, now.month, now.day);

    final patrolType = patrolGroup.trim();
    final plantValue = plant.trim();

    if (patrolType.isNotEmpty) {
      params['type'] = patrolType;
    }

    params['plant'] = plantValue;
    params['from'] = fmtDate(from);
    params['to'] = fmtDate(to);

    return PatrolExportQuery.fromMap(params);
  }
}
