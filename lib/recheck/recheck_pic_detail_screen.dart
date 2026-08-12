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
  // ============================================================
  // CONSTANTS
  // ============================================================

  static const String _emptyPicLabel = 'UNKNOWN';

  static const List<String> _riskOptions = ['V', 'IV', 'III', 'II', 'I'];

  static const LinearGradient _backgroundGradient = LinearGradient(
    colors: [Color(0xFF121826), Color(0xFF1F2937), Color(0xFF374151)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============================================================
  // STATE
  // ============================================================

  Future<List<PatrolReportModel>>? _futureReport;

  String? _selectedArea;
  String? _selectedRisk;
  String? _selectedRowKey;

  /// Nếu detail có update thì khi back ra Pivot
  /// sẽ trả true để Pivot reload.
  bool _hasChanges = false;

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

  String get _normalizedPic {
    final value = widget.pic.trim();

    if (value == _emptyPicLabel) {
      return '';
    }

    return value;
  }

  void _reloadReports() {
    if (!mounted) {
      return;
    }

    final future = PatrolReportApi.fetchReports(
      plant: widget.plant,
      type: widget.patrolGroup.name,
      pic: _normalizedPic,
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
    final areas = reports
        .map((report) => report.area.trim())
        .where((area) => area.isNotEmpty)
        .toSet()
        .toList();

    areas.sort();

    return areas;
  }

  // ============================================================
  // FILTER + SORT
  //
  // LOGIC:
  //
  // 1. Risk cao hơn lên trước
  //    V -> IV -> III -> II -> I
  //
  // 2. Cùng Risk:
  //    overdue trước
  //    sau đó deadline gần hiện tại hơn
  //
  // 3. Cùng Risk + cùng deadline:
  //    ID nhỏ hơn trước
  // ============================================================

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
      // ========================================================
      // 1. RISK CAO TRƯỚC
      // ========================================================

      final aRisk = CommonUI.riskToScore(a.riskTotal);

      final bRisk = CommonUI.riskToScore(b.riskTotal);

      final riskCompare = bRisk.compareTo(aRisk);

      if (riskCompare != 0) {
        return riskCompare;
      }

      // ========================================================
      // 2. CÙNG RISK -> DEADLINE
      // ========================================================

      final deadlineCompare = _compareDueDate(a.dueDate, b.dueDate, now);

      if (deadlineCompare != 0) {
        return deadlineCompare;
      }

      // ========================================================
      // 3. CÙNG HẾT -> ID
      // ========================================================

      final aId = a.id ?? 0;
      final bId = b.id ?? 0;

      return aId.compareTo(bId);
    });

    return filtered;
  }

  // ============================================================
  // DEADLINE SORT
  // ============================================================

  int _compareDueDate(DateTime? a, DateTime? b, DateTime now) {
    // ============================================================
    // NULL -> CUỐI
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
    // overdue trước
    // chưa overdue sau
    // cùng trạng thái -> gần hiện tại hơn trước
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

  // ============================================================
  // DATE
  // ============================================================

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  Future<void> _openDetail(PatrolReportModel report) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedRowKey = _rowKey(report);
    });

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RecheckDetailPage(
          accountCode: widget.accountCode,
          patrolGroup: widget.patrolGroup,
          report: report,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (result == true) {
      // ========================================================
      // DATA ĐÃ UPDATE
      // ========================================================

      _hasChanges = true;

      // ========================================================
      // RELOAD LIST
      // ========================================================

      _reloadReports();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,

      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        Navigator.of(context).pop(_hasChanges);
      },

      child: Scaffold(
        appBar: _buildAppBar(),

        body: Container(
          decoration: const BoxDecoration(gradient: _backgroundGradient),

          child: FutureBuilder<List<PatrolReportModel>>(
            future: _futureReport,

            builder: (context, snapshot) {
              // =================================================
              // LOADING
              // =================================================

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // =================================================
              // ERROR
              // =================================================

              if (snapshot.hasError) {
                return ErrorDisplay(
                  errorMessage: snapshot.error.toString(),

                  onRetry: _reloadReports,
                );
              }

              // =================================================
              // DATA
              // =================================================

              final reports = snapshot.data ?? const <PatrolReportModel>[];

              if (reports.isEmpty) {
                return const Center(
                  child: Text(
                    'No data available',
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                );
              }

              // =================================================
              // FILTER DATA
              // =================================================

              final areas = _extractAreas(reports);

              final filteredReports = _applyFiltersAndSort(reports);

              // =================================================
              // UI
              // =================================================

              return Padding(
                padding: const EdgeInsets.all(8),

                child: Column(
                  children: [
                    _buildFilterHeader(areas),

                    const SizedBox(height: 8),

                    _buildResultSummary(
                      displayed: filteredReports.length,
                      total: reports.length,
                    ),

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
          Navigator.pop(context, _hasChanges);
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

  Widget _buildFilterHeader(List<String> areas) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),

      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.25),

        borderRadius: BorderRadius.circular(12),
      ),

      child: Row(
        children: [
          // ======================================================
          // AREA
          // ======================================================
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

          // ======================================================
          // RISK
          // ======================================================
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

          // ======================================================
          // CLEAR FILTER
          // ======================================================
          GlassActionButton(icon: Icons.filter_alt_off, onTap: _clearFilters),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildResultSummary({required int displayed, required int total}) {
    return Align(
      alignment: Alignment.centerLeft,

      child: Row(
        children: [
          const Icon(
            Icons.priority_high_rounded,
            size: 15,
            color: Colors.orangeAccent,
          ),

          const SizedBox(width: 5),

          Text(
            '$displayed / $total reports'
            ' • Risk → Deadline',

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
            columnSpacing: 8,

            horizontalMargin: 8,

            headingRowHeight: 44,

            dataRowHeight: 64,

            headingRowColor: MaterialStateProperty.all(
              Colors.white.withOpacity(.10),
            ),

            headingTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),

            columns: const [
              // ACTION
              DataColumn(label: Text('')),

              // QR
              DataColumn(label: Text('QR')),

              // AREA
              DataColumn(label: Text('Area')),

              // MACHINE
              DataColumn(label: Text('Machine')),

              // RISK
              DataColumn(
                label: Row(
                  children: [
                    Icon(
                      Icons.priority_high_rounded,
                      color: Colors.orangeAccent,
                      size: 14,
                    ),

                    SizedBox(width: 3),

                    Text('Risk'),
                  ],
                ),
              ),

              // DEADLINE
              DataColumn(
                label: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      color: Colors.cyanAccent,
                      size: 14,
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
  // ROW KEY
  // ============================================================

  String _rowKey(PatrolReportModel report) {
    return '${report.id}_'
        '${report.qr_key}_'
        '${report.area}_'
        '${report.machine}';
  }

  // ============================================================
  // DATA ROW
  // ============================================================

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
        // ======================================================
        // ACTION
        // ======================================================
        DataCell(_buildViewButton(report)),

        // ======================================================
        // QR
        // ======================================================
        DataCell(_buildQrCell(report)),

        // ======================================================
        // AREA
        // ======================================================
        DataCell(_buildWrappedText(report.area, maxWidth: 90)),

        // ======================================================
        // MACHINE
        // ======================================================
        DataCell(_buildWrappedText(report.machine, maxWidth: 100)),

        // ======================================================
        // RISK
        // ======================================================
        DataCell(_buildRiskCell(report.riskTotal, riskColor)),

        // ======================================================
        // DEADLINE
        // ======================================================
        DataCell(_buildDeadlineCell(report.dueDate)),
      ],
    );
  }

  // ============================================================
  // VIEW BUTTON
  // ============================================================

  Widget _buildViewButton(PatrolReportModel report) {
    return SizedBox(
      width: 34,
      height: 34,

      child: Material(
        color: Colors.white.withOpacity(.10),

        borderRadius: BorderRadius.circular(9),

        child: InkWell(
          borderRadius: BorderRadius.circular(9),

          onTap: () {
            _openDetail(report);
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
    );
  }

  // ============================================================
  // QR
  // ============================================================

  Widget _buildQrCell(PatrolReportModel report) {
    final qr = '${report.qr_key}';

    return SizedBox(
      width: 45,

      child: Text(
        qr,

        maxLines: 2,

        overflow: TextOverflow.ellipsis,

        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  // ============================================================
  // TEXT CELL
  // ============================================================

  Widget _buildWrappedText(String value, {double maxWidth = 80}) {
    final text = value.trim().isEmpty ? '-' : value.trim();

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),

      child: Text(
        text,

        softWrap: true,

        maxLines: 3,

        overflow: TextOverflow.ellipsis,

        style: TextStyle(color: Colors.white.withOpacity(.85), fontSize: 12),
      ),
    );
  }

  // ============================================================
  // RISK
  // ============================================================

  Widget _buildRiskCell(String risk, Color color) {
    return SizedBox(
      width: 40,

      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),

          decoration: BoxDecoration(
            color: color.withOpacity(.12),

            borderRadius: BorderRadius.circular(8),

            border: Border.all(color: color.withOpacity(.35)),
          ),

          child: Text(
            risk,

            style: TextStyle(
              color: color,

              fontWeight: FontWeight.w900,

              fontSize: 13,
            ),
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
        width: 110,

        child: Text('-', style: TextStyle(color: Colors.white38)),
      );
    }

    final now = DateTime.now();

    final today = _dateOnly(now);

    final date = _dateOnly(dueDate);

    final days = date.difference(today).inDays;

    final String statusText;

    final IconData icon;

    // ==========================================================
    // DEADLINE STATUS
    // ==========================================================

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
      width: 115,

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // ====================================================
          // DD/MM/YYYY
          // ====================================================
          Text(
            DateFormat('dd/MM/yyyy').format(dueDate),

            style: TextStyle(
              color: color,

              fontWeight: FontWeight.w700,

              fontSize: 12,
            ),
          ),

          const SizedBox(height: 3),

          // ====================================================
          // STATUS
          // ====================================================
          Row(
            children: [
              Icon(icon, size: 11, color: color.withOpacity(.85)),

              const SizedBox(width: 4),

              Flexible(
                child: Text(
                  statusText,

                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(
                    color: color.withOpacity(.80),

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
