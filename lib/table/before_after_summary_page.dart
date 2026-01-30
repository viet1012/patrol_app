// import 'package:flutter/material.dart';
//
// import '../api/summary_api.dart';
// import '../model/division_summary.dart';
//
// class BeforeAfterSummaryPage extends StatefulWidget {
//   final String fromD; // yyyy-MM-dd
//   final String toD;
//   final String fac;
//   final String type;
//
//   const BeforeAfterSummaryPage({
//     super.key,
//     required this.fromD,
//     required this.toD,
//     required this.fac,
//     required this.type,
//   });
//
//   @override
//   State<BeforeAfterSummaryPage> createState() => _BeforeAfterSummaryPageState();
// }
//
// class _BeforeAfterSummaryPageState extends State<BeforeAfterSummaryPage> {
//   final SummaryApi _api = const SummaryApi();
//
//   late Future<List<DivisionSummary>> _future;
//
//   // scroll controllers (để Scrollbar không báo lỗi)
//   final ScrollController _afterHCtrl = ScrollController();
//   final ScrollController _beforeHCtrl = ScrollController();
//
//   @override
//   void initState() {
//     super.initState();
//     _future = _load();
//   }
//
//   Future<List<DivisionSummary>> _load() {
//     return _api.fetchDivisionSummary(
//       fromD: widget.fromD,
//       toD: widget.toD,
//       fac: widget.fac,
//       type: widget.type,
//     );
//   }
//
//   void _refresh() => setState(() => _future = _load());
//
//   @override
//   void dispose() {
//     _afterHCtrl.dispose();
//     _beforeHCtrl.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white10,
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF0B0B0B),
//         title: Text('BEFORE / AFTER  (${widget.fac})'),
//         actions: [
//           IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
//         ],
//       ),
//       body: FutureBuilder<List<DivisionSummary>>(
//         future: _future,
//         builder: (context, snap) {
//           if (snap.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           if (snap.hasError) {
//             return Center(
//               child: Text(
//                 'Load failed: ${snap.error}',
//                 style: const TextStyle(color: Colors.redAccent),
//                 textAlign: TextAlign.center,
//               ),
//             );
//           }
//
//           final rows = snap.data ?? [];
//           if (rows.isEmpty) {
//             return const Center(
//               child: Text('No data', style: TextStyle(color: Colors.white70)),
//             );
//           }
//
//           final totals = _Totals.from(rows);
//
//           return LayoutBuilder(
//             builder: (context, c) {
//               final isWide = c.maxWidth >= 900;
//
//               final before = _BeforeCard(
//                 rows: rows,
//                 sumAll: totals.sumAll,
//                 controller: _beforeHCtrl,
//               );
//
//               final after = _AfterCard(
//                 rows: rows,
//                 totals: totals,
//                 controller: _afterHCtrl,
//               );
//
//               if (isWide) {
//                 return Padding(
//                   padding: const EdgeInsets.all(12),
//                   child: Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       SizedBox(width: 450, child: before),
//                       const SizedBox(width: 12),
//                       Expanded(child: after),
//                     ],
//                   ),
//                 );
//               }
//
//               return SingleChildScrollView(
//                 padding: const EdgeInsets.all(12),
//                 child: Column(
//                   children: [before, const SizedBox(height: 12), after],
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
//
// // =======================
// // Totals helper
// // =======================
// class _Totals {
//   final int sumAll;
//   final int sumPro;
//   final int sumHse;
//   final int sumRemain;
//
//   _Totals({
//     required this.sumAll,
//     required this.sumPro,
//     required this.sumHse,
//     required this.sumRemain,
//   });
//
//   int get done => sumPro + sumHse;
//
//   int get donePct => (sumAll == 0) ? 0 : ((done / sumAll) * 100).round();
//
//   int get remainPct => (sumAll == 0) ? 0 : ((sumRemain / sumAll) * 100).round();
//
//   static _Totals from(List<DivisionSummary> rows) {
//     var sumAll = 0, sumPro = 0, sumHse = 0, sumRemain = 0;
//     for (final r in rows) {
//       sumAll += r.allTtl;
//       sumPro += r.proDoneTtl;
//       sumHse += r.hseDoneTtl;
//       sumRemain += r.remainTtl;
//     }
//     return _Totals(
//       sumAll: sumAll,
//       sumPro: sumPro,
//       sumHse: sumHse,
//       sumRemain: sumRemain,
//     );
//   }
// }
//
// // =======================
// // BEFORE card
// // =======================
// class _BeforeCard extends StatelessWidget {
//   final List<DivisionSummary> rows;
//   final int sumAll;
//   final ScrollController controller;
//
//   const _BeforeCard({
//     required this.rows,
//     required this.sumAll,
//     required this.controller,
//   });
//
//   static const double _wArea = 170;
//   static const double _wPic = 120;
//   static const double _wTotal = 70;
//
//   @override
//   Widget build(BuildContext context) {
//     final tableWidth = _wArea + _wPic + _wTotal;
//
//     return _Glass(
//       child: Scrollbar(
//         controller: controller,
//         thumbVisibility: true,
//         child: SingleChildScrollView(
//           controller: controller,
//           scrollDirection: Axis.horizontal,
//           child: SizedBox(
//             width: tableWidth,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const _TitleBar(
//                   text: 'BEFORE',
//                   color: Colors.redAccent,
//                   width: double.infinity,
//                 ),
//                 const SizedBox(height: 10),
//
//                 _RowHeader(
//                   cells: const [
//                     _CellSpec(
//                       'Patrolled Area',
//                       w: _wArea,
//                       align: TextAlign.left,
//                     ),
//                     _CellSpec('PIC', w: _wPic),
//                     _CellSpec('Total', w: _wTotal, bold: true),
//                   ],
//                 ),
//
//                 const SizedBox(height: 6),
//
//                 ...rows.map(
//                   (r) => _RowLine(
//                     cells: [
//                       _CellSpec(r.division, w: _wArea, align: TextAlign.left),
//                       const _CellSpec('-', w: _wPic),
//                       _CellSpec('${r.allTtl}', w: _wTotal, bold: true),
//                     ],
//                   ),
//                 ),
//
//                 const SizedBox(height: 10),
//                 Align(
//                   alignment: Alignment.centerRight,
//                   child: _badgeNumber(sumAll, bg: Colors.yellow),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // =======================
// // AFTER card
// // =======================
// class _AfterCard extends StatelessWidget {
//   final List<DivisionSummary> rows;
//   final _Totals totals;
//   final ScrollController controller;
//
//   const _AfterCard({
//     required this.rows,
//     required this.totals,
//     required this.controller,
//   });
//
//   static const double _wDiv = 170;
//   static const double _wNum = 56;
//
//   @override
//   Widget build(BuildContext context) {
//     // 1 (division) + 18 columns (6 pro + 6 hse + 6 remain)
//     final tableWidth = _wDiv + (_wNum * 18);
//
//     return _Glass(
//       child: Scrollbar(
//         controller: controller,
//         thumbVisibility: true,
//         child: SingleChildScrollView(
//           controller: controller,
//           scrollDirection: Axis.horizontal,
//           child: SizedBox(
//             width: tableWidth,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 _TitleBar(
//                   text: 'AFTER',
//                   color: const Color(0xFFD8F5C7),
//                   width: tableWidth,
//                 ),
//                 const SizedBox(height: 6),
//
//                 // group header row
//                 Row(
//                   children: [
//                     _groupHeader(
//                       'Finished (Pro)',
//                       Colors.greenAccent,
//                       _wDiv + _wNum * 6,
//                     ),
//                     _groupHeader(
//                       'Finished (HSE recheck)',
//                       Colors.greenAccent,
//                       _wNum * 6,
//                     ),
//                     _groupHeader('Remain', Colors.redAccent, _wNum * 6),
//                   ],
//                 ),
//
//                 // sub header row
//                 Row(
//                   children: [
//                     _RowHeader(
//                       cells: const [
//                         _CellSpec('Area', w: _wDiv, align: TextAlign.left),
//                         _CellSpec('TTL', w: _wNum),
//                         _CellSpec('I', w: _wNum),
//                         _CellSpec('II', w: _wNum),
//                         _CellSpec('III', w: _wNum),
//                         _CellSpec('IV', w: _wNum),
//                         _CellSpec('V', w: _wNum),
//                       ],
//                     ),
//                     _RowHeader(
//                       cells: const [
//                         _CellSpec('TTL', w: _wNum),
//                         _CellSpec('I', w: _wNum),
//                         _CellSpec('II', w: _wNum),
//                         _CellSpec('III', w: _wNum),
//                         _CellSpec('IV', w: _wNum),
//                         _CellSpec('V', w: _wNum),
//                       ],
//                     ),
//                     _RowHeader(
//                       cells: const [
//                         _CellSpec('TTL', w: _wNum),
//                         _CellSpec('I', w: _wNum),
//                         _CellSpec('II', w: _wNum),
//                         _CellSpec('III', w: _wNum),
//                         _CellSpec('IV', w: _wNum),
//                         _CellSpec('V', w: _wNum),
//                       ],
//                     ),
//                   ],
//                 ),
//
//                 const SizedBox(height: 6),
//
//                 // data rows
//                 ...rows.map((r) {
//                   return Row(
//                     children: [
//                       _RowLine(
//                         bg: const Color(0xFFBFF2C8),
//                         cells: [
//                           _CellSpec(
//                             r.division,
//                             w: _wDiv,
//                             align: TextAlign.left,
//                           ),
//                           _CellSpec('${r.proDoneTtl}', w: _wNum),
//                           _CellSpec('${r.proDoneI}', w: _wNum),
//                           _CellSpec('${r.proDoneII}', w: _wNum),
//                           _CellSpec('${r.proDoneIII}', w: _wNum),
//                           _CellSpec('${r.proDoneIV}', w: _wNum),
//                           _CellSpec('${r.proDoneV}', w: _wNum),
//                         ],
//                       ),
//                       _RowLine(
//                         bg: const Color(0xFFBFF2C8),
//                         cells: [
//                           _CellSpec('${r.hseDoneTtl}', w: _wNum),
//                           _CellSpec('${r.hseDoneI}', w: _wNum),
//                           _CellSpec('${r.hseDoneII}', w: _wNum),
//                           _CellSpec('${r.hseDoneIII}', w: _wNum),
//                           _CellSpec('${r.hseDoneIV}', w: _wNum),
//                           _CellSpec('${r.hseDoneV}', w: _wNum),
//                         ],
//                       ),
//                       _RowLine(
//                         bg: const Color(0xFFFFC2C2),
//                         cells: [
//                           _CellSpec('${r.remainTtl}', w: _wNum),
//                           _CellSpec('${r.remainI}', w: _wNum),
//                           _CellSpec('${r.remainII}', w: _wNum),
//                           _CellSpec('${r.remainIII}', w: _wNum),
//                           _CellSpec('${r.remainIV}', w: _wNum),
//                           _CellSpec('${r.remainV}', w: _wNum),
//                         ],
//                       ),
//                     ],
//                   );
//                 }),
//
//                 const SizedBox(height: 10),
//
//                 // bottom totals
//                 Row(
//                   children: [
//                     _badgeNumber(totals.done, bg: Colors.yellow),
//                     const SizedBox(width: 8),
//                     _badgePercent(totals.donePct),
//                     const SizedBox(width: 24),
//                     _badgeNumber(totals.sumRemain, bg: Colors.yellow),
//                     const SizedBox(width: 8),
//                     _badgePercent(totals.remainPct),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // =======================
// // Shared small widgets
// // =======================
// class _Glass extends StatelessWidget {
//   final Widget child;
//
//   const _Glass({required this.child});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(0.35),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: Colors.white.withOpacity(0.12)),
//       ),
//       child: child,
//     );
//   }
// }
//
// class _RowHeader extends StatelessWidget {
//   final List<_CellSpec> cells;
//
//   const _RowHeader({required this.cells});
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(children: cells.map((c) => _cell(c, header: true)).toList());
//   }
// }
//
// class _RowLine extends StatelessWidget {
//   final List<_CellSpec> cells;
//   final Color? bg;
//
//   const _RowLine({required this.cells, this.bg});
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(children: cells.map((c) => _cell(c, bg: bg)).toList());
//   }
// }
//
// Widget _cell(_CellSpec c, {bool header = false, Color? bg}) {
//   final textColor = header ? Colors.black : Colors.black87;
//   final baseBg = header
//       ? const Color(0xFFDDDDDD)
//       : (bg ?? const Color(0xFFEFEFEF));
//
//   return Container(
//     width: c.w,
//     height: header ? 34 : 38,
//     alignment: _align(c.align),
//     padding: const EdgeInsets.symmetric(horizontal: 8),
//     decoration: BoxDecoration(
//       color: baseBg,
//       border: Border.all(color: Colors.black12, width: 1),
//     ),
//     child: Text(
//       c.text,
//       overflow: TextOverflow.ellipsis,
//       style: TextStyle(
//         color: textColor,
//         fontSize: 14,
//         fontWeight: c.bold ? FontWeight.w800 : FontWeight.w600,
//       ),
//     ),
//   );
// }
//
// Alignment _align(TextAlign a) {
//   switch (a) {
//     case TextAlign.left:
//       return Alignment.centerLeft;
//     case TextAlign.right:
//       return Alignment.centerRight;
//     default:
//       return Alignment.center;
//   }
// }
//
// Widget _groupHeader(String title, Color c, double width) {
//   return Container(
//     width: width,
//     padding: const EdgeInsets.symmetric(vertical: 10),
//     alignment: Alignment.center,
//     child: Text(
//       title,
//       style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 16),
//     ),
//   );
// }
//
// Widget _badgeNumber(int v, {required Color bg}) {
//   return Container(
//     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//     decoration: BoxDecoration(
//       color: bg,
//       border: Border.all(color: Colors.black, width: 1.2),
//     ),
//     child: Text(
//       '$v',
//       style: const TextStyle(
//         fontSize: 18,
//         fontWeight: FontWeight.w900,
//         color: Colors.black,
//       ),
//     ),
//   );
// }
//
// Widget _badgePercent(int pct) {
//   return Container(
//     padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//     decoration: BoxDecoration(
//       color: Colors.yellow,
//       border: Border.all(color: Colors.black, width: 1.2),
//     ),
//     child: Text(
//       '$pct%',
//       style: const TextStyle(
//         fontSize: 18,
//         fontWeight: FontWeight.w900,
//         color: Colors.blue,
//       ),
//     ),
//   );
// }
//
// class _TitleBar extends StatelessWidget {
//   final String text;
//   final Color color;
//   final double? width;
//
//   const _TitleBar({required this.text, required this.color, this.width});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: width,
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       alignment: Alignment.center,
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.18),
//         border: Border.all(color: color.withOpacity(0.5)),
//       ),
//       child: Text(
//         text,
//         style: TextStyle(
//           color: color,
//           fontSize: 18,
//           fontWeight: FontWeight.w900,
//         ),
//       ),
//     );
//   }
// }
//
// class _CellSpec {
//   final String text;
//   final double w;
//   final bool bold;
//   final TextAlign align;
//
//   const _CellSpec(
//     this.text, {
//     required this.w,
//     this.bold = false,
//     this.align = TextAlign.center,
//   });
// }

import 'package:flutter/material.dart';

import '../api/summary_api.dart';
import '../model/division_summary.dart';
import '../widget/glass_action_button.dart'; // bạn đang dùng
// nếu không có GlassActionButton thì thay bằng IconButton bình thường

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

  void _refresh() => setState(() => _future = _load());

  @override
  void dispose() {
    _afterHCtrl.dispose();
    _beforeHCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxW = 1700.0; // ⬅ tăng lên
    final w = MediaQuery.of(context).size.width;
    final dialogW = w < 600 ? w - 24 : (w < maxW ? w - 64 : maxW);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogW,
          maxHeight: MediaQuery.of(context).size.height * 0.86,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BEFORE / AFTER (${widget.fac})',
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
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Divider(color: Colors.white.withOpacity(0.08), height: 1),

              // ===== Body =====
              Expanded(
                child: FutureBuilder<List<DivisionSummary>>(
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
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final rows = snap.data ?? [];
                    if (rows.isEmpty) {
                      return const Center(
                        child: Text(
                          'No data',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    final totals = _Totals.from(rows);

                    return LayoutBuilder(
                      builder: (context, c) {
                        final isWide = c.maxWidth >= 900;

                        final before = _BeforeCard(
                          rows: rows,
                          sumAll: totals.sumAll,
                          controller: _beforeHCtrl,
                        );

                        final after = _AfterCard(
                          rows: rows,
                          totals: totals,
                          controller: _afterHCtrl,
                        );

                        if (isWide) {
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 400, child: before),
                                const SizedBox(width: 12),
                                Expanded(child: after),
                              ],
                            ),
                          );
                        }

                        // màn hình nhỏ: xếp dọc + scroll dọc
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              before,
                              const SizedBox(height: 12),
                              after,
                            ],
                          ),
                        );
                      },
                    );
                  },
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
  final int sumAll;
  final int sumPro;
  final int sumHse;
  final int sumRemain;

  _Totals({
    required this.sumAll,
    required this.sumPro,
    required this.sumHse,
    required this.sumRemain,
  });

  int get done => sumPro + sumHse;

  int get donePct => (sumAll == 0) ? 0 : ((done / sumAll) * 100).round();

  int get remainPct => (sumAll == 0) ? 0 : ((sumRemain / sumAll) * 100).round();

  static _Totals from(List<DivisionSummary> rows) {
    var sumAll = 0, sumPro = 0, sumHse = 0, sumRemain = 0;
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
}

// =======================
// BEFORE card
// =======================
class _BeforeCard extends StatelessWidget {
  final List<DivisionSummary> rows;
  final int sumAll;
  final ScrollController controller;

  const _BeforeCard({
    required this.rows,
    required this.sumAll,
    required this.controller,
  });

  static const double _wArea = 170;
  static const double _wPic = 120;
  static const double _wTotal = 70;

  @override
  Widget build(BuildContext context) {
    final tableWidth = _wArea + _wPic + _wTotal;

    return _Glass(
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TitleBar(
                  text: 'BEFORE',
                  color: Colors.redAccent,
                  width: double.infinity,
                ),
                const SizedBox(height: 10),
                _RowHeader(
                  cells: const [
                    _CellSpec(
                      'Patrolled Area',
                      w: _wArea,
                      align: TextAlign.left,
                    ),
                    _CellSpec('PIC', w: _wPic),
                    _CellSpec('Total', w: _wTotal, bold: true),
                  ],
                ),
                const SizedBox(height: 6),
                ...rows.map(
                  (r) => _RowLine(
                    cells: [
                      _CellSpec(r.division, w: _wArea, align: TextAlign.left),
                      const _CellSpec('-', w: _wPic),
                      _CellSpec('${r.allTtl}', w: _wTotal, bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: _badgeNumber(sumAll, bg: Colors.yellow),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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

  static const double _wDiv = 170;
  static const double _wNum = 56;

  @override
  Widget build(BuildContext context) {
    final tableWidth = _wDiv + (_wNum * 18);

    return _Glass(
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TitleBar(
                  text: 'AFTER',
                  color: const Color(0xFFD8F5C7),
                  width: tableWidth,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _groupHeader(
                      'Finished (Pro)',
                      Colors.greenAccent,
                      _wDiv + _wNum * 6,
                    ),
                    _groupHeader(
                      'Finished (HSE recheck)',
                      Colors.blueAccent,
                      _wNum * 6,
                    ),
                    _groupHeader('Remain', Colors.redAccent, _wNum * 6),
                  ],
                ),
                Row(
                  children: [
                    _RowHeader(
                      cells: const [
                        _CellSpec('Area', w: _wDiv, align: TextAlign.left),
                      ],
                    ),
                    _RowHeader(
                      bg: const Color(0xFF8FEFA0),
                      cells: const [
                        // _CellSpec('Area', w: _wDiv, align: TextAlign.left),
                        _CellSpec('TTL', w: _wNum),
                        _CellSpec('I', w: _wNum),
                        _CellSpec('II', w: _wNum),
                        _CellSpec('III', w: _wNum),
                        _CellSpec('IV', w: _wNum),
                        _CellSpec('V', w: _wNum),
                      ],
                    ),
                    _RowHeader(
                      bg: const Color(0xFF72C7F4),
                      cells: const [
                        _CellSpec('TTL', w: _wNum),
                        _CellSpec('I', w: _wNum),
                        _CellSpec('II', w: _wNum),
                        _CellSpec('III', w: _wNum),
                        _CellSpec('IV', w: _wNum),
                        _CellSpec('V', w: _wNum),
                      ],
                    ),
                    _RowHeader(
                      bg: const Color(0xFFF89292),
                      cells: const [
                        _CellSpec('TTL', w: _wNum),
                        _CellSpec('I', w: _wNum),
                        _CellSpec('II', w: _wNum),
                        _CellSpec('III', w: _wNum),
                        _CellSpec('IV', w: _wNum),
                        _CellSpec('V', w: _wNum),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                ...rows.map((r) {
                  return Row(
                    children: [
                      _RowLine(
                        cells: [
                          _CellSpec(
                            r.division,
                            w: _wDiv,
                            align: TextAlign.left,
                          ),
                        ],
                      ),
                      _RowLine(
                        bg: const Color(0xFFBFF2C8),
                        cells: [
                          _CellSpec('${r.proDoneTtl}', w: _wNum),
                          _CellSpec('${r.proDoneI}', w: _wNum),
                          _CellSpec('${r.proDoneII}', w: _wNum),
                          _CellSpec('${r.proDoneIII}', w: _wNum),
                          _CellSpec('${r.proDoneIV}', w: _wNum),
                          _CellSpec('${r.proDoneV}', w: _wNum),
                        ],
                      ),
                      _RowLine(
                        bg: const Color(0xFFBFE0F2),
                        cells: [
                          _CellSpec('${r.hseDoneTtl}', w: _wNum),
                          _CellSpec('${r.hseDoneI}', w: _wNum),
                          _CellSpec('${r.hseDoneII}', w: _wNum),
                          _CellSpec('${r.hseDoneIII}', w: _wNum),
                          _CellSpec('${r.hseDoneIV}', w: _wNum),
                          _CellSpec('${r.hseDoneV}', w: _wNum),
                        ],
                      ),
                      _RowLine(
                        bg: const Color(0xFFFFC2C2),
                        cells: [
                          _CellSpec('${r.remainTtl}', w: _wNum),
                          _CellSpec('${r.remainI}', w: _wNum),
                          _CellSpec('${r.remainII}', w: _wNum),
                          _CellSpec('${r.remainIII}', w: _wNum),
                          _CellSpec('${r.remainIV}', w: _wNum),
                          _CellSpec('${r.remainV}', w: _wNum),
                        ],
                      ),
                    ],
                  );
                }),

                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Done',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _badgeNumber(totals.done, bg: Colors.yellow),
                    const SizedBox(width: 8),
                    _badgePercent(totals.donePct),

                    const SizedBox(width: 24),

                    const Icon(
                      Icons.hourglass_bottom,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Remain',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _badgeNumber(totals.sumRemain, bg: Colors.yellow),
                    const SizedBox(width: 8),
                    _badgePercent(totals.remainPct),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

class _RowHeader extends StatelessWidget {
  final List<_CellSpec> cells;
  final Color? bg;

  const _RowHeader({required this.cells, this.bg});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: cells.map((c) => _cell(c, header: true, bg: bg)).toList(),
    );
  }
}

class _RowLine extends StatelessWidget {
  final List<_CellSpec> cells;
  final Color? bg;

  const _RowLine({required this.cells, this.bg});

  @override
  Widget build(BuildContext context) {
    return Row(children: cells.map((c) => _cell(c, bg: bg)).toList());
  }
}

Widget _cell(_CellSpec c, {bool header = false, Color? bg}) {
  final textColor = header ? Colors.black : Colors.black87;
  // final baseBg = header
  //     ? const Color(0xFFDDDDDD)
  //     : (bg ?? const Color(0xFFEFEFEF));

  final baseBg = header
      ? (bg ?? const Color(0xFFDDDDDD)) // ✅ header cũng dùng bg nếu truyền vào
      : (bg ?? const Color(0xFFEFEFEF));
  return Container(
    width: c.w,
    height: header ? 34 : 38,
    alignment: _align(c.align),
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

Alignment _align(TextAlign a) {
  switch (a) {
    case TextAlign.left:
      return Alignment.centerLeft;
    case TextAlign.right:
      return Alignment.centerRight;
    default:
      return Alignment.center;
  }
}

Widget _groupHeader(String title, Color c, double width) {
  return Container(
    width: width,
    padding: const EdgeInsets.symmetric(vertical: 10),
    alignment: Alignment.center,
    child: Text(
      title,
      style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 16),
    ),
  );
}

Widget _badgeNumber(int v, {required Color bg}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: bg,
      border: Border.all(color: Colors.black, width: 1.2),
    ),
    child: Text(
      '$v',
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: Colors.black,
      ),
    ),
  );
}

Widget _badgePercent(int pct) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.yellow,
      border: Border.all(color: Colors.black, width: 1.2),
    ),
    child: Text(
      '$pct%',
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: Colors.blue,
      ),
    ),
  );
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

  const _CellSpec(
    this.text, {
    required this.w,
    this.bold = false,
    this.align = TextAlign.center,
  });
}
