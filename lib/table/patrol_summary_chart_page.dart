import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../model/risk_summary.dart';
import '../widget/glass_action_button.dart';

class PatrolRiskSummarySfPage extends StatefulWidget {
  const PatrolRiskSummarySfPage({super.key});

  @override
  State<PatrolRiskSummarySfPage> createState() =>
      _PatrolRiskSummarySfPageState();
}

class _PatrolRiskSummarySfPageState extends State<PatrolRiskSummarySfPage> {
  late final PatrolApi api;

  // demo params (bạn có thể thay bằng date picker/dropdown)
  String fromD = '2026-01-02';
  String toD = '2026-01-15';
  String fac = 'Fac_2';
  String type = 'Patrol';

  late Future<List<RiskSummary>> future;

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

    future = _load();
  }

  Future<List<RiskSummary>> _load() {
    return api.fetchRiskSummary(fromD: fromD, toD: toD, fac: fac, type: type);
  }

  void _reload() {
    setState(() => future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Risk Summary'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<RiskSummary>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(message: snap.error.toString(), onRetry: _reload);
          }

          final items = snap.data ?? const <RiskSummary>[];
          if (items.isEmpty) {
            return _EmptyView(onRetry: _reload);
          }

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassActionButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.pop(context, false),
                    ),
                    // header nhỏ gọn
                    Row(
                      children: [
                        const Icon(Icons.stacked_bar_chart_rounded, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Patrol Summary',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        _MiniChip('$fromD → $toD'),
                        const SizedBox(width: 8),
                        _MiniChip(fac),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: items.length * 20 + 80,
                      child: _RiskStackedBarChart(
                        key: ValueKey(
                          'sf_chart_${items.length}_${items.hashCode}',
                        ),
                        items: items,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RiskStackedBarChart extends StatelessWidget {
  final List<RiskSummary> items;
  const _RiskStackedBarChart({super.key, required this.items});

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
      // ✅ category nằm trên trục X
      xValueMapper: (e, _) => e.shortLabel, // "Group 1 (Fac_A)"
      // ✅ số nằm trên trục Y
      yValueMapper: (e, _) => v(e),
      dataLabelMapper: (e, _) {
        final value = v(e);
        return value > 0 ? value.toString() : null;
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

class _MiniChip extends StatelessWidget {
  final String text;
  const _MiniChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

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
          const Text('No data', style: TextStyle(fontWeight: FontWeight.w700)),
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
