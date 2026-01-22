import 'package:auto_size_text/auto_size_text.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../after/after_pic_detail_screen.dart';
import '../api/patrol_pivot_api.dart';
import '../api/patrol_report_api.dart';
import '../common/common_ui_helper.dart';
import '../common/due_date_utils.dart';
import '../homeScreen/patrol_home_screen.dart';
import '../model/machine_model.dart';
import '../model/patrol_report_model.dart';
import '../model/pivot_response.dart';
import '../translator.dart';
import '../widget/error_display.dart';
import '../widget/glass_action_button.dart';
import 'recheck_pic_detail_screen.dart';

class RecheckDetailScreen extends StatefulWidget {
  final String accountCode;
  final List<MachineModel> machines;
  final String? selectedPlant;
  final String titleScreen;
  final PatrolGroup patrolGroup;

  const RecheckDetailScreen({
    super.key,
    required this.machines,
    required this.selectedPlant,
    required this.titleScreen,
    required this.patrolGroup,
    required this.accountCode,
  });

  @override
  State<RecheckDetailScreen> createState() => _RecheckDetailScreenState();
}

class _RecheckDetailScreenState extends State<RecheckDetailScreen> {
  Future<RiskPivotResponse>? _futurePivot;

  // filter input
  String? _selectedPlant;
  String _atStatus = 'Done'; // hoặc 'Wait,Redo'

  @override
  void initState() {
    super.initState();
    _selectedPlant = widget.selectedPlant;

    if (_selectedPlant != null) {
      _loadPivot();
    }
  }

  List<String> _mapStatusesForApi(String uiStatus) {
    if (uiStatus == 'Wait') return ['Wait', 'Redo']; // ✅ Wait bao gồm Redo
    return [uiStatus]; // Done -> Done
  }

  void _loadPivot() {
    if (_selectedPlant == null) return;

    final statuses = _mapStatusesForApi(_atStatus);

    setState(() {
      _futurePivot = PatrolPivotApi.fetchPivot(
        plant: _selectedPlant!,
        atStatus: statuses, // ✅ đổi param
        type: widget.patrolGroup.name,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121826),
        centerTitle: false,
        titleSpacing: 4,
        leading: GlassActionButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            SizedBox(
              width: 170,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '[Recheck] ${widget.titleScreen}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_selectedPlant ?? '-'} | $_atStatus',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),

            /// nếu muốn đổi atStatus nhanh
            // SizedBox(
            //   width: 140,
            //   child: DropdownButtonFormField<String>(
            //     value: _atStatus,
            //     dropdownColor: const Color(0xFF161D23),
            //     decoration: InputDecoration(
            //       contentPadding: const EdgeInsets.symmetric(
            //         horizontal: 10,
            //         vertical: 10,
            //       ),
            //       filled: true,
            //       fillColor: Colors.white.withOpacity(0.08),
            //       border: OutlineInputBorder(
            //         borderRadius: BorderRadius.circular(12),
            //         borderSide: BorderSide.none,
            //       ),
            //     ),
            //     style: const TextStyle(color: Colors.white),
            //     items: const [
            //       DropdownMenuItem(value: 'Wait', child: Text('Wait')),
            //       DropdownMenuItem(value: 'Done', child: Text('Done')),
            //       DropdownMenuItem(value: 'Redo', child: Text('Redo')),
            //     ],
            //     onChanged: (v) {
            //       if (v == null) return;
            //       setState(() => _atStatus = v);
            //       _loadPivot();
            //     },
            //   ),
            // ),
          ],
        ),
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
        child: _futurePivot == null
            ? Center(
                child: Text(
                  'No plant selected',
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
              )
            : FutureBuilder<RiskPivotResponse>(
                future: _futurePivot,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ErrorDisplay(
                      errorMessage: snapshot.error.toString(),
                      onRetry: _loadPivot,
                    );
                  }
                  final data = snapshot.data;
                  if (data == null) {
                    return const Center(
                      child: Text(
                        'No data available',
                        style: TextStyle(color: Colors.grey, fontSize: 18),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        _buildSummaryCard(data),
                        const SizedBox(height: 10),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, asyncSnapshot) {
                              return _buildPivotTable(
                                data,
                                asyncSnapshot.maxWidth,
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

  Widget _colHighlight({
    required Widget child,
    required double width,
    required bool isFirst, // cột bắt đầu khung đỏ
    required bool isLast, // cột kết thúc khung đỏ
    Color borderColor = Colors.red,
    Color bg = const Color(0x22FF0000), // đỏ mờ
  }) {
    return SizedBox(
      width: width,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            left: isFirst
                ? BorderSide(color: borderColor, width: 1)
                : BorderSide.none,
            right: isLast
                ? BorderSide(color: borderColor, width: 1)
                : BorderSide.none,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildSummaryCard(RiskPivotResponse data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Icon(Icons.table_chart_rounded, color: Colors.white.withOpacity(0.8)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Grand Total: ${data.grandTotal}  |  PIC count: ${data.rows.length}',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          GlassActionButton(icon: Icons.refresh_rounded, onTap: _loadPivot),
        ],
      ),
    );
  }

  Widget _buildPivotTable(RiskPivotResponse data, double maxWidth) {
    final rows = [...data.rows]..sort((a, b) => b.total.compareTo(a.total));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: maxWidth),

          child: DataTable(
            // ✅ KÉO GẦN LẠI
            columnSpacing: 8,
            horizontalMargin: 6, //
            checkboxHorizontalMargin: 6,
            headingRowHeight: 42,
            dataRowHeight: 40,

            headingRowColor: MaterialStateProperty.all(
              Colors.white.withOpacity(0.10),
            ),
            headingTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),

            columns: [
              const DataColumn(
                label: SizedBox(width: 100, child: Text('PIC')),
              ), // 👈 PIC rộng vừa đủ
              const DataColumn(
                label: SizedBox(width: 28, child: Center(child: Text('I'))),
              ),
              const DataColumn(
                label: SizedBox(width: 28, child: Center(child: Text('II'))),
              ),
              const DataColumn(
                label: SizedBox(width: 34, child: Center(child: Text('III'))),
              ),
              DataColumn(
                label: _colHighlight(
                  width: 34,
                  isFirst: true,
                  isLast: true,
                  borderColor: Colors.redAccent,
                  bg: Colors.redAccent.withOpacity(0.08),
                  child: const Text(
                    'IV',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
              DataColumn(
                label: _colHighlight(
                  width: 34,
                  isFirst: true,
                  isLast: true,
                  borderColor: Colors.red,
                  bg: Colors.red.withOpacity(0.08),
                  child: const Text('V', style: TextStyle(color: Colors.red)),
                ),
              ),

              const DataColumn(
                label: SizedBox(
                  width: 46,
                  child: Center(
                    child: Text(
                      'Total',
                      style: TextStyle(color: Colors.cyanAccent),
                    ),
                  ),
                ),
              ),
            ],

            rows: [
              ...rows.map((r) => _rowToDataRowCompact(r, isTotal: false)),
              _rowToDataRowCompact(data.totals, isTotal: true),
            ],
          ),
        ),
      ),
    );
  }

  DataRow _rowToDataRowCompact(RiskPivotRow r, {required bool isTotal}) {
    final textStyle = TextStyle(
      color: isTotal ? Colors.white : Colors.white.withOpacity(0.85),
      fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
      fontSize: 13,
    );

    Widget numCell(
      int v, {
      double w = 28,
      Color? color, // ✅ màu riêng cho từng cột
    }) {
      final display = (v == 0) ? '-' : '$v';

      return SizedBox(
        width: w,
        child: Center(
          child: Text(
            display,
            style: textStyle.copyWith(color: color ?? textStyle.color),
          ),
        ),
      );
    }

    return DataRow(
      color: isTotal
          ? MaterialStateProperty.all(Colors.white.withOpacity(0.08))
          : null,
      cells: [
        DataCell(
          InkWell(
            onTap: isTotal
                ? null
                : () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecheckPicDetailScreen(
                          accountCode: widget.accountCode,
                          plant: _selectedPlant!,
                          atStatus: _atStatus,
                          pic: r.pic,
                          patrolGroup: widget.patrolGroup,
                        ),
                      ),
                    );

                    // ✅ nếu màn detail update gì đó, quay lại reload pivot
                    if (result == true) {
                      _loadPivot();
                    }
                  },
            child: Row(
              children: [
                Text(r.pic, style: textStyle),
                if (!isTotal) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: Colors.white10.withOpacity(0.5),
                  ),
                ],
              ],
            ),
          ),
        ),
        // ... I, II, III giữ nguyên
        DataCell(numCell(r.i, w: 28)),
        DataCell(numCell(r.ii, w: 28)),
        DataCell(numCell(r.iii, w: 28)),

        // IV / V / Total nổi bật
        // IV
        DataCell(
          _colHighlight(
            width: 34,
            isFirst: true,
            isLast: true,
            borderColor: Colors.redAccent,
            bg: Colors.redAccent.withOpacity(0.06),
            child: Text(
              (r.iv == 0) ? '-' : '${r.iv}',
              style: textStyle.copyWith(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // V
        DataCell(
          _colHighlight(
            width: 34,
            isFirst: true,
            isLast: true,
            borderColor: Colors.red,
            bg: Colors.red.withOpacity(0.06),
            child: Text(
              (r.v == 0) ? '-' : '${r.v}',
              style: textStyle.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        DataCell(
          SizedBox(
            width: 46,
            child: Center(
              child: Text(
                (r.total == 0) ? '-' : '${r.total}',
                style: textStyle.copyWith(color: Colors.cyanAccent),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
