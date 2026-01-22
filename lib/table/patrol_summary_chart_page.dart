import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../common/common_ui_helper.dart';
import '../model/risk_summary.dart';

class PatrolRiskSummarySfPage extends StatefulWidget {
  final String plant;
  final String patrolGroup;

  final void Function(String grp, String division)? onSelect;
  final void Function(DateTime from, DateTime to)? onDateChanged; // ✅

  const PatrolRiskSummarySfPage({
    super.key,
    this.onSelect,
    this.onDateChanged,
    required this.plant,
    required this.patrolGroup,
  });

  @override
  State<PatrolRiskSummarySfPage> createState() =>
      _PatrolRiskSummarySfPageState();
}

class _PatrolRiskSummarySfPageState extends State<PatrolRiskSummarySfPage> {
  late final PatrolApi api;

  // String fac = 'Fac_2';
  // String type = 'Patrol';

  late TextEditingController _fromCtrl;
  late TextEditingController _toCtrl;

  late DateTime _fromDate;
  late DateTime _toDate;

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // last good
  List<RiskSummary> _lastGoodItems = const [];
  DateTime? _lastGoodFrom;
  DateTime? _lastGoodTo;

  bool _noData = false;
  String _noDataMsg = '';

  bool _loading = true;
  String? _error;
  List<RiskSummary> _items = const [];

  @override
  void initState() {
    super.initState();

    api = PatrolApi(
      dio: Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
        ),
      ),
      baseUrl: 'http://192.168.122.15:9299',
    );

    final now = DateTime.now();
    _toDate = DateTime(now.year, now.month, now.day);
    _fromDate = DateTime(now.year, now.month, 1);

    _fromCtrl = TextEditingController(text: _fmt(_fromDate));
    _toCtrl = TextEditingController(text: _fmt(_toDate));

    _fetch();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
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
        fromD: _fmt(_fromDate),
        toD: _fmt(_toDate),
        fac: widget.plant,
        type: widget.patrolGroup,
      );

      if (!mounted) return;

      if (res.isEmpty) {
        // ✅ không phá dữ liệu cũ
        setState(() {
          _loading = false;
          _noData = true;
          _noDataMsg = 'Không có dữ liệu cho khoảng ngày đã chọn';
          _items = const []; // để shownItems tự fallback về lastGood
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

    if (isFrom) {
      newFrom = DateTime(picked.year, picked.month, picked.day);
    } else {
      newTo = DateTime(picked.year, picked.month, picked.day);
    }

    if (newFrom.isAfter(newTo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('From date must be <= To date')),
      );
      return;
    }

    setState(() {
      _fromDate = newFrom;
      _toDate = newTo;
      _fromCtrl.text = _fmt(_fromDate);
      _toCtrl.text = _fmt(_toDate);
    });
    // ✅ báo cho parent biết ngày mới
    widget.onDateChanged?.call(_fromDate, _toDate);
    _fetch(); // ✅ gọi API ngay
  }

  void _revertToLastGood() {
    if (_lastGoodFrom == null || _lastGoodTo == null || _lastGoodItems.isEmpty)
      return;

    setState(() {
      _fromDate = _lastGoodFrom!;
      _toDate = _lastGoodTo!;
      _fromCtrl.text = _fmt(_fromDate);
      _toCtrl.text = _fmt(_toDate);

      _items = _lastGoodItems;
      _noData = false;
      _noDataMsg = '';
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _reload);
    }

    // ✅ shownItems: ưu tiên kết quả mới, rỗng thì fallback lastGood
    final shownItems = _items.isNotEmpty ? _items : _lastGoodItems;
    final totalItem = shownItems.cast<RiskSummary?>().firstWhere(
      (e) => e?.grp == 'TOTAL',
      orElse: () => null,
    );

    final chartItems = shownItems.where((e) => e.grp != 'TOTAL').toList();

    if (shownItems.isEmpty) {
      return _EmptyView(onRetry: _reload);
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.stacked_bar_chart_rounded, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Patrol Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  _DateField(
                    ctrl: _fromCtrl,
                    label: 'From',
                    onTap: () => _pickDate(isFrom: true),
                  ),
                  const SizedBox(width: 8),
                  _DateField(
                    ctrl: _toCtrl,
                    label: 'To',
                    onTap: () => _pickDate(isFrom: false),
                  ),
                ],
              ),
              if (totalItem != null) ...[
                const SizedBox(height: 10),
                _TotalRiskBar(totalItem),
              ],

              if (_noData) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_noDataMsg)),
                      TextButton.icon(
                        onPressed: _revertToLastGood,
                        icon: const Icon(Icons.history),
                        label: const Text('Back'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),

              SizedBox(
                height: chartItems.length * 20 + 80,
                child: _RiskStackedBarChart(
                  // key: ValueKey(
                  //   'sf_chart_${chartItems.length}_${chartItems.hashCode}',
                  // ),
                  items: chartItems,
                  onSelect: widget.onSelect,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskStackedBarChart extends StatelessWidget {
  final List<RiskSummary> items;
  final void Function(String grp, String division)? onSelect;
  const _RiskStackedBarChart({super.key, required this.items, this.onSelect});

  static const Color cMinus = Color(0xFFE5E7EB);
  static const Color cI = Color(0xFFD1FAE5);
  static const Color cII = Color(0xFF86EFAC);
  static const Color cIII = Color(0xFF22C55E);
  static const Color cIV = Color(0xFFFACC15);
  static const Color cV = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return SfCartesianChart(
      tooltipBehavior: TooltipBehavior(enable: true),
      plotAreaBorderWidth: 0,
      margin: const EdgeInsets.fromLTRB(6, 8, 8, 6),
      legend: const Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        overflowMode: LegendItemOverflowMode.wrap,
        itemPadding: 10,
      ),

      // ✅ X là category (Group/Division)
      primaryXAxis: CategoryAxis(
        labelPlacement: LabelPlacement.betweenTicks,
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        labelStyle: const TextStyle(fontSize: 11, height: 1.1),
      ),

      // ✅ Y là số (0..)
      primaryYAxis: NumericAxis(
        minimum: 0,
        interval: 5,
        majorGridLines: const MajorGridLines(
          width: 1,
          color: Color(0x22000000),
        ),
        axisLine: const AxisLine(width: 0),
        labelStyle: const TextStyle(fontSize: 11, color: Colors.black54),
      ),

      series: <StackedBarSeries<RiskSummary, String>>[
        _stack(name: '-', color: cMinus, v: (e) => e.minus),
        _stack(name: 'I', color: cI, v: (e) => e.i),
        _stack(name: 'II', color: cII, v: (e) => e.ii),
        _stack(name: 'III', color: cIII, v: (e) => e.iii),
        _stack(name: 'IV', color: cIV, v: (e) => e.iv),
        _stack(name: 'V', color: cV, v: (e) => e.v),
      ],
    );
  }

  StackedBarSeries<RiskSummary, String> _stack({
    required String name,
    required Color color,
    required int Function(RiskSummary e) v,
  }) {
    return StackedBarSeries<RiskSummary, String>(
      name: name,
      dataSource: items,
      // animationDuration: 0,
      xValueMapper: (e, _) => e.shortLabel,
      yValueMapper: (e, _) => v(e),
      dataLabelMapper: (e, _) {
        final value = v(e);
        return value == 0 ? '' : value.toString();
      },

      onPointTap: (ChartPointDetails details) {
        final idx = details.pointIndex;
        if (idx == null) return;

        final e = items[idx];

        onSelect?.call(e.grp, e.division); // 🔥 callback ngược lên
      },

      color: color,
      enableTooltip: true,
      width: 0.5,

      dataLabelSettings: const DataLabelSettings(
        isVisible: true,
        labelAlignment: ChartDataLabelAlignment.middle,
        textStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

// ====== UI helpers nhỏ gọn ======

class _EmptyView extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_rounded, size: 46, color: Colors.grey),
          const SizedBox(height: 10),
          const Text(
            'No data',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reload'),
          ),
        ],
      ),
    );
  }
}

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

class _DateField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final VoidCallback onTap;

  const _DateField({
    required this.ctrl,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 38,
      child: TextField(
        controller: ctrl,
        readOnly: true,
        onTap: onTap,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_month, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}

class _TotalRiskBar extends StatelessWidget {
  final RiskSummary t;
  const _TotalRiskBar(this.t);

  int get total => (t.minus) + t.i + t.ii + t.iii + t.iv + t.v;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, int v) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CommonUI.riskColor(label)),
      ),
      child: Text(
        '$label: $v',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: CommonUI.riskColor(label),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.summarize_rounded, size: 18),
          const SizedBox(width: 8),
          Text(
            'Total Risk: $total',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              chip('-', t.minus),
              chip('I', t.i),
              chip('II', t.ii),
              chip('III', t.iii),
              chip('IV', t.iv),
              chip('V', t.v),
            ],
          ),
        ],
      ),
    );
  }
}
