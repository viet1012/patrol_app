import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// =====================
// CONFIG
// =====================
const String kBaseUrl = 'http://localhost:9299'; // đổi theo server bạn

// =====================
// MODELS
// =====================

class RiskBreakdownDto {
  final int total;
  final int i, ii, iii, iv, v;

  const RiskBreakdownDto({
    required this.total,
    required this.i,
    required this.ii,
    required this.iii,
    required this.iv,
    required this.v,
  });

  factory RiskBreakdownDto.fromJson(Map<String, dynamic> j) {
    int n(dynamic x) => (x is num) ? x.toInt() : 0;
    return RiskBreakdownDto(
      total: n(j['total']),
      i: n(j['i']),
      ii: n(j['ii']),
      iii: n(j['iii']),
      iv: n(j['iv']),
      v: n(j['v']),
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

  factory PatrolPicRowDto.fromJson(Map<String, dynamic> j) {
    int n(dynamic x) => (x is num) ? x.toInt() : 0;
    return PatrolPicRowDto(
      pic: (j['pic'] ?? '').toString(),
      before: RiskBreakdownDto.fromJson(
        (j['before'] ?? const {}) as Map<String, dynamic>,
      ),
      finished: RiskBreakdownDto.fromJson(
        (j['finished'] ?? const {}) as Map<String, dynamic>,
      ),
      remain: RiskBreakdownDto.fromJson(
        (j['remain'] ?? const {}) as Map<String, dynamic>,
      ),
      recheckAllTotal: n(j['recheckAllTotal']),
      recheckOk: RiskBreakdownDto.fromJson(
        (j['recheckOk'] ?? const {}) as Map<String, dynamic>,
      ),
      recheckNg: RiskBreakdownDto.fromJson(
        (j['recheckNg'] ?? const {}) as Map<String, dynamic>,
      ),
    );
  }
}

class PatrolFacSummaryDto {
  final String fac;
  final double? finishedRate, remainRate, okRate, ngRate;
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

  factory PatrolFacSummaryDto.fromJson(Map<String, dynamic> j) {
    double? d(dynamic x) => (x is num) ? x.toDouble() : null;
    final rows = (j['rows'] as List? ?? [])
        .map((e) => PatrolPicRowDto.fromJson(e as Map<String, dynamic>))
        .toList();

    final total = (j['total'] == null)
        ? null
        : PatrolPicRowDto.fromJson(j['total'] as Map<String, dynamic>);

    return PatrolFacSummaryDto(
      fac: (j['fac'] ?? '').toString(),
      finishedRate: d(j['finishedRate']),
      remainRate: d(j['remainRate']),
      okRate: d(j['okRate']),
      ngRate: d(j['ngRate']),
      rows: rows,
      total: total,
    );
  }
}

class PatrolSummaryResponseDto {
  final String fromD, toD, plant, type;
  final List<PatrolFacSummaryDto> facs;

  const PatrolSummaryResponseDto({
    required this.fromD,
    required this.toD,
    required this.plant,
    required this.type,
    required this.facs,
  });

  factory PatrolSummaryResponseDto.fromJson(Map<String, dynamic> j) {
    final facs = (j['facs'] as List? ?? [])
        .map((e) => PatrolFacSummaryDto.fromJson(e as Map<String, dynamic>))
        .toList();

    return PatrolSummaryResponseDto(
      fromD: (j['fromD'] ?? '').toString(),
      toD: (j['toD'] ?? '').toString(),
      plant: (j['plant'] ?? '').toString(),
      type: (j['type'] ?? '').toString(),
      facs: facs,
    );
  }
}

// =====================
// API
// =====================
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

    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    return PatrolSummaryResponseDto.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }
}

// =====================
// SCREEN
// =====================

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
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Load failed: ${snap.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final data = snap.data;
        final facs = data?.facs ?? const <PatrolFacSummaryDto>[];
        if (facs.isEmpty) {
          return const Center(
            child: Text('No data', style: TextStyle(color: Colors.white70)),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
          itemCount: facs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, idx) => _FacBlockCard(fac: facs[idx]),
        );
      },
    );
  }
}

// =====================
// UI WIDGETS
// =====================
double colW(String c) {
  if (c == 'PIC') return 140;
  if (c == 'All') return 60;
  return 80; // ✅ bạn muốn rộng thì để 68, nhưng CHỈ 1 CHỖ
}

double tableW(List<String> cols) => cols.fold(0.0, (s, c) => s + colW(c));

class _FacBlockCard extends StatelessWidget {
  final PatrolFacSummaryDto fac;

  const _FacBlockCard({required this.fac});

  String _pct(double? v) => v == null ? '--' : '${(v * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final rows = fac.rows;
    final total = fac.total;
    final displayRows = [...rows, if (total != null) total];

    const gap = 12.0;
    const tablesH = 380.0;

    // ✅ columns đúng y như table đang dùng
    const beforeCols = ['PIC', 'Total', 'I', 'II', 'III', 'IV', 'V'];
    const afterCols = [
      'PIC',
      'Fin T',
      'Fin I',
      'Fin II',
      'Fin III',
      'Fin IV',
      'Fin V',
      'Rem T',
      'Rem I',
      'Rem II',
      'Rem III',
      'Rem IV',
      'Rem V',
    ];
    const recheckCols = [
      'PIC',
      'All',
      'OK T',
      'OK I',
      'OK II',
      'OK III',
      'OK IV',
      'OK V',
      'NG T',
      'NG I',
      'NG II',
      'NG III',
      'NG IV',
      'NG V',
    ];

    final beforeW = tableW(beforeCols);
    final afterW = tableW(afterCols);
    final recheckW = tableW(recheckCols);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                fac.fac,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              _pill('Finished', _pct(fac.finishedRate)),
              const SizedBox(width: 8),
              _pill('Remain', _pct(fac.remainRate)),
              const SizedBox(width: 8),
              _pill('OK', _pct(fac.okRate)),
              const SizedBox(width: 8),
              _pill('NG', _pct(fac.ngRate)),
            ],
          ),
          const SizedBox(height: 10),

          SizedBox(
            height: tablesH,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: beforeW,
                    child: _BeforeTable(rows: displayRows),
                  ),
                  const SizedBox(width: gap),
                  SizedBox(
                    width: afterW,
                    child: _AfterTable(
                      rows: displayRows,
                      finishedRate: fac.finishedRate,
                      remainRate: fac.remainRate,
                    ),
                  ),
                  const SizedBox(width: gap),
                  SizedBox(
                    width: recheckW,
                    child: _RecheckTable(
                      rows: displayRows,
                      okRate: fac.okRate,
                      ngRate: fac.ngRate,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.black.withOpacity(0.20),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BeforeTable extends StatelessWidget {
  final List<PatrolPicRowDto> rows;

  const _BeforeTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _ExcelLikeTable(
      titleLeft: 'BEFORE',
      titleCenter: 'NG points',
      headerColor: Colors.white,
      columns: const ['PIC', 'Total', 'I', 'II', 'III', 'IV', 'V'],
      rows: rows.map((r) {
        final b = r.before;
        final isTotal = r.pic.toUpperCase() == 'TOTAL';
        return _RowData(
          isTotal: isTotal,
          cells: [r.pic, b.total, b.i, b.ii, b.iii, b.iv, b.v],
        );
      }).toList(),
    );
  }
}

class _AfterTable extends StatelessWidget {
  final List<PatrolPicRowDto> rows;
  final double? finishedRate;
  final double? remainRate;

  const _AfterTable({
    required this.rows,
    required this.finishedRate,
    required this.remainRate,
  });

  String _pct(double? v) => v == null ? '--' : '${(v * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    return _ExcelLikeTable(
      titleLeft: 'AFTER TOTAL',
      titleCenter: 'Pro action (All)',
      subtitleRight:
      'Finished ${_pct(finishedRate)}   •   Remain ${_pct(remainRate)}',
      headerColor: Colors.white,
      columns: const [
        'PIC',
        'Fin T',
        'Fin I',
        'Fin II',
        'Fin III',
        'Fin IV',
        'Fin V',
        'Rem T',
        'Rem I',
        'Rem II',
        'Rem III',
        'Rem IV',
        'Rem V',
      ],
      rows: rows.map((r) {
        final f = r.finished;
        final rm = r.remain;
        final isTotal = r.pic.toUpperCase() == 'TOTAL';
        return _RowData(
          isTotal: isTotal,
          cells: [
            r.pic,
            f.total,
            f.i,
            f.ii,
            f.iii,
            f.iv,
            f.v,
            rm.total,
            rm.i,
            rm.ii,
            rm.iii,
            rm.iv,
            rm.v,
          ],
        );
      }).toList(),
      // group headers like the picture
      groupedHeaders: const [
        _GroupedHeader(label: 'Finished', startCol: 1, colSpan: 6),
        _GroupedHeader(label: 'Remain', startCol: 7, colSpan: 6),
      ],
    );
  }
}

class _RecheckTable extends StatelessWidget {
  final List<PatrolPicRowDto> rows;
  final double? okRate;
  final double? ngRate;

  const _RecheckTable({
    required this.rows,
    required this.okRate,
    required this.ngRate,
  });

  String _pct(double? v) => v == null ? '--' : '${(v * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    return _ExcelLikeTable(
      titleCenter: 'HSE re-check (All)',
      subtitleRight: 'OK ${_pct(okRate)}   •   NG ${_pct(ngRate)}',
      columns: const [
        'PIC',
        'All',
        'OK T',
        'OK I',
        'OK II',
        'OK III',
        'OK IV',
        'OK V',
        'NG T',
        'NG I',
        'NG II',
        'NG III',
        'NG IV',
        'NG V',
      ],
      rows: rows.map((r) {
        final ok = r.recheckOk;
        final ng = r.recheckNg;
        final isTotal = r.pic.toUpperCase() == 'TOTAL';
        return _RowData(
          isTotal: isTotal,
          cells: [
            r.pic,
            r.recheckAllTotal,
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
      groupedHeaders: const [
        _GroupedHeader(label: 'OK', startCol: 2, colSpan: 6),
        _GroupedHeader(label: 'NG', startCol: 8, colSpan: 6),
      ],
    );
  }
}

// =====================
// Generic Excel-like table
// =====================

class _GroupedHeader {
  final String label;
  final int startCol; // 0-based col index in "columns"
  final int colSpan;

  const _GroupedHeader({
    required this.label,
    required this.startCol,
    required this.colSpan,
  });
}

class _RowData {
  final bool isTotal;
  final List<dynamic> cells; // String or int
  const _RowData({required this.isTotal, required this.cells});
}

class _ExcelLikeTable extends StatelessWidget {
  final String? titleLeft;
  final String? titleCenter;
  final String? subtitleRight;

  final List<String> columns;
  final List<_RowData> rows;

  final List<_GroupedHeader> groupedHeaders;

  const _ExcelLikeTable({
    this.titleLeft,
    this.titleCenter,
    this.subtitleRight,
    required this.columns,
    required this.rows,
    this.groupedHeaders = const [],
    this.headerColor,
  });

  final Color? headerColor;

  @override
  Widget build(BuildContext context) {
    const cellH = 32.0;
    const borderC = Color(0xFF2A3447);
    double wFor(String c) => colW(c);

    final colWidths = <int, TableColumnWidth>{};
    for (int i = 0; i < columns.length; i++) {
      colWidths[i] = FixedColumnWidth(wFor(columns[i]));
    }

    TextStyle h1 = const TextStyle(
      color: Colors.redAccent,
      fontWeight: FontWeight.w900,
      fontSize: 13,
    );
    TextStyle h2 = const TextStyle(
      color: Colors.blueAccent,
      fontWeight: FontWeight.w900,
      fontSize: 13,
    );
    TextStyle sub = const TextStyle(color: Colors.white70, fontSize: 13);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderC),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // title row (like the picture)
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                if (titleLeft != null) Text(titleLeft!, style: h1),
                const Spacer(),
                if (titleCenter != null) Text(titleCenter!, style: h2),
                const Spacer(),
                if (subtitleRight != null) Text(subtitleRight!, style: sub),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: borderC),

          // grouped header row (Finished/Remain or OK/NG)
          if (groupedHeaders.isNotEmpty)
            _buildGroupedHeaderRow(
              columns: columns,
              grouped: groupedHeaders,
              colWidths: colWidths,
            ),

          // column headers
          Table(
            columnWidths: colWidths,
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: const TableBorder(
              horizontalInside: BorderSide(color: borderC),
              verticalInside: BorderSide(color: borderC),
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(color: (headerColor ?? Colors.white)),
                children: columns.map((c) {
                  return SizedBox(
                    height: cellH,
                    child: Center(
                      child: Text(
                        c,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // data rows
          Table(
            columnWidths: colWidths,
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: const TableBorder(
              horizontalInside: BorderSide(color: borderC),
              verticalInside: BorderSide(color: borderC),
            ),
            children: rows.map((r) {
              final bg = r.isTotal
                  ? const Color(0xFFFFFF99)
                  : Colors.white; // giống dòng Sum vàng
              return TableRow(
                decoration: BoxDecoration(color: bg),
                children: r.cells.map((v) {
                  final isNum = v is num;
                  return SizedBox(
                    height: cellH,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Align(
                        alignment: isNum
                            ? Alignment.center
                            : Alignment.centerLeft,
                        child: Text(
                          v.toString(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: r.isTotal
                                ? FontWeight.w900
                                : FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedHeaderRow({
    required List<String> columns,
    required List<_GroupedHeader> grouped,
    required Map<int, TableColumnWidth> colWidths,
  }) {
    const borderC = Color(0xFF2A3447);

    // map startCol -> grouped header
    final map = <int, _GroupedHeader>{};
    for (final g in grouped) {
      map[g.startCol] = g;
    }

    // Build 1 TableRow với colSpan bằng TableCell.verticalAlignment + child spanning:
    // Table không support colspan trực tiếp => trick: render label ở col start,
    // các cột còn lại để rỗng, và dùng Stack để vẽ background span.
    //
    // Cách sạch hơn: dùng Row + ClipRect + SingleChildScrollView. Nhưng bạn muốn hết lệch,
    // ta dùng Stack overlay span theo tổng width chính xác.

    // Tính offset theo colWidths (đúng tuyệt đối)
    double wForIndex(int idx) {
      final w = colWidths[idx];
      if (w is FixedColumnWidth) return w.value;
      return 80;
    }

    // Build nền span bằng Positioned
    final spans = <Widget>[];
    for (final g in grouped) {
      double left = 0;
      for (int i = 0; i < g.startCol; i++) {
        left += wForIndex(i);
      }
      double width = 0;
      for (int k = 0; k < g.colSpan; k++) {
        width += wForIndex(g.startCol + k);
      }

      spans.add(
        Positioned(
          left: left,
          top: 0,
          bottom: 0,
          width: width,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              border: Border(
                right: BorderSide(color: borderC),
                bottom: BorderSide(color: borderC),
              ),
            ),
            child: Text(
              g.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: (g.label == 'Remain' || g.label == 'NG')
                    ? Colors.red
                    : Colors.green,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 28,
      child: ClipRect(
        child: Stack(
          children: [
            // base grid (để vạch dọc đúng cột)
            Table(
              columnWidths: colWidths,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: const TableBorder(
                horizontalInside: BorderSide(color: borderC),
                verticalInside: BorderSide(color: borderC),
              ),
              children: [
                TableRow(
                  children: List.generate(columns.length, (i) {
                    return const SizedBox(
                      height: 28,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Color(0xFFF2F2F2)),
                      ),
                    );
                  }),
                ),
              ],
            ),

            // spans overlay
            ...spans,
          ],
        ),
      ),
    );
  }
}
