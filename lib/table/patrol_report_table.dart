import 'package:flutter/material.dart';
import '../api/patrol_report_api.dart';
import '../model/patrol_report_model.dart';

class PatrolReportTable extends StatefulWidget {
  const PatrolReportTable({super.key});

  @override
  State<PatrolReportTable> createState() => _PatrolReportTableState();
}

class _PatrolReportTableState extends State<PatrolReportTable> {
  late Future<List<PatrolReportModel>> _futureReports;

  final ScrollController _horizontalCtrl = ScrollController();
  final ScrollController _verticalCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _futureReports = PatrolReportApi.fetchReports();
  }

  @override
  void dispose() {
    _horizontalCtrl.dispose();
    _verticalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: FutureBuilder<List<PatrolReportModel>>(
          future: _futureReports,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _buildError(snapshot.error.toString());
            }

            final reports = snapshot.data ?? [];

            if (reports.isEmpty) {
              return _buildEmpty();
            }

            return Column(children: [Expanded(child: _buildTable(reports))]);
          },
        ),
      ),
    );
  }

  // ===================== TABLE =====================
  Widget _buildTable(List<PatrolReportModel> reports) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Scrollbar(
        controller: _horizontalCtrl, // ✅ GẮN CONTROLLER
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _horizontalCtrl, // ✅ CÙNG CONTROLLER
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 4000,
            child: Column(
              children: [
                _buildHeader(),
                const Divider(height: 1),

                /// scroll dọc
                Expanded(
                  child: Scrollbar(
                    controller: _verticalCtrl,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _verticalCtrl,
                      itemCount: reports.length,
                      itemBuilder: (_, i) => _buildRow(reports[i]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 46,
      color: Colors.grey.shade200,
      child: Row(
        children: [
          _HCell('STT', 50),
          _HCell('Type', 80),
          _HCell('Group', 90),
          _HCell('Plant', 70),
          _HCell('Division', 90),
          _HCell('Area', 90),
          _HCell('Machine', 100),

          _HCell('Risk F', 80),
          _HCell('Risk P', 80),
          _HCell('Risk S', 80),
          _HCell('Risk T', 90),

          _HCell('Comment', 260),
          _HCell('Countermeasure', 260),
          _HCell('Check Info', 180),

          _HCell('Created', 100),
          _HCell('Due', 100),
          _HCell('PIC', 90),

          _HCell('Img(B)', 90),

          _HCell('AT Stt', 90),
          _HCell('AT PIC', 90),
          _HCell('AT Date', 100),
          _HCell('AT Cmt', 260),
          _HCell('Img(A)', 100),

          _HCell('HSE J', 90),
          _HCell('HSE D', 100),
          _HCell('HSE C', 260),
          _HCell('Img(H)', 100),

          _HCell('Load', 100),
        ],
      ),
    );
  }

  Widget _buildRow(PatrolReportModel e) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          _cell(e.stt.toString(), 50),
          _cell(e.type ?? '-', 80),
          _cell(e.grp, 90),
          _cell(e.plant, 70),
          _cell(e.division, 90),
          _cell(e.area, 90),
          _cell(e.machine, 100),

          _cellClickable(context, e.riskFreq, 80, 'Risk Frequency'),

          _cell(e.riskProb, 80),
          _cell(e.riskSev, 80),
          _badgeRisk(e.riskTotal),

          _cell(e.comment, 260),
          _cell(e.countermeasure, 260),
          _cell(e.checkInfo, 180),

          _cell(fmtDate(e.createdAt), 100),
          _cell(fmtDate(e.dueDate), 100),
          _cell(e.pic ?? '-', 90),

          _cell('${e.imageNames.length}', 90),

          _badgeStatus(e.atStatus),
          _cell(e.atPic ?? '-', 90),
          _cell(fmtDate(e.atDate), 100),
          _cell(e.atComment ?? '-', 260),
          _cell('${e.atImageNames.length}', 100),

          _cell(e.hseJudge ?? '-', 90),
          _cell(fmtDate(e.hseDate), 100),
          _cell(e.hseComment ?? '-', 260),
          _cell('${e.hseImageNames.length}', 100),

          _cell(e.loadStatus ?? '-', 100),
        ],
      ),
    );
  }

  Widget _cellClickable(
    BuildContext context,
    String text,
    double w,
    String title,
  ) {
    final value = text.isEmpty ? '-' : text;

    return SizedBox(
      width: w,
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(child: SelectableText(value)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  Widget _cell(String text, double w) {
    final value = text.isEmpty ? '-' : text;

    return SizedBox(
      width: w,
      child: Tooltip(
        message: value,
        waitDuration: const Duration(milliseconds: 400),
        textStyle: const TextStyle(fontSize: 13, color: Colors.white70),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color c, double w) {
    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _badgeRisk(String risk) {
    Color c = Colors.green;
    if (risk.contains('HIGH')) c = Colors.red;
    if (risk.contains('MEDIUM')) c = Colors.orange;
    return _badge(risk, c, 90);
  }

  Widget _badgeStatus(String? stt) {
    if (stt == null || stt.isEmpty) {
      return _badge('Pending', Colors.grey, 90);
    }
    return _badge(
      stt == 'COMPLETED' ? 'Done' : stt,
      stt == 'COMPLETED' ? Colors.green : Colors.orange,
      90,
    );
  }

  // ===================== STATES =====================
  Widget _buildError(String msg) {
    return Center(
      child: Text(msg, style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _buildEmpty() {
    return const Center(child: Text('No data'));
  }
}

// ===================== UTIL =====================
String fmtDate(DateTime? d) {
  if (d == null) return '-';
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _HCell extends StatelessWidget {
  final String text;
  final double width;
  const _HCell(this.text, this.width);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }
}
