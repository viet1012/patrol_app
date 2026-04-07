import 'dart:convert';

import 'package:chuphinh/api/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

String kBaseUrl = ApiConfig.baseUrl;

class RiskBreakdownDto {
  final int total;
  final int i;
  final int ii;
  final int iii;
  final int iv;
  final int v;

  const RiskBreakdownDto({
    required this.total,
    required this.i,
    required this.ii,
    required this.iii,
    required this.iv,
    required this.v,
  });

  factory RiskBreakdownDto.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) => value is num ? value.toInt() : 0;

    return RiskBreakdownDto(
      total: toInt(json['total']),
      i: toInt(json['i']),
      ii: toInt(json['ii']),
      iii: toInt(json['iii']),
      iv: toInt(json['iv']),
      v: toInt(json['v']),
    );
  }
}

class PatrolPicRowDto {
  final String pic;
  final RiskBreakdownDto before;
  final RiskBreakdownDto finished;
  final RiskBreakdownDto remain;
  final int recheckAllTotal;
  final RiskBreakdownDto recheckOk;
  final RiskBreakdownDto recheckNg;

  const PatrolPicRowDto({
    required this.pic,
    required this.before,
    required this.finished,
    required this.remain,
    required this.recheckAllTotal,
    required this.recheckOk,
    required this.recheckNg,
  });

  factory PatrolPicRowDto.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) => value is num ? value.toInt() : 0;

    return PatrolPicRowDto(
      pic: (json['pic'] ?? '').toString(),
      before: RiskBreakdownDto.fromJson(
        (json['before'] ?? const {}) as Map<String, dynamic>,
      ),
      finished: RiskBreakdownDto.fromJson(
        (json['finished'] ?? const {}) as Map<String, dynamic>,
      ),
      remain: RiskBreakdownDto.fromJson(
        (json['remain'] ?? const {}) as Map<String, dynamic>,
      ),
      recheckAllTotal: toInt(json['recheckAllTotal']),
      recheckOk: RiskBreakdownDto.fromJson(
        (json['recheckOk'] ?? const {}) as Map<String, dynamic>,
      ),
      recheckNg: RiskBreakdownDto.fromJson(
        (json['recheckNg'] ?? const {}) as Map<String, dynamic>,
      ),
    );
  }
}

class PatrolFacSummaryDto {
  final String fac;
  final double? finishedRate;
  final double? remainRate;
  final double? okRate;
  final double? ngRate;
  final List<PatrolPicRowDto> rows;
  final PatrolPicRowDto? total;

  const PatrolFacSummaryDto({
    required this.fac,
    required this.finishedRate,
    required this.remainRate,
    required this.okRate,
    required this.ngRate,
    required this.rows,
    required this.total,
  });

  factory PatrolFacSummaryDto.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic value) => value is num ? value.toDouble() : null;

    final rows = (json['rows'] as List? ?? [])
        .map((e) => PatrolPicRowDto.fromJson(e as Map<String, dynamic>))
        .toList();

    final total = json['total'] == null
        ? null
        : PatrolPicRowDto.fromJson(json['total'] as Map<String, dynamic>);

    return PatrolFacSummaryDto(
      fac: (json['fac'] ?? '').toString(),
      finishedRate: toDouble(json['finishedRate']),
      remainRate: toDouble(json['remainRate']),
      okRate: toDouble(json['okRate']),
      ngRate: toDouble(json['ngRate']),
      rows: rows,
      total: total,
    );
  }
}

class PatrolSummaryResponseDto {
  final String fromD;
  final String toD;
  final String plant;
  final String type;
  final List<PatrolFacSummaryDto> facs;

  const PatrolSummaryResponseDto({
    required this.fromD,
    required this.toD,
    required this.plant,
    required this.type,
    required this.facs,
  });

  factory PatrolSummaryResponseDto.fromJson(Map<String, dynamic> json) {
    final facs = (json['facs'] as List? ?? [])
        .map((e) => PatrolFacSummaryDto.fromJson(e as Map<String, dynamic>))
        .toList();

    return PatrolSummaryResponseDto(
      fromD: (json['fromD'] ?? '').toString(),
      toD: (json['toD'] ?? '').toString(),
      plant: (json['plant'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      facs: facs,
    );
  }
}

class PatrolApi {
  const PatrolApi();

  Future<PatrolSummaryResponseDto> fetchSummary({
    required String from,
    required String to,
    required String plant,
    required String type,
  }) async {
    final uri = Uri.parse('$kBaseUrl/api/patrol_report/summary').replace(
      queryParameters: {'from': from, 'to': to, 'plant': plant, 'type': type},
    );

    print("url: ${uri}");
    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    return PatrolSummaryResponseDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

class PatrolSummaryScreen extends StatefulWidget {
  final String fromD;
  final String toD;
  final String plant;
  final String type;

  const PatrolSummaryScreen({
    super.key,
    required this.fromD,
    required this.toD,
    required this.plant,
    required this.type,
  });

  @override
  State<PatrolSummaryScreen> createState() => _PatrolSummaryScreenState();
}

class _PatrolSummaryScreenState extends State<PatrolSummaryScreen> {
  final PatrolApi _api = const PatrolApi();
  late Future<PatrolSummaryResponseDto> _future;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _future = _api.fetchSummary(
      from: widget.fromD,
      to: widget.toD,
      plant: widget.plant,
      type: widget.type,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PatrolSummaryResponseDto>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Load failed: ${snapshot.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final facs = snapshot.data?.facs ?? const <PatrolFacSummaryDto>[];
        if (facs.isEmpty) {
          return const Center(
            child: Text('No data', style: TextStyle(color: Colors.white70)),
          );
        }

        return Column(
          children: [
            for (int i = 0; i < facs.length; i++) ...[
              FacSummaryCard(fac: facs[i]),
              if (i != facs.length - 1) const SizedBox(height: 14),
            ],
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class TableUiConfig {
  static const double cardPadding = 10;
  static const double tableHeight = 340;
  static const double gapBetweenTables = 8;

  static const double titleHeight = 36;
  static const double groupHeaderHeight = 30;
  static const double headerRowHeight = 34;
  static const double cellHeight = 34;

  static const double borderRadius = 12;

  static const Color borderColor = Color(0xFFD7DCE5);
  static const Color groupedHeaderBg = Color(0xFFF3F6FA);
  static const Color headerBg = Color(0xFFF8FAFC);
  static const Color totalRowBg = Color(0xFFFFF7CC);
  static const Color tableBg = Colors.white;

  static const Color finishedHeaderBg = const Color(0xFF8FEFA0);
  static const Color okHeaderBg = const Color(0xFF8FEFA0);
  static const Color remainHeaderBg = const Color(0xFFF89292);
  static const Color ngHeaderBg = const Color(0xFFF89292);

  static const Color finishedBg = const Color(0xFFBFF2C8);
  static const Color remainBg = Color(0xFFFFC2C2);
  static const Color okBg = const Color(0xFFBFF2C8);
  static const Color ngBg = Color(0xFFFFC2C2);

  static const Color finishedBorder = Color(0xFF7BCB8D);
  static const Color remainBorder = Color(0xFFF89292);
  static const Color okBorder = Color(0xFF7BCB8D);
  static const Color ngBorder = Color(0xFFF89292);
  static const List<String> beforeColumns = [
    'PIC',
    'Total',
    'I',
    'II',
    'III',
    'IV',
    'V',
  ];

  static const List<String> afterColumns = [
    'PIC',
    'Total',
    'I',
    'II',
    'III',
    'IV',
    'V',
    'Total',
    'I',
    'II',
    'III',
    'IV',
    'V',
  ];

  static const List<String> recheckColumns = [
    'PIC',
    'All',
    'Total',
    'I',
    'II',
    'III',
    'IV',
    'V',
    'Total',
    'I',
    'II',
    'III',
    'IV',
    'V',
  ];

  static double columnWidth(String column) {
    switch (column) {
      case 'PIC':
        return 150;
      case 'Total':
      case 'All':
        return 54;
      case 'I':
      case 'II':
      case 'III':
      case 'IV':
      case 'V':
        return 42;
      default:
        return 58;
    }
  }

  static double tableWidth(List<String> columns) {
    return columns.fold(0.0, (sum, item) => sum + columnWidth(item));
  }
}

class FacSummaryCard extends StatefulWidget {
  final PatrolFacSummaryDto fac;

  const FacSummaryCard({super.key, required this.fac});

  @override
  State<FacSummaryCard> createState() => _FacSummaryCardState();
}

class _FacSummaryCardState extends State<FacSummaryCard> {
  late final ScrollController _horizontalController;

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  String _percent(double? value) {
    if (value == null) return '--';
    return '${(value * 100).round()}%';
  }

  List<PatrolPicRowDto> get _displayRows => [
    ...widget.fac.rows,
    if (widget.fac.total != null) widget.fac.total!,
  ];

  double get _tableHeight {
    final rowCount = _displayRows.length;

    if (rowCount <= 5) return 300;
    if (rowCount >= 8) return 480;

    return 370;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(TableUiConfig.borderRadius),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryHeader(
            facName: widget.fac.fac,
            finishedRate: _percent(widget.fac.finishedRate),
            remainRate: _percent(widget.fac.remainRate),
            okRate: _percent(widget.fac.okRate),
            ngRate: _percent(widget.fac.ngRate),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: _tableHeight,
            child: Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              trackVisibility: true,
              notificationPredicate: (notification) =>
                  notification.metrics.axis == Axis.horizontal,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: TableUiConfig.tableWidth(
                        TableUiConfig.beforeColumns,
                      ),
                      child: BeforeTable(rows: _displayRows),
                    ),
                    const SizedBox(width: TableUiConfig.gapBetweenTables),
                    SizedBox(
                      width: TableUiConfig.tableWidth(
                        TableUiConfig.afterColumns,
                      ),
                      child: AfterTable(
                        rows: _displayRows,
                        finishedRate: widget.fac.finishedRate,
                        remainRate: widget.fac.remainRate,
                      ),
                    ),
                    const SizedBox(width: TableUiConfig.gapBetweenTables),
                    SizedBox(
                      width: TableUiConfig.tableWidth(
                        TableUiConfig.recheckColumns,
                      ),
                      child: RecheckTable(
                        rows: _displayRows,
                        okRate: widget.fac.okRate,
                        ngRate: widget.fac.ngRate,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final String facName;
  final String finishedRate;
  final String remainRate;
  final String okRate;
  final String ngRate;

  const _SummaryHeader({
    required this.facName,
    required this.finishedRate,
    required this.remainRate,
    required this.okRate,
    required this.ngRate,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            facName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        // _SummaryPill(label: 'Finished', value: finishedRate),
        // _SummaryPill(label: 'Remain', value: remainRate),
        // _SummaryPill(label: 'OK', value: okRate),
        // _SummaryPill(label: 'NG', value: ngRate),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryPill({required this.label, required this.value});

  Color _valueColor() {
    switch (label) {
      case 'Finished':
      case 'OK':
        return Colors.greenAccent;
      case 'Remain':
      case 'NG':
        return Colors.orangeAccent;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.black.withOpacity(0.18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: _valueColor(),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class BeforeTable extends StatelessWidget {
  final List<PatrolPicRowDto> rows;

  const BeforeTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return ExcelLikeTable(
      titleLeft: 'BEFORE',
      titleCenter: 'NG points',
      columns: TableUiConfig.beforeColumns,
      rows: rows.map((row) {
        final before = row.before;
        return TableRowData(
          isTotal: row.pic.toUpperCase() == 'TOTAL',
          cells: [
            row.pic,
            before.total,
            before.i,
            before.ii,
            before.iii,
            before.iv,
            before.v,
          ],
        );
      }).toList(),
    );
  }
}

class AfterTable extends StatelessWidget {
  final List<PatrolPicRowDto> rows;
  final double? finishedRate;
  final double? remainRate;

  const AfterTable({
    super.key,
    required this.rows,
    required this.finishedRate,
    required this.remainRate,
  });

  String _percent(double? value) {
    if (value == null) return '--';
    return '${(value * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    return ExcelLikeTable(
      titleLeft: 'AFTER TOTAL',
      titleCenter: 'Pro action (All)',
      subtitleRightWidget: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          children: [
            const TextSpan(
              text: 'Finished ',
              style: TextStyle(color: Colors.black54),
            ),
            TextSpan(
              text: _percent(finishedRate),
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w800,
              ),
            ),
            const TextSpan(
              text: '   •   ',
              style: TextStyle(color: Colors.black38),
            ),
            const TextSpan(
              text: 'Remain ',
              style: TextStyle(color: Colors.black54),
            ),
            TextSpan(
              text: _percent(remainRate),
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      columns: TableUiConfig.afterColumns,
      groupedHeaders: const [
        GroupedHeader(
          label: 'Finished',
          startCol: 1,
          colSpan: 6,
          backgroundColor: TableUiConfig.finishedHeaderBg,
          borderColor: TableUiConfig.finishedBorder,
        ),
        GroupedHeader(
          label: 'Remain',
          startCol: 7,
          colSpan: 6,
          backgroundColor: TableUiConfig.remainHeaderBg,
          borderColor: TableUiConfig.remainBorder,
        ),
      ],
      rows: rows.map((row) {
        final finished = row.finished;
        final remain = row.remain;
        return TableRowData(
          isTotal: row.pic.toUpperCase() == 'TOTAL',
          cells: [
            row.pic,
            finished.total,
            finished.i,
            finished.ii,
            finished.iii,
            finished.iv,
            finished.v,
            remain.total,
            remain.i,
            remain.ii,
            remain.iii,
            remain.iv,
            remain.v,
          ],
        );
      }).toList(),
    );
  }
}

class RecheckTable extends StatelessWidget {
  final List<PatrolPicRowDto> rows;
  final double? okRate;
  final double? ngRate;

  const RecheckTable({
    super.key,
    required this.rows,
    required this.okRate,
    required this.ngRate,
  });

  String _percent(double? value) {
    if (value == null) return '--';
    return '${(value * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    return ExcelLikeTable(
      titleCenter: 'HSE re-check (All)',
      subtitleRightWidget: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          children: [
            const TextSpan(
              text: 'OK ',
              style: TextStyle(color: Colors.black54),
            ),
            TextSpan(
              text: _percent(okRate),
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w800,
              ),
            ),
            const TextSpan(
              text: '   •   ',
              style: TextStyle(color: Colors.black38),
            ),
            const TextSpan(
              text: 'NG ',
              style: TextStyle(color: Colors.black54),
            ),
            TextSpan(
              text: _percent(ngRate),
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      columns: TableUiConfig.recheckColumns,
      groupedHeaders: const [
        GroupedHeader(
          label: 'OK',
          startCol: 2,
          colSpan: 6,
          backgroundColor: TableUiConfig.okHeaderBg,
          borderColor: TableUiConfig.okBorder,
        ),
        GroupedHeader(
          label: 'NG',
          startCol: 8,
          colSpan: 6,
          backgroundColor: TableUiConfig.ngHeaderBg,
          borderColor: TableUiConfig.ngBorder,
        ),
      ],
      rows: rows.map((row) {
        final ok = row.recheckOk;
        final ng = row.recheckNg;

        return TableRowData(
          isTotal: row.pic.toUpperCase() == 'TOTAL',
          cells: [
            row.pic,
            row.recheckAllTotal,
            ok.total,
            ok.i,
            ok.ii,
            ok.iii,
            ok.iv,
            ok.v,
            ng.total,
            ng.i,
            ng.ii,
            ng.iii,
            ng.iv,
            ng.v,
          ],
        );
      }).toList(),
    );
  }
}

class GroupedHeader {
  final String label;
  final int startCol;
  final int colSpan;
  final Color? backgroundColor;
  final Color? borderColor;

  const GroupedHeader({
    required this.label,
    required this.startCol,
    required this.colSpan,
    this.backgroundColor,
    this.borderColor,
  });
}

class TableRowData {
  final bool isTotal;
  final List<dynamic> cells;

  const TableRowData({required this.isTotal, required this.cells});
}

class ExcelLikeTable extends StatelessWidget {
  final String? titleLeft;
  final String? titleCenter;
  final String? subtitleRight;
  final Widget? subtitleRightWidget;
  final List<String> columns;
  final List<TableRowData> rows;
  final List<GroupedHeader> groupedHeaders;

  const ExcelLikeTable({
    super.key,
    this.titleLeft,
    this.titleCenter,
    this.subtitleRight,
    this.subtitleRightWidget,
    required this.columns,
    required this.rows,
    this.groupedHeaders = const [],
  });

  Map<int, TableColumnWidth> _buildColumnWidths() {
    final widths = <int, TableColumnWidth>{};
    for (int i = 0; i < columns.length; i++) {
      widths[i] = FixedColumnWidth(TableUiConfig.columnWidth(columns[i]));
    }
    return widths;
  }

  double _columnWidthAt(int index) {
    return TableUiConfig.columnWidth(columns[index]);
  }

  double _leftOffsetOfColumn(int startIndex) {
    double offset = 0;
    for (int i = 0; i < startIndex; i++) {
      offset += _columnWidthAt(i);
    }
    return offset;
  }

  double _spanWidth(GroupedHeader header) {
    double width = 0;
    for (int i = 0; i < header.colSpan; i++) {
      width += _columnWidthAt(header.startCol + i);
    }
    return width;
  }

  Color _groupHeaderBg(GroupedHeader header) {
    return header.backgroundColor ?? TableUiConfig.groupedHeaderBg;
  }

  Color _groupBorderColor(GroupedHeader header) {
    return header.borderColor ?? TableUiConfig.borderColor;
  }

  bool _isAfterFinishedColumn(int index) => index >= 1 && index <= 6;

  bool _isAfterRemainColumn(int index) => index >= 7 && index <= 12;

  bool _isRecheckOkColumn(int index) => index >= 2 && index <= 7;

  bool _isRecheckNgColumn(int index) => index >= 8 && index <= 13;

  Color? _cellBackground(int index) {
    if (index == 0) return const Color(0xFFF7F8FA);
    if (titleLeft == 'AFTER TOTAL') {
      if (_isAfterFinishedColumn(index)) return TableUiConfig.finishedBg;
      if (_isAfterRemainColumn(index)) return TableUiConfig.remainBg;
    }

    if (titleCenter == 'HSE re-check (All)') {
      if (_isRecheckOkColumn(index)) return TableUiConfig.okBg;
      if (_isRecheckNgColumn(index)) return TableUiConfig.ngBg;
    }

    return null;
  }

  Border _cellBorder(int index) {
    final normal = BorderSide(color: const Color(0xFFBFC7D3), width: 1);

    final rowLine = BorderSide(color: const Color(0xFFD7DCE5), width: 1);

    final picDivider = BorderSide(color: const Color(0xFF98A2B3), width: 2);

    final finishedStrong = BorderSide(
      color: TableUiConfig.finishedBorder,
      width: 2,
    );

    final remainStrong = BorderSide(
      color: TableUiConfig.remainBorder,
      width: 2,
    );

    final okStrong = BorderSide(color: TableUiConfig.okBorder, width: 2);

    final ngStrong = BorderSide(color: TableUiConfig.ngBorder, width: 2);

    if (index == 0) {
      return Border(bottom: rowLine);
    }

    if (titleLeft == 'AFTER TOTAL') {
      if (index == 1) {
        return Border(left: finishedStrong, right: normal, bottom: rowLine);
      }
      if (index == 6) {
        return Border(right: finishedStrong, bottom: rowLine);
      }
      if (index == 7) {
        return Border(left: remainStrong, bottom: rowLine);
      }
      if (index == 12) {
        return Border(right: remainStrong, bottom: rowLine);
      }
    }

    if (titleCenter == 'HSE re-check (All)') {
      if (index == 2) {
        return Border(left: okStrong, bottom: rowLine);
      }
      if (index == 7) {
        return Border(right: okStrong, bottom: rowLine);
      }
      if (index == 8) {
        return Border(left: ngStrong, bottom: rowLine);
      }
      if (index == 13) {
        return Border(right: ngStrong, bottom: rowLine);
      }
    }

    return Border(
      right: BorderSide(color: const Color(0xFFD7DCE5), width: 1),
      bottom: rowLine,
    );
  }

  @override
  Widget build(BuildContext context) {
    final columnWidths = _buildColumnWidths();

    return Container(
      decoration: BoxDecoration(
        color: TableUiConfig.tableBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TableUiConfig.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TableTitleBar(
            titleLeft: titleLeft,
            titleCenter: titleCenter,
            subtitleRight: subtitleRight,
            subtitleRightWidget: subtitleRightWidget,
          ),

          if (groupedHeaders.isNotEmpty)
            SizedBox(
              height: TableUiConfig.groupHeaderHeight,
              child: Stack(
                children: [
                  Table(
                    columnWidths: columnWidths,
                    border: const TableBorder(
                      horizontalInside: BorderSide(
                        color: TableUiConfig.borderColor,
                        width: 1,
                      ),
                      verticalInside: BorderSide(
                        color: TableUiConfig.borderColor,
                      ),
                    ),
                    children: [
                      TableRow(
                        children: List.generate(
                          columns.length,
                          (_) => Container(
                            height: TableUiConfig.groupHeaderHeight,
                            color: TableUiConfig.groupedHeaderBg,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ...groupedHeaders.map((header) {
                    return Positioned(
                      left: _leftOffsetOfColumn(header.startCol),
                      top: 0,
                      bottom: 0,
                      width: _spanWidth(header),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _groupHeaderBg(header),
                          border: Border(
                            left: BorderSide(
                              color: _groupBorderColor(header),
                              width: 2,
                            ),
                            right: BorderSide(
                              color: _groupBorderColor(header),
                              width: 2,
                            ),
                            bottom: const BorderSide(
                              color: TableUiConfig.borderColor,
                            ),
                          ),
                        ),
                        child: Text(
                          header.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            )
          else
            Container(
              height: TableUiConfig.groupHeaderHeight,
              decoration: const BoxDecoration(
                color: TableUiConfig.groupedHeaderBg,
                border: Border(
                  bottom: BorderSide(color: TableUiConfig.borderColor),
                ),
              ),
            ),

          Table(
            columnWidths: columnWidths,
            border: const TableBorder(
              horizontalInside: BorderSide(
                color: TableUiConfig.borderColor,
                width: 1,
              ),
              verticalInside: BorderSide(color: TableUiConfig.borderColor),
            ),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: TableUiConfig.headerBg),
                children: List.generate(columns.length, (index) {
                  final column = columns[index];
                  return Container(
                    height: TableUiConfig.headerRowHeight,
                    decoration: BoxDecoration(
                      color: _cellBackground(index) ?? TableUiConfig.headerBg,
                      border: _cellBorder(index),
                    ),
                    child: Center(
                      child: Text(
                        column,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Table(
                columnWidths: columnWidths,
                border: const TableBorder(
                  horizontalInside: BorderSide(
                    color: TableUiConfig.borderColor,
                  ),
                  verticalInside: BorderSide(color: TableUiConfig.borderColor),
                ),
                children: rows.map((row) {
                  return TableRow(
                    decoration: BoxDecoration(
                      color: row.isTotal
                          ? TableUiConfig.totalRowBg
                          : Colors.white,
                    ),
                    children: List.generate(row.cells.length, (index) {
                      final cell = row.cells[index];
                      final isNumber = cell is num;

                      return Container(
                        height: TableUiConfig.cellHeight,
                        decoration: BoxDecoration(
                          color: row.isTotal
                              ? TableUiConfig.totalRowBg
                              : (_cellBackground(index) ?? Colors.white),
                          border: _cellBorder(index),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Align(
                            alignment: isNumber
                                ? Alignment.center
                                : Alignment.centerLeft,
                            child: Text(
                              cell.toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: row.isTotal
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableTitleBar extends StatelessWidget {
  final String? titleLeft;
  final String? titleCenter;
  final String? subtitleRight;

  final Widget? subtitleRightWidget; // 👈 thêm

  const _TableTitleBar({
    this.titleLeft,
    this.titleCenter,
    this.subtitleRight,
    this.subtitleRightWidget, // 👈 thêm
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: TableUiConfig.titleHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: TableUiConfig.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                titleLeft ?? '',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                titleCenter ?? '',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  subtitleRightWidget ??
                  Text(
                    subtitleRight ?? '',
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
