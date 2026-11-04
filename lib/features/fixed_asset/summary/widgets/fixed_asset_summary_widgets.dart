import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:chuphinh/core/models/fixed_asset_summary.dart';
import 'package:chuphinh/features/fixed_asset/summary/fixed_asset_summary_strings.dart';

/// Màu chung mục Summary (tông tối như các màn Fixed Asset).
abstract final class FixedAssetSummaryColors {
  static const appBar = Color(0xFF121826);
  static const surface = Color(0xFF1F2937);
  static const accent = Color(0xFF4DD0E1);
  static const green = Color(0xFF22C55E);
  static const yellow = Color(0xFFFACC15);
  static const orange = Color(0xFFFB923C);

  /// Trạng thái chậm kế hoạch (chỉ dùng cho trạng thái, không trang trí).
  static const behind = Color(0xFFEF4444);

  /// Chữ phụ / trạng thái trung tính.
  static const muted = Color(0x8CFFFFFF); // trắng 0.55

  /// Vạch / nhãn "hôm nay" (xanh dương).
  static const today = Color(0xFF42A5F5);
  static const border = Color(0x24FFFFFF); // trắng 0.14
  static const card = Color(0x0FFFFFFF); // trắng 0.06

  static const background = BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF121826), Color(0xFF1F2937), Color(0xFF374151)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );
}

/// Khung card tối bo góc.
class FixedAssetSummaryCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const FixedAssetSummaryCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: padding,
          decoration: BoxDecoration(
            color: FixedAssetSummaryColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: FixedAssetSummaryColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Chip nhỏ bo tròn: chữ + viền màu [color].
class FixedAssetSummaryChip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const FixedAssetSummaryChip({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thanh tiến độ [pct] (0–100) + vạch trắng tại [planPct] (kế hoạch).
class FixedAssetPlanProgressBar extends StatelessWidget {
  final double pct;
  final double? planPct;
  final Color color;
  final double height;

  const FixedAssetPlanProgressBar({
    super.key,
    required this.pct,
    required this.color,
    this.planPct,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    final value = (pct / 100).clamp(0.0, 1.0);
    final plan = planPct == null ? null : (planPct! / 100).clamp(0.0, 1.0);
    return SizedBox(
      height: height + 6,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Container(
                width: width * value,
                height: height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              if (plan != null)
                Positioned(
                  left: (width * plan - 1).clamp(0.0, width - 2),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Avatar chữ cái đầu của tên PIC, nền theo màu trạng thái.
class FixedAssetPicAvatar extends StatelessWidget {
  final String name;
  final Color color;
  final double size;

  const FixedAssetPicAvatar({
    super.key,
    required this.name,
    required this.color,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: .18),
        border: Border.all(color: color.withValues(alpha: .6)),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: color,
          fontSize: size * .45,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

enum _PicSort {
  machines(FixedAssetSummaryStrings.sortMachines),
  behind(FixedAssetSummaryStrings.sortBehindPlan);

  final String label;

  const _PicSort(this.label);
}

/// Bảng "Tiến độ theo PIC": sắp xếp, cột PIC | Máy | thanh % cả quý |
/// Đã kiểm | %.
/// - Cột thanh chia 3 tháng: vạch dọc ở 1/3, 2/3 xuyên header + các dòng.
/// - Vạch "hôm nay" xanh dương nét đứt tại [planPct] + nhãn ngày trên header (quý
///   không chứa [today] thì không vẽ).
/// - [wide] = false (< 900 px): ẩn Máy.
/// - [compact] (mobile < 600 px): list 2 dòng mỗi PIC (tên + "a/t · %";
///   thanh có vạch kế hoạch + vạch chia tháng), sort chỉ icon, 1 dòng chú
///   thích hôm nay; không cột Máy, nhãn tháng, pill ngày.
/// - "Chưa có PIC" (pic = null) luôn cuối, không bấm được.
class FixedAssetPicProgressTable extends StatefulWidget {
  final String title;

  /// picRows của /summary, đã bỏ dòng tổng.
  final List<FixedAssetSummaryPicRow> rows;
  final double planPct;
  final FixedAssetPeriod period;
  final DateTime today;
  final bool wide;
  final bool compact;
  final String Function(FixedAssetSummaryPicRow row) nameOf;
  final void Function(FixedAssetSummaryPicRow row) onOpen;

  const FixedAssetPicProgressTable({
    super.key,
    required this.title,
    required this.rows,
    required this.planPct,
    required this.period,
    required this.today,
    required this.wide,
    this.compact = false,
    required this.nameOf,
    required this.onOpen,
  });

  @override
  State<FixedAssetPicProgressTable> createState() =>
      _FixedAssetPicProgressTableState();
}

class _FixedAssetPicProgressTableState
    extends State<FixedAssetPicProgressTable> {
  _PicSort _sort = _PicSort.machines;

  static const double _rowHeight = 44;

  /// Hàng nhãn cột (PIC, Máy, tháng, Đã kiểm, %).
  static const double _labelHeight = 30;

  /// Dải trên header chứa pill ngày (chỉ khi quý chứa hôm nay) — tách riêng
  /// để pill không bao giờ đè nhãn tháng.
  static const double _pillBand = 22;

  int _behindOf(FixedAssetSummaryPicRow r) =>
      fixedAssetBehindMachines(widget.planPct, r.total, r.audited);

  /// "Chưa có PIC" cuối; rồi theo [_sort]; rồi theo tên.
  int _compare(FixedAssetSummaryPicRow a, FixedAssetSummaryPicRow b) {
    if (a.isUnassigned != b.isUnassigned) return a.isUnassigned ? 1 : -1;
    final byKey = switch (_sort) {
      _PicSort.machines => b.total.compareTo(a.total),
      _PicSort.behind => _behindOf(b).compareTo(_behindOf(a)),
    };
    return byKey != 0
        ? byKey
        : widget.nameOf(a).compareTo(widget.nameOf(b));
  }

  /// Bố cục cột chung cho header, dòng và các lớp phủ (vạch tháng, vạch hôm
  /// nay).
  Widget _cells({
    Widget pic = const SizedBox.shrink(),
    Widget machines = const SizedBox.shrink(),
    required Widget bar,
    Widget audited = const SizedBox.shrink(),
    Widget pct = const SizedBox.shrink(),
  }) {
    final wide = widget.wide;
    final gap = wide ? 14.0 : 10.0;
    Widget cell(double width, Widget child, {bool end = false}) => SizedBox(
      width: width,
      child: Align(
        alignment: end ? Alignment.centerRight : Alignment.centerLeft,
        child: child,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cell(wide ? 180 : 110, pic),
          if (wide) ...[SizedBox(width: gap), cell(56, machines, end: true)],
          SizedBox(width: gap),
          Expanded(child: bar),
          SizedBox(width: gap),
          cell(wide ? 96 : 80, audited, end: true),
          SizedBox(width: gap),
          cell(wide ? 64 : 56, pct, end: true),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final period = widget.period;
    final months = [for (var i = 1; i <= 3; i++) period.monthOf(i)];
    final current = period.monthIndexOf(widget.today);
    final visible = [...widget.rows]..sort(_compare);
    if (widget.compact) return _buildCompact(visible, inQuarter: current > 0);
    final today = current > 0
        ? _TodayMark(
            fraction: (widget.planPct / 100).clamp(0.0, 1.0),
            label: DateFormat('dd-MMM-yy', 'en_US').format(widget.today),
            tooltip: FixedAssetSummaryStrings.todayTooltip(
              DateFormat('dd/MM').format(widget.today),
              widget.planPct,
            ),
          )
        : null;

    return FixedAssetSummaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(),
          const SizedBox(height: 10),
          Stack(
            children: [
              // Không tô nền tháng hiện tại, chỉ vạch chia tháng.
              Positioned.fill(
                child: _cells(bar: const _MonthGrid(current: 0)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(months, current, today),
                  if (visible.isEmpty)
                    SizedBox(
                      height: _rowHeight * 1.5,
                      child: Center(
                        child: Text(
                          FixedAssetSummaryStrings.noData,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .6),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final r in visible) _row(r),
                ],
              ),
              if (today != null)
                Positioned.fill(
                  child: _cells(
                    bar: _TodayMarker(mark: today, pillBand: _pillBand),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Lề ngang của item mobile; hàng trục dùng cùng lề để khớp thanh.
  static const double _compactSide = 4;

  /// Mobile: tiêu đề + nút sort (chỉ icon), hàng trục tháng (+ pill ngày tại
  /// planPct), chú thích kế hoạch ([inQuarter]), list PIC 2 dòng.
  Widget _buildCompact(
    List<FixedAssetSummaryPicRow> visible, {
    required bool inQuarter,
  }) {
    final plan = inQuarter ? (widget.planPct / 100).clamp(0.0, 1.0) : null;
    final period = widget.period;
    return FixedAssetSummaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _compactSide),
            child: _CompactAxis(
              months: [for (var i = 1; i <= 3; i++) period.monthOf(i)],
              current: period.monthIndexOf(widget.today),
              plan: plan,
              dateLabel: DateFormat('dd/MM').format(widget.today),
            ),
          ),
          if (inQuarter) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 2,
                  height: 10,
                  decoration: BoxDecoration(
                    color: FixedAssetSummaryColors.today,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    FixedAssetSummaryStrings.planTodayLegend(widget.planPct),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FixedAssetSummaryColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          if (visible.isEmpty)
            SizedBox(
              height: _rowHeight * 1.5,
              child: Center(
                child: Text(
                  FixedAssetSummaryStrings.noData,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .6),
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            for (final r in visible) _compactItem(r, plan),
        ],
      ),
    );
  }

  /// Item mobile: dòng 1 tên | "a/t · pct%"; dòng 2 thanh full width.
  Widget _compactItem(FixedAssetSummaryPicRow r, double? plan) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: r.pic == null ? null : () => widget.onOpen(r),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: _compactSide,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: .06)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.nameOf(r),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: r.isUnassigned
                            ? Colors.white.withValues(alpha: .6)
                            : Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text.rich(
                    TextSpan(
                      text: '${r.audited}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                      children: [
                        TextSpan(
                          text: FixedAssetSummaryStrings.picOfPct(
                            r.total,
                            r.pct,
                          ),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .55),
                            fontWeight: FontWeight.w600,
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
              const SizedBox(height: 6),
              _CompactPicBar(pct: r.pct, plan: plan),
            ],
          ),
        ),
      ),
    );
  }

  /// Mobile: nút sort chỉ icon, tên kiểu sort trong menu.
  Widget _sortMenu() {
    return PopupMenuButton<_PicSort>(
      tooltip: FixedAssetSummaryStrings.sortTooltip,
      initialValue: _sort,
      color: FixedAssetSummaryColors.surface,
      onSelected: (s) => setState(() => _sort = s),
      itemBuilder: (context) => [
        for (final s in _PicSort.values)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: s == _sort
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: FixedAssetSummaryColors.accent,
                        )
                      : null,
                ),
                Text(
                  s.label,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
      ],
      icon: Icon(
        Icons.sort_rounded,
        size: 20,
        color: Colors.white.withValues(alpha: .8),
      ),
    );
  }

  Widget _toolbar() {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (widget.compact) _sortMenu() else ..._sortDropdown(),
      ],
    );
  }

  /// Desktop: icon sort + dropdown có tên kiểu sort.
  List<Widget> _sortDropdown() {
    return [
      const SizedBox(width: 8),
      Icon(
        Icons.sort_rounded,
        size: 18,
        color: Colors.white.withValues(alpha: .6),
      ),
      const SizedBox(width: 4),
      DropdownButtonHideUnderline(
        child: DropdownButton<_PicSort>(
          value: _sort,
          isDense: true,
          dropdownColor: FixedAssetSummaryColors.surface,
          iconEnabledColor: Colors.white70,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
          items: [
            for (final s in _PicSort.values)
              DropdownMenuItem(value: s, child: Text(s.label)),
          ],
          onChanged: (s) {
            if (s != null) setState(() => _sort = s);
          },
        ),
      ),
    ];
  }

  Widget _header(List<int> months, int current, _TodayMark? today) {
    final style = TextStyle(
      color: Colors.white.withValues(alpha: .55),
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
    );
    Widget label(String text) =>
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    // Đo bằng cùng font với Text (DefaultTextStyle) để không lệch chiều rộng.
    final base = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    return Container(
      height: _labelHeight + (today != null ? _pillBand : 0),
      // Pill ngày nằm ở dải trên (vẽ bởi _TodayMarker), nhãn cột ở dải dưới.
      padding: EdgeInsets.only(top: today != null ? _pillBand : 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: .12)),
        ),
      ),
      child: _cells(
        pic: label(FixedAssetSummaryStrings.colPic),
        machines: label(FixedAssetSummaryStrings.colMachines),
        // Nhãn tháng căn giữa từng 1/3, luôn hiển thị. Tháng hiện tại không
        // đủ chỗ thì bỏ " · tháng này". Tháng chứa vạch hôm nay được đẩy né
        // vạch (pill đã ở dải riêng phía trên nên không còn chồng).
        bar: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final segment = width / 3;
            final lineX = today == null ? null : width * today.fraction;
            final pill = lineX == null ? null : (lineX - 1, lineX + 1);
            final pillMonth = today == null
                ? -1
                : (today.fraction * 3).floor().clamp(0, 2);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < 3; i++)
                  () {
                    final isCurrent = i + 1 == current;
                    final textStyle = base.merge(
                      isCurrent
                          ? style.copyWith(
                              color: FixedAssetSummaryColors.accent,
                              fontWeight: FontWeight.w900,
                            )
                          : style,
                    );
                    final minLeft = segment * i + 4;
                    final maxRight = segment * (i + 1) - 4;
                    final room = math.max(0.0, maxRight - minLeft);
                    var text = isCurrent
                        ? FixedAssetSummaryStrings.colMonthCurrent(months[i])
                        : FixedAssetSummaryStrings.colMonth(months[i]);
                    var textWidth = _textWidth(text, textStyle, scaler) + 2;
                    if (isCurrent && textWidth > room) {
                      text = FixedAssetSummaryStrings.colMonth(months[i]);
                      textWidth = _textWidth(text, textStyle, scaler) + 2;
                    }
                    var left = segment * i + (segment - textWidth) / 2;
                    if (pill != null && i == pillMonth) {
                      left = _avoidRange(
                        left,
                        textWidth,
                        minLeft,
                        maxRight,
                        pill,
                      );
                    }
                    return Positioned(
                      left: left,
                      width: textWidth,
                      top: 0,
                      bottom: 0,
                      child: Align(
                        child: Text(
                          text,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: textStyle,
                        ),
                      ),
                    );
                  }(),
              ],
            );
          },
        ),
        audited: label(FixedAssetSummaryStrings.statAudited),
        pct: label(FixedAssetSummaryStrings.colPercent),
      ),
    );
  }

  Widget _row(FixedAssetSummaryPicRow r) {
    final content = Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: .06)),
        ),
      ),
      child: _cells(
        pic: Text(
          widget.nameOf(r),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: r.isUnassigned
                ? Colors.white.withValues(alpha: .6)
                : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        machines: Text(
          '${r.total}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .8),
            fontSize: 15,
          ),
        ),
        bar: Center(
          child: FixedAssetPlanProgressBar(
            pct: r.pct,
            color: FixedAssetSummaryColors.accent,
            height: 12,
          ),
        ),
        audited: Text.rich(
          TextSpan(
            text: '${r.audited}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
            children: [
              TextSpan(
                text: '/${r.total}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .45),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          maxLines: 1,
          softWrap: false,
        ),
        pct: Text(
          FixedAssetSummaryStrings.percent1(r.pct),
          style: const TextStyle(
            color: FixedAssetSummaryColors.accent,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: r.pic == null ? null : () => widget.onOpen(r),
        hoverColor: Colors.white.withValues(alpha: .05),
        child: content,
      ),
    );
  }
}

/// Thanh cả quý như "Tiến độ theo PIC": nhãn 3 tháng chia đều phía trên
/// (tháng hiện tại accent đậm + nền nhạt), thanh 0→100% một màu accent.
class FixedAssetQuarterProgressBar extends StatelessWidget {
  final double pct;
  final FixedAssetPeriod period;
  final DateTime today;

  const FixedAssetQuarterProgressBar({
    super.key,
    required this.pct,
    required this.period,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final current = period.monthIndexOf(today);
    final style = TextStyle(
      color: Colors.white.withValues(alpha: .55),
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );
    return Stack(
      children: [
        Positioned.fill(child: _MonthGrid(current: current)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 18,
              child: Row(
                children: [
                  for (var i = 1; i <= 3; i++)
                    Expanded(
                      child: Center(
                        child: Text(
                          i == current
                              ? FixedAssetSummaryStrings.colMonthCurrent(
                                  period.monthOf(i),
                                )
                              : FixedAssetSummaryStrings.colMonth(
                                  period.monthOf(i),
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: i == current
                              ? style.copyWith(
                                  color: FixedAssetSummaryColors.accent,
                                  fontWeight: FontWeight.w900,
                                )
                              : style,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            FixedAssetPlanProgressBar(
              pct: pct,
              color: FixedAssetSummaryColors.accent,
              height: 10,
            ),
          ],
        ),
      ],
    );
  }
}

/// Màu % (mobile): 0% xám muted, > 0 accent, 100% xanh lá.
Color fixedAssetPctColor(double pct) => pct >= 100
    ? FixedAssetSummaryColors.green
    : (pct > 0 ? FixedAssetSummaryColors.accent : FixedAssetSummaryColors.muted);

/// Timeline quý gọn (mobile): nhãn "T10 · T11 · T12" giữa từng 1/3 (tháng
/// hiện tại accent đậm, không nền), thanh [pct] + vạch mờ chia tháng + vạch
/// xanh dương "hôm nay" tại [planPct] (quý không chứa [today] thì không vẽ).
class FixedAssetQuarterTimeline extends StatelessWidget {
  final double pct;
  final double planPct;
  final FixedAssetPeriod period;
  final DateTime today;

  const FixedAssetQuarterTimeline({
    super.key,
    required this.pct,
    required this.planPct,
    required this.period,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final current = period.monthIndexOf(today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 1; i <= 3; i++)
              Expanded(
                child: Text(
                  FixedAssetSummaryStrings.monthShort(period.monthOf(i)),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: i == current
                        ? FixedAssetSummaryColors.accent
                        : FixedAssetSummaryColors.muted,
                    fontSize: 12,
                    fontWeight: i == current
                        ? FontWeight.w900
                        : FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        _CompactPicBar(
          pct: pct,
          plan: current > 0 ? (planPct / 100).clamp(0.0, 1.0) : null,
        ),
      ],
    );
  }
}

/// Hàng trục tháng (mobile, trên list PIC; cùng bề rộng thanh của item):
/// nhãn "T10 · T11 · T12" giữa từng 1/3 (tháng [current] accent đậm), vạch
/// mờ chia tháng tại 1/3, 2/3; pill ngày xanh dương có mũi chỉ xuống, tâm tại
/// [plan] (0–1, clamp trong mép; null = không vẽ). Pill ở dải riêng phía
/// trên, nhãn tháng luôn hiện ở hàng dưới và chỉ né vạch hôm nay.
class _CompactAxis extends StatelessWidget {
  final List<int> months;
  final int current;
  final double? plan;
  final String dateLabel;

  const _CompactAxis({
    required this.months,
    required this.current,
    required this.plan,
    required this.dateLabel,
  });

  static const double _pillHeight = 18;
  static const double _arrow = 4;

  /// Dải pill (pill + mũi) phía trên; hàng nhãn tháng riêng phía dưới để
  /// pill không bao giờ che nhãn tháng.
  static const double _pillBand = _pillHeight + _arrow;
  static const double _monthHeight = 16;
  static const double _pillPadding = 6;
  static const TextStyle _pillStyle = TextStyle(
    color: Colors.white,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    height: 1,
  );

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    final top = plan != null ? _pillBand : 0.0;
    return SizedBox(
      height: top + _monthHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final segment = width / 3;
          final plan = this.plan;
          (double, double)? pill;
          double? x;
          if (plan != null) {
            x = width * plan;
            final pillWidth =
                _textWidth(dateLabel, base.merge(_pillStyle), scaler) +
                _pillPadding * 2 +
                2;
            final left = (x - pillWidth / 2)
                .clamp(0.0, math.max(0.0, width - pillWidth))
                .toDouble();
            pill = (left, left + pillWidth);
          }
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final f in const [1 / 3, 2 / 3])
                Positioned(
                  left: width * f - .5,
                  width: 1,
                  top: top,
                  bottom: 0,
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: .12),
                  ),
                ),
              // Vạch hôm nay nối từ mũi pill xuống qua hàng tháng.
              if (x != null)
                Positioned(
                  left: (x - 1).clamp(0.0, math.max(0.0, width - 2)),
                  width: 2,
                  top: top,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: FixedAssetSummaryColors.today,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              for (var i = 0; i < 3; i++)
                () {
                  final isCurrent = i + 1 == current;
                  final style = base.merge(
                    TextStyle(
                      color: isCurrent
                          ? FixedAssetSummaryColors.accent
                          : FixedAssetSummaryColors.muted,
                      fontSize: 11,
                      fontWeight: isCurrent
                          ? FontWeight.w900
                          : FontWeight.w600,
                    ),
                  );
                  final text = FixedAssetSummaryStrings.monthShort(months[i]);
                  final textWidth = _textWidth(text, style, scaler) + 2;
                  var left = segment * i + (segment - textWidth) / 2;
                  // Luôn hiện nhãn tháng; chỉ đẩy né vạch hôm nay trong 1/3.
                  if (x != null) {
                    left = _avoidRange(
                      left,
                      textWidth,
                      segment * i + 2,
                      segment * (i + 1) - 2,
                      (x - 1, x + 1),
                    );
                  }
                  return Positioned(
                    left: left,
                    width: textWidth,
                    top: top,
                    height: _monthHeight,
                    child: Center(
                      child: Text(
                        text,
                        maxLines: 1,
                        softWrap: false,
                        style: style,
                      ),
                    ),
                  );
                }(),
              if (pill != null && x != null) ...[
                Positioned(
                  left: pill.$1,
                  width: pill.$2 - pill.$1,
                  top: 0,
                  height: _pillHeight,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: FixedAssetSummaryColors.today,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      dateLabel,
                      maxLines: 1,
                      softWrap: false,
                      style: _pillStyle,
                    ),
                  ),
                ),
                // Mũi chỉ xuống đúng tại planPct (giữ trong mép trục).
                Positioned(
                  left:
                      x.clamp(_arrow, math.max(_arrow, width - _arrow))
                          .toDouble() -
                      _arrow,
                  width: _arrow * 2,
                  top: _pillHeight - .5,
                  height: _arrow + .5,
                  child: const CustomPaint(painter: _ArrowDownPainter()),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Tam giác nhỏ chỉ xuống, màu "hôm nay".
class _ArrowDownPainter extends CustomPainter {
  const _ArrowDownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = FixedAssetSummaryColors.today);
  }

  @override
  bool shouldRepaint(_ArrowDownPainter old) => false;
}

/// Thanh tiến độ PIC mobile: nền + phần [pct] accent, vạch mờ chia 3 tháng,
/// vạch dọc xanh dương tại [plan] (0–1; null = quý không chứa hôm nay).
class _CompactPicBar extends StatelessWidget {
  final double pct;
  final double? plan;

  const _CompactPicBar({required this.pct, this.plan});

  static const double _barHeight = 8;
  static const double _height = 14;

  @override
  Widget build(BuildContext context) {
    final value = (pct / 100).clamp(0.0, 1.0);
    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final plan = this.plan;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: _barHeight,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Container(
                width: width * value,
                height: _barHeight,
                decoration: BoxDecoration(
                  color: FixedAssetSummaryColors.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              for (final f in const [1 / 3, 2 / 3])
                Positioned(
                  left: width * f - .5,
                  width: 1,
                  top: (_height - _barHeight) / 2,
                  height: _barHeight,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: .35),
                  ),
                ),
              if (plan != null)
                Positioned(
                  left: (width * plan - 1).clamp(0.0, width - 2),
                  width: 2,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: FixedAssetSummaryColors.today,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Lớp nền cột thanh: vạch dọc mảnh ở 1/3, 2/3; nền accent nhạt vùng tháng
/// [current] (1–3; 0 = ngoài quý, không tô).
class _MonthGrid extends StatelessWidget {
  final int current;

  const _MonthGrid({required this.current});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          children: [
            if (current > 0)
              Positioned(
                left: width * (current - 1) / 3,
                width: width / 3,
                top: 0,
                bottom: 0,
                child: ColoredBox(
                  color: FixedAssetSummaryColors.accent.withValues(alpha: .07),
                ),
              ),
            for (final f in const [1 / 3, 2 / 3])
              Positioned(
                left: width * f - .5,
                width: 1,
                top: 0,
                bottom: 0,
                child: ColoredBox(color: Colors.white.withValues(alpha: .12)),
              ),
          ],
        );
      },
    );
  }
}

double _textWidth(String text, TextStyle style, TextScaler scaler) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  return painter.width;
}

/// Vị trí left của đoạn rộng [width] tránh [range] (cách 6 px), giữ trong
/// [minLeft, maxRight]; không tránh hết thì chọn bên ít chồng hơn.
double _avoidRange(
  double left,
  double width,
  double minLeft,
  double maxRight,
  (double, double) range,
) {
  const gap = 6.0;
  final (start, end) = (range.$1 - gap, range.$2 + gap);
  if (left + width <= start || left >= end) return left;
  final maxLeft = math.max(minLeft, maxRight - width);
  final toLeft = (start - width).clamp(minLeft, maxLeft).toDouble();
  final toRight = end.clamp(minLeft, maxLeft).toDouble();
  double overlap(double l) =>
      math.max(0.0, math.min(l + width, end) - math.max(l, start));
  final (a, b) = (overlap(toLeft), overlap(toRight));
  if (a != b) return a < b ? toLeft : toRight;
  return (toLeft - left).abs() <= (toRight - left).abs() ? toLeft : toRight;
}

/// Dữ liệu vạch "hôm nay": [fraction] (0–1) trên cột thanh, nhãn pill
/// [label] và [tooltip].
class _TodayMark {
  final double fraction;
  final String label;
  final String tooltip;

  static const labelStyle = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );
  static const padding = EdgeInsets.symmetric(horizontal: 7, vertical: 2);

  const _TodayMark({
    required this.fraction,
    required this.label,
    required this.tooltip,
  });
}

/// Pill ngày ở dải trên header (cao [pillBand], tách khỏi hàng nhãn tháng)
/// + vạch dọc xanh dương nét đứt từ ngay dưới pill xuống hết các dòng; hover
/// vạch / pill hiện tooltip.
class _TodayMarker extends StatelessWidget {
  final _TodayMark mark;
  final double pillBand;

  const _TodayMarker({required this.mark, required this.pillBand});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final x = width * mark.fraction;
        final top = pillBand - 2;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DashedLinePainter(x: x, top: top),
                ),
              ),
            ),
            Positioned(
              left: x - 5,
              width: 10,
              top: top,
              bottom: 0,
              child: Tooltip(
                message: mark.tooltip,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            // Pill rộng theo nội dung, căn giữa tại vạch, clamp trong vùng
            // timeline.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: pillBand,
              child: CustomSingleChildLayout(
                delegate: _CenterClampLayout(x),
                child: Tooltip(
                  message: mark.tooltip,
                  child: Container(
                    padding: _TodayMark.padding,
                    decoration: BoxDecoration(
                      color: FixedAssetSummaryColors.today,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      mark.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: _TodayMark.labelStyle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Con không giới hạn chiều rộng (tự co theo nội dung), căn giữa theo [x],
/// clamp trong khung, căn giữa dọc.
class _CenterClampLayout extends SingleChildLayoutDelegate {
  final double x;

  const _CenterClampLayout(this.x);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxHeight: constraints.maxHeight);

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    (x - childSize.width / 2)
        .clamp(0.0, math.max(0.0, size.width - childSize.width))
        .toDouble(),
    (size.height - childSize.height) / 2,
  );

  @override
  bool shouldRelayout(_CenterClampLayout old) => old.x != x;
}

/// Đường dọc nét đứt (dày 1.5, dash 4 / gap 3) tại [x], từ [top] xuống đáy.
class _DashedLinePainter extends CustomPainter {
  final double x;
  final double top;

  const _DashedLinePainter({required this.x, required this.top});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = FixedAssetSummaryColors.today
      ..strokeWidth = 1.5;
    for (var y = top; y < size.height; y += 7) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, math.min(y + 4, size.height)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.x != x || old.top != top;
}

/// Donut 2 lớp: cung trắng mờ = kế hoạch [planPct] (null = không vẽ), cung
/// accent = đã kiểm [pct] (0–100) đè lên; giữa là "{pct}%". Fill animation
/// 400 ms. [tooltip] khi hover / nhấn giữ.
class FixedAssetPlanDonut extends StatelessWidget {
  final double pct;
  final double? planPct;
  final String? tooltip;
  final double size;
  final double thickness;

  const FixedAssetPlanDonut({
    super.key,
    required this.pct,
    this.planPct,
    this.tooltip,
    this.size = 72,
    this.thickness = 8,
  });

  @override
  Widget build(BuildContext context) {
    final donut = SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: (pct / 100).clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => CustomPaint(
          painter: _DonutPainter(
            value: value,
            plan: planPct == null ? null : (planPct! / 100).clamp(0.0, 1.0),
            thickness: thickness,
          ),
          child: child,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(thickness + 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                FixedAssetSummaryStrings.percent(pct),
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? donut : Tooltip(message: tooltip, child: donut);
  }
}

class _DonutPainter extends CustomPainter {
  final double value;
  final double? plan;
  final double thickness;

  const _DonutPainter({
    required this.value,
    required this.plan,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - thickness) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = Colors.white.withValues(alpha: .08),
    );
    if (plan != null && plan! > 0) {
      canvas.drawArc(
        rect,
        start,
        2 * math.pi * plan!,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = plan! >= 1 ? StrokeCap.butt : StrokeCap.round
          ..color = Colors.white.withValues(alpha: .28),
      );
    }
    if (value > 0) {
      canvas.drawArc(
        rect,
        start,
        2 * math.pi * value,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = value >= 1 ? StrokeCap.butt : StrokeCap.round
          ..color = FixedAssetSummaryColors.accent,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.value != value || old.plan != plan || old.thickness != thickness;
}

/// Thông báo giữa màn (trống / lỗi) — vẫn kéo xuống tải lại được khi đặt
/// trong RefreshIndicator.
class FixedAssetSummaryMessage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String? detail;
  final VoidCallback? onRetry;

  const FixedAssetSummaryMessage({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
    this.detail,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 44),
                  const SizedBox(height: 10),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      detail!,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .6),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  if (onRetry != null) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text(FixedAssetSummaryStrings.retry),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FixedAssetSummaryColors.accent,
                        side: BorderSide(
                          color: FixedAssetSummaryColors.accent.withValues(
                            alpha: .6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton các dòng cao [rowHeight] khi đang tải (thay spinner để layout
/// không nhảy); cuộn được để vẫn kéo xuống tải lại.
class FixedAssetSkeletonRows extends StatelessWidget {
  final int count;
  final double rowHeight;

  const FixedAssetSkeletonRows({
    super.key,
    this.count = 12,
    this.rowHeight = 44,
  });

  static const List<double> _widths = [.8, .55, .7, .62];

  @override
  Widget build(BuildContext context) {
    final fill = Colors.white.withValues(alpha: .08);
    Widget block({double? width}) => Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: count,
      itemExtent: rowHeight,
      itemBuilder: (context, index) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: .06)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              block(width: 72),
              const SizedBox(width: 16),
              Expanded(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _widths[index % _widths.length],
                  child: block(),
                ),
              ),
              const SizedBox(width: 16),
              block(width: 56),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ô tìm gọn (cao [height], mặc định 32) cho thanh trên card bảng; nút xóa
/// theo text đang gõ (không đợi debounce, không rebuild bảng).
class FixedAssetCompactSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final double height;

  const FixedAssetCompactSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: FixedAssetSummaryColors.accent.withValues(alpha: .35),
      ),
    );
    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(color: Colors.white, fontSize: 13.5),
        cursorColor: FixedAssetSummaryColors.accent,
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: .5),
            fontSize: 13.5,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: .08),
          contentPadding: EdgeInsets.zero,
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 16,
            color: Colors.white.withValues(alpha: .6),
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: 32,
            minHeight: height,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    onPressed: onClear,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: .7),
                    ),
                  ),
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 28,
            minHeight: 28,
          ),
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(
              color: FixedAssetSummaryColors.accent,
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
