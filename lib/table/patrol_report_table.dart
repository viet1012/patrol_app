// import 'package:chuphinh/common/common_ui_helper.dart';
// import 'package:chuphinh/table/patrol_images_dialog.dart';
// import 'package:chuphinh/table/patrol_summary_chart_page.dart';
// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
//
// import '../api/api_config.dart';
// import '../api/patrol_report_api.dart';
// import '../api/patrol_report_download_api.dart';
// import '../model/patrol_export_query.dart';
// import '../model/patrol_report_model.dart';
// import '../widget/glass_action_button.dart';
// import 'before_after_summary_page.dart';
// import 'edit_report_dialog.dart';
//
// class PatrolReportTable extends StatefulWidget {
//   final String patrolGroup;
//   final String plant;
//
//   const PatrolReportTable({
//     super.key,
//     required this.patrolGroup,
//     required this.plant,
//   });
//
//   @override
//   State<PatrolReportTable> createState() => _PatrolReportTableState();
// }
//
// class _PatrolReportTableState extends State<PatrolReportTable> {
//   static const _pageSizeOptions = [15, 30, 50, 100];
//
//   final ScrollController _horizontalScrollCtrl = ScrollController();
//   final ScrollController _verticalScrollCtrl = ScrollController();
//   final ScrollController _filterListScrollCtrl = ScrollController();
//   final TextEditingController _searchCtrl = TextEditingController();
//
//   final OverlayPortalController _overlayCtrl = OverlayPortalController();
//   final Map<String, LayerLink> _filterLinks = {};
//
//   late final Future<List<PatrolReportModel>> _futureReports;
//   late final List<_ColumnSpec> _columns = _buildColumns();
//
//   List<PatrolReportModel> _reports = [];
//
//   DateTime? _fromDate;
//   DateTime? _toDate;
//
//   String _searchQuery = '';
//   String _filterSearch = '';
//
//   int _rowsPerPage = 30;
//   int _page = 0;
//   int? _selectedReportId;
//
//   bool _showSummary = true;
//   bool _downloading = false;
//
//   String? _activeFilterColumn;
//   final Map<String, Set<String>> _filterValues = {};
//
//   @override
//   void initState() {
//     super.initState();
//
//     final now = DateTime.now();
//     _toDate = now;
//     _fromDate = DateTime(now.year, now.month - 1, 1);
//
//     _futureReports = _loadReports();
//
//     for (final col in _columns) {
//       _filterLinks[col.label] = LayerLink();
//     }
//
//     _searchCtrl.addListener(_onSearchChanged);
//   }
//
//   Future<List<PatrolReportModel>> _loadReports() async {
//     final data = await PatrolReportApi.fetchReports(
//       type: widget.patrolGroup,
//       plant: widget.plant,
//     );
//     _reports = List<PatrolReportModel>.from(data);
//     return _reports;
//   }
//
//   void _onSearchChanged() {
//     setState(() {
//       _searchQuery = _searchCtrl.text.trim().toLowerCase();
//       _page = 0;
//     });
//
//     _jumpVerticalToTop();
//   }
//
//   @override
//   void dispose() {
//     _horizontalScrollCtrl.dispose();
//     _verticalScrollCtrl.dispose();
//     _filterListScrollCtrl.dispose();
//     _searchCtrl.dispose();
//     super.dispose();
//   }
//
//   List<_ColumnSpec> _buildColumns() {
//     return [
//       _ColumnSpec(
//         label: 'STT',
//         width: 70,
//         align: TextAlign.center,
//         valueGetter: (e) => e.stt.toString(),
//       ),
//       _ColumnSpec(
//         label: 'QR',
//         width: 70,
//         align: TextAlign.center,
//         queryKey: 'qrKey',
//         valueGetter: (e) => e.qr_key?.toString() ?? '',
//       ),
//       _ColumnSpec(
//         label: 'Group',
//         width: 70,
//         align: TextAlign.left,
//         queryKey: 'grp',
//         valueGetter: (e) => e.grp,
//       ),
//       _ColumnSpec(
//         label: 'Plant',
//         width: 70,
//         align: TextAlign.left,
//         queryKey: 'plant',
//         valueGetter: (e) => e.plant,
//       ),
//       _ColumnSpec(
//         label: 'Division',
//         width: 90,
//         align: TextAlign.left,
//         queryKey: 'division',
//         valueGetter: (e) => e.division,
//       ),
//       _ColumnSpec(
//         label: 'Area',
//         width: 120,
//         align: TextAlign.left,
//         queryKey: 'area',
//         valueGetter: (e) => e.area,
//       ),
//       _ColumnSpec(
//         label: 'Machine',
//         width: 100,
//         align: TextAlign.left,
//         queryKey: 'machine',
//         valueGetter: (e) => e.machine,
//       ),
//       _ColumnSpec(
//         label: 'Patrol User',
//         width: 110,
//         align: TextAlign.left,
//         queryKey: 'patrolUser',
//         valueGetter: (e) => e.patrol_user ?? '',
//       ),
//       _ColumnSpec(
//         label: 'Img(B)',
//         width: 90,
//         align: TextAlign.center,
//         valueGetter: (_) => '',
//       ),
//       _ColumnSpec(
//         label: 'Risk T',
//         width: 90,
//         align: TextAlign.center,
//         valueGetter: (e) => e.riskTotal,
//       ),
//       _ColumnSpec(
//         label: 'Comment',
//         width: 260,
//         align: TextAlign.left,
//         valueGetter: (e) => e.comment,
//       ),
//       _ColumnSpec(
//         label: 'Countermeasure',
//         width: 260,
//         align: TextAlign.left,
//         valueGetter: (e) => e.countermeasure,
//       ),
//       _ColumnSpec(
//         label: 'Created',
//         width: 100,
//         align: TextAlign.center,
//         valueGetter: (e) => CommonUI.fmtDate(e.createdAt),
//       ),
//       _ColumnSpec(
//         label: 'Due',
//         width: 100,
//         align: TextAlign.center,
//         valueGetter: (e) => CommonUI.fmtDate(e.dueDate),
//       ),
//       _ColumnSpec(
//         label: 'PIC',
//         width: 90,
//         align: TextAlign.left,
//         queryKey: 'pic',
//         valueGetter: (e) => e.pic ?? '',
//       ),
//       _ColumnSpec(
//         label: 'Check Info',
//         width: 120,
//         align: TextAlign.left,
//         valueGetter: (e) => e.checkInfo,
//       ),
//       _ColumnSpec(
//         label: 'Risk F',
//         width: 120,
//         align: TextAlign.center,
//         valueGetter: (e) => e.riskFreq,
//       ),
//       _ColumnSpec(
//         label: 'Risk P',
//         width: 100,
//         align: TextAlign.center,
//         valueGetter: (e) => e.riskProb,
//       ),
//       _ColumnSpec(
//         label: 'Risk S',
//         width: 100,
//         align: TextAlign.center,
//         valueGetter: (e) => e.riskSev,
//       ),
//       _ColumnSpec(
//         label: 'AT Stt',
//         width: 100,
//         align: TextAlign.center,
//         queryKey: 'afStatus',
//         valueGetter: (e) => e.atStatus ?? '',
//       ),
//       _ColumnSpec(
//         label: 'AT PIC',
//         width: 90,
//         align: TextAlign.left,
//         valueGetter: (e) => e.atPic ?? '',
//       ),
//       _ColumnSpec(
//         label: 'AT Date',
//         width: 100,
//         align: TextAlign.center,
//         valueGetter: (e) => CommonUI.fmtDate(e.atDate),
//       ),
//       _ColumnSpec(
//         label: 'AT Cmt',
//         width: 260,
//         align: TextAlign.left,
//         valueGetter: (e) => e.atComment ?? '',
//       ),
//       _ColumnSpec(
//         label: 'Img(A)',
//         width: 100,
//         align: TextAlign.center,
//         valueGetter: (_) => '',
//       ),
//       _ColumnSpec(
//         label: 'HSE J',
//         width: 90,
//         align: TextAlign.center,
//         valueGetter: (e) => e.hseJudge ?? '',
//       ),
//       _ColumnSpec(
//         label: 'HSE D',
//         width: 100,
//         align: TextAlign.center,
//         valueGetter: (e) => CommonUI.fmtDate(e.hseDate),
//       ),
//       _ColumnSpec(
//         label: 'HSE C',
//         width: 260,
//         align: TextAlign.left,
//         valueGetter: (e) => e.hseComment ?? '',
//       ),
//       _ColumnSpec(
//         label: 'Img(H)',
//         width: 100,
//         align: TextAlign.center,
//         valueGetter: (_) => '',
//       ),
//       _ColumnSpec(
//         label: 'Load',
//         width: 100,
//         align: TextAlign.center,
//         valueGetter: (e) => e.loadStatus ?? '',
//       ),
//     ];
//   }
//
//   String _fmtDate(DateTime d) {
//     final month = d.month.toString().padLeft(2, '0');
//     final day = d.day.toString().padLeft(2, '0');
//     return '${d.year}-$month-$day';
//   }
//
//   _ColumnSpec _columnByLabel(String label) {
//     return _columns.firstWhere((c) => c.label == label);
//   }
//
//   double _widthOf(String label) => _columnByLabel(label).width;
//
//   String _cellValue(PatrolReportModel row, String columnLabel) {
//     return _columnByLabel(columnLabel).valueGetter(row).trim();
//   }
//
//   List<PatrolReportModel> get _filteredReports {
//     return _applyFilters(_reports, query: _searchQuery);
//   }
//
//   int get _totalPages {
//     final total = (_filteredReports.length / _rowsPerPage).ceil();
//     return total <= 0 ? 1 : total;
//   }
//
//   int get _safePage => _page.clamp(0, _totalPages - 1);
//
//   List<PatrolReportModel> get _currentPageItems {
//     final filtered = _filteredReports;
//     if (filtered.isEmpty) return const [];
//
//     final start = _safePage * _rowsPerPage;
//     final end = (start + _rowsPerPage).clamp(0, filtered.length);
//
//     return filtered.sublist(start, end);
//   }
//
//   List<PatrolReportModel> _applyFilters(
//     List<PatrolReportModel> source, {
//     required String query,
//     String? excludeColumn,
//   }) {
//     return source.where((row) {
//       if (query.isNotEmpty) {
//         final haystack = [
//           row.stt.toString(),
//           row.type ?? '',
//           row.grp,
//           row.plant,
//           row.division,
//           row.area,
//           row.machine,
//           row.comment,
//           row.countermeasure,
//           row.checkInfo,
//           row.pic ?? '',
//           row.atPic ?? '',
//           row.atStatus ?? '',
//           row.atComment ?? '',
//           row.hseJudge ?? '',
//           row.hseComment ?? '',
//           row.loadStatus ?? '',
//         ].join(' ').toLowerCase();
//
//         if (!haystack.contains(query)) return false;
//       }
//
//       if (_fromDate != null) {
//         final created = row.createdAt;
//         final startDate = DateTime(
//           _fromDate!.year,
//           _fromDate!.month,
//           _fromDate!.day,
//         );
//         if (created == null || created.isBefore(startDate)) {
//           return false;
//         }
//       }
//
//       if (_toDate != null) {
//         final created = row.createdAt;
//         final endExclusive = DateTime(
//           _toDate!.year,
//           _toDate!.month,
//           _toDate!.day,
//         ).add(const Duration(days: 1));
//
//         if (created == null || !created.isBefore(endExclusive)) {
//           return false;
//         }
//       }
//
//       for (final entry in _filterValues.entries) {
//         if (entry.key == excludeColumn) continue;
//         if (entry.value.isEmpty) continue;
//
//         final value = _cellValue(row, entry.key);
//         if (!entry.value.contains(value)) return false;
//       }
//
//       return true;
//     }).toList();
//   }
//
//   List<String> _distinctColumnValues(
//     String columnLabel,
//     List<PatrolReportModel> source,
//   ) {
//     final values = <String>{};
//
//     for (final row in source) {
//       final value = _cellValue(row, columnLabel);
//       if (value.isNotEmpty) {
//         values.add(value);
//       }
//     }
//
//     return values.toList()..sort();
//   }
//
//   PatrolExportQuery _buildExportQuery() {
//     final params = <String, String>{};
//
//     for (final entry in _filterValues.entries) {
//       if (entry.value.isEmpty) continue;
//
//       final column = _columnByLabel(entry.key);
//       final queryKey = column.queryKey;
//       if (queryKey == null) continue;
//
//       params[queryKey] = entry.value.join(',');
//     }
//
//     final now = DateTime.now();
//     final from = _fromDate ?? DateTime(now.year, now.month, 1);
//     final to = _toDate ?? DateTime(now.year, now.month, now.day);
//
//     final patrolType = widget.patrolGroup.trim();
//     final plant = widget.plant.trim();
//
//     if (patrolType.isNotEmpty) {
//       params['type'] = patrolType;
//     }
//
//     params['plant'] = plant;
//     params['from'] = _fmtDate(from);
//     params['to'] = _fmtDate(to);
//
//     return PatrolExportQuery.fromMap(params);
//   }
//
//   void _jumpVerticalToTop() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_verticalScrollCtrl.hasClients) {
//         _verticalScrollCtrl.jumpTo(0);
//       }
//     });
//   }
//
//   void _jumpBothScrollsToStart() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_verticalScrollCtrl.hasClients) {
//         _verticalScrollCtrl.jumpTo(0);
//       }
//       if (_horizontalScrollCtrl.hasClients) {
//         _horizontalScrollCtrl.jumpTo(0);
//       }
//     });
//   }
//
//   Future<void> _downloadExcel() async {
//     if (_downloading) return;
//
//     setState(() => _downloading = true);
//
//     try {
//       final downloader = PatrolReportDownloadService(
//         dio: Dio(),
//         baseUrl: ApiConfig.baseUrl,
//       );
//
//       await downloader.downloadExportExcel(
//         query: _buildExportQuery(),
//         fileName: 'patrol_reports.xlsx',
//       );
//
//       if (!mounted) return;
//       CommonUI.showSuccessSnack(
//         context,
//         message: 'Excel file downloaded successfully',
//       );
//     } catch (e) {
//       if (!mounted) return;
//       CommonUI.showWarning(
//         context: context,
//         title: 'Warning',
//         message: 'Download failed: $e',
//       );
//     } finally {
//       if (!mounted) return;
//       setState(() => _downloading = false);
//     }
//   }
//
//   void _applySummaryFilter(String group, String division) {
//     setState(() {
//       _filterValues['Group'] = {group};
//       _filterValues['Division'] = {division};
//       _page = 0;
//     });
//
//     _jumpVerticalToTop();
//
//     CommonUI.showSuccessSnack(
//       context,
//       message: 'Filtered by $group / $division',
//     );
//   }
//
//   void _clearAll() {
//     setState(() {
//       _searchCtrl.clear();
//       _searchQuery = '';
//       _filterSearch = '';
//       _filterValues.clear();
//       _activeFilterColumn = null;
//       _selectedReportId = null;
//       _page = 0;
//     });
//
//     _overlayCtrl.hide();
//     _jumpBothScrollsToStart();
//   }
//
//   Future<void> _openBeforeAfterSummary() async {
//     final now = DateTime.now();
//     final from = _fromDate ?? DateTime(now.year, now.month, 1);
//     final to = _toDate ?? DateTime(now.year, now.month, now.day);
//
//     setState(() {
//       _fromDate = from;
//       _toDate = to;
//     });
//
//     await BeforeAfterSummaryDialog.show(
//       context,
//       fromD: _fmtDate(from),
//       toD: _fmtDate(to),
//       fac: widget.plant,
//       type: widget.patrolGroup,
//     );
//   }
//
//   void _openFilterPopup(String columnLabel) {
//     setState(() {
//       _activeFilterColumn = columnLabel;
//       _filterSearch = '';
//     });
//
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_filterListScrollCtrl.hasClients) {
//         _filterListScrollCtrl.jumpTo(0);
//       }
//     });
//
//     _overlayCtrl.show();
//   }
//
//   void _closeFilterPopup() {
//     setState(() => _activeFilterColumn = null);
//     _overlayCtrl.hide();
//   }
//
//   void _toggleFilterValue({
//     required String column,
//     required String value,
//     required bool checked,
//   }) {
//     setState(() {
//       final selected = _filterValues.putIfAbsent(column, () => <String>{});
//       if (checked) {
//         selected.add(value);
//       } else {
//         selected.remove(value);
//         if (selected.isEmpty) {
//           _filterValues.remove(column);
//         }
//       }
//       _page = 0;
//     });
//
//     _jumpVerticalToTop();
//   }
//
//   void _clearColumnFilter(String column) {
//     setState(() {
//       _filterValues.remove(column);
//       _page = 0;
//     });
//
//     _jumpVerticalToTop();
//   }
//
//   Future<void> _editReport(PatrolReportModel report) async {
//     setState(() => _selectedReportId = report.id);
//
//     final updated = await EditReportDialog.show(context, model: report);
//     if (updated == null || !mounted) return;
//
//     setState(() {
//       final index = _reports.indexWhere((e) => e.id == updated.id);
//       if (index != -1) {
//         _reports[index] = updated;
//       }
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     const pageBg = Color(0xFF0F2027);
//
//     return Scaffold(
//       backgroundColor: pageBg,
//       body: SafeArea(
//         child: FutureBuilder<List<PatrolReportModel>>(
//           future: _futureReports,
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return const Center(child: CircularProgressIndicator());
//             }
//
//             if (snapshot.hasError) {
//               return CommonUI.errorPage(
//                 message: snapshot.error.toString(),
//                 context: context,
//               );
//             }
//
//             if (_reports.isEmpty) {
//               return CommonUI.emptyState(
//                 context: context,
//                 title: 'No reports',
//                 message: 'There are no patrol reports yet.',
//                 icon: Icons.assignment_outlined,
//               );
//             }
//
//             final filtered = _filteredReports;
//             final currentItems = _currentPageItems;
//
//             return Column(
//               children: [
//                 _buildSummaryToggle(),
//                 AnimatedSwitcher(
//                   duration: const Duration(milliseconds: 250),
//                   switchInCurve: Curves.easeOut,
//                   switchOutCurve: Curves.easeIn,
//                   child: _showSummary
//                       ? Padding(
//                           key: const ValueKey('summary'),
//                           padding: const EdgeInsets.only(bottom: 8),
//                           child: PatrolRiskSummarySfPage(
//                             onSelect: _applySummaryFilter,
//                             onDateChanged: (from, to) {
//                               setState(() {
//                                 _fromDate = from;
//                                 _toDate = to;
//                                 _page = 0;
//                               });
//                             },
//                             fromD: _fromDate,
//                             toD: _toDate,
//                             plant: widget.plant,
//                             patrolGroup: widget.patrolGroup,
//                           ),
//                         )
//                       : const SizedBox(key: ValueKey('summary_empty')),
//                 ),
//                 _buildTopBar(total: _reports.length, shown: filtered.length),
//                 if (_downloading)
//                   CommonUI.exportLoadingBanner(
//                     accentColor: Colors.amber,
//                     title: 'Exporting Excel',
//                     subtitle: 'Large dataset detected, please wait…',
//                   ),
//                 Expanded(
//                   child: _buildTable(context: context, reports: currentItems),
//                 ),
//                 _buildPager(
//                   totalItems: filtered.length,
//                   totalPages: _totalPages,
//                 ),
//               ],
//             );
//           },
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSummaryToggle() {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
//       child: Row(
//         children: [
//           const Text('Summary', style: TextStyle(fontWeight: FontWeight.w700)),
//           const Spacer(),
//           TextButton.icon(
//             onPressed: () {
//               setState(() => _showSummary = !_showSummary);
//             },
//             icon: Icon(
//               _showSummary
//                   ? Icons.expand_less_rounded
//                   : Icons.expand_more_rounded,
//               color: Colors.white,
//             ),
//             label: Text(
//               _showSummary ? 'Hide' : 'Show',
//               style: const TextStyle(color: Colors.white70),
//             ),
//           ),
//           TextButton.icon(
//             onPressed: _openBeforeAfterSummary,
//             icon: const Icon(Icons.analytics_outlined, color: Colors.white),
//             label: const Text('Open', style: TextStyle(color: Colors.white70)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildTopBar({required int total, required int shown}) {
//     final canClear = _searchQuery.isNotEmpty || _filterValues.isNotEmpty;
//
//     return Row(
//       children: [
//         GlassActionButton(
//           icon: Icons.arrow_back_rounded,
//           onTap: () => context.go('/home'),
//         ),
//         IconButton(
//           icon: const Icon(Icons.download_rounded, color: Colors.greenAccent),
//           onPressed: _downloadExcel,
//         ),
//         Expanded(
//           child: TextField(
//             controller: _searchCtrl,
//             decoration: InputDecoration(
//               hintText: 'Search (stt, type, group, comment, PIC...)',
//               prefixIcon: const Icon(Icons.search),
//               isDense: true,
//               filled: true,
//               fillColor: Colors.white,
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(10),
//               ),
//             ),
//           ),
//         ),
//         IconButton(
//           icon: const Icon(Icons.cleaning_services, color: Colors.greenAccent),
//           onPressed: canClear ? _clearAll : null,
//         ),
//         const SizedBox(width: 10),
//         _buildChip('$shown / $total'),
//       ],
//     );
//   }
//
//   Widget _buildChip(String text) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(999),
//         border: Border.all(color: Colors.grey.shade300),
//       ),
//       child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
//     );
//   }
//
//   Widget _buildTable({
//     required BuildContext context,
//     required List<PatrolReportModel> reports,
//   }) {
//     final totalWidth = _columns.fold<double>(
//       0,
//       (sum, column) => sum + column.width,
//     );
//
//     return Card(
//       elevation: 2,
//       margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       clipBehavior: Clip.antiAlias,
//       child: Scrollbar(
//         controller: _horizontalScrollCtrl,
//         thumbVisibility: true,
//         child: SingleChildScrollView(
//           controller: _horizontalScrollCtrl,
//           scrollDirection: Axis.horizontal,
//           child: SizedBox(
//             width: totalWidth,
//             child: Column(
//               children: [
//                 _buildHeader(),
//                 const Divider(height: 1, thickness: 1),
//                 Expanded(
//                   child: PrimaryScrollController(
//                     controller: _verticalScrollCtrl,
//                     child: Scrollbar(
//                       controller: _verticalScrollCtrl,
//                       thumbVisibility: true,
//                       child: ListView.builder(
//                         controller: _verticalScrollCtrl,
//                         primary: false,
//                         itemCount: reports.length,
//                         itemBuilder: (_, index) {
//                           final report = reports[index];
//                           return _buildRow(report, index);
//                         },
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildHeader() {
//     return OverlayPortal(
//       controller: _overlayCtrl,
//       overlayChildBuilder: (_) {
//         if (_activeFilterColumn == null) return const SizedBox();
//
//         return Stack(
//           children: [
//             Positioned.fill(
//               child: GestureDetector(
//                 behavior: HitTestBehavior.translucent,
//                 onTap: _closeFilterPopup,
//               ),
//             ),
//             _buildFilterPopup(_reports),
//           ],
//         );
//       },
//       child: Container(
//         height: 44,
//         color: Colors.grey.shade200,
//         child: Row(
//           children: _columns.map((column) {
//             final hasFilter = _filterValues[column.label]?.isNotEmpty == true;
//
//             return _HeaderFilterCell(
//               label: column.label,
//               width: column.width,
//               align: column.align,
//               hasFilter: hasFilter,
//               layerLink: _filterLinks[column.label]!,
//               onFilterTap: () => _openFilterPopup(column.label),
//             );
//           }).toList(),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildFilterPopup(List<PatrolReportModel> allReports) {
//     final column = _activeFilterColumn;
//     if (column == null) return const SizedBox();
//
//     final base = _applyFilters(
//       allReports,
//       query: _searchQuery,
//       excludeColumn: column,
//     );
//
//     final valuesInBase = _distinctColumnValues(column, base);
//     final selected = _filterValues[column] ?? <String>{};
//
//     final mergedValues = <String>[
//       ...selected.where((value) => !valuesInBase.contains(value)),
//       ...valuesInBase,
//     ];
//
//     final shownValues = mergedValues
//         .where(
//           (value) => value.toLowerCase().contains(_filterSearch.toLowerCase()),
//         )
//         .toList();
//
//     return CompositedTransformFollower(
//       link: _filterLinks[column]!,
//       offset: const Offset(0, 44),
//       showWhenUnlinked: false,
//       child: Material(
//         color: Colors.transparent,
//         child: Container(
//           width: 260,
//           height: 340,
//           decoration: BoxDecoration(
//             color: const Color(0xFF172A33).withOpacity(.6),
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: Colors.white24),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.45),
//                 blurRadius: 14,
//                 offset: const Offset(0, 6),
//               ),
//             ],
//           ),
//           child: Column(
//             children: [
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 12,
//                   vertical: 10,
//                 ),
//                 decoration: const BoxDecoration(
//                   border: Border(bottom: BorderSide(color: Colors.white24)),
//                 ),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         column,
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontWeight: FontWeight.w700,
//                           fontSize: 14,
//                         ),
//                       ),
//                     ),
//                     InkWell(
//                       onTap: _closeFilterPopup,
//                       borderRadius: BorderRadius.circular(20),
//                       child: const Padding(
//                         padding: EdgeInsets.all(4),
//                         child: Icon(
//                           Icons.close,
//                           size: 18,
//                           color: Colors.white70,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.all(10),
//                 child: TextField(
//                   style: const TextStyle(color: Colors.white),
//                   decoration: InputDecoration(
//                     isDense: true,
//                     hintText: 'Search value',
//                     hintStyle: const TextStyle(color: Colors.white54),
//                     prefixIcon: const Icon(Icons.search, size: 16),
//                     prefixIconColor: Colors.white54,
//                     filled: true,
//                     fillColor: Colors.black.withOpacity(0.2),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8),
//                       borderSide: const BorderSide(color: Colors.white24),
//                     ),
//                     enabledBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8),
//                       borderSide: const BorderSide(color: Colors.white24),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8),
//                       borderSide: const BorderSide(color: Colors.blueAccent),
//                     ),
//                   ),
//                   onChanged: (value) {
//                     setState(() => _filterSearch = value);
//                   },
//                 ),
//               ),
//               Expanded(
//                 child: shownValues.isEmpty
//                     ? const Center(
//                         child: Text(
//                           'No values',
//                           style: TextStyle(color: Colors.white54),
//                         ),
//                       )
//                     : Scrollbar(
//                         controller: _filterListScrollCtrl,
//                         thumbVisibility: true,
//                         child: ListView.builder(
//                           controller: _filterListScrollCtrl,
//                           primary: false,
//                           padding: EdgeInsets.zero,
//                           itemCount: shownValues.length,
//                           itemBuilder: (_, index) {
//                             final value = shownValues[index];
//                             final checked = selected.contains(value);
//
//                             return InkWell(
//                               onTap: () {
//                                 _toggleFilterValue(
//                                   column: column,
//                                   value: value,
//                                   checked: !checked,
//                                 );
//                               },
//                               child: Container(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 12,
//                                   vertical: 6,
//                                 ),
//                                 child: Row(
//                                   children: [
//                                     Checkbox(
//                                       value: checked,
//                                       onChanged: (ok) {
//                                         _toggleFilterValue(
//                                           column: column,
//                                           value: value,
//                                           checked: ok == true,
//                                         );
//                                       },
//                                       checkColor: Colors.white,
//                                       side: const BorderSide(
//                                         color: Colors.white54,
//                                       ),
//                                       materialTapTargetSize:
//                                           MaterialTapTargetSize.shrinkWrap,
//                                     ),
//                                     const SizedBox(width: 6),
//                                     Expanded(
//                                       child: Text(
//                                         value,
//                                         maxLines: 1,
//                                         overflow: TextOverflow.ellipsis,
//                                         style: const TextStyle(
//                                           color: Colors.white,
//                                           fontSize: 13,
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 10,
//                   vertical: 8,
//                 ),
//                 decoration: const BoxDecoration(
//                   border: Border(top: BorderSide(color: Colors.white24)),
//                 ),
//                 child: Row(
//                   children: [
//                     GlassActionButton(
//                       icon: Icons.cleaning_services,
//                       onTap: () => _clearColumnFilter(column),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildRow(PatrolReportModel report, int pageIndex) {
//     final isSelected = _selectedReportId == report.id;
//     final baseColor = pageIndex.isEven ? Colors.white : Colors.grey.shade50;
//     final background = isSelected ? Colors.lightBlue.shade50 : baseColor;
//
//     return _HoverableRow(
//       height: 100,
//       background: background,
//       onDoubleTap: () => _editReport(report),
//       child: Row(
//         children: [
//           _textCell(
//             report.stt.toString(),
//             _widthOf('STT'),
//             align: TextAlign.center,
//           ),
//           _qrCell(report.qr_key?.toString(), _widthOf('QR')),
//           _textCell(report.grp, _widthOf('Group'), tooltip: true),
//           _textCell(report.plant, _widthOf('Plant'), tooltip: true),
//           _textCell(report.division, _widthOf('Division'), tooltip: true),
//           _textCell(report.area, _widthOf('Area'), tooltip: true),
//           _textCell(report.machine, _widthOf('Machine'), tooltip: true),
//           _textCell(
//             report.patrol_user ?? '-',
//             _widthOf('Patrol User'),
//             tooltip: true,
//           ),
//           _imageCell(
//             names: report.imageNames,
//             width: _widthOf('Img(B)'),
//             onTap: () {
//               PatrolImagesDialog.show(
//                 context: context,
//                 title: 'Before',
//                 e: report,
//                 names: report.imageNames,
//               );
//             },
//           ),
//           _riskBadgeCell(report.riskTotal, _widthOf('Risk T')),
//           _textCell(report.comment, _widthOf('Comment'), tooltip: true),
//           _textCell(
//             report.countermeasure,
//             _widthOf('Countermeasure'),
//             tooltip: true,
//           ),
//           _textCell(
//             CommonUI.fmtDate(report.createdAt),
//             _widthOf('Created'),
//             align: TextAlign.center,
//           ),
//           _textCell(
//             CommonUI.fmtDate(report.dueDate),
//             _widthOf('Due'),
//             align: TextAlign.center,
//           ),
//           _textCell(report.pic ?? '-', _widthOf('PIC'), tooltip: true),
//           _textCell(report.checkInfo, _widthOf('Check Info'), tooltip: true),
//           _textCell(
//             report.riskFreq,
//             _widthOf('Risk F'),
//             align: TextAlign.center,
//           ),
//           _textCell(
//             report.riskProb,
//             _widthOf('Risk P'),
//             align: TextAlign.center,
//           ),
//           _textCell(
//             report.riskSev,
//             _widthOf('Risk S'),
//             align: TextAlign.center,
//           ),
//           _statusBadgeCell(report.atStatus, _widthOf('AT Stt')),
//           _textCell(report.atPic ?? '-', _widthOf('AT PIC'), tooltip: true),
//           _textCell(
//             CommonUI.fmtDate(report.atDate),
//             _widthOf('AT Date'),
//             align: TextAlign.center,
//           ),
//           _textCell(report.atComment ?? '-', _widthOf('AT Cmt'), tooltip: true),
//           _imageCell(
//             names: report.atImageNames,
//             width: _widthOf('Img(A)'),
//             onTap: () {
//               PatrolImagesDialog.show(
//                 context: context,
//                 title: 'After',
//                 e: report,
//                 names: report.atImageNames,
//               );
//             },
//           ),
//           _textCell(
//             report.hseJudge ?? '-',
//             _widthOf('HSE J'),
//             align: TextAlign.center,
//           ),
//           _textCell(
//             CommonUI.fmtDate(report.hseDate),
//             _widthOf('HSE D'),
//             align: TextAlign.center,
//           ),
//           _textCell(report.hseComment ?? '-', _widthOf('HSE C'), tooltip: true),
//           _imageCell(
//             names: report.hseImageNames,
//             width: _widthOf('Img(H)'),
//             onTap: () {
//               PatrolImagesDialog.show(
//                 context: context,
//                 title: 'HSE',
//                 e: report,
//                 names: report.hseImageNames,
//               );
//             },
//           ),
//           _textCell(
//             report.loadStatus ?? '-',
//             _widthOf('Load'),
//             align: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _qrCell(String? qr, double width) {
//     final value = (qr ?? '').trim();
//     final hasQr = value.isNotEmpty;
//
//     return _boxedCell(
//       width: width,
//       align: TextAlign.center,
//       child: hasQr
//           ? Container(
//               margin: const EdgeInsets.only(bottom: 6),
//               width: 50,
//               height: 50,
//               decoration: BoxDecoration(
//                 color: Colors.blueGrey.shade50,
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(color: Colors.blueGrey.shade200),
//               ),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const Icon(
//                     Icons.qr_code_2_rounded,
//                     size: 24,
//                     color: Colors.blueGrey,
//                   ),
//                   const SizedBox(height: 2),
//                   Text(
//                     value,
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: TextStyle(
//                       fontSize: 13,
//                       color: Colors.grey.shade800,
//                       height: 1,
//                     ),
//                   ),
//                 ],
//               ),
//             )
//           : const Text('-'),
//     );
//   }
//
//   Widget _textCell(
//     String text,
//     double width, {
//     TextAlign align = TextAlign.left,
//     bool tooltip = false,
//   }) {
//     final value = text.trim().isEmpty ? '-' : text.trim();
//
//     final content = Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 2),
//       child: Text(
//         value,
//         style: const TextStyle(fontSize: 13),
//         textAlign: align,
//       ),
//     );
//
//     return _boxedCell(
//       width: width,
//       align: align,
//       child: tooltip
//           ? Tooltip(
//               message: value,
//               waitDuration: const Duration(milliseconds: 350),
//               child: content,
//             )
//           : content,
//     );
//   }
//
//   Widget _imageThumb(String imageName, {double size = 40}) {
//     if (imageName.isEmpty) {
//       return const Icon(
//         Icons.image_not_supported,
//         size: 20,
//         color: Colors.grey,
//       );
//     }
//
//     final url = '${ApiConfig.baseUrl}/images/$imageName';
//
//     return ClipRRect(
//       borderRadius: BorderRadius.circular(4),
//       child: Image.network(
//         url,
//         width: size,
//         height: size,
//         fit: BoxFit.cover,
//         errorBuilder: (_, __, ___) {
//           return const Icon(Icons.broken_image, color: Colors.red);
//         },
//         loadingBuilder: (context, child, progress) {
//           if (progress == null) return child;
//           return const SizedBox(
//             width: 20,
//             height: 20,
//             child: CircularProgressIndicator(strokeWidth: 2),
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _imageCell({
//     required List<String> names,
//     required double width,
//     VoidCallback? onTap,
//   }) {
//     final count = names.length;
//     final first = count > 0 ? names.first : '';
//
//     return _boxedCell(
//       width: width,
//       align: TextAlign.center,
//       child: InkWell(
//         onTap: count > 0 ? onTap : null,
//         borderRadius: BorderRadius.circular(8),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             if (count > 0)
//               Expanded(child: _imageThumb(first, size: 80))
//             else
//               const Icon(
//                 Icons.image_not_supported,
//                 size: 18,
//                 color: Colors.grey,
//               ),
//             Text(
//               '$count',
//               style: TextStyle(
//                 fontSize: 8,
//                 fontWeight: FontWeight.w700,
//                 color: count > 0 ? Colors.blueGrey.shade800 : Colors.grey,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _riskBadgeCell(String risk, double width) {
//     final color = CommonUI.riskColor(risk);
//
//     return _boxedCell(
//       width: width,
//       align: TextAlign.center,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//         decoration: BoxDecoration(
//           color: color.withOpacity(0.12),
//           borderRadius: BorderRadius.circular(6),
//         ),
//         child: Text(
//           risk,
//           style: TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//             color: color,
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _statusBadgeCell(String? statusValue, double width) {
//     final status = (statusValue == null || statusValue.isEmpty)
//         ? 'Wait'
//         : statusValue;
//     final color = CommonUI.statusColor(status);
//
//     return _boxedCell(
//       width: width,
//       align: TextAlign.center,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//         decoration: BoxDecoration(
//           color: color.withOpacity(0.15),
//           borderRadius: BorderRadius.circular(8),
//         ),
//         child: Text(
//           status,
//           style: TextStyle(
//             fontSize: 13,
//             fontWeight: FontWeight.bold,
//             color: color,
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _boxedCell({
//     required double width,
//     required TextAlign align,
//     required Widget child,
//   }) {
//     return Container(
//       width: width,
//       alignment: align == TextAlign.center
//           ? Alignment.center
//           : Alignment.centerLeft,
//       decoration: BoxDecoration(
//         border: Border(right: BorderSide(color: Colors.grey.shade300)),
//       ),
//       child: child,
//     );
//   }
//
//   Widget _buildPager({required int totalItems, required int totalPages}) {
//     const controlBg = Color(0xFF172A33);
//
//     return Container(
//       color: const Color(0xFF0F2027),
//       child: Row(
//         children: [
//           Text(
//             'Rows: $totalItems',
//             style: const TextStyle(color: Colors.white70),
//           ),
//           const Spacer(),
//           Text(
//             'Page ${_safePage + 1} / $totalPages',
//             style: const TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//           const SizedBox(width: 12),
//           IconButton(
//             onPressed: _safePage == 0
//                 ? null
//                 : () {
//                     setState(() => _page = _safePage - 1);
//                   },
//             icon: const Icon(Icons.chevron_left),
//             color: Colors.white,
//             disabledColor: Colors.white38,
//           ),
//           IconButton(
//             onPressed: (_safePage + 1 >= totalPages)
//                 ? null
//                 : () {
//                     setState(() => _page = _safePage + 1);
//                   },
//             icon: const Icon(Icons.chevron_right),
//             color: Colors.white,
//             disabledColor: Colors.white38,
//           ),
//           const SizedBox(width: 12),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 8),
//             decoration: BoxDecoration(
//               color: controlBg,
//               borderRadius: BorderRadius.circular(8),
//               border: Border.all(color: Colors.white24),
//             ),
//             child: DropdownButton<int>(
//               value: _rowsPerPage,
//               underline: const SizedBox(),
//               dropdownColor: controlBg,
//               iconEnabledColor: Colors.white,
//               style: const TextStyle(color: Colors.white),
//               items: _pageSizeOptions
//                   .map(
//                     (size) => DropdownMenuItem<int>(
//                       value: size,
//                       child: Text('$size / page'),
//                     ),
//                   )
//                   .toList(),
//               onChanged: (value) {
//                 if (value == null) return;
//                 setState(() {
//                   _rowsPerPage = value;
//                   _page = 0;
//                 });
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _ColumnSpec {
//   final String label;
//   final double width;
//   final TextAlign align;
//   final String? queryKey;
//   final String Function(PatrolReportModel row) valueGetter;
//
//   const _ColumnSpec({
//     required this.label,
//     required this.width,
//     required this.align,
//     required this.valueGetter,
//     this.queryKey,
//   });
// }
//
// class _HeaderFilterCell extends StatelessWidget {
//   final String label;
//   final double width;
//   final TextAlign align;
//   final bool hasFilter;
//   final VoidCallback onFilterTap;
//   final LayerLink layerLink;
//
//   const _HeaderFilterCell({
//     required this.label,
//     required this.width,
//     required this.onFilterTap,
//     required this.layerLink,
//     this.align = TextAlign.left,
//     this.hasFilter = false,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return CompositedTransformTarget(
//       link: layerLink,
//       child: Container(
//         width: width,
//         height: 44,
//         padding: const EdgeInsets.symmetric(horizontal: 6),
//         decoration: BoxDecoration(
//           color: Colors.grey.shade200,
//           border: Border(right: BorderSide(color: Colors.grey.shade300)),
//         ),
//         child: Row(
//           children: [
//             Expanded(
//               child: Text(
//                 label,
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//                 textAlign: align,
//                 style: const TextStyle(
//                   fontWeight: FontWeight.w700,
//                   fontSize: 13,
//                 ),
//               ),
//             ),
//             InkWell(
//               onTap: onFilterTap,
//               borderRadius: BorderRadius.circular(6),
//               child: Padding(
//                 padding: const EdgeInsets.all(4),
//                 child: Icon(
//                   hasFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
//                   size: 18,
//                   color: hasFilter ? Colors.blue : Colors.grey,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class _HoverableRow extends StatefulWidget {
//   final double height;
//   final Color background;
//   final Widget child;
//   final VoidCallback? onDoubleTap;
//
//   const _HoverableRow({
//     required this.height,
//     required this.background,
//     required this.child,
//     this.onDoubleTap,
//   });
//
//   @override
//   State<_HoverableRow> createState() => _HoverableRowState();
// }
//
// class _HoverableRowState extends State<_HoverableRow> {
//   bool _hover = false;
//
//   @override
//   Widget build(BuildContext context) {
//     final background = _hover
//         ? Colors.blueGrey.withOpacity(0.06)
//         : widget.background;
//
//     return MouseRegion(
//       onEnter: (_) => setState(() => _hover = true),
//       onExit: (_) => setState(() => _hover = false),
//       child: GestureDetector(
//         onDoubleTap: widget.onDoubleTap,
//         behavior: HitTestBehavior.opaque,
//         child: Container(
//           height: widget.height,
//           color: background,
//           child: widget.child,
//         ),
//       ),
//     );
//   }
// }

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
import '../api/patrol_report_api.dart';
import '../api/patrol_report_download_api.dart';
import '../model/patrol_report_model.dart';
import '../widget/glass_action_button.dart';
import 'before_after_summary_page.dart';
import 'edit_report_dialog.dart';

class PatrolReportTable extends StatefulWidget {
  final String patrolGroup;
  final String plant;

  const PatrolReportTable({
    super.key,
    required this.patrolGroup,
    required this.plant,
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

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _viewState = PatrolReportTableViewState(
      toDate: now,
      fromDate: DateTime(now.year, now.month - 1, 1),
    );

    _futureReports = _loadReports();

    for (final col in _columns) {
      _filterLinks[col.label] = LayerLink();
    }

    _searchCtrl.addListener(_onSearchChanged);
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

  List<String> get _availableGroups {
    final base = PatrolReportTableHelper.applyFilters(
      source: _reports,
      query: _viewState.searchQuery,
      fromDate: _viewState.fromDate,
      toDate: _viewState.toDate,
      filterValues: _viewState.filterValues,
      columns: _columns,
      excludeColumn: 'Group',
    );

    return PatrolReportTableHelper.distinctColumnValues(
      columnLabel: 'Group',
      source: base,
      columns: _columns,
    );
  }

  String? get _selectedGroup {
    final values = _viewState.filterValues['Group'];
    if (values == null || values.isEmpty) return null;
    return values.first;
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

  Future<void> _editReport(PatrolReportModel report) async {
    setState(() {
      _viewState = _viewState.copyWith(selectedReportId: report.id);
    });

    final updated = await EditReportDialog.show(context, model: report);
    if (updated == null || !mounted) return;

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

            return Column(
              children: [
                _buildSummaryToggle(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _viewState.showSummary
                      ? Padding(
                          key: const ValueKey('summary'),
                          padding: const EdgeInsets.only(bottom: 8),
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
                      : const SizedBox(key: ValueKey('summary_empty')),
                ),
                _buildTopBar(total: _reports.length, shown: filtered.length),
                // if (_viewState.activeFilterColumn == null) _buildGroupBar(),
                if (_viewState.downloading)
                  CommonUI.exportLoadingBanner(
                    accentColor: Colors.amber,
                    title: 'Exporting Excel',
                    subtitle: 'Large dataset detected, please wait…',
                  ),
                Expanded(
                  child: _buildTable(context: context, reports: currentItems),
                ),
                _buildPager(
                  totalItems: filtered.length,
                  totalPages: _totalPages,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryToggle() {
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
            label: const Text('Open', style: TextStyle(color: Colors.white70)),
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

  void _clearTableDateFilter() {
    setState(() {
      _viewState = _viewState.copyWith(fromDate: null, toDate: null, page: 0);
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
    final groups = _availableGroups;
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

    return Container(
      // width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...groups.map((group) {
            final selected = group == selectedGroup;

            return FilterChip(
              label: Text(group),
              selected: selected,
              onSelected: (_) => _onTapGroup(group),
              selectedColor: Colors.blue.withOpacity(0.22),
              backgroundColor: Colors.white,
              checkmarkColor: Colors.blue,
              labelStyle: TextStyle(
                color: selected ? Colors.blue.shade900 : Colors.black87,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              side: BorderSide(
                color: selected ? Colors.blue : Colors.grey.shade300,
              ),
            );
          }),

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
        ? 'Wait'
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
