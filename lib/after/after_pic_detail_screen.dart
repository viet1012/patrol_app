import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/patrol_report_api.dart';
import '../common/common_searchable_dropdown.dart';
import '../common/common_ui_helper.dart';
import '../common/due_date_utils.dart';
import '../homeScreen/patrol_home_screen.dart';
import '../model/patrol_report_model.dart';
import '../redo/redo_detail_page.dart';
import '../widget/error_display.dart';
import '../widget/glass_action_button.dart';
import 'after_patrol.dart';

class AfterPicDetailScreen extends StatefulWidget {
  final String accountCode;
  final String plant;
  final String atStatus;
  final String pic;
  final PatrolGroup patrolGroup;

  const AfterPicDetailScreen({
    super.key,
    required this.accountCode,
    required this.plant,
    required this.atStatus,
    required this.pic,
    required this.patrolGroup,
  });

  @override
  State<AfterPicDetailScreen> createState() => _AfterPicDetailScreenState();
}

class _AfterPicDetailScreenState extends State<AfterPicDetailScreen> {
  static const String _unknownPicLabel = 'UNKNOWN';
  static const List<String> _riskOptions = ['V', 'IV', 'III', 'II', 'I'];

  Future<List<PatrolReportModel>>? _futureReport;

  String? _selectedArea;
  String? _selectedRisk;
  String? _selectedRowKey;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  void _fetchReport() {
    final picFilter = widget.pic == _unknownPicLabel ? '' : widget.pic.trim();

    setState(() {
      _futureReport = PatrolReportApi.fetchReports(
        plant: widget.plant,
        type: widget.patrolGroup.name,
        pic: picFilter,
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

  List<String> _extractAreas(List<PatrolReportModel> reports) {
    return reports
        .map((e) => e.area)
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<PatrolReportModel> _getFilteredAndSortedReports(
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

  int _compareDueDate(DateTime? a, DateTime? b, DateTime now) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;

    final aOverdue = a.isBefore(now);
    final bOverdue = b.isBefore(now);

    if (aOverdue && !bOverdue) return -1;
    if (!aOverdue && bOverdue) return 1;

    final aDiff = a.difference(now).abs();
    final bDiff = b.difference(now).abs();

    return aDiff.compareTo(bDiff);
  }

  Future<void> _openDetail(PatrolReportModel report) async {
    setState(() {
      _selectedRowKey = _rowKey(report);
    });
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _buildTargetPage(report)),
    );

    if (result == true && mounted) {
      _fetchReport();
    }
  }

  Widget _buildTargetPage(PatrolReportModel report) {
    if (report.atStatus == 'Redo') {
      return RedoDetailPage(
        accountCode: widget.accountCode,
        patrolGroup: widget.patrolGroup,
        report: report,
      );
    }

    return AfterPatrol(
      accountCode: widget.accountCode,
      id: report.id!,
      patrolGroup: widget.patrolGroup,
    );
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'Redo':
        return Icons.restart_alt_rounded;
      case 'Wait':
        return Icons.edit_note_rounded;
      case 'Done':
        return Icons.check_circle_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'Redo':
        return Colors.orangeAccent;
      case 'Wait':
        return Colors.blueAccent;
      case 'Done':
        return Colors.greenAccent;
      default:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF121826), Color(0xFF1F2937), Color(0xFF374151)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FutureBuilder<List<PatrolReportModel>>(
          future: _futureReport,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ErrorDisplay(
                errorMessage: snapshot.error.toString(),
                onRetry: _fetchReport,
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
            final filteredReports = _getFilteredAndSortedReports(reports);

            return Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  _buildFilterSection(areas),
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
        GlassActionButton(icon: Icons.refresh_rounded, onTap: _fetchReport),
      ],
    );
  }

  Widget _buildFilterSection(List<String> areas) {
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
              items: _riskOptions,
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
        DataCell(_buildActionCell(report)),
        DataCell(_buildQrCell(report)),
        DataCell(_buildTextCell(report.area, maxWidth: 80)),
        DataCell(_buildTextCell(report.machine, maxWidth: 80)),
        DataCell(_buildRiskCell(report.riskTotal, riskColor)),
        DataCell(_buildDeadlineCell(report.dueDate)),
      ],
    );
  }

  Widget _buildActionCell(PatrolReportModel report) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 170),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Material(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openDetail(report),
                child: Center(
                  child: Icon(
                    _statusIcon(report.atStatus),
                    size: 28,
                    color: _statusColor(report.atStatus),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCell(PatrolReportModel report) {
    return SizedBox(
      width: 40,
      child: Text(
        '${report.qr_key}',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildTextCell(String value, {double maxWidth = 80}) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text(
        value,
        softWrap: true,
        maxLines: 3,
        overflow: TextOverflow.visible,
        style: TextStyle(color: Colors.white.withOpacity(0.85)),
      ),
    );
  }

  Widget _buildRiskCell(String risk, Color color) {
    return SizedBox(
      width: 32,
      child: Center(
        child: Text(
          risk,
          style: TextStyle(
            color: color.withOpacity(0.85),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDeadlineCell(DateTime? dueDate) {
    return SizedBox(
      width: 74,
      child: Text(
        dueDate == null ? '-' : DateFormat('M/d/yy').format(dueDate),
        style: TextStyle(
          color: DueDateUtils.getDueDateColor(dueDate),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
