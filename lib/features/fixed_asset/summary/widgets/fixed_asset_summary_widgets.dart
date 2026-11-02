import 'package:flutter/material.dart';

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
/// Đã kiểm | % | Thiếu so KH.
/// - Cột thanh chia 3 tháng: vạch dọc ở 1/3, 2/3 và nền accent nhạt vùng
///   tháng hiện tại xuyên header + các dòng (quý không chứa [today] thì
///   không tô nền).
/// - [wide] = false (< 900 px): ẩn Máy và Thiếu so KH.
/// - "Chưa có PIC" (pic = null) luôn cuối, không bấm được.
class FixedAssetPicProgressTable extends StatefulWidget {
  final String title;

  /// picRows của /summary, đã bỏ dòng tổng.
  final List<FixedAssetSummaryPicRow> rows;
  final double planPct;
  final FixedAssetPeriod period;
  final DateTime today;
  final bool wide;
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
  static const double _headerHeight = 38;

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

  /// Bố cục cột chung cho header, dòng và lớp nền (vạch tháng + vùng tháng
  /// hiện tại).
  Widget _cells({
    Widget pic = const SizedBox.shrink(),
    Widget machines = const SizedBox.shrink(),
    required Widget bar,
    Widget audited = const SizedBox.shrink(),
    Widget pct = const SizedBox.shrink(),
    Widget behind = const SizedBox.shrink(),
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
          if (wide) ...[SizedBox(width: gap), cell(96, behind, end: true)],
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

    return FixedAssetSummaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(),
          const SizedBox(height: 10),
          Stack(
            children: [
              Positioned.fill(
                child: _cells(bar: _MonthGrid(current: current)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(months, current),
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
            ],
          ),
        ],
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
      ],
    );
  }

  Widget _header(List<int> months, int current) {
    final style = TextStyle(
      color: Colors.white.withValues(alpha: .55),
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
    );
    Widget label(String text) =>
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: .12)),
        ),
      ),
      child: _cells(
        pic: label(FixedAssetSummaryStrings.colPic),
        machines: label(FixedAssetSummaryStrings.colMachines),
        bar: Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    i + 1 == current
                        ? FixedAssetSummaryStrings.colMonthCurrent(months[i])
                        : FixedAssetSummaryStrings.colMonth(months[i]),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: i + 1 == current
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
        audited: label(FixedAssetSummaryStrings.statAudited),
        pct: label(FixedAssetSummaryStrings.colPercent),
        behind: label(FixedAssetSummaryStrings.colBehindPlan),
      ),
    );
  }

  Widget _row(FixedAssetSummaryPicRow r) {
    final behind = _behindOf(r);
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
        behind: Text(
          FixedAssetSummaryStrings.behindPlan(behind),
          style: TextStyle(
            color: behind > 0
                ? FixedAssetSummaryColors.orange
                : Colors.white.withValues(alpha: .4),
            fontSize: 15,
            fontWeight: behind > 0 ? FontWeight.w900 : null,
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

/// Ô tìm gọn (cao 32) cho thanh trên card bảng; nút xóa theo text đang gõ
/// (không đợi debounce, không rebuild bảng).
class FixedAssetCompactSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const FixedAssetCompactSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
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
      height: 32,
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
          prefixIconConstraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
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
