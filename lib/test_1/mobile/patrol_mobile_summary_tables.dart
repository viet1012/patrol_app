import 'package:flutter/material.dart';

import '../patrol_summary_table.dart';

class PatrolMobileSummaryTables extends StatelessWidget {
  final List<PatrolPicRowDto> rows;
  final double tableHeight;
  final double? finishedRate;
  final double? remainRate;
  final double? okRate;
  final double? ngRate;

  const PatrolMobileSummaryTables({
    super.key,
    required this.rows,
    required this.tableHeight,
    required this.finishedRate,
    required this.remainRate,
    required this.okRate,
    required this.ngRate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _mobileTable(
          width: TableUiConfig.tableWidth(TableUiConfig.beforeColumns),
          child: BeforeTable(rows: rows),
        ),

        const SizedBox(height: 12),

        _mobileTable(
          width: TableUiConfig.tableWidth(TableUiConfig.beforeColumns),
          child: MobileRiskTable(
            title: 'FINISHED',
            groupLabel: 'Finished',
            rate: finishedRate,
            headerColor: TableUiConfig.finishedHeaderBg,
            bodyColor: TableUiConfig.finishedBg,
            borderColor: TableUiConfig.finishedBorder,
            rows: rows,
            valueBuilder: (row) => row.finished,
          ),
        ),

        const SizedBox(height: 12),

        _mobileTable(
          width: TableUiConfig.tableWidth(TableUiConfig.beforeColumns),
          child: MobileRiskTable(
            title: 'REMAIN',
            groupLabel: 'Remain',
            rate: remainRate,
            headerColor: TableUiConfig.remainHeaderBg,
            bodyColor: TableUiConfig.remainBg,
            borderColor: TableUiConfig.remainBorder,
            rows: rows,
            valueBuilder: (row) => row.remain,
          ),
        ),

        const SizedBox(height: 12),

        _mobileTable(
          width: TableUiConfig.tableWidth(TableUiConfig.deadlineColumns),
          child: MobileDeadlineTable(rows: rows),
        ),

        const SizedBox(height: 12),

        _mobileTable(
          width: TableUiConfig.tableWidth(TableUiConfig.beforeColumns),
          child: MobileRiskTable(
            title: 'OK',
            groupLabel: 'OK',
            rate: okRate,
            headerColor: TableUiConfig.okHeaderBg,
            bodyColor: TableUiConfig.okBg,
            borderColor: TableUiConfig.okBorder,
            rows: rows,
            valueBuilder: (row) => row.recheckOk,
          ),
        ),

        const SizedBox(height: 12),

        _mobileTable(
          width: TableUiConfig.tableWidth(TableUiConfig.beforeColumns),
          child: MobileRiskTable(
            title: 'NG',
            groupLabel: 'NG',
            rate: ngRate,
            headerColor: TableUiConfig.ngHeaderBg,
            bodyColor: TableUiConfig.ngBg,
            borderColor: TableUiConfig.ngBorder,
            rows: rows,
            valueBuilder: (row) => row.recheckNg,
          ),
        ),
      ],
    );
  }

  Widget _mobileTable({required double width, required Widget child}) {
    return SizedBox(
      height: tableHeight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: width, child: child),
      ),
    );
  }
}

class MobileRiskTable extends StatelessWidget {
  final String title;
  final String groupLabel;
  final double? rate;
  final Color headerColor;
  final Color bodyColor;
  final Color borderColor;
  final List<PatrolPicRowDto> rows;
  final RiskBreakdownDto Function(PatrolPicRowDto row) valueBuilder;

  const MobileRiskTable({
    super.key,
    required this.title,
    required this.groupLabel,
    required this.rate,
    required this.headerColor,
    required this.bodyColor,
    required this.borderColor,
    required this.rows,
    required this.valueBuilder,
  });

  String _percent(double? value) {
    if (value == null) return '--';
    return '${(value * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    return ExcelLikeTable(
      titleLeft: title,
      titleCenter: _percent(rate),
      columns: TableUiConfig.beforeColumns,
      groupedHeaders: [
        GroupedHeader(
          label: groupLabel,
          startCol: 1,
          colSpan: 6,
          backgroundColor: headerColor,
          borderColor: borderColor,
        ),
      ],
      rows: rows.map((row) {
        final data = valueBuilder(row);

        return TableRowData(
          isTotal: row.pic.toUpperCase() == 'TOTAL',
          cells: [
            row.pic,
            data.total,
            data.i,
            data.ii,
            data.iii,
            data.iv,
            data.v,
          ],
        );
      }).toList(),
    );
  }
}

class MobileDeadlineTable extends StatelessWidget {
  final List<PatrolPicRowDto> rows;

  const MobileDeadlineTable({
    super.key,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return ExcelLikeTable(
      titleLeft: 'DEADLINE',
      titleCenter: 'Remain due',
      columns: TableUiConfig.deadlineColumns,
      groupedHeaders: const [
        GroupedHeader(
          label: 'Deadline',
          startCol: 1,
          colSpan: 3,
          backgroundColor: TableUiConfig.deadlineBg,
          borderColor: TableUiConfig.deadlineBorder,
        ),
      ],
      rows: rows.map((row) {
        return TableRowData(
          isTotal: row.pic.toUpperCase() == 'TOTAL',
          cells: [
            row.pic,
            row.stillTimeTtl,
            row.threeDaysTtl,
            row.lateTtl,
          ],
        );
      }).toList(),
    );
  }
}