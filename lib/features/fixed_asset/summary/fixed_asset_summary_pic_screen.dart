import 'dart:async';

import 'package:flutter/material.dart';

import 'package:chuphinh/core/api/fixed_asset_backend.dart';
import 'package:chuphinh/core/models/fixed_asset_summary.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_audit_flow.dart'
    show fixedAssetErrorText;
import 'package:chuphinh/features/fixed_asset/fixed_asset_location.dart';
import 'package:chuphinh/features/fixed_asset/summary/fixed_asset_summary_nav.dart';
import 'package:chuphinh/features/fixed_asset/summary/fixed_asset_summary_strings.dart';
import 'package:chuphinh/features/fixed_asset/summary/widgets/fixed_asset_pic_machine_table.dart';
import 'package:chuphinh/features/fixed_asset/summary/widgets/fixed_asset_summary_widgets.dart';
import 'package:chuphinh/shared/widgets/glass_action_button.dart';

/// Màn C – Chi tiết PIC trong kỳ (chỉ xem): tiến độ so với kế hoạch theo số
/// máy; tab "Theo khu" (bảng gom theo Fac + Tầng, bấm khu xem bảng máy của
/// khu) và "Danh sách máy" (toàn bộ máy PIC).
class FixedAssetSummaryPicScreen extends StatefulWidget {
  final FixedAssetSummaryNav nav;
  final FixedAssetPeriod period;

  /// Số liệu từ màn trước: hiện ngay trong lúc tải chi tiết.
  final FixedAssetSummaryPic pic;
  final FixedAssetBackend api;

  const FixedAssetSummaryPicScreen({
    super.key,
    required this.nav,
    required this.period,
    required this.pic,
    this.api = const FixedAssetBackend(),
  });

  @override
  State<FixedAssetSummaryPicScreen> createState() =>
      _FixedAssetSummaryPicScreenState();
}

class _FixedAssetSummaryPicScreenState
    extends State<FixedAssetSummaryPicScreen> {
  /// Từ bề rộng này bấm khu mở panel phải; nhỏ hơn mở màn riêng.
  static const double _panelWidth = 900;

  FixedAssetSummaryPicDetail? _detail;
  bool _loading = true;
  String? _error;
  int _req = 0;

  /// Khu đang mở ở panel phải (màn rộng).
  FixedAssetSummaryZone? _panelZone;

  final GlobalKey<FixedAssetPicMachinesViewState> _machinesKey =
      GlobalKey<FixedAssetPicMachinesViewState>();
  final GlobalKey<FixedAssetPicMachinesViewState> _panelKey =
      GlobalKey<FixedAssetPicMachinesViewState>();

  /// pic-machines tải trước song song pic-detail; tab "Danh sách máy" dùng
  /// kết quả này ở lần dựng đầu.
  Future<List<FixedAssetPicMachine>>? _machinesPrefetch;

  /// Header chỉ dựng lại khi [_detail] đổi (đổi tab / panel / search không
  /// đụng tới).
  Object? _headerFor;
  Widget? _header;

  @override
  void initState() {
    super.initState();
    _prefetchMachines();
    _load();
  }

  void _prefetchMachines() {
    // ignore(): lỗi để tab tự hiện khi mở; không thành lỗi chưa xử lý.
    _machinesPrefetch = widget.api.fetchSummaryPicMachines(
      pic: widget.pic.email,
      period: widget.period.key,
    )..ignore();
  }

  /// [silent]: kéo xuống tải lại: giữ số cũ tới khi có mới.
  Future<void> _load({bool silent = false}) async {
    final req = ++_req;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final detail = await widget.api.fetchSummaryPicDetail(
        pic: widget.pic.email,
        period: widget.period.key,
      );
      if (!mounted || req != _req) return;
      setState(() {
        _detail = detail;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || req != _req) return;
      setState(() {
        _loading = false;
        if (!silent || _detail == null) _error = fixedAssetErrorText(error);
      });
    }
  }

  /// pic-detail + các bảng máy đang mở (tab "Danh sách máy", panel khu).
  Future<void> _refreshAll({bool silent = false}) {
    // Tab máy chưa mở: tải trước lại để lần mở đầu có số mới.
    if (_machinesKey.currentState == null) _prefetchMachines();
    return Future.wait([
      _load(silent: silent),
      if (_machinesKey.currentState != null)
        _machinesKey.currentState!.reload(silent: silent),
      if (_panelKey.currentState != null)
        _panelKey.currentState!.reload(silent: silent),
    ]);
  }

  static FixedAssetAuditLocation _locationOf(FixedAssetSummaryZone zone) =>
      FixedAssetAuditLocation(
        fac: zone.fac,
        floor: zone.floor,
        positionA: zone.positionA,
        positionAA: zone.positionAA,
      );

  /// Bấm khu: màn rộng mở panel phải, màn nhỏ mở màn riêng.
  void _openZone(FixedAssetSummaryZone zone) {
    if (MediaQuery.sizeOf(context).width >= _panelWidth) {
      setState(() => _panelZone = zone);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ZoneMachinesScreen(
          api: widget.api,
          pic: widget.pic.email,
          period: widget.period,
          zone: zone,
        ),
      ),
    );
  }

  /// Dưới bề rộng này: bỏ maxWidth, 4 ô số 2×2, thanh trên 2 hàng, ẩn cột
  /// Còn lại.
  static const double _narrowWidth = 700;
  static const double _maxWidth = 1600;

  /// Dưới bề rộng này: layout mobile (header 3 dòng, ô số dọc, list khu 2
  /// tầng, tab "Máy").
  static const double _mobileWidth = 600;

  /// Tab đang chọn: 0 = Theo khu, 1 = Danh sách máy.
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    // pic-detail không có planPct: giữ kế hoạch của màn trước.
    final pic = _detail?.pic.withPlanPct(widget.pic.planPct) ?? widget.pic;
    final panelZone = _panelZone;
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
            Text(
              pic.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              widget.period.label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: FixedAssetSummaryStrings.refresh,
            onPressed: _loading ? null : () => _refreshAll(),
            color: Colors.white,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < _narrowWidth;
          final mobile = constraints.maxWidth < _mobileWidth;
          final showPanel =
              panelZone != null && constraints.maxWidth >= _panelWidth;
          // Cùng một segmented cho 2 tab: mỗi tab đặt nó ở thanh trên của
          // mình (cạnh ô tìm / bộ lọc riêng của tab).
          final segmented = _PicTabSwitcher(
            index: _tab,
            expanded: narrow,
            onChanged: (i) => setState(() => _tab = i),
            tabs: [
              (
                Icons.grid_view_rounded,
                _detail == null
                    ? FixedAssetSummaryStrings.tabZones
                    : FixedAssetSummaryStrings.tabZonesCount(
                        _detail!.zones.length,
                      ),
              ),
              (
                Icons.view_list_rounded,
                mobile
                    ? FixedAssetSummaryStrings.tabMachinesShort(pic.total)
                    : FixedAssetSummaryStrings.tabMachines(pic.total),
              ),
            ],
          );
          final content = Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cachedHeader(pic, mobile),
                const SizedBox(height: 12),
                // Chỉ bảng cuộn bên trong card; card cao tới hết màn.
                Expanded(
                  child: _card(
                    child: IndexedStack(
                      index: _tab,
                      sizing: StackFit.expand,
                      children: [
                        _ZonesTab(
                          detail: _detail,
                          loading: _loading,
                          error: _error,
                          narrow: narrow,
                          mobile: mobile,
                          leading: segmented,
                          onRetry: () => _load(),
                          onRefresh: () => _refreshAll(silent: true),
                          onOpenZone: _openZone,
                        ),
                        FixedAssetPicMachinesView(
                          key: _machinesKey,
                          api: widget.api,
                          pic: widget.pic.email,
                          period: widget.period,
                          prefetch: _machinesPrefetch,
                          initialFilter: FixedAssetPicMachineFilter.unaudited,
                          showZoneFilter: true,
                          embedded: true,
                          leading: segmented,
                          onRefresh: () => _refreshAll(silent: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: FixedAssetSummaryColors.background,
                  child: narrow
                      ? content
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: _maxWidth,
                            ),
                            child: content,
                          ),
                        ),
                ),
              ),
              if (showPanel) ...[
                // Bấm vùng còn lại để đóng panel.
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _panelZone = null),
                    child: Container(
                      color: Colors.black.withValues(alpha: .5),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: constraints.maxWidth * .6,
                  child: _buildPanel(panelZone),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Card bo 12 (header / bảng).
  static Widget _card({required Widget child, EdgeInsetsGeometry? padding}) =>
      Container(
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: FixedAssetSummaryColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FixedAssetSummaryColors.border),
        ),
        child: child,
      );

  /// Widget header dùng lại nguyên instance khi [_detail] / [mobile] không
  /// đổi: Flutter bỏ qua rebuild khi setState vì tab / panel / khu.
  Widget _cachedHeader(FixedAssetSummaryPic pic, bool mobile) {
    final key = (_detail, mobile);
    if (_header == null || _headerFor != key) {
      _headerFor = key;
      _header = RepaintBoundary(
        child: mobile ? _buildMobileHeader(pic) : _buildHeader(pic),
      );
    }
    return _header!;
  }

  /// Header mobile: avatar + tên · email + "· n khu" · "{a}/{t} máy · {pct}%"
  /// lớn · timeline T10 · T11 · T12 (vạch hôm nay) · 3 ô số dọc.
  Widget _buildMobileHeader(FixedAssetSummaryPic pic) {
    const accent = FixedAssetSummaryColors.accent;
    const muted = FixedAssetSummaryColors.muted;
    final zones = _detail?.zones;
    final moved = zones?.fold<int>(0, (s, z) => s + (z.movedCount ?? 0));
    final stats = [
      _statVertical(
        FixedAssetSummaryStrings.statAudited,
        '${pic.audited}/${pic.total}',
        Colors.white,
      ),
      _statVertical(
        FixedAssetSummaryStrings.colMoved,
        moved == null ? '—' : '$moved',
        (moved ?? 0) > 0 ? FixedAssetSummaryColors.orange : Colors.white,
      ),
      _statVertical(
        FixedAssetSummaryStrings.statPendingQr,
        '${pic.pendingQr}',
        pic.pendingQr > 0 ? FixedAssetSummaryColors.orange : Colors.white,
      ),
    ];
    return _card(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FixedAssetPicAvatar(name: pic.name, color: accent, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pic.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                child: Text(
                  pic.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 12.5),
                ),
              ),
              if (zones != null)
                Text(
                  FixedAssetSummaryStrings.zoneCountDot(zones.length),
                  maxLines: 1,
                  style: const TextStyle(color: muted, fontSize: 12.5),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${pic.audited}',
                  style: const TextStyle(
                    color: accent,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: FixedAssetSummaryStrings.ofMachines(pic.total),
                  style: const TextStyle(
                    color: muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: FixedAssetSummaryStrings.percent(pic.pct),
                  style: const TextStyle(
                    color: accent,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 8),
          FixedAssetQuarterTimeline(
            pct: pic.pct,
            planPct: pic.planPct,
            period: widget.period,
            today: DateTime.now(),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: stats[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Ô số dọc (mobile): nhãn nhỏ muted trên (tối đa 2 dòng, không cắt), số
  /// lớn dưới.
  Widget _statVertical(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FixedAssetSummaryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            style: const TextStyle(
              color: FixedAssetSummaryColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Header (~120 px): avatar | tên · email · n khu | "{a}/{t} máy · {pct}%";
  /// thanh quý; 3 ô số chia đều 1 hàng.
  Widget _buildHeader(FixedAssetSummaryPic pic) {
    const accent = FixedAssetSummaryColors.accent;
    final muted = Colors.white.withValues(alpha: .55);
    final zones = _detail?.zones;
    final moved = zones?.fold<int>(0, (s, z) => s + (z.movedCount ?? 0));
    final stats = [
      _stat(
        FixedAssetSummaryStrings.statAudited,
        '${pic.audited}/${pic.total}',
        Colors.white,
      ),
      _stat(
        FixedAssetSummaryStrings.colMoved,
        moved == null ? '—' : '$moved',
        (moved ?? 0) > 0 ? FixedAssetSummaryColors.orange : Colors.white,
      ),
      _stat(
        FixedAssetSummaryStrings.statPendingQr,
        '${pic.pendingQr}',
        pic.pendingQr > 0 ? FixedAssetSummaryColors.orange : Colors.white,
      ),
    ];
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 36,
            child: Row(
              children: [
                FixedAssetPicAvatar(name: pic.name, color: accent, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: pic.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: FixedAssetSummaryStrings.picMeta(
                            pic.email,
                            zones?.length,
                          ),
                          style: TextStyle(color: muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${pic.audited}',
                        style: const TextStyle(
                          color: accent,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(
                        text:
                            '/${pic.total} '
                            '${FixedAssetSummaryStrings.machineUnit} · ',
                        style: TextStyle(
                          color: muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: FixedAssetSummaryStrings.percent(pic.pct),
                        style: const TextStyle(
                          color: accent,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FixedAssetQuarterProgressBar(
            pct: pic.pct,
            period: widget.period,
            today: DateTime.now(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: stats[i]),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Ô số cao 44: nhãn trái (12.5 px mờ), số phải (18 px đậm).
  Widget _stat(String label, String value, Color color) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FixedAssetSummaryColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .6),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // PANEL KHU (màn rộng)
  // ------------------------------------------------------------

  /// Nền panel một màu (không gradient) để vùng trống dưới bảng ít dòng
  /// cùng màu với panel; viền + shadow bên trái.
  Widget _buildPanel(FixedAssetSummaryZone zone) {
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: FixedAssetSummaryColors.appBar,
          border: Border(
            left: BorderSide(color: Colors.white.withValues(alpha: .14)),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(-6, 0),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
              child: Row(
                children: [
                  Expanded(child: _ZoneTitle(zone: zone)),
                  IconButton(
                    tooltip: FixedAssetSummaryStrings.close,
                    onPressed: () => setState(() => _panelZone = null),
                    color: Colors.white,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: FixedAssetSummaryColors.border),
            Expanded(
              child: FixedAssetPicMachinesView(
                key: _panelKey,
                api: widget.api,
                pic: widget.pic.email,
                period: widget.period,
                location: _locationOf(zone),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tên khu + "Fac · Tầng" (panel / màn khu).
class _ZoneTitle extends StatelessWidget {
  final FixedAssetSummaryZone zone;

  const _ZoneTitle({required this.zone});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${FixedAssetSummaryStrings.colZone} ${fixedAssetDash(zone.label)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '${fixedAssetDash(zone.fac)} · ${fixedAssetDash(zone.floor)}'
          ' — ${zone.audited}/${zone.total}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

/// Màn nhỏ: bảng máy của một khu (full màn).
class _ZoneMachinesScreen extends StatefulWidget {
  final FixedAssetBackend api;
  final String pic;
  final FixedAssetPeriod period;
  final FixedAssetSummaryZone zone;

  const _ZoneMachinesScreen({
    required this.api,
    required this.pic,
    required this.period,
    required this.zone,
  });

  @override
  State<_ZoneMachinesScreen> createState() => _ZoneMachinesScreenState();
}

class _ZoneMachinesScreenState extends State<_ZoneMachinesScreen> {
  final GlobalKey<FixedAssetPicMachinesViewState> _tableKey =
      GlobalKey<FixedAssetPicMachinesViewState>();

  @override
  Widget build(BuildContext context) {
    final zone = widget.zone;
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
        title: _ZoneTitle(zone: zone),
        actions: [
          IconButton(
            tooltip: FixedAssetSummaryStrings.refresh,
            onPressed: () => _tableKey.currentState?.reload(),
            color: Colors.white,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        decoration: FixedAssetSummaryColors.background,
        child: FixedAssetPicMachinesView(
          key: _tableKey,
          api: widget.api,
          pic: widget.pic,
          period: widget.period,
          location: _FixedAssetSummaryPicScreenState._locationOf(zone),
        ),
      ),
    );
  }
}

/// Tab "Theo khu" trong card bảng: thanh trên (segmented [leading] | tìm khu
/// + "Chỉ khu chưa xong"), header cột sticky, bảng khu gom theo Fac · Tầng.
/// State riêng (tìm, toggle, thu gọn nhóm) nên thao tác trong tab không dựng
/// lại header màn.
class _ZonesTab extends StatefulWidget {
  final FixedAssetSummaryPicDetail? detail;
  final bool loading;
  final String? error;

  /// < 700 px: thanh trên 2 hàng, ẩn cột Còn lại.
  final bool narrow;

  /// < 600 px: thanh trên 3 hàng (tab | tìm | toggle căn phải), list 2 tầng
  /// không header cột.
  final bool mobile;
  final Widget leading;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;
  final ValueChanged<FixedAssetSummaryZone> onOpenZone;

  const _ZonesTab({
    required this.detail,
    required this.loading,
    required this.error,
    required this.narrow,
    this.mobile = false,
    required this.leading,
    required this.onRetry,
    required this.onRefresh,
    required this.onOpenZone,
  });

  @override
  State<_ZonesTab> createState() => _ZonesTabState();
}

class _ZonesTabState extends State<_ZonesTab> {
  /// Nhóm Fac · Tầng đang thu gọn (mặc định mở hết).
  final Set<String> _collapsedGroups = {};

  /// Toggle "Chỉ khu chưa xong".
  bool _onlyUnfinished = false;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  Timer? _searchDebounce;

  static const double _rowHeight = 34;
  static const double _headerHeight = 30;
  static const double _side = 14;
  static const double _gap = 20;

  /// Dưới bề rộng này bảng khu cuộn ngang (đủ cho các cột cố định khi hẹp).
  static const double _minTableWidth = 640;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted && value != _query) setState(() => _query = value);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() => _query = '');
  }

  static bool _zoneDone(FixedAssetSummaryZone z) =>
      z.total > 0 && z.audited >= z.total;

  /// So sánh tự nhiên: A2-1 < A6-2 < A40-1 (đoạn số so theo giá trị).
  static int _naturalCompare(String a, String b) {
    final pattern = RegExp(r'\d+|\D+');
    final ta = pattern.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
    final tb = pattern.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
    for (var i = 0; i < ta.length && i < tb.length; i++) {
      final na = int.tryParse(ta[i]);
      final nb = int.tryParse(tb[i]);
      final c = na != null && nb != null
          ? na.compareTo(nb)
          : ta[i].compareTo(tb[i]);
      if (c != 0) return c;
    }
    return ta.length.compareTo(tb.length);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolbar(),
        Expanded(
          child: RefreshIndicator(
            color: FixedAssetSummaryColors.accent,
            // Bảng có thể nằm trong cuộn ngang: nhận cuộn dọc ở mọi độ sâu.
            notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
            onRefresh: widget.onRefresh,
            child: _body(),
          ),
        ),
      ],
    );
  }

  /// Thanh trên (padding 8×14, kẻ dưới). Hẹp: segmented full width, rồi
  /// tìm + toggle.
  Widget _toolbar() {
    final toggle = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          FixedAssetSummaryStrings.onlyUnfinishedZones,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .8),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(
          height: 32,
          child: FittedBox(
            child: Switch(
              value: _onlyUnfinished,
              activeThumbColor: FixedAssetSummaryColors.accent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) => setState(() => _onlyUnfinished = v),
            ),
          ),
        ),
      ],
    );
    final search = FixedAssetCompactSearchField(
      controller: _searchController,
      hint: FixedAssetSummaryStrings.searchZone,
      onChanged: _onSearchChanged,
      onClear: _clearSearch,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _side, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: FixedAssetSummaryColors.border),
        ),
      ),
      child: widget.mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                widget.leading,
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FixedAssetCompactSearchField(
                        controller: _searchController,
                        hint: FixedAssetSummaryStrings.searchZone,
                        onChanged: _onSearchChanged,
                        onClear: _clearSearch,
                        height: 40,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _unfinishedChip(),
                  ],
                ),
              ],
            )
          : widget.narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                widget.leading,
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 8),
                    toggle,
                  ],
                ),
              ],
            )
          : Row(
              children: [
                widget.leading,
                const Spacer(),
                SizedBox(width: 260, child: search),
                const SizedBox(width: 12),
                toggle,
              ],
            ),
    );
  }

  /// Mobile: nút lọc "Chưa xong" tự vẽ (không màu theme) cao 40, bo 8 như ô
  /// tìm, thay switch "Chỉ khu chưa xong". Tắt: nền trong suốt, viền như ô
  /// tìm, icon / chữ muted; bật: nền accent 0.15, viền + icon / chữ accent
  /// đậm.
  Widget _unfinishedChip() {
    const accent = FixedAssetSummaryColors.accent;
    final on = _onlyUnfinished;
    final color = on ? accent : FixedAssetSummaryColors.muted;
    final radius = BorderRadius.circular(8);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () => setState(() => _onlyUnfinished = !_onlyUnfinished),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: on ? accent.withValues(alpha: .15) : Colors.transparent,
            borderRadius: radius,
            // Tắt: cùng màu viền ô tìm (FixedAssetCompactSearchField).
            border: Border.all(
              color: on ? accent : accent.withValues(alpha: .35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_list_rounded, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                FixedAssetSummaryStrings.unfinishedChip,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 13.5,
                  fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final detail = widget.detail;
    if (detail == null && widget.loading) {
      return const FixedAssetSkeletonRows(rowHeight: _rowHeight);
    }
    if (detail == null) {
      return FixedAssetSummaryMessage(
        icon: Icons.cloud_off_rounded,
        color: Colors.redAccent,
        text: FixedAssetSummaryStrings.loadFailed,
        detail: widget.error,
        onRetry: widget.onRetry,
      );
    }
    if (detail.zones.isEmpty) {
      return const FixedAssetSummaryMessage(
        icon: Icons.map_outlined,
        color: Colors.white54,
        text: FixedAssetSummaryStrings.noZones,
      );
    }
    return _table(detail);
  }

  /// Bố cục cột: Khu 200 | Tiến độ (Expanded) | Đã kiểm 100 | % 70 |
  /// Còn lại 90 (ẩn khi hẹp) | Lệch vị trí 100; padding ngang 14, gap 20.
  Widget _cells({
    Widget zone = const SizedBox.shrink(),
    Widget bar = const SizedBox.shrink(),
    Widget audited = const SizedBox.shrink(),
    Widget pct = const SizedBox.shrink(),
    Widget remaining = const SizedBox.shrink(),
    Widget moved = const SizedBox.shrink(),
  }) {
    Widget cell(double width, Widget child, {bool end = true}) => SizedBox(
      width: width,
      child: Align(
        alignment: end ? Alignment.centerRight : Alignment.centerLeft,
        child: child,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _side),
      child: Row(
        children: [
          cell(200, zone, end: false),
          const SizedBox(width: _gap),
          Expanded(child: bar),
          const SizedBox(width: _gap),
          cell(100, audited),
          const SizedBox(width: _gap),
          cell(70, pct),
          if (!widget.narrow) ...[
            const SizedBox(width: _gap),
            cell(90, remaining),
          ],
          const SizedBox(width: _gap),
          cell(100, moved),
        ],
      ),
    );
  }

  Widget _table(FixedAssetSummaryPicDetail detail) {
    final query = _query.trim().toLowerCase();
    // Gom theo Fac + Tầng; nhóm sắp theo Fac rồi Tầng, khu theo tên tự nhiên.
    final groups = <String, List<FixedAssetSummaryZone>>{};
    for (final zone in detail.zones) {
      (groups['${zone.fac}\u0000${zone.floor}'] ??= []).add(zone);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        final ga = groups[a]!.first;
        final gb = groups[b]!.first;
        final byFac = _naturalCompare(ga.fac, gb.fac);
        return byFac != 0 ? byFac : _naturalCompare(ga.floor, gb.floor);
      });

    final rows = <Widget>[];
    for (final key in keys) {
      final all = groups[key]!
        ..sort((a, b) => _naturalCompare(a.label, b.label));
      final zones = [
        for (final z in all)
          if ((!_onlyUnfinished || !_zoneDone(z)) &&
              (query.isEmpty || z.label.toLowerCase().contains(query)))
            z,
      ];
      if (zones.isEmpty) continue;
      final mobile = widget.mobile;
      rows.add(mobile ? _mobileGroupRow(key, all) : _groupRow(key, all));
      if (!_collapsedGroups.contains(key)) {
        for (final zone in zones) {
          rows.add(mobile ? _mobileZoneRow(zone) : _zoneRow(zone));
        }
      }
    }

    // Mobile: không header cột, dòng cao theo nội dung, không cuộn ngang.
    if (widget.mobile) {
      return rows.isEmpty
          ? const FixedAssetSummaryMessage(
              icon: Icons.search_off_rounded,
              color: Colors.white54,
              text: FixedAssetSummaryStrings.noZoneMatch,
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 12),
              itemCount: rows.length,
              itemBuilder: (context, index) => rows[index],
            );
    }

    Text label(String text) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white.withValues(alpha: .55),
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    );
    final header = Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .12),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: .10)),
        ),
      ),
      child: _cells(
        zone: label(FixedAssetSummaryStrings.colZone),
        bar: label(FixedAssetSummaryStrings.colProgress),
        audited: label(FixedAssetSummaryStrings.statAudited),
        pct: label(FixedAssetSummaryStrings.colPercent),
        remaining: label(FixedAssetSummaryStrings.colRemaining),
        moved: label(FixedAssetSummaryStrings.colMoved),
      ),
    );

    // Header cột sticky; chỉ danh sách cuộn.
    Widget table(double width) => SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: rows.isEmpty
                ? const FixedAssetSummaryMessage(
                    icon: Icons.search_off_rounded,
                    color: Colors.white54,
                    text: FixedAssetSummaryStrings.noZoneMatch,
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 12),
                    itemExtent: _rowHeight,
                    itemCount: rows.length,
                    itemBuilder: (context, index) => rows[index],
                  ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth >= _minTableWidth
          ? table(constraints.maxWidth)
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: table(_minTableWidth),
            ),
    );
  }

  /// Dòng nhóm (34 px, nền tối hơn): "▾ {Fac} · {Tầng}" + "{n} khu"; thanh
  /// 5 px; tổng nhóm thẳng cột Đã kiểm / %. Bấm thu gọn / mở.
  Widget _groupRow(String key, List<FixedAssetSummaryZone> zones) {
    final total = zones.fold<int>(0, (s, z) => s + z.total);
    final audited = zones.fold<int>(0, (s, z) => s + z.audited);
    final pct = total <= 0 ? 0.0 : audited * 100 / total;
    final collapsed = _collapsedGroups.contains(key);
    const style = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w800,
    );
    return Material(
      color: Colors.black.withValues(alpha: .18),
      child: InkWell(
        onTap: () => setState(() {
          if (!_collapsedGroups.remove(key)) _collapsedGroups.add(key);
        }),
        child: _cells(
          zone: Row(
            children: [
              Icon(
                collapsed
                    ? Icons.arrow_right_rounded
                    : Icons.arrow_drop_down_rounded,
                size: 20,
                color: FixedAssetSummaryColors.accent,
              ),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: FixedAssetSummaryStrings.groupTitle(
                          fixedAssetDash(zones.first.fac),
                          fixedAssetDash(zones.first.floor),
                        ),
                        style: style,
                      ),
                      TextSpan(
                        text: '  ${FixedAssetSummaryStrings.zoneCount(zones.length)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .5),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          bar: FixedAssetPlanProgressBar(
            pct: pct,
            color: FixedAssetSummaryColors.accent,
            height: 5,
          ),
          audited: Text('$audited/$total', maxLines: 1, style: style),
          pct: Text(
            FixedAssetSummaryStrings.percent(pct),
            maxLines: 1,
            style: style.copyWith(color: FixedAssetSummaryColors.accent),
          ),
        ),
      ),
    );
  }

  /// Nội dung 2 tầng mobile: [title] | "a/t · pct%" (màu theo %); thanh
  /// full width + "Còn n" (+ chip "Lệch n").
  Widget _mobileTwoLines({
    required Widget title,
    required int audited,
    required int total,
    required double pct,
    required int remaining,
    required int moved,
    required double barHeight,
    required bool bold,
  }) {
    final pctColor = fixedAssetPctColor(pct);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 8),
            Text.rich(
              TextSpan(
                text: '$audited',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w800,
                ),
                children: [
                  TextSpan(
                    text: FixedAssetSummaryStrings.ofPct(total, pct),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(fontSize: 13.5),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: FixedAssetPlanProgressBar(
                pct: pct,
                color: pctColor == FixedAssetSummaryColors.muted
                    ? FixedAssetSummaryColors.accent
                    : pctColor,
                height: barHeight,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              FixedAssetSummaryStrings.remainingShort(remaining),
              style: TextStyle(
                color: pctColor == FixedAssetSummaryColors.green
                    ? FixedAssetSummaryColors.green
                    : FixedAssetSummaryColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (moved > 0) ...[
              const SizedBox(width: 6),
              FixedAssetSummaryChip(
                text: FixedAssetSummaryStrings.movedShort(moved),
                color: FixedAssetSummaryColors.orange,
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Dòng nhóm mobile: "▾ Fac · Tầng · n khu" | "a/t · pct%", thanh nhóm;
  /// nền tối hơn, bấm thu gọn / mở.
  Widget _mobileGroupRow(String key, List<FixedAssetSummaryZone> zones) {
    final total = zones.fold<int>(0, (s, z) => s + z.total);
    final audited = zones.fold<int>(0, (s, z) => s + z.audited);
    final moved = zones.fold<int>(0, (s, z) => s + (z.movedCount ?? 0));
    final pct = total <= 0 ? 0.0 : audited * 100 / total;
    final collapsed = _collapsedGroups.contains(key);
    return Material(
      color: Colors.black.withValues(alpha: .18),
      child: InkWell(
        onTap: () => setState(() {
          if (!_collapsedGroups.remove(key)) _collapsedGroups.add(key);
        }),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, _side, 8),
          child: _mobileTwoLines(
            title: Row(
              children: [
                Icon(
                  collapsed
                      ? Icons.arrow_right_rounded
                      : Icons.arrow_drop_down_rounded,
                  size: 20,
                  color: FixedAssetSummaryColors.accent,
                ),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: FixedAssetSummaryStrings.groupTitle(
                            fixedAssetDash(zones.first.fac),
                            fixedAssetDash(zones.first.floor),
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(
                          text: FixedAssetSummaryStrings.zoneCountDot(
                            zones.length,
                          ),
                          style: const TextStyle(
                            color: FixedAssetSummaryColors.muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            audited: audited,
            total: total,
            pct: pct,
            remaining: (total - audited).clamp(0, total),
            moved: moved,
            barHeight: 5,
            bold: true,
          ),
        ),
      ),
    );
  }

  /// Dòng khu mobile: tên (lùi theo nhóm) + check nếu xong | "a/t · pct%";
  /// thanh + "Còn n" (+ "Lệch n"). Bấm mở bảng máy của khu.
  Widget _mobileZoneRow(FixedAssetSummaryZone zone) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onOpenZone(zone),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 9, _side, 9),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: .05)),
            ),
          ),
          child: _mobileTwoLines(
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    fixedAssetDash(zone.label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_zoneDone(zone)) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: FixedAssetSummaryColors.green,
                  ),
                ],
              ],
            ),
            audited: zone.audited,
            total: zone.total,
            pct: zone.pct,
            remaining: zone.remaining,
            moved: zone.movedCount ?? 0,
            barHeight: 6,
            bold: false,
          ),
        ),
      ),
    );
  }

  /// Dòng khu (34 px, chữ 14.5): tên lùi 16 + check nếu xong; thanh 7 px.
  Widget _zoneRow(FixedAssetSummaryZone zone) {
    final moved = zone.movedCount ?? 0;
    const body = TextStyle(
      color: Colors.white,
      fontSize: 14.5,
      fontWeight: FontWeight.w600,
    );
    final muted = Colors.white.withValues(alpha: .45);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onOpenZone(zone),
        hoverColor: Colors.white.withValues(alpha: .05),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: .05)),
            ),
          ),
          child: _cells(
            zone: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      fixedAssetDash(zone.label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: body.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (_zoneDone(zone)) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: FixedAssetSummaryColors.accent,
                    ),
                  ],
                ],
              ),
            ),
            bar: FixedAssetPlanProgressBar(
              pct: zone.pct,
              color: FixedAssetSummaryColors.accent,
              height: 7,
            ),
            audited: Text.rich(
              TextSpan(
                text: '${zone.audited}',
                style: body.copyWith(fontWeight: FontWeight.w800),
                children: [
                  TextSpan(
                    text: '/${zone.total}',
                    style: TextStyle(color: muted, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              maxLines: 1,
            ),
            pct: Text(
              FixedAssetSummaryStrings.percent(zone.pct),
              maxLines: 1,
              style: body.copyWith(
                color: FixedAssetSummaryColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            remaining: Text('${zone.remaining}', maxLines: 1, style: body),
            moved: Text(
              moved > 0 ? '$moved' : '—',
              maxLines: 1,
              style: moved > 0
                  ? body.copyWith(
                      color: FixedAssetSummaryColors.orange,
                      fontWeight: FontWeight.w900,
                    )
                  : body.copyWith(color: muted),
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented control 2 tab: nút cao 32, chữ 14, tự co theo chữ (không tràn);
/// nút đang chọn nền accent nhạt + viền accent (đổi 150 ms). [expanded]:
/// full width, các nút chia đều.
class _PicTabSwitcher extends StatefulWidget {
  /// (icon, nhãn) theo thứ tự tab.
  final List<(IconData, String)> tabs;
  final int index;
  final bool expanded;
  final ValueChanged<int> onChanged;

  const _PicTabSwitcher({
    required this.tabs,
    required this.index,
    required this.expanded,
    required this.onChanged,
  });

  @override
  State<_PicTabSwitcher> createState() => _PicTabSwitcherState();
}

class _PicTabSwitcherState extends State<_PicTabSwitcher> {
  static const Duration _duration = Duration(milliseconds: 150);
  int _hovered = -1;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      for (var i = 0; i < widget.tabs.length; i++)
        widget.expanded ? Expanded(child: _button(i)) : _button(i),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FixedAssetSummaryColors.border),
      ),
      child: Row(
        mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
        children: buttons,
      ),
    );
  }

  Widget _button(int i) {
    final (icon, label) = widget.tabs[i];
    final selected = i == widget.index;
    final color = selected
        ? FixedAssetSummaryColors.accent
        : Colors.white.withValues(alpha: .7);
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 14,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = i),
      onExit: (_) => setState(() => _hovered = -1),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onChanged(i),
        child: AnimatedContainer(
          duration: _duration,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? FixedAssetSummaryColors.accent.withValues(alpha: .18)
                : (_hovered == i
                      ? Colors.white.withValues(alpha: .06)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? FixedAssetSummaryColors.accent
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              // Tự co theo chữ; chỉ khi full width (bề rộng có hạn) mới cắt "…".
              if (widget.expanded) Flexible(child: text) else text,
            ],
          ),
        ),
      ),
    );
  }
}
