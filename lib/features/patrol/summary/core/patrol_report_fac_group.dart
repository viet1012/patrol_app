import 'package:chuphinh/core/models/patrol_report_model.dart';
import 'package:chuphinh/shared/utils/natural_sort.dart';

/// Danh sách Fac (= `report.plant`, nơi patrol) và Group theo từng Fac,
/// kèm số lượng theo bộ lọc hiện tại.
///
/// - Danh mục Fac/Group lấy từ toàn bộ report đã tải, nên Group có count 0
///   theo bộ lọc vẫn hiện (mờ). 1 Group có thể thuộc nhiều Fac.
/// - Số lượng tính trên dữ liệu đã lọc nhưng bỏ qua lựa chọn Fac & Group.
class PatrolReportFacGroups {
  /// Fac đã natural-sort.
  final List<String> facs;

  /// Fac -> các Group (natural-sort).
  final Map<String, List<String>> groupsByFac;

  final Map<String, int> facCounts;
  final Map<String, Map<String, int>> groupCounts;
  final int total;

  const PatrolReportFacGroups({
    required this.facs,
    required this.groupsByFac,
    required this.facCounts,
    required this.groupCounts,
    required this.total,
  });

  static const empty = PatrolReportFacGroups(
    facs: [],
    groupsByFac: {},
    facCounts: {},
    groupCounts: {},
    total: 0,
  );

  int facCount(String fac) => facCounts[fac] ?? 0;

  int groupCount(String fac, String group) => groupCounts[fac]?[group] ?? 0;

  bool facHasGroup(String fac, String group) =>
      groupsByFac[fac]?.contains(group) ?? false;

  /// Danh mục (fac -> groups) từ toàn bộ report.
  static Map<String, List<String>> catalog(Iterable<PatrolReportModel> all) {
    final map = <String, Set<String>>{};
    for (final r in all) {
      final fac = r.plant.trim();
      final grp = r.grp.trim();
      if (fac.isEmpty) continue;
      final groups = map.putIfAbsent(fac, () => <String>{});
      if (grp.isNotEmpty) groups.add(grp);
    }
    final facs = map.keys.toList()..sort(naturalCompare);
    return {for (final f in facs) f: (map[f]!.toList()..sort(naturalCompare))};
  }

  static PatrolReportFacGroups build({
    required Map<String, List<String>> catalog,
    required Iterable<PatrolReportModel> filtered,
  }) {
    final facCounts = <String, int>{};
    final groupCounts = <String, Map<String, int>>{};
    var total = 0;

    for (final r in filtered) {
      total++;
      final fac = r.plant.trim();
      if (fac.isEmpty) continue;
      facCounts[fac] = (facCounts[fac] ?? 0) + 1;
      final grp = r.grp.trim();
      if (grp.isEmpty) continue;
      final byGroup = groupCounts.putIfAbsent(fac, () => <String, int>{});
      byGroup[grp] = (byGroup[grp] ?? 0) + 1;
    }

    return PatrolReportFacGroups(
      facs: catalog.keys.toList(),
      groupsByFac: catalog,
      facCounts: facCounts,
      groupCounts: groupCounts,
      total: total,
    );
  }
}
