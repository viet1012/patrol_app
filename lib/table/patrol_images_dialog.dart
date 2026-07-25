import 'dart:ui';

import 'package:flutter/material.dart';

import '../api/api_config.dart';
import '../common/common_ui_helper.dart';
import '../model/patrol_report_model.dart';

class _PatrolDialogTheme {
  static const Color background = Color(0xFF07111F);
  static const Color surface = Color(0xB31A2A40);
  static const Color surfaceAlt = Color(0x8F21344E);
  static const Color surfaceSoft = Color(0x732A405C);

  static const Color primary = Color(0xFF93E4FF);
  static const Color primaryStrong = Color(0xFF38BDF8);
  static const Color text = Color(0xFFF8FAFC);
  static const Color subText = Color(0xFFA9B8CA);

  static const Color border = Color(0x5C9CC8E7);
  static const Color borderSoft = Color(0x3D9CC8E7);

  static const LinearGradient dialogGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xE6122034), Color(0xE80C1828), Color(0xE5162940)],
  );

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x2EFFFFFF), Color(0x14FFFFFF), Color(0x0A8ECDF5)],
  );

  static const LinearGradient imageGlassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x382A405C), Color(0x20172A42), Color(0x301D3651)],
  );

  static BoxShadow get shadow => BoxShadow(
    color: Colors.black.withOpacity(.34),
    blurRadius: 30,
    offset: const Offset(0, 18),
  );

  static BoxShadow get glassShadow => BoxShadow(
    color: Colors.black.withOpacity(.18),
    blurRadius: 18,
    offset: const Offset(0, 9),
  );
}

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
      barrierColor: Colors.black.withOpacity(.72),
      builder: (_) => _PatrolImagesDialogView(
        title: title,
        e: e,
        names: names,
        baseUrl: ApiConfig.baseUrl,
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
      insetPadding: const EdgeInsets.all(4),
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: size.width * 0.985,
            height: size.height * 0.985,
            decoration: BoxDecoration(
              gradient: _PatrolDialogTheme.dialogGradient,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(.14)),
              boxShadow: [_PatrolDialogTheme.shadow],
            ),
            child: Column(
              children: [
                // ===== Top bar =====
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    gradient: _PatrolDialogTheme.glassGradient,
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(.07)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _PatrolDialogTheme.primary.withOpacity(.10),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: _PatrolDialogTheme.primary.withOpacity(.24),
                          ),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: _PatrolDialogTheme.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: _PatrolDialogTheme.text,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '${names.length} images',
                              style: const TextStyle(
                                color: _PatrolDialogTheme.subText,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(.045),
                          foregroundColor: Colors.white70,
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),

                // ===== Images area (ít ?nh thì phóng to l?p full) =====
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
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
                                  const SizedBox(width: 4),
                              ],
                            ],
                          )
                        : GridView.builder(
                            shrinkWrap: false,
                            primary: false,
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: names.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  crossAxisSpacing: 4,
                                  mainAxisSpacing: 4,
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

                // ===== Info panel =====
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            gradient: _PatrolDialogTheme.glassGradient,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _PatrolDialogTheme.border,
                            ),
                            boxShadow: [_PatrolDialogTheme.glassShadow],
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
                                    Divider(
                                      height: 10,
                                      color: Colors.white.withOpacity(.07),
                                    ),
                                    _InfoRow2(
                                      'Created',
                                      CommonUI.fmtDate(e.createdAt),
                                    ),
                                    _InfoRow2(
                                      'Due',
                                      CommonUI.fmtDate(e.dueDate),
                                    ),
                                    _InfoRow2('Check Info', e.checkInfo),
                                    _InfoRow2('Risk F', e.riskFreq),
                                    _InfoRow2('Risk P', e.riskProb),
                                    _InfoRow2('Risk S', e.riskSev),
                                    Divider(
                                      height: 10,
                                      color: Colors.white.withOpacity(.07),
                                    ),
                                    _RiskTotalCard(e.riskTotal),
                                    Divider(
                                      height: 10,
                                      color: Colors.white.withOpacity(.07),
                                    ),
                                    _InfoBlock('Comment', e.comment),
                                    const SizedBox(height: 4),
                                    _InfoBlock(
                                      'Countermeasure',
                                      e.countermeasure,
                                    ),
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
                                        _InfoRow2(
                                          'Due',
                                          CommonUI.fmtDate(e.dueDate),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _InfoBlock('Comment', e.comment),
                                        const SizedBox(height: 4),
                                        _InfoBlock(
                                          'Countermeasure',
                                          e.countermeasure,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    flex: 1,
                                    child: _RiskTotalCard(e.riskTotal),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
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
}

class _ImageTile extends StatelessWidget {
  final String name;
  final String baseUrl;
  final PatrolReportModel e;
  final String title;
  final int index;
  final int total;

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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
            borderRadius: BorderRadius.circular(14),
            color: Colors.transparent,
            border: Border.all(color: Colors.white.withOpacity(.12)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  url,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                ),

                Positioned(
                  left: 6,
                  top: 6,
                  child: _ImageIndexBadge(index: index, total: total),
                ),

                const Positioned(right: 6, top: 6, child: _ImageExpandBadge()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageIndexBadge extends StatelessWidget {
  final int index;
  final int total;

  const _ImageIndexBadge({required this.index, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xB31A2A40),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.18)),
      ),
      child: Text(
        '${index + 1}/$total',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ImageExpandBadge extends StatelessWidget {
  const _ImageExpandBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xB31A2A40),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withOpacity(.18)),
      ),
      child: const Icon(
        Icons.open_in_full_rounded,
        size: 15,
        color: Colors.white,
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
      barrierColor: Colors.black.withOpacity(.78),
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(4),
        backgroundColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                gradient: _PatrolDialogTheme.dialogGradient,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(.14)),
                boxShadow: [_PatrolDialogTheme.shadow],
              ),
              width: MediaQuery.of(context).size.width * 0.992,
              height: MediaQuery.of(context).size.height * 0.985,
              child: Column(
                children: [
                  // ===== Top bar =====
                  Container(
                    height: 48,
                    // padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.025),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(.07),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.image_outlined,
                          color: _PatrolDialogTheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            '$title • Image ${index + 1}/$total',
                            style: const TextStyle(
                              color: _PatrolDialogTheme.text,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(.045),
                            foregroundColor: Colors.white70,
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),

                  // ===== Body =====
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final isWide = c.maxWidth >= 1100;

                        Widget imageView = Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            gradient: _PatrolDialogTheme.imageGlassGradient,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(.16),
                            ),
                            boxShadow: [_PatrolDialogTheme.glassShadow],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Center(
                              child: InteractiveViewer(
                                minScale: 0.5,
                                maxScale: 8,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        'Cannot load image\n$imageUrl',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.red,
                                        ),
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
                            ),
                          ),
                        );

                        Widget leftInfo = _InfoPanelLeft(e: e);
                        Widget rightInfo = _InfoPanelRight(e: e);

                        if (!isWide) {
                          return Column(
                            children: [
                              Expanded(flex: 6, child: imageView),
                              Divider(
                                height: 1,
                                color: Colors.white.withOpacity(.07),
                              ),
                              Expanded(
                                flex: 4,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(3),
                                  child: Column(
                                    children: [
                                      leftInfo,
                                      const SizedBox(height: 4),
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
                              width: 285,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(3),
                                child: leftInfo,
                              ),
                            ),
                            VerticalDivider(
                              width: 1,
                              color: Colors.white.withOpacity(.07),
                            ),

                            // IMAGE
                            Expanded(child: imageView),

                            VerticalDivider(
                              width: 1,
                              color: Colors.white.withOpacity(.07),
                            ),

                            // RIGHT
                            SizedBox(
                              width: 340,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(3),
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
          Divider(height: 10, color: Colors.white.withOpacity(.07)),
          _InfoRow2('Created', CommonUI.fmtDate(e.createdAt)),
          _InfoRow2('Due', CommonUI.fmtDate(e.dueDate)),
          _InfoRow2('Check Info', e.checkInfo),
          Divider(height: 10, color: Colors.white.withOpacity(.07)),
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
        const SizedBox(height: 8),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoBlock('Comment', e.comment),
              const SizedBox(height: 4),
              _InfoBlock('Countermeasure', e.countermeasure),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _panel({required Widget child}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: _PatrolDialogTheme.glassGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _PatrolDialogTheme.borderSoft),
          boxShadow: [_PatrolDialogTheme.glassShadow],
        ),
        child: child,
      ),
    ),
  );
}

class _RiskTotalCard extends StatelessWidget {
  final String risk;

  const _RiskTotalCard(this.risk);

  @override
  Widget build(BuildContext context) {
    final r = risk.trim().toUpperCase();

    final Color mainColor = CommonUI.riskColor(r);

    final Color bg = mainColor.withOpacity(.10);
    final Color border = mainColor.withOpacity(.72);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            mainColor.withOpacity(.16),
            const Color(0x44243B56),
            const Color(0x26172A42),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: mainColor.withOpacity(.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
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
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            r.isEmpty ? '-' : r,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: mainColor,
              fontSize: 35,
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(.06)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              k.toUpperCase(),
              style: TextStyle(
                fontSize: 16,
                color: _PatrolDialogTheme.subText,
                fontWeight: FontWeight.w800,
                letterSpacing: .35,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _PatrolDialogTheme.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
          style: const TextStyle(
            fontSize: 18,
            color: _PatrolDialogTheme.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: _PatrolDialogTheme.glassGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _PatrolDialogTheme.borderSoft),
          ),
          child: SelectableText(
            value,
            style: const TextStyle(
              color: _PatrolDialogTheme.text,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
