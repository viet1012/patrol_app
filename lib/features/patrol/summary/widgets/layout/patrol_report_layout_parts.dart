import 'package:flutter/material.dart';

/// Desktop: summary chiếm tối đa 45% chiều cao (SPC nhiều division).
const kPatrolReportSummaryMaxHeightRatio = 0.45;

/// Mobile (summary mở): bảng cao tối thiểu 62% chiều cao, và không dưới 320.
const kPatrolReportMobileTableHeightRatio = 0.62;
const kPatrolReportMobileTableMinHeight = 320.0;

const kPatrolReportSummaryAnimDuration = Duration(milliseconds: 250);

ScrollbarThemeData patrolReportScrollbarTheme({required Color trackColor}) {
  return ScrollbarThemeData(
    thumbColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.8)),
    trackColor: WidgetStatePropertyAll(trackColor),
    trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
    radius: const Radius.circular(999),
    thickness: const WidgetStatePropertyAll(10),
    thumbVisibility: const WidgetStatePropertyAll(true),
    trackVisibility: const WidgetStatePropertyAll(true),
  );
}

/// Các khối dùng chung giữa layout desktop và mobile;
/// khác nhau chỉ ở tham số `compact` / `rowHeight`.
class PatrolReportLayoutParts {
  final bool showSummary;
  final Widget groupBar;
  final Widget summaryPage;
  final Widget? exportBanner;

  /// Thanh tiến trình mảnh khi reload (giữ dữ liệu cũ); null khi không tải.
  final Widget? reloadIndicator;
  final Widget Function({required bool compact}) toolbar;
  final Widget Function({required bool compact}) activeFilters;
  final Widget Function({required bool compact}) pagination;
  final Widget Function({required bool compact}) table;
  final Future<void> Function() onRefresh;

  const   PatrolReportLayoutParts({
    required this.showSummary,
    required this.groupBar,
    required this.summaryPage,
    required this.exportBanner,
    required this.reloadIndicator,
    required this.toolbar,
    required this.activeFilters,
    required this.pagination,
    required this.table,
    required this.onRefresh,
  });

  /// Toolbar + progress + chip filter + banner export (thứ tự dùng chung).
  List<Widget> toolbarSection({required bool compact}) => [
    toolbar(compact: compact),
    SizedBox(height: 2, child: reloadIndicator),
    activeFilters(compact: compact),
    if (exportBanner != null) exportBanner!,
  ];
}
