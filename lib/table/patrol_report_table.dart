import 'package:flutter/material.dart';
import '../api/api_config.dart';
import '../api/patrol_report_api.dart';
import '../model/patrol_report_model.dart';

class PatrolReportTable extends StatefulWidget {
  const PatrolReportTable({super.key});

  @override
  State<PatrolReportTable> createState() => _PatrolReportTableState();
}

class _PatrolReportTableState extends State<PatrolReportTable> {
  late Future<List<PatrolReportModel>> _futureReports;

  final ScrollController _hCtrl = ScrollController();
  final ScrollController _vCtrl = ScrollController();

  // UI state
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  int _rowsPerPage = 30;
  int _page = 0;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _futureReports = PatrolReportApi.fetchReports();
    _searchCtrl.addListener(() {
      setState(() {
        _query = _searchCtrl.text.trim().toLowerCase();
        _page = 0;
      });
    });
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _vCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = Colors.grey.shade100;

    return Scaffold(
      backgroundColor: bg,
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

            final all = snapshot.data ?? [];
            if (all.isEmpty) return _buildEmpty();

            final filtered = _applyFilter(all, _query);

            final totalPages = (filtered.length / _rowsPerPage).ceil().clamp(
              1,
              999999,
            );
            _page = _page.clamp(0, totalPages - 1);

            final start = _page * _rowsPerPage;
            final end = (start + _rowsPerPage).clamp(0, filtered.length);
            final pageItems = filtered.sublist(start, end);

            return Column(
              children: [
                _buildTopBar(total: all.length, shown: filtered.length),
                Expanded(child: _buildTable(context, pageItems)),
                _buildPager(
                  totalItems: filtered.length,
                  totalPages: totalPages,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===================== FILTER =====================
  List<PatrolReportModel> _applyFilter(List<PatrolReportModel> src, String q) {
    if (q.isEmpty) return src;

    bool hit(PatrolReportModel e) {
      // Bạn có thể mở rộng thêm field cần search
      final hay = [
        e.stt.toString(),
        e.type ?? '',
        e.grp,
        e.plant,
        e.division,
        e.area,
        e.machine,
        e.comment,
        e.countermeasure,
        e.checkInfo,
        e.pic ?? '',
        e.atPic ?? '',
        e.atStatus ?? '',
        e.atComment ?? '',
        e.hseJudge ?? '',
        e.hseComment ?? '',
        e.loadStatus ?? '',
      ].join(' ').toLowerCase();

      return hay.contains(q);
    }

    return src.where(hit).toList();
  }

  // ===================== TOP BAR =====================
  Widget _buildTopBar({required int total, required int shown}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search (stt, type, group, comment, PIC...)',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _chip('$shown / $total'),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  // ===================== TABLE =====================
  Widget _buildTable(BuildContext context, List<PatrolReportModel> reports) {
    // Tính tổng width từ danh sách cột (không hardcode 4000)
    final totalWidth = _cols.fold<double>(0, (s, c) => s + c.w);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: _hCtrl,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _hCtrl,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: Column(
              children: [
                // sticky header: luôn ở trên, chỉ body cuộn dọc
                _buildHeader(),
                const Divider(height: 1, thickness: 1),
                Expanded(
                  child: Scrollbar(
                    controller: _vCtrl,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _vCtrl,
                      itemCount: reports.length,
                      itemBuilder: (_, i) => _buildRow(reports[i], i),
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
      height: 44,
      color: Colors.grey.shade200,
      child: Row(
        children: _cols.map((c) {
          return _HCell(c.label, c.w, align: c.align);
        }).toList(),
      ),
    );
  }

  Widget _buildRow(PatrolReportModel e, int index) {
    final isSelected = _selectedIndex == index;
    final base = index.isEven ? Colors.white : Colors.grey.shade50;
    final bg = isSelected ? Colors.lightBlue.shade50 : base;

    return _HoverableRow(
      height: 46,
      background: bg,
      onTap: () => setState(() => _selectedIndex = index),
      child: Row(
        children: [
          // === GIỮ NGUYÊN TẤT CẢ CỘT ===
          _cell(e.stt.toString(), _w('STT'), align: TextAlign.center),
          _cell(e.type ?? '-', _w('Type'), tooltip: true),
          _cell(e.grp, _w('Group'), tooltip: true),
          _cell(e.plant, _w('Plant'), tooltip: true),
          _cell(e.division, _w('Division'), tooltip: true),
          _cell(e.area, _w('Area'), tooltip: true),
          _cell(e.machine, _w('Machine'), tooltip: true),

          _cell(e.riskFreq, _w('Risk F'), align: TextAlign.center),
          _cell(e.riskProb, _w('Risk P'), align: TextAlign.center),
          _cell(e.riskSev, _w('Risk S'), align: TextAlign.center),
          _badgeRisk(e.riskTotal, _w('Risk T')),

          _cell(e.comment, _w('Comment'), tooltip: true),
          _cell(e.countermeasure, _w('Countermeasure'), tooltip: true),
          _cell(e.checkInfo, _w('Check Info'), tooltip: true),

          _cell(fmtDate(e.createdAt), _w('Created'), align: TextAlign.center),
          _cell(fmtDate(e.dueDate), _w('Due'), align: TextAlign.center),
          _cell(e.pic ?? '-', _w('PIC'), tooltip: true),

          _imgCell(
            names: e.imageNames,
            width: _w('Img(B)'),
            onTap: () => _showImagesDialog('Before images', e.imageNames),
          ),

          _badgeStatus(e.atStatus, _w('AT Stt')),
          _cell(e.atPic ?? '-', _w('AT PIC'), tooltip: true),
          _cell(fmtDate(e.atDate), _w('AT Date'), align: TextAlign.center),
          _cell(e.atComment ?? '-', _w('AT Cmt'), tooltip: true),
          _imgCell(
            names: e.atImageNames,
            width: _w('Img(A)'),
            onTap: () => _showImagesDialog('After images', e.atImageNames),
          ),

          _cell(e.hseJudge ?? '-', _w('HSE J'), align: TextAlign.center),
          _cell(fmtDate(e.hseDate), _w('HSE D'), align: TextAlign.center),
          _cell(e.hseComment ?? '-', _w('HSE C'), tooltip: true),
          _imgCell(
            names: e.hseImageNames,
            width: _w('Img(H)'),
            onTap: () => _showImagesDialog('HSE images', e.hseImageNames),
          ),

          _cell(e.loadStatus ?? '-', _w('Load'), align: TextAlign.center),
        ],
      ),
    );
  }

  // ===================== CELLS =====================
  Widget _cell(
    String text,
    double w, {
    TextAlign align = TextAlign.left,
    bool tooltip = false,
  }) {
    final value = text.trim().isEmpty ? '-' : text.trim();

    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
        textAlign: align,
      ),
    );

    return _boxed(
      width: w,
      align: align,
      child: tooltip
          ? Tooltip(
              message: value,
              waitDuration: const Duration(milliseconds: 350),
              child: child,
            )
          : child,
    );
  }

  Widget _imageThumb(String imageName, {double size = 40}) {
    if (imageName.isEmpty) {
      return const Icon(
        Icons.image_not_supported,
        size: 20,
        color: Colors.grey,
      );
    }

    final url = '${ApiConfig.baseUrl}/images/$imageName';

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.red),
        loadingBuilder: (c, w, p) {
          if (p == null) return w;
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        },
      ),
    );
  }

  Widget _imgCell({
    required List<String> names,
    required double width,
    VoidCallback? onTap,
  }) {
    final count = names.length;
    final first = count > 0 ? names.first : '';

    return _boxed(
      width: width,
      align: TextAlign.center,
      child: InkWell(
        onTap: (count > 0) ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // thumbnail
              if (count > 0)
                _imageThumb(first, size: 32)
              else
                const Icon(
                  Icons.image_not_supported,
                  size: 18,
                  color: Colors.grey,
                ),
              const SizedBox(width: 6),
              // count
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: count > 0 ? Colors.blueGrey.shade800 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badgeRisk(String risk, double w) {
    final r = risk.toUpperCase();
    Color c = Colors.green.shade700;
    if (r.contains('HIGH')) c = Colors.red.shade700;
    if (r.contains('MEDIUM')) c = Colors.orange.shade800;

    return _boxed(
      width: w,
      align: TextAlign.center,
      child: Text(
        risk,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c),
      ),
    );
  }

  Widget _badgeStatus(String? stt, double w) {
    final text = (stt == null || stt.isEmpty)
        ? 'Pending'
        : (stt == 'COMPLETED' ? 'Done' : stt);
    final c = (stt == 'COMPLETED')
        ? Colors.green
        : ((stt == null || stt.isEmpty) ? Colors.grey : Colors.orange);

    return _boxed(
      width: w,
      align: TextAlign.center,
      child: Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c),
      ),
    );
  }

  Widget _boxed({
    required double width,
    required TextAlign align,
    required Widget child,
  }) {
    return Container(
      width: width,
      alignment: align == TextAlign.center
          ? Alignment.center
          : Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: child,
    );
  }

  // ===================== DIALOG (placeholder) =====================
  void _showImagesDialog(String title, List<String> names) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 700,
          child: names.isEmpty
              ? const Text('No images')
              : GridView.builder(
                  shrinkWrap: true,
                  itemCount: names.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (_, i) {
                    final name = names[i];
                    final url = '${ApiConfig.baseUrl}/images/$name';
                    print("url: $url");
                    return InkWell(
                      onTap: () => _showSingleImage(url, name),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSingleImage(String url, String name) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== PAGER =====================
  Widget _buildPager({required int totalItems, required int totalPages}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          Text(
            'Rows: $totalItems',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const Spacer(),
          Text(
            'Page ${_page + 1} / $totalPages',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _page == 0 ? null : () => setState(() => _page--),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            onPressed: (_page + 1 >= totalPages)
                ? null
                : () => setState(() => _page++),
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 10),
          DropdownButton<int>(
            value: _rowsPerPage,
            items: const [15, 30, 50, 100]
                .map(
                  (e) => DropdownMenuItem(value: e, child: Text('$e / page')),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _rowsPerPage = v;
                _page = 0;
              });
            },
          ),
        ],
      ),
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

  // ===================== COLUMN DEFINITIONS =====================
  // GIỮ nguyên cột, chỉ gom lại để dễ quản lý width/alignment.
  late final List<_Col> _cols = [
    _Col('STT', 50, TextAlign.center),
    _Col('Type', 60, TextAlign.left),
    _Col('Group', 80, TextAlign.left),
    _Col('Plant', 60, TextAlign.left),
    _Col('Division', 60, TextAlign.left),
    _Col('Area', 90, TextAlign.left),
    _Col('Machine', 90, TextAlign.left),

    _Col('Risk F', 100, TextAlign.center),
    _Col('Risk P', 100, TextAlign.center),
    _Col('Risk S', 100, TextAlign.center),
    _Col('Risk T', 60, TextAlign.center),

    _Col('Comment', 260, TextAlign.left),
    _Col('Countermeasure', 260, TextAlign.left),
    _Col('Check Info', 120, TextAlign.left),

    _Col('Created', 100, TextAlign.center),
    _Col('Due', 100, TextAlign.center),
    _Col('PIC', 90, TextAlign.left),

    _Col('Img(B)', 90, TextAlign.center),

    _Col('AT Stt', 70, TextAlign.center),
    _Col('AT PIC', 90, TextAlign.left),
    _Col('AT Date', 100, TextAlign.center),
    _Col('AT Cmt', 260, TextAlign.left),
    _Col('Img(A)', 100, TextAlign.center),

    _Col('HSE J', 90, TextAlign.center),
    _Col('HSE D', 100, TextAlign.center),
    _Col('HSE C', 260, TextAlign.left),
    _Col('Img(H)', 100, TextAlign.center),

    _Col('Load', 100, TextAlign.center),
  ];

  double _w(String label) => _cols.firstWhere((c) => c.label == label).w;
}

// ===================== UTIL =====================
String fmtDate(DateTime? d) {
  if (d == null) return '-';
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _Col {
  final String label;
  final double w;
  final TextAlign align;
  const _Col(this.label, this.w, this.align);
}

class _HCell extends StatelessWidget {
  final String text;
  final double width;
  final TextAlign align;
  const _HCell(this.text, this.width, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      alignment: align == TextAlign.center
          ? Alignment.center
          : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

// Hover row (web/desktop friendly)
class _HoverableRow extends StatefulWidget {
  final double height;
  final Color background;
  final Widget child;
  final VoidCallback? onTap;

  const _HoverableRow({
    required this.height,
    required this.background,
    required this.child,
    this.onTap,
  });

  @override
  State<_HoverableRow> createState() => _HoverableRowState();
}

class _HoverableRowState extends State<_HoverableRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hover ? Colors.blueGrey.withOpacity(0.06) : widget.background;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(height: widget.height, color: bg, child: widget.child),
      ),
    );
  }
}
