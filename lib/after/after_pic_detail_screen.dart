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

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _reloadReports();
  }

  // ============================================================
  // API
  // ============================================================

  String get _picFilter {
    final value = widget.pic.trim();

    return value == _unknownPicLabel ? '' : value;
  }

  void _reloadReports() {
    if (!mounted) return;

    final future = PatrolReportApi.fetchReports(
      plant: widget.plant,
      type: widget.patrolGroup.name,
      pic: _picFilter,
      afStatus: widget.atStatus,
    );

    setState(() {
      _futureReport = future;
    });
  }

  // ============================================================
  // FILTER
  // ============================================================

  void _clearFilters() {
    if (_selectedArea == null && _selectedRisk == null) {
      return;
    }

    setState(() {
      _selectedArea = null;
      _selectedRisk = null;
    });
  }

  List<String> _extractAreas(List<PatrolReportModel> reports) {
    final result = reports
        .map((e) => e.area.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    result.sort();

    return result;
  }

  // ============================================================
  // FILTER + SORT
  // ============================================================

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
      // ============================================================
      // 1. RISK CAO HƠN -> LÊN TRƯỚC
      //
      // V
      // IV
      // III
      // II
      // I
      // ============================================================

      final riskCompare = CommonUI.riskToScore(
        b.riskTotal,
      ).compareTo(CommonUI.riskToScore(a.riskTotal));

      if (riskCompare != 0) {
        return riskCompare;
      }

      // ============================================================
      // 2. CÙNG RISK -> DEADLINE
      // ============================================================

      final deadlineCompare = _compareDueDate(a.dueDate, b.dueDate, now);

      if (deadlineCompare != 0) {
        return deadlineCompare;
      }

      // ============================================================
      // 3. CÙNG RISK + CÙNG DEADLINE -> ID
      // ============================================================

      final aId = a.id ?? 0;
      final bId = b.id ?? 0;

      return aId.compareTo(bId);
    });

    return filtered;
  }

  // ============================================================
  // DEADLINE SORT
  //
  // Logic:
  //
  // overdue lâu nhất
  // -> overdue gần nhất
  // -> hôm nay
  // -> ngày mai
  // -> tương lai
  // -> null
  // ============================================================

  int _compareDueDate(DateTime? a, DateTime? b, DateTime now) {
    // ============================================================
    // NULL -> XUỐNG CUỐI
    // ============================================================

    if (a == null && b == null) {
      return 0;
    }

    if (a == null) {
      return 1;
    }

    if (b == null) {
      return -1;
    }

    // ============================================================
    // GIỮ LOGIC CŨ
    //
    // 1. Overdue trước
    // 2. Chưa overdue sau
    // 3. Trong cùng nhóm -> ngày gần hiện tại hơn trước
    // ============================================================

    final aOverdue = a.isBefore(now);

    final bOverdue = b.isBefore(now);

    if (aOverdue && !bOverdue) {
      return -1;
    }

    if (!aOverdue && bOverdue) {
      return 1;
    }

    final aDiff = a.difference(now).abs();

    final bDiff = b.difference(now).abs();

    return aDiff.compareTo(bDiff);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  // ============================================================
  // DETAIL
  // ============================================================

  Future<void> _openDetail(PatrolReportModel report) async {
    final rowKey = _rowKey(report);

    if (mounted) {
      setState(() {
        _selectedRowKey = rowKey;
      });
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _buildTargetPage(report)),
    );

    if (!mounted) {
      return;
    }

    if (result == true) {
      _reloadReports();
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

    final reportId = report.id;

    if (reportId == null) {
      return const Scaffold(body: Center(child: Text('Invalid report ID')));
    }

    return AfterPatrol(
      accountCode: widget.accountCode,
      id: reportId,
      patrolGroup: widget.patrolGroup,
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'Redo':
        return Icons.restart_alt_rounded;

      case 'Wait':
      case 'Doing':
        return Icons.edit_note_rounded;

      case 'Done':
      case 'Pro_Done':
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
      case 'Doing':
        return Colors.blueAccent;

      case 'Done':
      case 'Pro_Done':
        return Colors.greenAccent;

      default:
        return Colors.white70;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

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
                onRetry: _reloadReports,
              );
            }

            final reports = snapshot.data ?? const <PatrolReportModel>[];

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

                  _buildResultSummary(filteredReports.length, reports.length),

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

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF121826),

      centerTitle: false,

      titleSpacing: 4,

      leading: GlassActionButton(
        icon: Icons.arrow_back_rounded,

        onTap: () {
          Navigator.pop(context, true);
        },
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
            '${widget.plant} | '
            '${widget.atStatus}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),

      actions: [
        GlassActionButton(icon: Icons.refresh_rounded, onTap: _reloadReports),
      ],
    );
  }

  // ============================================================
  // FILTER
  // ============================================================

  Widget _buildFilterSection(List<String> areas) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),

      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.25),

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

              onChanged: (value) {
                if (value == _selectedArea) {
                  return;
                }

                setState(() {
                  _selectedArea = value;
                });
              },
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: CommonSearchableDropdown(
              label: 'Risk',

              selectedValue: _selectedRisk,

              items: _riskOptions,

              isRequired: false,

              onChanged: (value) {
                if (value == _selectedRisk) {
                  return;
                }

                setState(() {
                  _selectedRisk = value;
                });
              },
            ),
          ),

          const SizedBox(width: 12),

          GlassActionButton(icon: Icons.filter_alt_off, onTap: _clearFilters),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildResultSummary(int displayed, int total) {
    return Align(
      alignment: Alignment.centerLeft,

      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 15,
            color: Colors.orangeAccent,
          ),

          const SizedBox(width: 5),

          Text(
            '$displayed / $total reports'
            ' • Deadline priority',

            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TABLE
  // ============================================================

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
              Colors.white.withOpacity(.10),
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
              DataColumn(
                label: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: Colors.orangeAccent,
                    ),
                    SizedBox(width: 4),
                    Text('Deadline'),
                  ],
                ),
              ),
            ],

            rows: reports.map(_buildDataRow).toList(),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ROW
  // ============================================================

  String _rowKey(PatrolReportModel report) {
    return '${report.id}_'
        '${report.qr_key}_'
        '${report.area}_'
        '${report.machine}';
  }

  DataRow _buildDataRow(PatrolReportModel report) {
    final riskColor = CommonUI.riskColor(report.riskTotal);

    final isSelected = _selectedRowKey == _rowKey(report);

    return DataRow(
      color: MaterialStateProperty.resolveWith<Color?>((_) {
        if (isSelected) {
          return Colors.amber.withOpacity(.20);
        }

        return null;
      }),

      cells: [
        DataCell(_buildActionCell(report)),

        DataCell(_buildQrCell(report)),

        DataCell(_buildTextCell(report.area)),

        DataCell(_buildTextCell(report.machine)),

        DataCell(_buildRiskCell(report.riskTotal, riskColor)),

        DataCell(_buildDeadlineCell(report.dueDate)),
      ],
    );
  }

  // ============================================================
  // ACTION
  // ============================================================

  Widget _buildActionCell(PatrolReportModel report) {
    return SizedBox(
      width: 32,
      height: 32,

      child: Material(
        color: Colors.white.withOpacity(.10),

        borderRadius: BorderRadius.circular(8),

        child: InkWell(
          borderRadius: BorderRadius.circular(8),

          onTap: () {
            _openDetail(report);
          },

          child: Center(
            child: Icon(
              _statusIcon(report.atStatus),

              size: 26,

              color: _statusColor(report.atStatus),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // QR
  // ============================================================

  Widget _buildQrCell(PatrolReportModel report) {
    return SizedBox(
      width: 40,

      child: Text(
        '${report.qr_key ?? '-'}',

        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  // ============================================================
  // TEXT CELL
  // ============================================================

  Widget _buildTextCell(String value, {double maxWidth = 80}) {
    final text = value.trim().isEmpty ? '-' : value.trim();

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),

      child: Text(
        text,
        softWrap: true,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,

        style: TextStyle(color: Colors.white.withOpacity(.85)),
      ),
    );
  }

  // ============================================================
  // RISK
  // ============================================================

  Widget _buildRiskCell(String risk, Color color) {
    return SizedBox(
      width: 32,

      child: Center(
        child: Text(
          risk,

          style: TextStyle(
            color: color.withOpacity(.90),

            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DEADLINE
  // ============================================================

  Widget _buildDeadlineCell(DateTime? dueDate) {
    if (dueDate == null) {
      return const SizedBox(
        width: 86,
        child: Text('-', style: TextStyle(color: Colors.white38)),
      );
    }

    final now = DateTime.now();

    final today = _dateOnly(now);

    final date = _dateOnly(dueDate);

    final days = date.difference(today).inDays;

    final String statusText;

    final IconData icon;

    if (days < 0) {
      statusText = 'Late ${days.abs()}d';
      icon = Icons.warning_rounded;
    } else if (days == 0) {
      statusText = 'Today';
      icon = Icons.priority_high_rounded;
    } else if (days == 1) {
      statusText = 'Tomorrow';
      icon = Icons.schedule_rounded;
    } else {
      statusText = '${days}d left';
      icon = Icons.schedule_rounded;
    }

    final color = DueDateUtils.getDueDateColor(dueDate);

    return SizedBox(
      width: 100,

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            DateFormat('d/M/yy').format(dueDate),

            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 2),

          Row(
            children: [
              Icon(icon, size: 11, color: color.withOpacity(.8)),

              const SizedBox(width: 3),

              Flexible(
                child: Text(
                  statusText,

                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(
                    color: color.withOpacity(.75),

                    fontSize: 9,

                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
