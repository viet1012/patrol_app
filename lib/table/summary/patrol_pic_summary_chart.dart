import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../model/patrol_pic_summary.dart';

class PatrolPicSummaryChart extends StatelessWidget {
  final List<PatrolPicSummary> items;

  const PatrolPicSummaryChart({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return SfCartesianChart(
      plotAreaBorderWidth: 0,

      legend: const Legend(isVisible: true, position: LegendPosition.bottom),

      tooltipBehavior: TooltipBehavior(enable: true),

      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
      ),

      primaryYAxis: NumericAxis(minimum: 0, interval: 2),

      series: <CartesianSeries>[
        _stack(name: 'Doing', color: Colors.orange, value: (e) => e.doingCount),

        _stack(
          name: 'Pro Done',
          color: Colors.green,
          value: (e) => e.proDoneCount,
        ),

        _stack(name: 'Closed', color: Colors.blue, value: (e) => e.closedCount),

        _stack(name: 'Redo', color: Colors.red, value: (e) => e.redoCount),
      ],
    );
  }

  StackedBarSeries<PatrolPicSummary, String> _stack({
    required String name,
    required Color color,
    required int Function(PatrolPicSummary e) value,
  }) {
    return StackedBarSeries<PatrolPicSummary, String>(
      name: name,

      dataSource: items,

      xValueMapper: (e, _) => e.pic,

      yValueMapper: (e, _) => value(e),

      color: color,

      width: 0.6,

      enableTooltip: true,

      dataLabelSettings: const DataLabelSettings(
        isVisible: true,
        textStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),

      dataLabelMapper: (e, _) {
        final v = value(e);

        return v == 0 ? '' : v.toString();
      },
    );
  }
}
