import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/patrol_report_api.dart';
import '../common/common_searchable_dropdown.dart';
import '../common/common_ui_helper.dart';
import '../common/due_date_utils.dart';
import '../homeScreen/patrol_home_screen.dart';
import '../model/patrol_report_model.dart';
import '../qrCode/after_patrol.dart';
import '../redo/redo_detail_page.dart';
import '../widget/error_display.dart';
import '../widget/glass_action_button.dart';
import 'after_detail_page.dart';

class AfterPicDetailScreen extends StatefulWidget {
  final String accountCode;
  final String plant;
  final String atStatus; // Wait / Redo / Done (hoặc Wait,Redo)
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
  Future<List<PatrolReportModel>>? _futureReport;

  String? _filterArea;
  String? _filterRisk;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  void _loadReport() {
    // nếu pic = UNKNOWN thì lọc pic rỗng giống bạn
    const emptyLabel = 'UNKNOWN';
    final picFilter = (widget.pic == emptyLabel) ? '' : widget.pic.trim();

    setState(() {
      _futureReport = PatrolReportApi.fetchReports(
        plant: widget.plant,
        type: widget.patrolGroup.name,
        pic: picFilter,
        afStatus: widget.atStatus,
      );
    });
  }
  //
  // int _riskToScore(String risk) {
  //   switch (risk) {
  //     case 'V':
  //       return 5;
  //     case 'IV':
  //       return 4;
  //     case 'III':
  //       return 3;
  //     case 'II':
  //       return 2;
  //     case 'I':
  //       return 1;
  //     default:
  //       return 0;
  //   }
  // }
  //
  // Color _riskColor(String risk) {
  //   switch (risk) {
  //     case 'V':
  //       return Colors.red;
  //     case 'IV':
  //       return Colors.redAccent;
  //     default:
  //       return Colors.grey;
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
          GlassActionButton(icon: Icons.refresh_rounded, onTap: _loadReport),
        ],
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
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
                onRetry: _loadReport,
              );
            }

            final list = snapshot.data ?? [];
            if (list.isEmpty) {
              return const Center(
                child: Text(
                  'No data available',
                  style: TextStyle(color: Colors.grey, fontSize: 18),
                ),
              );
            }

            final areas = list.map((e) => e.area).toSet().toList();

            return Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  _buildFilterHeader(areas),
                  const SizedBox(height: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) =>
                          _buildReportTable(list, c.maxWidth),
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
              label: "Area",
              selectedValue: _filterArea,
              items: areas,
              isRequired: false,
              onChanged: (v) => setState(() => _filterArea = v),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CommonSearchableDropdown(
              label: "Risk",
              selectedValue: _filterRisk,
              items: const ['V', 'IV', 'III', 'II', 'I'],
              isRequired: false,
              onChanged: (v) => setState(() => _filterRisk = v),
            ),
          ),

          const SizedBox(width: 12),
          GlassActionButton(
            icon: Icons.filter_alt_off,
            onTap: () => setState(() {
              _filterArea = null;
              _filterRisk = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTable(List<PatrolReportModel> list, double maxWidth) {
    final filtered =
        list.where((r) {
          if (_filterArea != null && r.area != _filterArea) return false;
          if (_filterRisk != null && r.riskTotal != _filterRisk) return false;
          return true;
        }).toList()..sort((a, b) {
          final riskCompare = CommonUI.riskToScore(
            b.riskTotal,
          ).compareTo(CommonUI.riskToScore(a.riskTotal));
          if (riskCompare != 0) return riskCompare;

          final now = DateTime.now();
          final aDue = a.dueDate;
          final bDue = b.dueDate;

          if (aDue == null && bDue == null) return 0;
          if (aDue == null) return 1;
          if (bDue == null) return -1;

          final aOverdue = aDue.isBefore(now);
          final bOverdue = bDue.isBefore(now);

          if (aOverdue && !bOverdue) return -1;
          if (!aOverdue && bOverdue) return 1;

          final aDiff = (aDue.difference(now)).abs();
          final bDiff = (bDue.difference(now)).abs();
          return aDiff.compareTo(bDiff);
        });

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
            // ✅ FIX: chỉ set 1 cái để tránh NOT NORMALIZED
            dataRowHeight: 60, // đủ cho Area/Machine/Status xuống dòng

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
            rows: filtered.map((r) {
              final color = CommonUI.riskColor(r.riskTotal);

              return DataRow(
                cells: [
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 170),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: Material(
                              color: Colors.white.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => buildTarget(r),
                                    ),
                                  ).then((result) {
                                    if (result == true && mounted) {
                                      _loadReport();
                                    }
                                  });
                                },
                                child: Center(
                                  child: Icon(
                                    _statusIcon(r.atStatus),
                                    size: 28,
                                    color: _statusColor(r.atStatus),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  DataCell(
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${r.qr_key}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 80),
                      child: Text(
                        r.area,
                        softWrap: true,
                        maxLines: 3,
                        overflow: TextOverflow.visible,
                        style: TextStyle(color: Colors.white.withOpacity(0.85)),
                      ),
                    ),
                  ),

                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 80),
                      child: Text(
                        r.machine,
                        softWrap: true,
                        maxLines: 3,
                        overflow: TextOverflow.visible,
                        style: TextStyle(color: Colors.white.withOpacity(0.85)),
                      ),
                    ),
                  ),

                  DataCell(
                    SizedBox(
                      width: 32,
                      child: Center(
                        child: Text(
                          r.riskTotal,
                          style: TextStyle(
                            color: color.withOpacity(0.85),
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
                        r.dueDate == null
                            ? '-'
                            : DateFormat('M/d/yy').format(r.dueDate!),
                        style: TextStyle(
                          color: DueDateUtils.getDueDateColor(r.dueDate),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  // DataCell(
                  //   ConstrainedBox(
                  //     constraints: const BoxConstraints(maxWidth: 170),
                  //     child: Row(
                  //       crossAxisAlignment: CrossAxisAlignment.center,
                  //       children: [
                  //         SizedBox(
                  //           width: 32,
                  //           height: 32,
                  //           child: Material(
                  //             color: Colors.white.withOpacity(0.10),
                  //             borderRadius: BorderRadius.circular(8),
                  //             child: InkWell(
                  //               borderRadius: BorderRadius.circular(8),
                  //               onTap: () async {
                  //                 Navigator.push(
                  //                   context,
                  //                   MaterialPageRoute(
                  //                     builder: (_) => AfterDetailPage(
                  //                       accountCode: widget.accountCode,
                  //                       report: r,
                  //                       patrolGroup: widget.patrolGroup,
                  //                     ),
                  //                   ),
                  //                 ).then((result) {
                  //                   if (result == true && mounted) {
                  //                     _loadReport();
                  //                   }
                  //                 });
                  //
                  //                 // if (result == true) {
                  //                 //   _loadReport();
                  //                 //   Navigator.pop(context, true);
                  //                 // }
                  //               },
                  //               child: const Center(
                  //                 child: Icon(
                  //                   Icons.visibility_rounded,
                  //                   size: 18,
                  //                   color: Colors.white,
                  //                 ),
                  //               ),
                  //             ),
                  //           ),
                  //         ),
                  //         const SizedBox(width: 6),
                  //         // Expanded(
                  //         //   child: Text(
                  //         //     r.atStatus.toString(),
                  //         //     softWrap: true,
                  //         //     maxLines: 3,
                  //         //     overflow: TextOverflow.visible,
                  //         //     style: TextStyle(
                  //         //       color: DueDateUtils.getDueDateColor(r.dueDate),
                  //         //       fontWeight: FontWeight.w500,
                  //         //     ),
                  //         //   ),
                  //         // ),
                  //       ],
                  //     ),
                  //   ),
                  // ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'Redo':
        return Icons.restart_alt_rounded; // 🔁 redo
      case 'Wait':
        return Icons.edit_note_rounded; // ✏️ chờ xử lý
      case 'Done':
        return Icons.check_circle_rounded; // ✅ xong
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

  Widget buildTarget(PatrolReportModel r) {
    if (r.atStatus == 'Redo') {
      return RedoDetailPage(
        accountCode: widget.accountCode,
        patrolGroup: widget.patrolGroup,
        report: r,
      );
    }

    return AfterPatrol(
      accountCode: widget.accountCode,
      id: r.id!,
      patrolGroup: widget.patrolGroup,
    );
  }
}
