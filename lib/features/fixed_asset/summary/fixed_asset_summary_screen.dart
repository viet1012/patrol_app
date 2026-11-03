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
  static const double _mobileWidth = 600;

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
        final mobile = width < _mobileWidth;
        final side = mobile ? 16.0 : 24.0;
        return _buildList(overview, width - side * 2, side, mobile);
      },
    );
  }

  /// [width]: bề rộng nội dung (đã trừ padding). [mobile]: màn < 600 px.
  Widget _buildList(
    FixedAssetSummaryOverview overview,
    double width,
    double side,
    bool mobile,
  ) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(side, 12, side, 24),
      children: [
        mobile ? _buildMobileGrid(overview) : _buildGrid(overview, width),
        const SizedBox(height: 10),
        _buildPicProgress(overview, width, mobile),
      ],
    );
  }

  /// "Tiến độ theo PIC · Quý q/yyyy" (mobile: bỏ tên quý, dạng list): từ
  /// picRows (bỏ dòng tổng) + planPct của /summary.
  Widget _buildPicProgress(
    FixedAssetSummaryOverview o,
    double width,
    bool mobile,
  ) {
    final byEmail = {for (final p in _pics ?? const []) p.email: p};
    return FixedAssetPicProgressTable(
      title: mobile
          ? FixedAssetSummaryStrings.picProgressTitleShort
          : FixedAssetSummaryStrings.picProgressTitle(_period.label),
      rows: [for (final r in o.picRows) if (!r.isTotal) r],
      planPct: o.planPct,
      period: _period,
      today: o.today,
      wide: width >= _desktopWidth,
      compact: mobile,
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

  /// Số ngày từ [today] đến [end], gồm cả hôm nay (ngày dương lịch).
  static int _daysLeft(DateTime today, DateTime end) =>
      DateTime.utc(end.year, end.month, end.day)
          .difference(DateTime.utc(today.year, today.month, today.day))
          .inDays +
      1;

  /// Máy đã kiểm trong tháng thứ [index] của quý: dòng tổng picRows, không
  /// có thì cộng các dòng PIC; backend chưa trả số tháng -> null.
  int? _monthAudited(FixedAssetSummaryOverview o, int index) {
    final month = _period.monthOf(index);
    int? of(FixedAssetSummaryPicRow r) {
      for (final m in r.months) {
        if (m.month == month) return m.audited;
      }
      final byOrder = r.months.length >= index ? r.months[index - 1] : null;
      return byOrder?.month == null ? byOrder?.audited : null;
    }

    for (final r in o.picRows) {
      if (r.isTotal) return of(r);
    }
    int? sum;
    for (final r in o.picRows) {
      final value = of(r);
      if (value != null) sum = (sum ?? 0) + value;
    }
    return sum;
  }

  /// KPI mobile (< 600 px): Tiến độ quý full width (chip dưới cột chữ) ·
  /// Mục tiêu tháng | Còn lại cả quý (dòng phụ tối đa 2 dòng) · hàng gọn
  /// "n máy chờ thay QR".
  Widget _buildMobileGrid(FixedAssetSummaryOverview o) {
    final index = _period.monthIndexOf(o.today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _quarterTile(o, inQuarter: index > 0, mobile: true),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _monthTile(o, index, wrap: true)),
              const SizedBox(width: 8),
              Expanded(
                child: _remainingTile(o, inQuarter: index > 0, wrap: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _pendingQrRow(o),
      ],
    );
  }

  /// Hàng gọn mobile: icon QR + "n máy chờ thay QR" + chevron; bấm mở danh
  /// sách Thay QR.
  Widget _pendingQrRow(FixedAssetSummaryOverview o) {
    final color = o.pendingQr > 0
        ? FixedAssetSummaryColors.orange
        : FixedAssetSummaryColors.green;
    return FixedAssetSummaryCard(
      onTap: _openReplace,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.qr_code_2_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '${o.pendingQr}',
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
                children: const [
                  TextSpan(
                    text: FixedAssetSummaryStrings.pendingQrSuffix,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: Colors.white38,
          ),
        ],
      ),
    );
  }

  /// 4 ô KPI: Tiến độ quý · Mục tiêu tháng · Còn lại cả quý · Chờ thay QR.
  /// ≥ 900 px: 1 hàng 4 ô; nhỏ hơn: lưới 2×2. Quý không chứa hôm nay: bỏ
  /// kế hoạch / chip, mục tiêu tháng "—", bỏ dòng máy/ngày.
  Widget _buildGrid(FixedAssetSummaryOverview o, double width) {
    final index = _period.monthIndexOf(o.today);
    final tiles = [
      _quarterTile(o, inQuarter: index > 0),
      _monthTile(o, index),
      _remainingTile(o, inQuarter: index > 0),
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

  /// Ô "Tiến độ quý": donut 2 lớp (kế hoạch mờ + đã kiểm accent), "a / t máy",
  /// kế hoạch đến hôm nay, chip Chậm / Vượt / Đúng tiến độ (|chênh| ≤ 1%).
  /// Ngoài quý: chỉ lớp đã kiểm, bỏ kế hoạch và chip. [mobile]: ô full width,
  /// chip dưới cùng cột chữ thay vì cạnh tiêu đề.
  Widget _quarterTile(
    FixedAssetSummaryOverview o, {
    required bool inQuarter,
    bool mobile = false,
  }) {
    Widget? chip;
    if (inQuarter) {
      final (text, color) = o.diff.abs() <= 1
          ? (FixedAssetSummaryStrings.onSchedule, FixedAssetSummaryColors.muted)
          : o.behindMachines > 0
          ? (
              FixedAssetSummaryStrings.behindChip(o.behindMachines),
              FixedAssetSummaryColors.behind,
            )
          : (
              FixedAssetSummaryStrings.aheadChip(o.aheadMachines),
              FixedAssetSummaryColors.green,
            );
      chip = FixedAssetSummaryChip(text: text, color: color);
    }
    // Donut 72 cao hơn nội dung ô chuẩn (~62) nên padding dọc 7 thay vì 12,
    // giữ chiều cao hàng (mobile: ô riêng một hàng, padding 12).
    return FixedAssetSummaryCard(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: mobile ? 12 : 7),
      child: Row(
        children: [
          FixedAssetPlanDonut(
            pct: o.pct,
            planPct: inQuarter ? o.planPct : null,
            tooltip: inQuarter ? FixedAssetSummaryStrings.donutTooltip : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _header(
                  FixedAssetSummaryStrings.quarterProgress,
                  trailing: mobile ? null : chip,
                ),
                const SizedBox(height: 2),
                _value(
                  '${o.audited}',
                  suffix: FixedAssetSummaryStrings.auditedOfSuffix(o.total),
                ),
                if (inQuarter)
                  _detail(
                    FixedAssetSummaryStrings.planToday(
                      o.planMachines,
                      o.planPct,
                    ),
                  ),
                if (mobile && chip != null) ...[
                  const SizedBox(height: 6),
                  chip,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Ô "Mục tiêu tháng": máy còn cần kiểm để đạt mục tiêu lũy kế cuối tháng
  /// thứ [index], ≈ máy/ngày đến hết tháng, thanh đã kiểm trong tháng / chỉ
  /// tiêu tháng. [index] = 0 (ngoài quý): "—". [wrap]: xem [_tile].
  Widget _monthTile(
    FixedAssetSummaryOverview o,
    int index, {
    bool wrap = false,
  }) {
    const icon = Icons.flag_rounded;
    if (index == 0) {
      return _tile(
        icon: icon,
        label: FixedAssetSummaryStrings.monthTarget(null),
        value: FixedAssetSummaryStrings.noValue,
        wrap: wrap,
      );
    }
    final end = _period.monthEnd(index);
    final target = o.monthTargetMachines(index);
    final need = target > o.audited ? target - o.audited : 0;
    final days = _daysLeft(o.today, end);
    final quota = target - o.monthTargetMachines(index - 1);
    final done = _monthAudited(o, index);
    return _tile(
      icon: icon,
      label: FixedAssetSummaryStrings.monthTarget(_period.monthOf(index)),
      value: '$need',
      suffix: FixedAssetSummaryStrings.monthNeedSuffix(
        FixedAssetSummaryStrings.dayMonth(end),
      ),
      detail: need == 0
          ? FixedAssetSummaryStrings.monthReached
          : FixedAssetSummaryStrings.perDay((need / days).ceil(), days),
      progress: done == null || quota <= 0 ? null : done / quota,
      wrap: wrap,
    );
  }

  /// Ô "Còn lại cả quý": máy chưa kiểm, ≈ máy/ngày đến cuối quý (ngoài quý
  /// bỏ dòng này). [wrap]: xem [_tile].
  Widget _remainingTile(
    FixedAssetSummaryOverview o, {
    required bool inQuarter,
    bool wrap = false,
  }) {
    final end = _period.monthEnd(3);
    final days = _daysLeft(o.today, end);
    return _tile(
      icon: Icons.pending_actions_rounded,
      label: FixedAssetSummaryStrings.quarterRemaining,
      value: '${o.remaining}',
      suffix: FixedAssetSummaryStrings.unauditedSuffix,
      detail: inQuarter
          ? FixedAssetSummaryStrings.perDayUntil(
              (o.remaining / days).ceil(),
              FixedAssetSummaryStrings.dayMonth(end),
              days,
            )
          : null,
      wrap: wrap,
    );
  }

  static final _labelStyle = TextStyle(
    color: Colors.white.withValues(alpha: .7),
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  /// Tiêu đề ô: [icon] (tùy chọn) + nhãn một dòng + [trailing].
  static Widget _header(String label, {IconData? icon, Widget? trailing}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: Colors.white.withValues(alpha: .6)),
          const SizedBox(width: 5),
        ],
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _labelStyle,
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 6), trailing],
      ],
    );
  }

  /// Số lớn 23 px + [suffix] nhỏ muted cùng dòng ([maxLines] 2: suffix được
  /// xuống dòng).
  static Widget _value(
    String value, {
    String? suffix,
    Color color = Colors.white,
    int maxLines = 1,
  }) {
    return Text.rich(
      TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: 23,
          fontWeight: FontWeight.w900,
          height: 1.15,
        ),
        children: [
          if (suffix != null)
            TextSpan(
              text: suffix,
              style: const TextStyle(
                color: FixedAssetSummaryColors.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Dòng phụ 12 px muted. [wrap]: tối đa 2 dòng, không ellipsis.
  static Widget _detail(String text, {bool wrap = false}) => Text(
    text,
    maxLines: wrap ? 2 : 1,
    overflow: wrap ? TextOverflow.clip : TextOverflow.ellipsis,
    style: const TextStyle(color: FixedAssetSummaryColors.muted, fontSize: 12),
  );

  /// Ô chuẩn ~84 px: padding 12, tiêu đề một dòng, số 23 px (+ [suffix]),
  /// dòng phụ 12 px. [progress] (0–1): thanh 3 px lấy chỗ từ padding dưới nên
  /// chiều cao ô không đổi. [wrap] (mobile, ô hẹp): số + suffix và dòng phụ
  /// được xuống tối đa 2 dòng.
  Widget _tile({
    required IconData icon,
    required String label,
    required String value,
    String? suffix,
    String? detail,
    Color color = Colors.white,
    double? progress,
    VoidCallback? onTap,
    bool wrap = false,
  }) {
    return FixedAssetSummaryCard(
      onTap: onTap,
      padding: progress == null
          ? const EdgeInsets.all(12)
          : const EdgeInsets.fromLTRB(12, 12, 12, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(
            label,
            icon: icon,
            trailing: onTap == null
                ? null
                : const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Colors.white38,
                  ),
          ),
          const SizedBox(height: 2),
          _value(
            value,
            suffix: suffix,
            color: color,
            maxLines: wrap ? 2 : 1,
          ),
          if (detail != null) _detail(detail, wrap: wrap),
          if (progress != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: .10),
                color: FixedAssetSummaryColors.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
