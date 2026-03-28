import 'package:chuphinh/common/common_ui_helper.dart';
import 'package:chuphinh/recheck/recheck_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/patrol_report_api.dart';
import '../common/common_searchable_dropdown.dart';
import '../common/due_date_utils.dart';
import '../homeScreen/patrol_home_screen.dart';
import '../model/patrol_report_model.dart';
import '../widget/error_display.dart';
import '../widget/glass_action_button.dart';

class RecheckPicDetailScreen extends StatefulWidget {
  final String accountCode;
  final String plant;
  final String atStatus;
  final String pic;
  final PatrolGroup patrolGroup;

  const RecheckPicDetailScreen({
    super.key,
    required this.accountCode,
    required this.plant,
    required this.atStatus,
    required this.pic,
    required this.patrolGroup,
  });

  @override
  State<RecheckPicDetailScreen> createState() => _RecheckPicDetailScreenState();
}

class _RecheckPicDetailScreenState extends State<RecheckPicDetailScreen> {
  static const _emptyPicLabel = 'UNKNOWN';
  static const _backgroundGradient = LinearGradient(
    colors: [Color(0xFF121826), Color(0xFF1F2937), Color(0xFF374151)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  Future<List<PatrolReportModel>>? _futureReport;
  String? _selectedArea;
  String? _selectedRisk;
  String? _selectedRowKey;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  String get _normalizedPic =>
      widget.pic.trim() == _emptyPicLabel ? '' : widget.pic.trim();

  void _fetchReports() {
    setState(() {
      _futureReport = PatrolReportApi.fetchReports(
        plant: widget.plant,
        type: widget.patrolGroup.name,
        pic: _normalizedPic,
        afStatus: widget.atStatus,
      );
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedArea = null;
      _selectedRisk = null;
    });
  }

  List<PatrolReportModel> _applyFiltersAndSort(
    List<PatrolReportModel> reports,
  ) {
    final now = DateTime.now();

    final filtered = reports.where((report) {
      final matchArea = _selectedArea == null || report.area == _selectedArea;
      final matchRisk =
          _selectedRisk == null || report.riskTotal == _selectedRisk;

      return matchArea && matchRisk;
    }).toList();

    filtered.sort((a, b) {
      final riskCompare = CommonUI.riskToScore(
        b.riskTotal,
      ).compareTo(CommonUI.riskToScore(a.riskTotal));
      if (riskCompare != 0) return riskCompare;

      return _compareDueDate(a.dueDate, b.dueDate, now);
    });

    return filtered;
  }

  int _compareDueDate(DateTime? aDue, DateTime? bDue, DateTime now) {
    if (aDue == null && bDue == null) return 0;
    if (aDue == null) return 1;
    if (bDue == null) return -1;

    final aOverdue = aDue.isBefore(now);
    final bOverdue = bDue.isBefore(now);

    if (aOverdue && !bOverdue) return -1;
    if (!aOverdue && bOverdue) return 1;

    final aDiff = aDue.difference(now).abs();
    final bDiff = bDue.difference(now).abs();
    return aDiff.compareTo(bDiff);
  }

  List<String> _extractAreas(List<PatrolReportModel> reports) {
    return reports.map((e) => e.area).toSet().toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Container(
        decoration: const BoxDecoration(gradient: _backgroundGradient),
        child: FutureBuilder<List<PatrolReportModel>>(
          future: _futureReport,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ErrorDisplay(
                errorMessage: snapshot.error.toString(),
                onRetry: _fetchReports,
              );
            }

            final reports = snapshot.data ?? [];
            if (reports.isEmpty) {
              return const Center(
                child: Text(
                  'No data available',
                  style: TextStyle(color: Colors.grey, fontSize: 18),
                ),
              );
            }

            final areas = _extractAreas(reports);
            final filteredReports = _applyFiltersAndSort(reports);

            return Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  _buildFilterHeader(areas),
                  const SizedBox(height: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return _buildReportTable(
                          filteredReports,
                          constraints.maxWidth,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF121826),
      centerTitle: false,
      titleSpacing: 4,
      leading: GlassActionButton(
        icon: Icons.arrow_back_rounded,
        onTap: () => Navigator.pop(context, false),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'PIC: ${widget.pic}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${widget.plant} | ${widget.atStatus}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
      actions: [
        GlassActionButton(icon: Icons.refresh_rounded, onTap: _fetchReports),
      ],
    );
  }

  Widget _buildFilterHeader(List<String> areas) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: CommonSearchableDropdown(
              label: 'Area',
              selectedValue: _selectedArea,
              items: areas,
              isRequired: false,
              onChanged: (value) => setState(() => _selectedArea = value),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CommonSearchableDropdown(
              label: 'Risk',
              selectedValue: _selectedRisk,
              items: const ['V', 'IV', 'III', 'II', 'I'],
              isRequired: false,
              onChanged: (value) => setState(() => _selectedRisk = value),
            ),
          ),
          const SizedBox(width: 12),
          GlassActionButton(icon: Icons.filter_alt_off, onTap: _clearFilters),
        ],
      ),
    );
  }

  Widget _buildReportTable(List<PatrolReportModel> reports, double maxWidth) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: maxWidth),
          child: DataTable(
            columnSpacing: 6,
            horizontalMargin: 6,
            headingRowHeight: 42,
            dataRowHeight: 60,
            headingRowColor: MaterialStateProperty.all(
              Colors.white.withOpacity(0.10),
            ),
            headingTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            columns: const [
              DataColumn(label: Text('')),
              DataColumn(label: Text('QR')),
              DataColumn(label: Text('Area')),
              DataColumn(label: Text('Machine')),
              DataColumn(label: Text('Risk')),
              DataColumn(label: Text('Deadline')),
            ],
            rows: reports.map(_buildDataRow).toList(),
          ),
        ),
      ),
    );
  }

  String _rowKey(PatrolReportModel report) {
    return '${report.qr_key}_${report.area}_${report.machine}_${report.dueDate?.toIso8601String() ?? ''}';
  }

  DataRow _buildDataRow(PatrolReportModel report) {
    final riskColor = CommonUI.riskColor(report.riskTotal);
    final isSelected = _selectedRowKey == _rowKey(report);

    return DataRow(
      color: MaterialStateProperty.resolveWith<Color?>((states) {
        if (isSelected) {
          return Colors.amber.withOpacity(0.25); // màu highlight
        }
        return null;
      }),

      cells: [
        DataCell(_buildViewButton(report)),
        DataCell(
          SizedBox(
            width: 40,
            child: Text(
              '${report.qr_key}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        DataCell(_buildWrappedText(report.area)),
        DataCell(_buildWrappedText(report.machine)),
        DataCell(
          SizedBox(
            width: 32,
            child: Center(
              child: Text(
                report.riskTotal,
                style: TextStyle(
                  color: riskColor.withOpacity(0.85),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 74,
            child: Text(
              report.dueDate == null
                  ? '-'
                  : DateFormat('M/d/yy').format(report.dueDate!),
              style: TextStyle(
                color: DueDateUtils.getDueDateColor(report.dueDate),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewButton(PatrolReportModel report) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 170),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            height: 32,
            child: Material(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  setState(() {
                    _selectedRowKey = _rowKey(report);
                  });

                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecheckDetailPage(
                        accountCode: widget.accountCode,
                        patrolGroup: widget.patrolGroup,
                        report: report,
                      ),
                    ),
                  );

                  if (result == true && mounted) {
                    _fetchReports();
                  }
                },
                child: const Center(
                  child: Icon(
                    Icons.visibility_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWrappedText(String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 80),
      child: Text(
        value,
        softWrap: true,
        maxLines: 3,
        overflow: TextOverflow.visible,
        style: TextStyle(color: Colors.white.withOpacity(0.85)),
      ),
    );
  }
}
