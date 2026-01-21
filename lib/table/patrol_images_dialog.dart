import 'package:chuphinh/table/patrol_report_table.dart';
import 'package:flutter/material.dart';

import '../api/api_config.dart';
import '../common/common_ui_helper.dart';
import '../model/patrol_report_model.dart';

class PatrolImagesDialog {
  static void show({
    required BuildContext context,
    required String title,
    required PatrolReportModel e,
    required List<String> names,
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
        baseUrl: ApiConfig.imgUrl,
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
      child: Container(
        width: size.width * 0.96,
        height: size.height * 0.96,
        color: Colors.black,

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
                                e: e,
                                title: title,
                                index: i,
                                total: names.length,
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
                        itemBuilder: (_, i) => _ImageTile(
                          name: names[i],
                          baseUrl: baseUrl,
                          e: e,
                          title: title,
                          index: i,
                          total: names.length,
                        ),
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
                  padding: const EdgeInsets.all(8),
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
                            flex: 2,
                            child: Column(
                              children: [
                                _InfoRow2('QR Code', e.qr_key ?? '-'),
                                _InfoRow2('Group', e.grp),
                                _InfoRow2('Plant', e.plant),
                                _InfoRow2('Division', e.division),
                                _InfoRow2('Area', e.area),
                                _InfoRow2('Machine', e.machine),
                                _InfoRow2('PIC', e.pic ?? '-'),
                                _InfoRow2('Due', CommonUI.fmtDate(e.dueDate)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            flex: 5,
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
                          Expanded(flex: 1, child: _RiskTotalCard(e.riskTotal)),
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
  final PatrolReportModel e; // ✅ thêm
  final String title; // ✅ thêm
  final int index; // ✅ thêm
  final int total; // ✅ thêm

  const _ImageTile({
    required this.name,
    required this.baseUrl,
    required this.e,
    required this.title,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final url = '$baseUrl/images/$name';

    return InkWell(
      onTap: () => FullImageDialog.show(
        context: context,
        imageUrl: url,
        e: e,
        title: title,
        index: index,
        total: total,
      ),
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
  static void show({
    required BuildContext context,
    required String imageUrl,
    required PatrolReportModel e,
    required String title,
    required int index,
    required int total,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(10),
        clipBehavior: Clip.antiAlias,
        child: Container(
          color: Colors.black,
          width: MediaQuery.of(context).size.width * 0.98,
          height: MediaQuery.of(context).size.height * 0.96,
          child: Column(
            children: [
              // ===== Top bar =====
              Container(
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                color: Colors.grey.shade50,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$title • Image ${index + 1}/$total',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
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

              // ===== Body =====
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final isWide = c.maxWidth >= 1100;

                    Widget imageView = Container(
                      color: Colors.black,
                      child: Center(
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
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                          ),
                        ),
                      ),
                    );

                    Widget leftInfo = _InfoPanelLeft(e: e);
                    Widget rightInfo = _InfoPanelRight(e: e);

                    if (!isWide) {
                      return Column(
                        children: [
                          Expanded(flex: 6, child: imageView),
                          const Divider(height: 1),
                          Expanded(
                            flex: 4,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  leftInfo,
                                  const SizedBox(height: 12),
                                  rightInfo,
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        // LEFT
                        SizedBox(
                          width: 320,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: leftInfo,
                          ),
                        ),
                        const VerticalDivider(width: 1),

                        // IMAGE
                        Expanded(child: imageView),

                        const VerticalDivider(width: 1),

                        // RIGHT
                        SizedBox(
                          width: 380,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: rightInfo,
                          ),
                        ),
                      ],
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

/// ===== Left panel: info nhanh =====
class _InfoPanelLeft extends StatelessWidget {
  final PatrolReportModel e;
  const _InfoPanelLeft({required this.e});

  @override
  Widget build(BuildContext context) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow2('QR Code', e.qr_key ?? '-'),
          _InfoRow2('Group', e.grp),
          _InfoRow2('Plant', e.plant),
          _InfoRow2('Division', e.division),
          _InfoRow2('Area', e.area),
          _InfoRow2('Machine', e.machine),
          _InfoRow2('Patrol User', e.patrol_user ?? '-'),
          _InfoRow2('PIC', e.pic ?? '-'),
          const Divider(height: 22),
          _InfoRow2('Created', CommonUI.fmtDate(e.createdAt)),
          _InfoRow2('Due', CommonUI.fmtDate(e.dueDate)),
          _InfoRow2('Check Info', e.checkInfo),
          const Divider(height: 22),
          _InfoRow2('Risk F', e.riskFreq),
          _InfoRow2('Risk P', e.riskProb),
          _InfoRow2('Risk S', e.riskSev),
        ],
      ),
    );
  }
}

/// ===== Right panel: risk + comment =====
class _InfoPanelRight extends StatelessWidget {
  final PatrolReportModel e;
  const _InfoPanelRight({required this.e});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _panel(child: _RiskTotalCard(e.riskTotal)),
        const SizedBox(height: 18),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoBlock('Comment', e.comment),
              const SizedBox(height: 12),
              _InfoBlock('Countermeasure', e.countermeasure),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _panel({required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: child,
  );
}

class _RiskTotalCard extends StatelessWidget {
  final String risk;
  const _RiskTotalCard(this.risk);

  @override
  Widget build(BuildContext context) {
    final r = risk.trim().toUpperCase();

    final Color mainColor = CommonUI.riskColor(r);

    // background nhẹ theo màu risk
    final Color bg = mainColor.withOpacity(0.08);
    final Color border = mainColor.withOpacity(0.9);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 2),
        boxShadow: [
          BoxShadow(
            color: mainColor.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'RISK LEVEL',
            style: TextStyle(
              color: mainColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            r.isEmpty ? '-' : r,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: mainColor,
              fontSize: 32,
              fontWeight: FontWeight.bold,
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

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.4))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              k.toUpperCase(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
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
            fontSize: 16,
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.brown.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: SelectableText(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
