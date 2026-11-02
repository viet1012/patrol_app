import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:chuphinh/core/api/fixed_asset_backend.dart';
import 'package:chuphinh/core/models/fixed_asset_summary.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_audit_flow.dart'
    show fixedAssetErrorText;
import 'package:chuphinh/features/fixed_asset/fixed_asset_location.dart';
import 'package:chuphinh/features/fixed_asset/summary/fixed_asset_summary_strings.dart';
import 'package:chuphinh/features/fixed_asset/summary/widgets/fixed_asset_summary_table.dart';
import 'package:chuphinh/features/fixed_asset/summary/widgets/fixed_asset_summary_widgets.dart';

/// Bộ lọc nhanh của bảng máy.
enum FixedAssetPicMachineFilter { all, unaudited, audited, abnormal }

/// Bảng máy của một PIC (chỉ xem): tự tải GET /summary/pic-machines theo
/// [location] (null = toàn bộ máy PIC). Filter chip + tìm mã / tên (+ lọc
/// khu khi [showZoneFilter]) lọc phía client. Tải lại: [FixedAssetPicMachinesViewState.reload].
class FixedAssetPicMachinesView extends StatefulWidget {
  final FixedAssetBackend api;
  final String pic;
  final FixedAssetPeriod period;
  final FixedAssetAuditLocation? location;
  final FixedAssetPicMachineFilter initialFilter;
  final bool showZoneFilter;

  /// Kéo xuống tải lại; null = chỉ tải lại bảng này.
  final Future<void> Function()? onRefresh;

  /// Dữ liệu đã tải trước (màn cha gọi song song pic-detail); lần tải đầu
  /// dùng kết quả này thay vì gọi API.
  final Future<List<FixedAssetPicMachine>>? prefetch;

  /// Widget đầu thanh trên (segmented chọn tab của màn chi tiết PIC).
  final Widget? leading;

  /// Nằm trong card bảng: không lề ngang, thanh trên padding 8×14 + kẻ dưới.
  final bool embedded;

  const FixedAssetPicMachinesView({
    super.key,
    required this.api,
    required this.pic,
    required this.period,
    this.location,
    this.initialFilter = FixedAssetPicMachineFilter.all,
    this.showZoneFilter = false,
    this.onRefresh,
    this.prefetch,
    this.leading,
    this.embedded = false,
  });

  @override
  State<FixedAssetPicMachinesView> createState() =>
      FixedAssetPicMachinesViewState();
}

class FixedAssetPicMachinesViewState extends State<FixedAssetPicMachinesView>
    with AutomaticKeepAliveClientMixin {
  static final DateFormat _time = DateFormat('dd/MM HH:mm');

  List<FixedAssetPicMachine>? _machines;
  bool _loading = true;
  String? _error;
  int _req = 0;

  late FixedAssetPicMachineFilter _filter = widget.initialFilter;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _zoneFilter;

  /// Search debounce 250 ms.
  Timer? _searchDebounce;

  /// Prefetch chỉ dùng cho lần tải đầu.
  Future<List<FixedAssetPicMachine>>? _prefetch;

  // Cache: số đếm filter + danh sách khu (theo [_machines]) và kết quả lọc
  // (theo machines / filter / query / khu); tính lại chỉ khi input đổi.
  List<FixedAssetPicMachine>? _statsFor;
  Map<FixedAssetPicMachineFilter, int> _counts = const {};
  List<String> _zones = const [];
  Object? _visibleKey;
  List<FixedAssetPicMachine> _visible = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _prefetch = widget.prefetch;
    reload();
  }

  @override
  void didUpdateWidget(covariant FixedAssetPicMachinesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location ||
        oldWidget.period != widget.period ||
        oldWidget.pic != widget.pic) {
      _machines = null;
      reload();
    }
  }

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

  void _updateStats(List<FixedAssetPicMachine> machines) {
    if (identical(_statsFor, machines)) return;
    _statsFor = machines;
    _counts = {
      for (final f in FixedAssetPicMachineFilter.values)
        f: machines.where((m) => _matches(f, m)).length,
    };
    _zones = {
      for (final m in machines)
        if (m.zoneLabel.isNotEmpty) m.zoneLabel,
    }.toList()..sort();
  }

  List<FixedAssetPicMachine> _visibleOf(List<FixedAssetPicMachine> machines) {
    final query = _query.trim().toLowerCase();
    final zoneFilter = widget.showZoneFilter ? _zoneFilter : null;
    final key = (machines, _filter, query, zoneFilter);
    if (key == _visibleKey) return _visible;
    _visibleKey = key;
    return _visible = [
      for (final m in machines)
        if (_matchesFilter(m) &&
            (zoneFilter == null || m.zoneLabel == zoneFilter) &&
            (query.isEmpty ||
                m.machineCode.toLowerCase().contains(query) ||
                m.machineName.toLowerCase().contains(query)))
          m,
    ];
  }

  /// [silent]: giữ bảng cũ tới khi có dữ liệu mới.
  Future<void> reload({bool silent = false}) async {
    final req = ++_req;
    if (!silent || _machines == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final location = widget.location;
    final prefetch = _prefetch;
    _prefetch = null;
    try {
      final machines =
          await (prefetch ??
              widget.api.fetchSummaryPicMachines(
                pic: widget.pic,
                period: widget.period.key,
                fac: location?.fac,
                floor: location?.floor,
                positionA: location?.positionA,
                positionAA: location?.positionAA,
              ));
      if (!mounted || req != _req) return;
      setState(() {
        _machines = machines;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || req != _req) return;
      setState(() {
        _loading = false;
        if (!silent || _machines == null) _error = fixedAssetErrorText(error);
      });
    }
  }

  bool _matchesFilter(FixedAssetPicMachine m) => _matches(_filter, m);

  static bool _matches(
    FixedAssetPicMachineFilter filter,
    FixedAssetPicMachine m,
  ) => switch (filter) {
    FixedAssetPicMachineFilter.all => true,
    FixedAssetPicMachineFilter.unaudited => !m.audited,
    FixedAssetPicMachineFilter.audited => m.audited,
    FixedAssetPicMachineFilter.abnormal => m.abnormal || m.pendingQr,
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final machines = _machines;
    if (machines != null) _updateStats(machines);
    final Widget content;
    if (machines == null && _loading) {
      content = const FixedAssetSkeletonRows(rowHeight: 36);
    } else if (machines == null) {
      content = FixedAssetSummaryMessage(
        icon: Icons.cloud_off_rounded,
        color: Colors.redAccent,
        text: FixedAssetSummaryStrings.loadFailed,
        detail: _error,
        onRetry: () => reload(),
      );
    } else {
      content = _buildTable(machines);
    }

    // Toolbar và bảng cùng lề ngang [side] (trong card: 0, thanh trên kẻ dưới).
    final side = widget.embedded ? 0.0 : _side;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: widget.embedded
              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
              : const EdgeInsets.fromLTRB(_side, 10, _side, 8),
          decoration: widget.embedded
              ? const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: FixedAssetSummaryColors.border),
                  ),
                )
              : null,
          child: _buildToolbar(),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: side),
            child: RefreshIndicator(
              color: FixedAssetSummaryColors.accent,
              // Bảng có thể nằm trong cuộn ngang: nhận cuộn dọc ở mọi độ sâu.
              notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
              onRefresh: widget.onRefresh ?? () => reload(silent: true),
              child: content,
            ),
          ),
        ),
      ],
    );
  }

  static const double _side = 16;

  /// Thanh trên: [FixedAssetPicMachinesView.leading] bên trái; bên phải
  /// filter trạng thái + ô tìm (w 200) (+ lọc khu). Màn < 700 px (hoặc không
  /// có leading): 2 hàng — leading full width, rồi tìm / lọc / chip.
  /// Số đếm / danh sách khu lấy từ cache ([_updateStats]).
  Widget _buildToolbar() {
    final hasData = _machines != null;
    final zones = hasData ? _zones : const <String>[];
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final chips = [
      for (final f in FixedAssetPicMachineFilter.values)
        _filterChip(f, hasData ? (_counts[f] ?? 0) : 0),
    ];
    final search = FixedAssetCompactSearchField(
      controller: _searchController,
      hint: FixedAssetSummaryStrings.searchMachine,
      onChanged: _onSearchChanged,
      onClear: _clearSearch,
    );
    final leading = widget.leading;
    if (narrow || leading == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (leading != null) ...[leading, const SizedBox(height: 8)],
          Row(
            children: [
              Expanded(child: search),
              if (widget.showZoneFilter) ...[
                const SizedBox(width: 8),
                _buildZoneFilter(zones),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: chips),
        ],
      );
    }
    return Row(
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              ...chips,
              const SizedBox(width: 2),
              SizedBox(width: 200, child: search),
              if (widget.showZoneFilter) _buildZoneFilter(zones),
            ],
          ),
        ),
      ],
    );
  }

  /// Chip lọc vẽ tay (màu tường minh theo nền tối, không checkmark):
  /// chưa chọn nền trong suốt; đang chọn nền / viền / chữ cyan.
  Widget _filterChip(FixedAssetPicMachineFilter filter, int count) {
    final label = switch (filter) {
      FixedAssetPicMachineFilter.all => FixedAssetSummaryStrings.filterAll,
      FixedAssetPicMachineFilter.unaudited =>
        FixedAssetSummaryStrings.filterUnaudited,
      FixedAssetPicMachineFilter.audited =>
        FixedAssetSummaryStrings.filterAudited,
      FixedAssetPicMachineFilter.abnormal =>
        FixedAssetSummaryStrings.filterAbnormal,
    };
    final selected = _filter == filter;
    const accent = FixedAssetSummaryColors.accent;
    return Material(
      color: selected ? accent.withValues(alpha: .18) : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? accent : Colors.white.withValues(alpha: .2),
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => setState(() => _filter = filter),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            FixedAssetSummaryStrings.filterCount(label, count),
            style: TextStyle(
              color: selected ? accent : Colors.white.withValues(alpha: .75),
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoneFilter(List<String> zones) {
    // Khu đang lọc không còn (sau tải lại): coi như tất cả.
    final value = zones.contains(_zoneFilter) ? _zoneFilter : null;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: FixedAssetSummaryColors.accent.withValues(alpha: .35),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isDense: true,
          dropdownColor: FixedAssetSummaryColors.surface,
          iconEnabledColor: FixedAssetSummaryColors.accent,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text(FixedAssetSummaryStrings.allZones),
            ),
            for (final zone in zones)
              DropdownMenuItem<String?>(value: zone, child: Text(zone)),
          ],
          onChanged: (zone) => setState(() => _zoneFilter = zone),
        ),
      ),
    );
  }

  /// Cột theo tỉ lệ flex 1.2 | 3 | 2 | 2.4 | 1.4 | 2.2 | 2 (× [_flexUnit] =
  /// bề rộng tối thiểu): đủ chỗ thì giãn đúng tỉ lệ theo bề rộng panel,
  /// thiếu chỗ thì cuộn ngang.
  static const double _flexUnit = 50;
  static const List<FixedAssetSummaryTableColumn> _columns = [
    FixedAssetSummaryTableColumn(
      FixedAssetSummaryStrings.colMachineCode,
      1.2 * _flexUnit,
    ),
    FixedAssetSummaryTableColumn(
      FixedAssetSummaryStrings.colMachineName,
      3 * _flexUnit,
    ),
    FixedAssetSummaryTableColumn(
      FixedAssetSummaryStrings.colStatus,
      2 * _flexUnit,
    ),
    FixedAssetSummaryTableColumn(
      FixedAssetSummaryStrings.colAuditor,
      2.4 * _flexUnit,
    ),
    FixedAssetSummaryTableColumn(
      FixedAssetSummaryStrings.colTime,
      1.4 * _flexUnit,
    ),
    FixedAssetSummaryTableColumn(
      FixedAssetSummaryStrings.colQrMaster,
      2.2 * _flexUnit,
    ),
    FixedAssetSummaryTableColumn(
      FixedAssetSummaryStrings.colNote,
      2 * _flexUnit,
    ),
  ];

  Widget _buildTable(List<FixedAssetPicMachine> machines) {
    final rows = _visibleOf(machines);
    if (rows.isEmpty) {
      return const FixedAssetSummaryMessage(
        icon: Icons.search_off_rounded,
        color: Colors.white54,
        text: FixedAssetSummaryStrings.noMachine,
      );
    }
    // Dòng 36; có Người kiểm 2 dòng (MSNV + tên) thì 40.
    return FixedAssetSummaryTable(
      columns: _columns,
      headerHeight: 30,
      rowHeight: rows.any((m) => m.auditUserId.isNotEmpty) ? 40 : 36,
      rowCount: rows.length,
      rowBuilder: (index) => FixedAssetSummaryTableRow(_cells(rows[index])),
    );
  }

  List<Widget> _cells(FixedAssetPicMachine m) {
    final auditedAt = m.auditedAt;
    final locations = [
      if (m.qrMismatch) FixedAssetSummaryStrings.qrAt(fixedAssetDash(m.qrLocation)),
      if (m.isMoved)
        FixedAssetSummaryStrings.masterAt(fixedAssetDash(m.masterLocation)),
    ];
    return [
      _text(m.machineCode, weight: FontWeight.w800),
      _text(
        fixedAssetDash(m.machineName),
        color: Colors.white.withValues(alpha: .8),
      ),
      _statusChips(m),
      _auditor(m),
      _text(auditedAt == null ? '-' : _time.format(auditedAt)),
      _text(
        locations.isEmpty ? '-' : locations.join(' · '),
        color: locations.isEmpty ? null : FixedAssetSummaryColors.orange,
      ),
      _text(
        fixedAssetDash(m.note),
        color: Colors.white.withValues(alpha: .75),
      ),
    ];
  }

  /// MSNV (nhỏ, mờ) trên, họ tên dưới; thiếu MSNV thì chỉ họ tên.
  Widget _auditor(FixedAssetPicMachine m) {
    final name = _text(fixedAssetDash(m.auditUserName));
    if (m.auditUserId.isEmpty) return name;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _text(
          m.auditUserId,
          size: 11.5,
          weight: FontWeight.w500,
          color: Colors.white.withValues(alpha: .5),
        ),
        name,
      ],
    );
  }

  /// Chưa kiểm (xám) / Đã kiểm (xanh) + Lệch vị trí (cam) + Chờ thay QR (đỏ).
  Widget _statusChips(FixedAssetPicMachine m) {
    final chips = [
      m.audited
          ? const FixedAssetSummaryChip(
              text: FixedAssetSummaryStrings.chipAudited,
              color: FixedAssetSummaryColors.green,
            )
          : const FixedAssetSummaryChip(
              text: FixedAssetSummaryStrings.chipUnaudited,
              color: Colors.white54,
            ),
      if (m.abnormal)
        const FixedAssetSummaryChip(
          text: FixedAssetSummaryStrings.chipMoved,
          color: FixedAssetSummaryColors.orange,
        ),
      if (m.pendingQr)
        const FixedAssetSummaryChip(
          text: FixedAssetSummaryStrings.chipPendingQr,
          color: Colors.redAccent,
        ),
    ];
    // Thiếu chỗ (3 chip) thì thu nhỏ, không tràn.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            chips[i],
          ],
        ],
      ),
    );
  }

  Widget _text(
    String text, {
    FontWeight weight = FontWeight.w600,
    Color? color,
    double size = 14.5,
  }) {
    return _EllipsisText(
      text,
      style: TextStyle(
        color: color ?? Colors.white,
        fontSize: size,
        fontWeight: weight,
      ),
    );
  }
}

/// Text một dòng, cắt "…". Không đo sẵn: chỉ khi hover / bấm mới kiểm tra
/// bị cắt, bị cắt thì tạo Tooltip và hiện ngay.
class _EllipsisText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _EllipsisText(this.text, {required this.style});

  @override
  State<_EllipsisText> createState() => _EllipsisTextState();
}

class _EllipsisTextState extends State<_EllipsisText> {
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();
  bool _truncated = false;
  TextScaler _scaler = TextScaler.noScaling;
  TextDirection _direction = TextDirection.ltr;

  @override
  void didUpdateWidget(covariant _EllipsisText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _truncated = false;
  }

  /// Text bị cắt khi không vừa bề rộng hiện tại của chính nó (Text cắt thì
  /// rộng đúng bằng giới hạn).
  bool _isTruncated() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: _direction,
      textScaler: _scaler,
    )..layout(maxWidth: box.size.width);
    final truncated = painter.didExceedMaxLines;
    painter.dispose();
    return truncated;
  }

  void _show() {
    if (_truncated) {
      _tooltipKey.currentState?.ensureTooltipVisible();
      return;
    }
    if (!_isTruncated()) return;
    setState(() => _truncated = true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _tooltipKey.currentState?.ensureTooltipVisible(),
    );
  }

  @override
  Widget build(BuildContext context) {
    _scaler = MediaQuery.textScalerOf(context);
    _direction = Directionality.of(context);
    final text = Text(
      widget.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.style,
    );
    if (_truncated) {
      return Tooltip(
        key: _tooltipKey,
        message: widget.text,
        triggerMode: TooltipTriggerMode.tap,
        showDuration: const Duration(seconds: 5),
        child: text,
      );
    }
    return MouseRegion(
      onEnter: (_) => _show(),
      child: GestureDetector(onTap: _show, child: text),
    );
  }
}
