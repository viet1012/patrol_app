import 'package:chuphinh/table/patrol_report_table.dart';
import 'package:flutter/material.dart';

import '../common/common_ui_helper.dart';
import '../model/patrol_report_model.dart';

class PatrolImagesDialog {
  static void show({
    required BuildContext context,
    required String title,
    required PatrolReportModel e,
    required List<String> names,
    required String baseUrl, // ApiConfig.baseUrl
    String emptyText = 'No images',
  }) {
    if (names.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(content: Text(emptyText)),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _PatrolImagesDialogView(
        title: title,
        e: e,
        names: names,
        baseUrl: baseUrl,
      ),
    );
  }
}

class _PatrolImagesDialogView extends StatelessWidget {
  final String title;
  final PatrolReportModel e;
  final List<String> names;
  final String baseUrl;

  const _PatrolImagesDialogView({
    required this.title,
    required this.e,
    required this.names,
    required this.baseUrl,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final cols = size.width >= 1400
        ? 3
        : size.width >= 980
        ? 2
        : 1;

    return Dialog(
      insetPadding: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size.width * 0.96,
        height: size.height * 0.96,
        child: Column(
          children: [
            // ===== Top bar =====
            Container(
              padding: const EdgeInsets.fromLTRB(14, 5, 5, 5),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$title • ${names.length} images',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ===== Images area (ít ảnh thì phóng to lấp full) =====
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: (names.length <= cols)
                    ? Row(
                        children: [
                          for (int i = 0; i < names.length; i++) ...[
                            Expanded(
                              child: _ImageTile(
                                name: names[i],
                                baseUrl: baseUrl,
                              ),
                            ),
                            if (i != names.length - 1)
                              const SizedBox(width: 10),
                          ],
                        ],
                      )
                    : GridView.builder(
                        shrinkWrap: false,
                        primary: false,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: names.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: cols == 1 ? 16 / 10 : 4 / 3,
                        ),
                        itemBuilder: (_, i) =>
                            _ImageTile(name: names[i], baseUrl: baseUrl),
                      ),
              ),
            ),

            const Divider(height: 1),

            // ===== Info panel =====
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final isWide = c.maxWidth >= 900;

                      if (!isWide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InfoRow2('QR Code', e.qr_key ?? '-'),
                            _InfoRow2('Group', e.grp),
                            _InfoRow2('Plant', e.plant),
                            _InfoRow2('Division', e.division),
                            _InfoRow2('Area', e.area),
                            _InfoRow2('Machine', e.machine),
                            _InfoRow2('PIC', e.pic ?? '-'),
                            const Divider(height: 22),
                            _InfoRow2('Created', CommonUI.fmtDate(e.createdAt)),
                            _InfoRow2('Due', CommonUI.fmtDate(e.dueDate)),
                            _InfoRow2('Check Info', e.checkInfo),
                            _InfoRow2('Risk F', e.riskFreq),
                            _InfoRow2('Risk P', e.riskProb),
                            _InfoRow2('Risk S', e.riskSev),
                            const Divider(height: 22),
                            _RiskTotalCard(e.riskTotal),
                            const Divider(height: 22),
                            _InfoBlock('Comment', e.comment),
                            const SizedBox(height: 12),
                            _InfoBlock('Countermeasure', e.countermeasure),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                _InfoRow2('QR Code', e.qr_key ?? '-'),
                                _InfoRow2('Group', e.grp),
                                _InfoRow2('Plant', e.plant),
                                _InfoRow2('Division', e.division),
                                _InfoRow2('Area', e.area),
                                _InfoRow2('Machine', e.machine),
                                _InfoRow2('PIC', e.pic ?? '-'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                _InfoRow2(
                                  'Created',
                                  CommonUI.fmtDate(e.createdAt),
                                ),
                                _InfoRow2('Due', CommonUI.fmtDate(e.dueDate)),
                                _InfoRow2('Check Info', e.checkInfo),
                                _InfoRow2('Risk F', e.riskFreq),
                                _InfoRow2('Risk P', e.riskProb),
                                _InfoRow2('Risk S', e.riskSev),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _InfoBlock('Comment', e.comment),
                                const SizedBox(height: 12),
                                _InfoBlock('Countermeasure', e.countermeasure),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(flex: 2, child: _RiskTotalCard(e.riskTotal)),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final String name;
  final String baseUrl;

  const _ImageTile({required this.name, required this.baseUrl});

  @override
  Widget build(BuildContext context) {
    final url = '$baseUrl/images/$name';

    return InkWell(
      onTap: () => FullImageDialog.show(context: context, imageUrl: url),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.black.withOpacity(0.03),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image, color: Colors.red),
                  ),
                  loadingBuilder: (_, w, p) {
                    if (p == null) return w;
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              ),
              const Positioned(
                right: 10,
                top: 10,
                child: Icon(Icons.open_in_full, size: 18, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FullImageDialog {
  static void show({required BuildContext context, required String imageUrl}) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.92,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
                color: Colors.grey.shade50,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Container(
                  color: Colors.black.withOpacity(0.03),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 8,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          'Cannot load image\n$imageUrl',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      loadingBuilder: (_, w, p) {
                        if (p == null) return w;
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
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

class _RiskTotalCard extends StatelessWidget {
  final String risk;
  const _RiskTotalCard(this.risk);

  @override
  Widget build(BuildContext context) {
    final r = risk.toUpperCase();

    Color bg = Colors.green.shade50;
    Color c = Colors.green.shade700;

    if (r.contains('HIGH')) {
      bg = Colors.red.shade50;
      c = Colors.red.shade700;
    } else if (r.contains('MEDIUM')) {
      bg = Colors.orange.shade50;
      c = Colors.orange.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c, width: 2),
        boxShadow: [
          BoxShadow(
            color: c.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'RISK TOTAL',
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            risk,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow2 extends StatelessWidget {
  final String k;
  final String v;

  const _InfoRow2(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    final value = v.trim().isEmpty ? '-' : v.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              k,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String k;
  final String v;

  const _InfoBlock(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    final value = v.trim().isEmpty ? '-' : v.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          k,
          style: TextStyle(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: SelectableText(value),
        ),
      ],
    );
  }
}
