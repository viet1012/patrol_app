import 'package:flutter/material.dart';

import 'package:chuphinh/core/api/patrol_risk_summary_api.dart';
import 'package:chuphinh/shared/utils/plant_constants.dart';
import 'package:chuphinh/core/models/risk_summary.dart';
import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';

typedef _F = PatrolReportFilterBarTokens;
typedef _T = PatrolReportTokens;

class PatrolRiskSummaryPage extends StatefulWidget {
  final String plant;
  final String patrolGroup;

  /// ✅ range từ parent (PatrolReportTable)
  final DateTime? fromD;
  final DateTime? toD;

  final void Function(String grp, String division, String plant)? onSelect;

  /// ✅ báo ngược lên parent khi user đổi ngày trong Summary
  final void Function(DateTime from, DateTime to)? onDateChanged;

  const PatrolRiskSummaryPage({
    super.key,
    this.onSelect,
    this.onDateChanged,
    required this.plant,
    required this.patrolGroup,
    this.fromD,
    this.toD,
  });

  @override
  State<PatrolRiskSummaryPage> createState() => _PatrolRiskSummaryPageState();
}

class _PatrolRiskSummaryPageState extends State<PatrolRiskSummaryPage> {
  late final PatrolRiskSummaryApi api;

  late DateTime _fromDate;
  late DateTime _toDate;

  // last good
  List<RiskSummary> _lastGoodItems = const [];
  DateTime? _lastGoodFrom;
  DateTime? _lastGoodTo;

  bool _noData = false;
  String _noDataMsg = '';

  bool _loading = true;
  String? _error;
  List<RiskSummary> _items = const [];
  late final DateTime _initialFrom;
  late final DateTime _initialTo;

  bool get _isMobile => _T.isMobile(context);

  @override
  void initState() {
    super.initState();

    api = const PatrolRiskSummaryApi();

    // ✅ 1) init range ưu tiên từ parent, nếu null thì default
    final now = DateTime.now();
    final defaultTo = DateTime(now.year, now.month, now.day);
    final defaultFrom = DateTime(now.year, now.month, 1);

    _fromDate = _normalize(widget.fromD) ?? defaultFrom;
    _toDate = _normalize(widget.toD) ?? defaultTo;
    _initialFrom = _fromDate;
    _initialTo = _toDate;
    // ✅ đảm bảo from <= to
    if (_fromDate.isAfter(_toDate)) {
      _fromDate = defaultFrom;
      _toDate = defaultTo;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onDateChanged?.call(_fromDate, _toDate);
      });
    }

    _fetch();
  }

  /// ✅ 2) parent đổi from/to => child sync lại + gọi API
  @override
  void didUpdateWidget(covariant PatrolRiskSummaryPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newFrom = _normalize(widget.fromD);
    final newTo = _normalize(widget.toD);

    final oldFrom = _normalize(oldWidget.fromD);
    final oldTo = _normalize(oldWidget.toD);

    final changed =
        (newFrom != null && !_sameDay(newFrom, oldFrom)) ||
        (newTo != null && !_sameDay(newTo, oldTo));

    if (changed) {
      final now = DateTime.now();
      final fallbackTo = DateTime(now.year, now.month, now.day);
      final fallbackFrom = DateTime(now.year, now.month, 1);

      final from = newFrom ?? fallbackFrom;
      final to = newTo ?? fallbackTo;

      if (from.isAfter(to)) return; // parent truyền sai thì bỏ qua

      setState(() {
        _fromDate = from;
        _toDate = to;
      });

      _fetch();
    }
  }

  DateTime? _normalize(DateTime? d) {
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day);
  }

  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _noData = false;
      _noDataMsg = '';
    });

    try {
      final res = await api.fetchRiskSummary(
        fromD: _fmtDate(_fromDate),
        toD: _fmtDate(_toDate),
        fac: widget.plant,
        type: widget.patrolGroup,
      );

      if (!mounted) return;

      if (res.isEmpty) {
        setState(() {
          _loading = false;
          _noData = true;
          _noDataMsg = 'No data for the selected date range';
          _items = const [];
        });
        return;
      }

      setState(() {
        _loading = false;
        _items = res;

        _lastGoodItems = res;
        _lastGoodFrom = _fromDate;
        _lastGoodTo = _toDate;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _reload() => _fetch();

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _fromDate : _toDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );

    if (picked == null) return;

    DateTime newFrom = _fromDate;
    DateTime newTo = _toDate;

    final p = DateTime(picked.year, picked.month, picked.day);

    if (isFrom) {
      newFrom = p;
    } else {
      newTo = p;
    }

    if (newFrom.isAfter(newTo)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('From date must be <= To date')),
      );
      return;
    }

    setState(() {
      _fromDate = newFrom;
      _toDate = newTo;
    });

    // ✅ báo cho parent biết (để Dialog Open dùng chung)
    widget.onDateChanged?.call(_fromDate, _toDate);

    _fetch();
  }

  void _revertToInitial() {
    setState(() {
      _fromDate = _initialFrom;
      _toDate = _initialTo;

      _noData = false;
      _noDataMsg = '';
      _error = null;
    });

    widget.onDateChanged?.call(_fromDate, _toDate);
    _fetch(); // ✅ quan trọng
  }

  void _revertToLastGood() {
    if (_lastGoodFrom == null ||
        _lastGoodTo == null ||
        _lastGoodItems.isEmpty) {
      return;
    }

    setState(() {
      _fromDate = _lastGoodFrom!;
      _toDate = _lastGoodTo!;

      _items = _lastGoodItems;
      _noData = false;
      _noDataMsg = '';
      _error = null;
    });

    // ✅ sync parent lại theo lastGood
    widget.onDateChanged?.call(_fromDate, _toDate);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _reload);
    }

    final shownItems = _items;

    final totalItem = shownItems.cast<RiskSummary?>().firstWhere(
      (e) => e?.grp == 'TOTAL',
      orElse: () => null,
    );

    final chartItems = shownItems.where((e) => e.grp != 'TOTAL').toList();
    final totals = totalItem ?? _sumOf(chartItems);
    final isMobile = _isMobile;

    // Không có lề trên: khoảng cách với hàng Group do hàng Group quyết định
    // (PatrolReportFilterBarTokens.rowBottomGap).
    final pad = isMobile ? _F.summaryPaddingCompact : _F.summaryPadding;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
      child: Card(
        elevation: 1.5,
        // Trắng thuần: bỏ ánh tím surface tint của Material 3.
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.fromLTRB(
          _F.summaryCardMargin,
          0,
          _F.summaryCardMargin,
          _F.summaryCardMargin,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 6 : 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SummaryHeader(
                totals: totals,
                from: _fromDate,
                to: _toDate,
                onPickFrom: () => _pickDate(isFrom: true),
                onPickTo: () => _pickDate(isFrom: false),
                isMobile: isMobile,
              ),

              if (_noData) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_noDataMsg)),
                      TextButton.icon(
                        onPressed: _revertToInitial,
                        icon: const Icon(Icons.history),
                        label: const Text('Back'),
                      ),
                    ],
                  ),
                ),
              ],

              if (!_noData && chartItems.isNotEmpty) ...[
                const SizedBox(height: 8),
                _RiskBars(
                  items: chartItems,
                  showPlant: isAllPlant(widget.plant),
                  onSelect: widget.onSelect,
                  labelWidth: isMobile ? _S.labelWidthMobile : _S.labelWidth,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Không có dòng TOTAL từ API: tự cộng các dòng.
  static RiskSummary _sumOf(List<RiskSummary> items) {
    int sum(int Function(RiskSummary e) f) =>
        items.fold(0, (acc, e) => acc + f(e));
    return RiskSummary(
      grp: 'TOTAL',
      division: '',
      minus: sum((e) => e.minus),
      i: sum((e) => e.i),
      ii: sum((e) => e.ii),
      iii: sum((e) => e.iii),
      iv: sum((e) => e.iv),
      v: sum((e) => e.v),
    );
  }
}

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ====== Style ======

abstract final class _S {
  static const double labelWidth = 132;
  static const double labelWidthMobile = 110;
  static const double labelGap = 8;

  static const double rowHeight = 24;
  static const double barHeight = 16;
  static const double barRadius = 4;

  /// Chỗ cho số tổng sau cuối thanh dài nhất.
  static const double totalWidth = 32;

  /// Đoạn hẹp hơn mức này: ẩn số.
  static const double minSegmentLabelWidth = 14;

  static const double pillHeight = 24;
  static const double dateButtonHeight = 32;
  static const double headerHeight = 40;

  static const Color gridLine = Color(0x14000000);
  static const Color muted = Colors.black54;

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color axisText = Color(0xFF6B7280);

  /// Dấu " · " trong nhãn dòng.
  static const TextStyle labelSeparator = TextStyle(
    fontWeight: FontWeight.w500,
    color: Color(0xFF9CA3AF),
  );

  /// Chữ trên đoạn III (#22C55E): xanh đậm thay vì trắng/đen.
  static const Color onLevelIII = Color(0xFF14532D);

  static const double legendSwatch = 10;
  static const double legendGap = 10;
  static const TextStyle legendStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];
}

/// Mức rủi ro theo thứ tự tăng dần. Màu giữ nguyên như biểu đồ Syncfusion cũ.
class _Level {
  final String name;
  final Color color;
  final int Function(RiskSummary e) of;

  const _Level(this.name, this.color, this.of);

  bool get isHigh => name == 'IV' || name == 'V';
}

int _minus(RiskSummary e) => e.minus;
int _i(RiskSummary e) => e.i;
int _ii(RiskSummary e) => e.ii;
int _iii(RiskSummary e) => e.iii;
int _iv(RiskSummary e) => e.iv;
int _v(RiskSummary e) => e.v;

const _levels = [
  _Level('-', Color(0xFFE5E7EB), _minus),
  _Level('I', Color(0xFFD1FAE5), _i),
  _Level('II', Color(0xFF86EFAC), _ii),
  _Level('III', Color(0xFF22C55E), _iii),
  _Level('IV', Color(0xFFFACC15), _iv),
  _Level('V', Color(0xFFEF4444), _v),
];

/// Chữ trên nền màu mức: III xanh đậm; trắng chỉ khi nền đủ tối; còn lại
/// gần đen.
Color _onLevel(Color bg) {
  if (bg == const Color(0xFF22C55E)) return _S.onLevelIII;
  return bg.computeLuminance() < 0.35 ? Colors.white : _S.textPrimary;
}

/// Trục "đẹp": 4–5 mốc chia đều, max >= [m] (vd. 8 → 8, 9 → 10, 23 → 25).
({int max, int step}) _niceAxis(int m) {
  if (m <= 0) return (max: 1, step: 1);
  for (var mag = 1; ; mag *= 10) {
    for (final f in const [1, 2, 5]) {
      final step = f * mag;
      final n = (m / step).ceil();
      if (n <= 5) return (max: n * step, step: step);
    }
  }
}

// ====== Header ======

class _SummaryHeader extends StatelessWidget {
  final RiskSummary totals;
  final DateTime from;
  final DateTime to;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final bool isMobile;

  const _SummaryHeader({
    required this.totals,
    required this.from,
    required this.to,
    required this.onPickFrom,
    required this.onPickTo,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    const title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.stacked_bar_chart_rounded, size: 18),
        SizedBox(width: 6),
        Text(
          'Patrol Summary',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ],
    );

    final total = Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: 'Total Risk ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _S.textSecondary,
            ),
          ),
          TextSpan(
            text: '${totals.total}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _S.textPrimary,
              fontFeatures: _S.tabular,
            ),
          ),
        ],
      ),
    );

    final pills = Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [for (final l in _levels) _LevelPill(l, l.of(totals))],
    );

    final dates = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DateButton(date: from, onTap: onPickFrom),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('→', style: TextStyle(color: _S.muted)),
        ),
        _DateButton(date: to, onTap: onPickTo),
      ],
    );

    // Mobile: wrap toàn bộ, tự xuống hàng.
    if (isMobile) {
      return Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [title, total, pills, dates],
      );
    }

    // Desktop: 1 hàng ~40, căn giữa dọc; pill chỉ wrap khi thật hẹp.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _S.headerHeight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          title,
          const SizedBox(width: 12),
          Container(width: 1, height: 20, color: _T.tableDivider),
          const SizedBox(width: 12),
          total,
          const SizedBox(width: 12),
          // Phần trống còn lại đẩy nút ngày sang phải; pill căn trái.
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: pills),
          ),
          const SizedBox(width: 12),
          dates,
        ],
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  final _Level level;
  final int count;

  const _LevelPill(this.level, this.count);

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (count == 0) {
      bg = const Color(0xFFF3F4F6);
      fg = Colors.black38;
    } else if (level.isHigh) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    } else {
      bg = const Color(0xFFE5E7EB);
      fg = Colors.black87;
    }

    // Rộng theo nội dung: không dùng Container(alignment:) vì nó giãn hết
    // bề ngang Wrap cho (mỗi pill thành 1 hàng).
    return Container(
      height: _S.pillHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          '${level.name} $count',
          maxLines: 1,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFeatures: _S.tabular,
          ),
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DateButton({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: _S.dateButtonHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _T.tableDivider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month, size: 16, color: _S.muted),
              const SizedBox(width: 6),
              Text(
                _fmtDate(date),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: _S.tabular,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====== Biểu đồ thanh ngang xếp chồng ======

class _RiskBars extends StatefulWidget {
  final List<RiskSummary> items;
  final bool showPlant;
  final void Function(String grp, String division, String plant)? onSelect;
  final double labelWidth;

  const _RiskBars({
    required this.items,
    required this.showPlant,
    required this.onSelect,
    required this.labelWidth,
  });

  @override
  State<_RiskBars> createState() => _RiskBarsState();
}

class _RiskBarsState extends State<_RiskBars> {
  int? _hovered;

  String _groupKey(RiskSummary e) => '${e.plant}|${e.grp}';

  String _rowLabel(RiskSummary e) {
    final base = '${e.grp} · ${e.division}';
    return widget.showPlant ? '${e.plant} · $base' : base;
  }

  /// "Group 14 · Fac_C — II: 1, III: 4, IV: 3 (8)"
  String _tooltip(RiskSummary e) {
    final parts = [
      for (final l in _levels)
        if (l.of(e) > 0) '${l.name}: ${l.of(e)}',
    ];
    return '${_rowLabel(e)} — ${parts.join(', ')} (${e.total})';
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final maxTotal = items.fold<int>(0, (m, e) => e.total > m ? e.total : m);
    final axis = _niceAxis(maxTotal);

    // Chỉ chú thích các mức có dữ liệu.
    final shownLevels = [
      for (final l in _levels)
        if (items.any((e) => l.of(e) > 0)) l,
    ];

    // Group xen kẽ nền; dòng đầu mỗi Group (trừ dòng đầu bảng) kẻ 1px.
    final groupIndex = <int>[];
    final groupStart = <bool>[];
    for (var k = 0; k < items.length; k++) {
      final isNew = k == 0 || _groupKey(items[k]) != _groupKey(items[k - 1]);
      groupStart.add(isNew && k > 0);
      groupIndex.add(k == 0 ? 0 : groupIndex[k - 1] + (isNew ? 1 : 0));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final barArea = (constraints.maxWidth - widget.labelWidth - _S.labelGap)
            .clamp(_S.totalWidth + 1, double.infinity);
        final plotWidth = barArea - _S.totalWidth;
        final scale = plotWidth / axis.max;
        final ticks = [
          for (var t = 0; t <= axis.max; t += axis.step) t * scale,
        ];
        final tickValues = [for (var t = 0; t <= axis.max; t += axis.step) t];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AxisAndLegend(
              labelWidth: widget.labelWidth,
              barArea: barArea,
              ticks: ticks,
              tickValues: tickValues,
              levels: shownLevels,
            ),
            for (var k = 0; k < items.length; k++)
              _buildRow(
                k,
                items[k],
                barArea: barArea,
                scale: scale,
                ticks: ticks,
                altBg: groupIndex[k].isOdd,
                groupStart: groupStart[k],
              ),
          ],
        );
      },
    );
  }

  Widget _buildRow(
    int k,
    RiskSummary e, {
    required double barArea,
    required double scale,
    required List<double> ticks,
    required bool altBg,
    required bool groupStart,
  }) {
    final hovered = _hovered == k;
    final bg = hovered ? _T.rowHover : (altBg ? _T.rowOdd : _T.rowEven);
    final barLength = e.total * scale;

    final label = Text.rich(
      TextSpan(
        // Plant / Group / Area đậm; dấu " · " xám nhạt.
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _S.textPrimary,
        ),
        children: [
          if (widget.showPlant) ...[
            TextSpan(text: e.plant),
            const TextSpan(text: ' · ', style: _S.labelSeparator),
          ],
          TextSpan(text: e.grp),
          const TextSpan(text: ' · ', style: _S.labelSeparator),
          TextSpan(text: e.division),
        ],
      ),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(_S.barRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final l in _levels)
            if (l.of(e) > 0) _segment(l, l.of(e), l.of(e) * scale),
        ],
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = k),
      onExit: (_) {
        if (_hovered == k) setState(() => _hovered = null);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSelect?.call(e.grp, e.division, e.plant),
        child: Tooltip(
          message: _tooltip(e),
          waitDuration: const Duration(milliseconds: 300),
          child: Container(
            height: _S.rowHeight,
            color: bg,
            foregroundDecoration: groupStart
                ? const BoxDecoration(
                    border: Border(top: BorderSide(color: _T.tableDivider)),
                  )
                : null,
            child: Row(
              children: [
                SizedBox(
                  width: widget.labelWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: label,
                  ),
                ),
                const SizedBox(width: _S.labelGap),
                SizedBox(
                  width: barArea,
                  height: _S.rowHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final x in ticks)
                        Positioned(
                          left: x,
                          top: 0,
                          bottom: 0,
                          width: 1,
                          child: const ColoredBox(color: _S.gridLine),
                        ),
                      Positioned(
                        left: 0,
                        top: (_S.rowHeight - _S.barHeight) / 2,
                        height: _S.barHeight,
                        child: bar,
                      ),
                      Positioned(
                        left: barLength + 4,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Text(
                            '${e.total}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _S.textPrimary,
                              fontFeatures: _S.tabular,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _segment(_Level l, int value, double width) {
    return Container(
      width: width,
      height: _S.barHeight,
      color: l.color,
      alignment: Alignment.center,
      child: width < _S.minSegmentLabelWidth
          ? null
          : Text(
              '$value',
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              style: TextStyle(
                fontSize: 10.5,
                height: 1,
                fontWeight: FontWeight.w700,
                color: _onLevel(l.color),
                fontFeatures: _S.tabular,
              ),
            ),
    );
  }
}

/// Đường kẻ mảnh phía trên; 1 hàng: nhãn trục thẳng lưới các dòng + chú thích
/// mức rủi ro căn phải vùng thanh. Nhãn trục nào đè lên chú thích thì ẩn.
class _AxisAndLegend extends StatelessWidget {
  final double labelWidth;
  final double barArea;
  final List<double> ticks;
  final List<int> tickValues;
  final List<_Level> levels;

  const _AxisAndLegend({
    required this.labelWidth,
    required this.barArea,
    required this.ticks,
    required this.tickValues,
    required this.levels,
  });

  static const double _tickLabelWidth = 28;
  static const double _rowHeight = 18;

  /// Bề rộng thực của chú thích (ô màu + gap + chữ, cách nhau legendGap).
  double _legendWidth(TextScaler scaler) {
    var w = 0.0;
    for (var i = 0; i < levels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: levels[i].name, style: _S.legendStyle),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      w += _S.legendSwatch + 4 + tp.width + (i > 0 ? _S.legendGap : 0);
    }
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final legendLeft =
        barArea - _legendWidth(MediaQuery.textScalerOf(context)) - 8;

    return Container(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _T.tableDivider)),
      ),
      child: SizedBox(
        height: _rowHeight,
        child: Row(
          children: [
            SizedBox(width: labelWidth + _S.labelGap),
            SizedBox(
              width: barArea,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var t = 0; t < ticks.length; t++)
                    if (ticks[t] + _tickLabelWidth / 2 <= legendLeft)
                      Positioned(
                        left: ticks[t] - _tickLabelWidth / 2,
                        width: _tickLabelWidth,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Text(
                            '${tickValues[t]}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _S.axisText,
                              fontFeatures: _S.tabular,
                            ),
                          ),
                        ),
                      ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < levels.length; i++) ...[
                          if (i > 0) const SizedBox(width: _S.legendGap),
                          _LegendItem(levels[i]),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final _Level level;

  const _LegendItem(this.level);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _S.legendSwatch,
          height: _S.legendSwatch,
          decoration: BoxDecoration(
            color: level.color,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: Colors.black12),
          ),
        ),
        const SizedBox(width: 4),
        Text(level.name, maxLines: 1, style: _S.legendStyle),
      ],
    );
  }
}

// ====== UI helpers nhỏ gọn ======

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 10),
            const Text(
              'API error',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
