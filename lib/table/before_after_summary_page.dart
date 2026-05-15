import 'package:flutter/material.dart';

import '../api/summary_api.dart';
import '../model/division_summary.dart';
import '../test_1/patrol_summary_table.dart';
import '../widget/glass_action_button.dart';

class BeforeAfterSummaryDialog extends StatefulWidget {
  final String fromD;
  final String toD;
  final String fac;
  final String type;

  const BeforeAfterSummaryDialog({
    super.key,
    required this.fromD,
    required this.toD,
    required this.fac,
    required this.type,
  });

  static Future<void> show(
    BuildContext context, {
    required String fromD,
    required String toD,
    required String fac,
    required String type,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => BeforeAfterSummaryDialog(
        fromD: fromD,
        toD: toD,
        fac: fac,
        type: type,
      ),
    );
  }

  @override
  State<BeforeAfterSummaryDialog> createState() =>
      _BeforeAfterSummaryDialogState();
}

class _BeforeAfterSummaryDialogState extends State<BeforeAfterSummaryDialog> {
  final SummaryApi _api = const SummaryApi();
  late Future<List<DivisionSummary>> _future;

  // scroll controllers
  final ScrollController _afterHCtrl = ScrollController();
  final ScrollController _beforeHCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DivisionSummary>> _load() {
    return _api.fetchDivisionSummary(
      fromD: widget.fromD,
      toD: widget.toD,
      fac: widget.fac,
      type: widget.type,
    );
  }

  @override
  void dispose() {
    _afterHCtrl.dispose();
    _beforeHCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final dialogW = w - 16; // hoặc -24 nếu muốn có viền
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogW,
          maxHeight: MediaQuery.of(context).size.height,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF121826), Color(0xFF1F2937), Color(0xFF374151)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                blurRadius: 24,
                spreadRadius: 2,
                color: Colors.black.withOpacity(0.35),
              ),
            ],
          ),
          child: Column(
            children: [
              // ===== Header giống AppBar =====
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    GlassActionButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'HSE PATROL SUMMARY → ${widget.fac}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${widget.fromD} → ${widget.toD}   •   ${widget.type}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Divider(color: Colors.white.withOpacity(0.08), height: 1),

              // ===== Body =====
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1) SUMMARY
                      FutureBuilder<List<DivisionSummary>>(
                        future: _future,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          if (snap.hasError) {
                            return Text(
                              'Load failed: ${snap.error}',
                              style: const TextStyle(color: Colors.redAccent),
                            );
                          }
                          final rows = snap.data ?? [];
                          if (rows.isEmpty) {
                            return const Text(
                              'No data',
                              style: TextStyle(color: Colors.white70),
                            );
                          }

                          final totals = _Totals.from(rows);
                          return _AfterCard(
                            rows: rows,
                            totals: totals,
                            controller: _afterHCtrl,
                          );
                        },
                      ),

                      const SizedBox(height: 8),
                      // ✅ 2) PATROL SUMMARY (fac blocks like image)
                      PatrolSummaryScreen(
                        fromD: widget.fromD,
                        toD: widget.toD,
                        plant: widget.fac, // nếu fac đang là Fac_2
                        type: widget.type,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =======================
// Totals helper
// =======================
class _Totals {
  final double sumAll;
  final double sumPro;
  final double sumHse;
  final double sumRemain;

  const _Totals({
    required this.sumAll,
    required this.sumPro,
    required this.sumHse,
    required this.sumRemain,
  });

  double get done => sumPro;

  double get donePct => sumAll == 0 ? 0 : _round1((done / sumAll) * 100);

  double get remainPct => sumAll == 0 ? 0 : _round1((sumRemain / sumAll) * 100);

  static _Totals from(List<DivisionSummary> rows) {
    double sumAll = 0;
    double sumPro = 0;
    double sumHse = 0;
    double sumRemain = 0;

    for (final r in rows) {
      sumAll += r.allTtl;
      sumPro += r.proDoneTtl;
      sumHse += r.hseDoneTtl;
      sumRemain += r.remainTtl;
    }

    return _Totals(
      sumAll: sumAll,
      sumPro: sumPro,
      sumHse: sumHse,
      sumRemain: sumRemain,
    );
  }

  static double _round1(double v) => double.parse(v.toStringAsFixed(1));
}

// =======================
// AFTER card
// =======================
class _AfterCard extends StatelessWidget {
  final List<DivisionSummary> rows;
  final _Totals totals;
  final ScrollController controller;

  const _AfterCard({
    required this.rows,
    required this.totals,
    required this.controller,
  });

  static const double _wDiv = 150;
  static const double _wNum = 68;

  static const Color _sumBg = Color(0xFFDDD6FE);
  static const Color _pctTtlBg = Color(0xFFBA94E1);

  static const Color _beforeBg = Color(0xFFF1E6A7);
  static const Color _proBg = Color(0xFFBFF2C8);
  static const Color _remainBg = Color(0xFFFFC2C2);
  static const Color _hseBg = Color(0xFFBFE0F2);

  double get _tableWidth => _wDiv + (_wNum * 24);

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: _tableWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TitleBar(
                  text: 'SUMMARY',
                  color: const Color(0xFFD8F5C7),
                  width: _tableWidth,
                ),

                const SizedBox(height: 6),

                _buildGroupHeader(),

                _buildColumnHeader(),

                const SizedBox(height: 6),

                ...rows.map(_buildDataRow),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupHeader() {
    return Row(
      children: [
        const SizedBox(width: _wDiv),
        _groupHeader('Before', Colors.yellow, _wNum * 6),
        _groupHeader('Finished (Pro)', Colors.greenAccent, _wNum * 6),
        _groupHeader('Remain', Colors.redAccent, _wNum * 6),
        _groupHeader('Finished (HSE recheck)', Colors.blueAccent, _wNum * 6),
      ],
    );
  }

  Widget _buildColumnHeader() {
    return Row(
      children: [
        const _Row(
          header: true,
          cells: [_CellSpec('Area', w: _wDiv, align: TextAlign.left)],
        ),

        _metricHeader(const Color(0xFFEFE28F)),

        _metricHeader(const Color(0xFF8FEFA0)),

        _metricHeader(const Color(0xFFF89292)),

        _metricHeader(const Color(0xFF72C7F4)),
      ],
    );
  }

  Widget _buildDataRow(DivisionSummary r) {
    final isSum = r.division == 'SUM';
    final isPct = r.division == '%';

    final rowBg = isSum ? _sumBg : null;
    final pctTtlBg = isPct ? _pctTtlBg : null;

    return Row(
      children: [
        _Row(
          cells: [
            _CellSpec(
              r.division,
              w: _wDiv,
              align: TextAlign.left,
              bold: isSum || isPct,
            ),
          ],
        ),

        _metricRow(
          bg: rowBg ?? (isPct ? null : _beforeBg),
          isPct: isPct,
          ttlBg: pctTtlBg,
          ttl: r.allTtl,
          i: r.allI,
          ii: r.allII,
          iii: r.allIII,
          iv: r.allIV,
          v: r.allV,
        ),

        _metricRow(
          bg: rowBg ?? (isPct ? null : _proBg),
          isPct: isPct,
          ttlBg: pctTtlBg,
          ttl: r.proDoneTtl,
          i: r.proDoneI,
          ii: r.proDoneII,
          iii: r.proDoneIII,
          iv: r.proDoneIV,
          v: r.proDoneV,
        ),

        _metricRow(
          bg: rowBg ?? (isPct ? null : _remainBg),
          isPct: isPct,
          ttlBg: pctTtlBg,
          ttl: r.remainTtl,
          i: r.remainI,
          ii: r.remainII,
          iii: r.remainIII,
          iv: r.remainIV,
          v: r.remainV,
        ),

        _metricRow(
          bg: rowBg ?? (isPct ? null : _hseBg),
          isPct: isPct,
          ttlBg: pctTtlBg,
          ttl: r.hseDoneTtl,
          i: r.hseDoneI,
          ii: r.hseDoneII,
          iii: r.hseDoneIII,
          iv: r.hseDoneIV,
          v: r.hseDoneV,
        ),
      ],
    );
  }

  Widget _metricHeader(Color bg) {
    return _Row(
      header: true,
      bg: bg,
      cells: const [
        _CellSpec('TTL', w: _wNum, bold: true),
        _CellSpec('I', w: _wNum),
        _CellSpec('II', w: _wNum),
        _CellSpec('III', w: _wNum),
        _CellSpec('IV', w: _wNum),
        _CellSpec('V', w: _wNum),
      ],
    );
  }

  Widget _metricRow({
    required Color? bg,
    required bool isPct,
    required double ttl,
    required double i,
    required double ii,
    required double iii,
    required double iv,
    required double v,
    Color? ttlBg,
  }) {
    return _Row(
      bg: bg,
      cells: _metricCells(
        isPct: isPct,
        ttlBg: ttlBg,
        ttl: ttl,
        i: i,
        ii: ii,
        iii: iii,
        iv: iv,
        v: v,
      ),
    );
  }

  List<_CellSpec> _metricCells({
    required bool isPct,
    required double ttl,
    required double i,
    required double ii,
    required double iii,
    required double iv,
    required double v,
    Color? ttlBg,
  }) {
    String value(double n) => isPct ? '' : fmtNum(n);

    return [
      _CellSpec(
        isPct ? fmtPct(ttl) : fmtNum(ttl),
        w: _wNum,
        bold: true,
        bg: ttlBg,
      ),
      _CellSpec(value(i), w: _wNum),
      _CellSpec(value(ii), w: _wNum),
      _CellSpec(value(iii), w: _wNum),
      _CellSpec(value(iv), w: _wNum),
      _CellSpec(value(v), w: _wNum),
    ];
  }
}

// =======================
// Shared UI
// =======================
class _Glass extends StatelessWidget {
  final Widget child;

  const _Glass({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: child,
    );
  }
}

class _Row extends StatelessWidget {
  final List<_CellSpec> cells;
  final Color? bg;
  final bool header;

  const _Row({required this.cells, this.bg, this.header = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: cells.map((c) => _cell(c, bg: bg, header: header)).toList(),
    );
  }
}

class _TitleBar extends StatelessWidget {
  final String text;
  final Color color;
  final double? width;

  const _TitleBar({required this.text, required this.color, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CellSpec {
  final String text;
  final double w;
  final bool bold;
  final TextAlign align;
  final Color? bg;

  const _CellSpec(
    this.text, {
    required this.w,
    this.bold = false,
    this.align = TextAlign.center,
    this.bg,
  });
}

// =======================
// Formatters
// =======================
String fmtNum(double v) {
  if (v == 0) return '-';

  return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
}

String fmtPct(double v) {
  if (v == 0) return '-';

  return '${v.toStringAsFixed(1)}%';
}

// =======================
// Cell
// =======================
Widget _cell(_CellSpec c, {bool header = false, Color? bg}) {
  final textColor = header ? Colors.black : Colors.black87;

  final baseBg =
      c.bg ??
      (header
          ? (bg ?? const Color(0xFFDDDDDD))
          : (bg ?? const Color(0xFFEFEFEF)));

  return Container(
    width: c.w,
    height: header ? 34 : 38,
    alignment: _resolveAlignment(c),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: baseBg,
      border: Border.all(color: Colors.black12, width: 1),
    ),
    child: Text(
      c.text,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: c.bold ? FontWeight.w800 : FontWeight.w600,
      ),
    ),
  );
}

Alignment _resolveAlignment(_CellSpec c) {
  if (c.align == TextAlign.left) {
    return Alignment.centerLeft;
  }

  if (c.align == TextAlign.right) {
    return Alignment.centerRight;
  }

  final text = c.text.trim();

  final isNumberLike =
      text == '-' ||
      text.endsWith('%') ||
      double.tryParse(text.replaceAll(',', '')) != null;

  return isNumberLike ? Alignment.centerRight : Alignment.centerLeft;
}

Widget _groupHeader(String title, Color color, double width) {
  return Container(
    width: width,
    padding: const EdgeInsets.symmetric(vertical: 10),
    alignment: Alignment.center,
    child: Text(
      title,
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16),
    ),
  );
}
