import 'package:flutter/material.dart';

import 'package:chuphinh/core/api/fixed_asset_backend.dart';
import 'package:chuphinh/core/models/fixed_asset_pic.dart';
import 'package:chuphinh/core/models/fixed_asset_summary.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_audit_flow.dart'
    show fixedAssetErrorText;
import 'package:chuphinh/features/fixed_asset/summary/fixed_asset_summary_nav.dart';
import 'package:chuphinh/features/fixed_asset/summary/fixed_asset_summary_pic_screen.dart';
import 'package:chuphinh/features/fixed_asset/summary/fixed_asset_summary_strings.dart';
import 'package:chuphinh/features/fixed_asset/summary/widgets/fixed_asset_summary_widgets.dart';
import 'package:chuphinh/shared/widgets/glass_action_button.dart';

/// Màn B – "4) Tổng quan": tổng quan kỳ (quý). Lưới 2×2 chỉ số, tiến độ theo
/// PIC (thanh ngang theo tháng), danh sách mọi PIC ("Theo PIC").
class FixedAssetSummaryScreen extends StatefulWidget {
  final FixedAssetSummaryNav nav;
  final FixedAssetBackend api;

  const FixedAssetSummaryScreen({
    super.key,
    required this.nav,
    this.api = const FixedAssetBackend(),
  });

  @override
  State<FixedAssetSummaryScreen> createState() =>
      _FixedAssetSummaryScreenState();
}

class _FixedAssetSummaryScreenState extends State<FixedAssetSummaryScreen> {
  FixedAssetPeriod _period = FixedAssetPeriod.of(DateTime.now());

  FixedAssetSummaryOverview? _overview;
  List<FixedAssetSummaryPic>? _pics;
  bool _loading = true;
  String? _error;
  int _req = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Tổng quan + danh sách PIC song song. [silent]: giữ số cũ khi tải lại.
  Future<void> _load({bool silent = false}) async {
    final req = ++_req;
    final period = _period;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        widget.api.fetchSummary(period: period.key),
        widget.api.fetchSummaryPics(period: period.key),
      ]);
      if (!mounted || req != _req) return;
      final raw = results[0] as FixedAssetSummaryOverview;
      // Kế hoạch theo tháng của backend; thiếu planPct thì FE tính dự phòng.
      final overview = raw.hasPlanPct
          ? raw
          : raw.withPlanPct(period.planPctAt(raw.today));
      setState(() {
        _overview = overview;
        // /summary/pics không có planPct: dùng kế hoạch chung của kỳ.
        _pics = [
          for (final p in results[1] as List<FixedAssetSummaryPic>)
            p.withPlanPct(overview.planPct),
        ];
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || req != _req) return;
      setState(() {
        _loading = false;
        if (!silent || _overview == null) _error = fixedAssetErrorText(error);
      });
    }
  }

  void _setPeriod(FixedAssetPeriod? period) {
    if (period == null || period == _period) return;
    setState(() {
      _period = period;
      _overview = null;
      _pics = null;
    });
    _load();
  }

  /// Quý cho dropdown: theo backend nếu có, không thì quý hiện tại + 3 quý
  /// trước. Luôn gồm quý đang chọn. Mới nhất trước.
  List<FixedAssetPeriod> get _periods {
    final fromApi = _overview?.periods ?? const <FixedAssetPeriod>[];
    final set = <FixedAssetPeriod>{...fromApi, _period};
    if (fromApi.isEmpty) {
      var p = FixedAssetPeriod.of(DateTime.now());
      for (var i = 0; i < 4; i++) {
        set.add(p);
        p = p.previous;
      }
    }
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  static const double _desktopWidth = 900;

  void _openPic(FixedAssetSummaryPic pic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FixedAssetSummaryPicScreen(
          nav: widget.nav,
          period: _period,
          pic: pic,
          api: widget.api,
        ),
      ),
    ).then((_) {
      if (mounted) _load(silent: true);
    });
  }

  void _openReplace() {
    widget.nav.openReplace(context).then((_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final overview = _overview;
    return Scaffold(
      backgroundColor: FixedAssetSummaryColors.appBar,
      appBar: AppBar(
        backgroundColor: FixedAssetSummaryColors.appBar,
        centerTitle: false,
        titleSpacing: 4,
        leading: GlassActionButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              FixedAssetSummaryStrings.overviewTitle,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              FixedAssetSummaryStrings.periodMonth(
                _period.label,
                _period.monthIndexOf(overview?.today ?? DateTime.now()),
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          _buildPeriodDropdown(),
          IconButton(
            tooltip: FixedAssetSummaryStrings.refresh,
            onPressed: _loading ? null : () => _load(silent: overview != null),
            color: Colors.white,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        decoration: FixedAssetSummaryColors.background,
        child: RefreshIndicator(
          color: FixedAssetSummaryColors.accent,
          onRefresh: () => _load(silent: true),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildPeriodDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<FixedAssetPeriod>(
        value: _period,
        dropdownColor: FixedAssetSummaryColors.surface,
        iconEnabledColor: Colors.white70,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
        items: [
          for (final p in _periods)
            DropdownMenuItem(value: p, child: Text(p.label)),
        ],
        onChanged: _loading ? null : _setPeriod,
      ),
    );
  }

  Widget _buildBody() {
    final overview = _overview;
    if (overview == null && _loading) {
      return const Center(
        child: CircularProgressIndicator(color: FixedAssetSummaryColors.accent),
      );
    }
    if (overview == null) {
      return FixedAssetSummaryMessage(
        icon: Icons.cloud_off_rounded,
        color: Colors.redAccent,
        text: FixedAssetSummaryStrings.loadFailed,
        detail: _error,
        onRetry: () => _load(),
      );
    }

    // Full chiều ngang; padding 24 px (desktop) / 16 px (mobile).
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final side = width >= 600 ? 24.0 : 16.0;
        return _buildList(overview, width - side * 2, side);
      },
    );
  }

  /// [width]: bề rộng nội dung (đã trừ padding).
  Widget _buildList(
    FixedAssetSummaryOverview overview,
    double width,
    double side,
  ) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(side, 12, side, 24),
      children: [
        _buildGrid(overview, width),
        const SizedBox(height: 10),
        _buildPicProgress(overview, width),
      ],
    );
  }

  /// "Tiến độ theo PIC · Quý q/yyyy": bảng 1 cột từ picRows (bỏ dòng tổng)
  /// + planPct của /summary.
  Widget _buildPicProgress(FixedAssetSummaryOverview o, double width) {
    final byEmail = {for (final p in _pics ?? const []) p.email: p};
    return FixedAssetPicProgressTable(
      title: FixedAssetSummaryStrings.picProgressTitle(_period.label),
      rows: [for (final r in o.picRows) if (!r.isTotal) r],
      planPct: o.planPct,
      period: _period,
      today: o.today,
      wide: width >= _desktopWidth,
      nameOf: (r) => r.pic == null
          ? FixedAssetSummaryStrings.picProgressUnassigned
          : (byEmail[r.pic]?.name ?? FixedAssetPic.nameOf(r.pic!)),
      onOpen: (r) => _openPic(
        byEmail[r.pic] ??
            FixedAssetSummaryPic(
              email: r.pic!,
              name: FixedAssetPic.nameOf(r.pic!),
              total: r.total,
              audited: r.audited,
              remaining: (r.total - r.audited).clamp(0, r.total),
              pct: r.pct,
              planPct: o.planPct,
              status: FixedAssetPaceStatus.unknown,
              pendingQr: 0,
              zoneCount: 0,
            ),
      ),
    );
  }

  /// Máy còn cần kiểm trong tháng hiện tại: max(0, mục tiêu cuối tháng −
  /// đã kiểm). Ngoài quý: theo mục tiêu cuối quý (trước quý: tháng 1).
  int _monthNeed(FixedAssetSummaryOverview o) {
    final index = _period.monthIndexOf(o.today);
    final target = o.monthTargetMachines(
      index > 0 ? index : (o.today.isBefore(_period.monthStart(1)) ? 1 : 3),
    );
    return target > o.audited ? target - o.audited : 0;
  }

  /// 4 ô KPI: Đã kiểm kê · Kế hoạch đến hôm nay · Còn lại · Chờ thay QR.
  /// ≥ 900 px: 1 hàng 4 ô; nhỏ hơn: lưới 2×2.
  Widget _buildGrid(FixedAssetSummaryOverview o, double width) {
    final behind = o.behindMachines;
    final paceColor = behind > 0
        ? FixedAssetSummaryColors.orange
        : FixedAssetSummaryColors.green;
    final tiles = [
      _tile(
        icon: Icons.task_alt_rounded,
        label: FixedAssetSummaryStrings.audited,
        value: FixedAssetSummaryStrings.percent(o.pct),
        detail: FixedAssetSummaryStrings.auditedOf(o.audited, o.total),
        color: FixedAssetSummaryColors.accent,
      ),
      _tile(
        icon: Icons.trending_up_rounded,
        label: FixedAssetSummaryStrings.planTodayTitle,
        value: FixedAssetSummaryStrings.machines(o.planMachines),
        detail: FixedAssetSummaryStrings.pace(behind, o.aheadMachines),
        color: Colors.white,
        detailColor: paceColor,
      ),
      _tile(
        icon: Icons.pending_actions_rounded,
        label: FixedAssetSummaryStrings.remaining,
        value: '${o.remaining}',
        detail: FixedAssetSummaryStrings.monthNeed(_monthNeed(o)),
        color: Colors.white,
      ),
      _tile(
        icon: Icons.qr_code_2_rounded,
        label: FixedAssetSummaryStrings.pendingQr,
        value: '${o.pendingQr}',
        detail: FixedAssetSummaryStrings.pendingQrHint,
        color: o.pendingQr > 0
            ? FixedAssetSummaryColors.orange
            : FixedAssetSummaryColors.green,
        onTap: _openReplace,
      ),
    ];
    Widget row(List<Widget> items) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: items[i]),
          ],
        ],
      ),
    );
    if (width >= _desktopWidth) return row(tiles);
    return Column(
      children: [
        row(tiles.sublist(0, 2)),
        const SizedBox(height: 8),
        row(tiles.sublist(2)),
      ],
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    required String value,
    required String detail,
    required Color color,
    Color? detailColor,
    VoidCallback? onTap,
  }) {
    // Gọn ~84 px: padding 12, icon + nhãn một dòng, số 23 px, dòng phụ 12 px.
    return FixedAssetSummaryCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: Colors.white.withValues(alpha: .6)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .7),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.white38,
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: detailColor ?? Colors.white.withValues(alpha: .55),
              fontSize: 12,
              fontWeight: detailColor == null ? null : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
