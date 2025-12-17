import 'package:flutter/material.dart';

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  // ===== Selected values =====
  String? selectedFac;
  String? selectedArea;
  String? selectedMachine;

  // ===== Mock data =====
  final List<String> facList = ['Fac A', 'Fac B'];

  final Map<String, List<String>> areaMap = {
    'Fac A': ['Rough', 'Finish'],
    'Fac B': ['Assembly'],
  };

  final Map<String, List<String>> machineMap = {
    'Rough': ['A-111', 'A-112'],
    'Finish': ['F-201'],
    'Assembly': ['B-301'],
  };

  // ===== Mock report data =====
  Map<String, String> reportData = {};

  void _loadReport() {
    reportData = {
      'no': '7',
      'patrolBy': 'Group 6',
      'time': '12/11/2025 14:30',
      'content': 'Dây điện bị rối',
      'action': 'Đi lại dây điện gọn gàng',
      'user': 'Việt',
      'comment': 'Đã đi lại dây điện',
    };
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết báo cáo'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSelectionBox(),
            const SizedBox(height: 16),

            if (selectedFac != null &&
                selectedArea != null &&
                selectedMachine != null)
              _buildReportTable()
            else
              const Text(
                'Vui lòng chọn đầy đủ Xưởng / Khu vực / Mã máy',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  // ================= SELECT BOX =================
  Widget _buildSelectionBox() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Xưởng'),
          value: selectedFac,
          items: facList
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            setState(() {
              selectedFac = v;
              selectedArea = null;
              selectedMachine = null;
            });
          },
        ),
        const SizedBox(height: 8),

        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Khu vực'),
          value: selectedArea,
          items: (areaMap[selectedFac] ?? [])
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: selectedFac == null
              ? null
              : (v) {
                  setState(() {
                    selectedArea = v;
                    selectedMachine = null;
                  });
                },
        ),
        const SizedBox(height: 8),

        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Mã máy'),
          value: selectedMachine,
          items: (machineMap[selectedArea] ?? [])
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: selectedArea == null
              ? null
              : (v) {
                  setState(() {
                    selectedMachine = v;
                    _loadReport();
                  });
                },
        ),
      ],
    );
  }

  // ================= REPORT TABLE (2 COLUMNS) =================
  Widget _buildReportTable() {
    return Table(
      border: TableBorder.all(color: Colors.black, width: 1.2),
      columnWidths: const {0: FlexColumnWidth(1.5), 1: FlexColumnWidth(3)},
      children: [
        _buildRow('No', reportData['no']!),
        _buildRow('Patrol by', reportData['patrolBy']!),
        _buildRow('Thời gian', reportData['time']!),
        _buildRow('Nội dung', reportData['content']!),
        _buildRow('Đối sách', reportData['action']!),

        // ===== Picture Before =====
        TableRow(
          children: [
            _cellText('Picture (Before)', bold: true, center: true),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImagePlaceholder('1'),
                  _buildImagePlaceholder('2'),
                ],
              ),
            ),
          ],
        ),

        // ===== Picture After =====
        TableRow(
          decoration: BoxDecoration(color: Colors.yellow.shade100),
          children: [
            _cellText('Picture (After)', bold: true, center: true),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Center(child: _buildLargeImagePlaceholder()),
            ),
          ],
        ),

        _buildRow(
          'Người thực hiện',
          reportData['user']!,
          background: Colors.yellow.shade100,
        ),
        _buildRow(
          'Comment',
          reportData['comment']!,
          background: Colors.yellow.shade100,
        ),
      ],
    );
  }

  // ================= TABLE HELPERS =================
  TableRow _buildRow(String label, String value, {Color? background}) {
    return TableRow(
      decoration: BoxDecoration(color: background),
      children: [_cellText(label, bold: true), _cellText(value)],
    );
  }

  Widget _cellText(String text, {bool bold = false, bool center = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  // ================= IMAGE PLACEHOLDERS =================
  Widget _buildImagePlaceholder(String number) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          number,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildLargeImagePlaceholder() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

// ================= MAIN =================
void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ReportDetailScreen(),
    ),
  );
}
