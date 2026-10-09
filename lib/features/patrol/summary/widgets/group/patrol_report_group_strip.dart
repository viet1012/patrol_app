import 'package:chuphinh/features/patrol/summary/core/patrol_report_fac_group.dart';
import 'package:chuphinh/features/patrol/summary/widgets/group/patrol_report_fac_segment.dart';
import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

typedef _T = PatrolReportTokens;
typedef _F = PatrolReportFilterBarTokens;

/// Chọn Group; [fac] khác null khi bấm chip trong chế độ "Tất cả Fac".
typedef PatrolReportGroupSelect = void Function(String? group, {String? fac});

/// Cấp 2: dải chip Group cuộn ngang.
///
/// - Chỉ hiện group có số lượng > 0 (chip đang chọn luôn hiện). Bấm lại
///   chip đang chọn = bỏ chọn. Fac = Tất cả và >= 2 Fac: nhóm theo Fac,
///   có nhãn + vạch ngăn. Không còn group nào: chữ mờ "Không có dữ liệu".
/// - Không có thanh cuộn; mờ mép khi còn nội dung khuất; nút ‹ › chỉ hiện
///   khi cuộn được; lăn chuột dọc = cuộn ngang; kéo bằng chuột được;
///   chip đang chọn tự cuộn vào giữa.
class PatrolReportGroupStrip extends StatefulWidget {
  final PatrolReportFacGroups data;
  final String? selectedFac;
  final String? selectedGroup;
  final PatrolReportGroupSelect onSelect;

  const PatrolReportGroupStrip({
    super.key,
    required this.data,
    required this.selectedFac,
    required this.selectedGroup,
    required this.onSelect,
  });

  @override
  State<PatrolReportGroupStrip> createState() => _PatrolReportGroupStripState();
}

class _PatrolReportGroupStripState extends State<PatrolReportGroupStrip> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _selectedKey = GlobalKey();

  bool _canLeft = false;
  bool _canRight = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateEdges);
    _afterLayout(animate: false);
  }

  @override
  void didUpdateWidget(PatrolReportGroupStrip old) {
    super.didUpdateWidget(old);
    final selectionChanged =
        old.selectedFac != widget.selectedFac ||
        old.selectedGroup != widget.selectedGroup;
    _afterLayout(animate: selectionChanged, scrollToSelected: selectionChanged);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _afterLayout({required bool animate, bool scrollToSelected = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (scrollToSelected) _revealSelected(animate: animate);
      _updateEdges();
    });
  }

  void _revealSelected({required bool animate}) {
    final ctx = _selectedKey.currentContext;
    if (ctx == null) {
      if (_scroll.hasClients && widget.selectedGroup == null) {
        animate
            ? _scroll.animateTo(
                0,
                duration: _F.scrollDuration,
                curve: Curves.easeOut,
              )
            : _scroll.jumpTo(0);
      }
      return;
    }
    // Chỉ cuộn dải này (ensureVisible sẽ kéo theo cả trang cuộn dọc).
    final box = ctx.findRenderObject();
    if (box == null || !_scroll.hasClients) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    final p = _scroll.position;
    final target = viewport
        .getOffsetToReveal(box, 0.5)
        .offset
        .clamp(0.0, p.maxScrollExtent);
    animate
        ? _scroll.animateTo(
            target,
            duration: _F.scrollDuration,
            curve: Curves.easeOut,
          )
        : _scroll.jumpTo(target);
  }

  void _updateEdges() {
    if (!_scroll.hasClients || !_scroll.position.hasContentDimensions) return;
    final p = _scroll.position;
    final left = p.pixels > 0.5;
    final right = p.pixels < p.maxScrollExtent - 0.5;
    if (left != _canLeft || right != _canRight) {
      setState(() {
        _canLeft = left;
        _canRight = right;
      });
    }
  }

  void _scrollBy(int direction) {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final target =
        (p.pixels + direction * p.viewportDimension * _F.scrollStepFraction)
            .clamp(0.0, p.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: _F.scrollDuration,
      curve: Curves.easeOutCubic,
    );
  }

  /// Lăn chuột dọc -> cuộn ngang (chỉ khi dải thực sự cuộn được).
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scroll.hasClients) return;
    if (_scroll.position.maxScrollExtent <= 0) return;

    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final s = e as PointerScrollEvent;
      final delta = s.scrollDelta.dy.abs() > s.scrollDelta.dx.abs()
          ? s.scrollDelta.dy
          : s.scrollDelta.dx;
      final p = _scroll.position;
      _scroll.jumpTo((p.pixels + delta).clamp(0.0, p.maxScrollExtent));
    });
  }

  List<Widget> _items() {
    final data = widget.data;
    final fac = widget.selectedFac;
    final group = widget.selectedGroup;
    var keyUsed = false;

    // Ẩn group count = 0, trừ chip đang chọn.
    List<String> visibleGroups(String f) => [
      for (final g in data.groupsByFac[f] ?? const <String>[])
        if (g == group || data.groupCount(f, g) > 0) g,
    ];

    final sections = <(String, List<String>)>[
      for (final f in fac == null ? data.facs : [fac])
        if (visibleGroups(f) case final gs when gs.isNotEmpty) (f, gs),
    ];

    // Nhãn Fac chỉ khi Fac = Tất cả và có từ 2 Fac trở lên.
    final showLabels = fac == null && data.facs.length >= 2;

    final items = <Widget>[];
    for (final (f, groups) in sections) {
      if (showLabels) {
        items.addAll([
          if (items.isNotEmpty) ...[
            const SizedBox(width: _F.facGroupGap),
            Container(width: 1, height: _F.facDividerHeight, color: _T.border),
            const SizedBox(width: _F.facGroupGap),
          ],
          Text(
            f,
            style: const TextStyle(
              color: _T.textMuted,
              fontSize: _T.fsXs,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ]);
      }
      for (final g in groups) {
        final selected = g == group;
        final useKey = selected && !keyUsed;
        if (useKey) keyUsed = true;
        if (items.isNotEmpty) items.add(const SizedBox(width: _F.chipGap));
        items.add(
          _GroupChip(
            key: useKey ? _selectedKey : null,
            label: g,
            count: data.groupCount(f, g),
            selected: selected,
            // Bấm lại chip đang chọn -> bỏ chọn, về tất cả group.
            onTap: () => selected
                ? widget.onSelect(null)
                : widget.onSelect(g, fac: fac == null ? f : null),
          ),
        );
      }
    }
    return items;
  }

  Widget _navButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Center(
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: _T.surfaceRaised,
          shape: const CircleBorder(side: BorderSide(color: _T.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: _F.navButtonSize,
              child: Icon(icon, size: 20, color: _T.textPrimary),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    if (items.isEmpty) {
      return const SizedBox(
        height: _F.segmentHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _F.noDataLabel,
            style: TextStyle(
              color: _T.textMuted,
              fontSize: _T.fsMd,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final strip = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      child: Listener(
        onPointerSignal: _onPointerSignal,
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (_) {
            _updateEdges();
            return false;
          },
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: Row(children: items),
          ),
        ),
      ),
    );

    // Mờ dần ở mép còn nội dung khuất.
    final faded = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final f = rect.width <= 0 ? 0.0 : (_F.fadeWidth / rect.width);
        return LinearGradient(
          colors: [
            _canLeft ? Colors.transparent : Colors.white,
            Colors.white,
            Colors.white,
            _canRight ? Colors.transparent : Colors.white,
          ],
          stops: [0, f.clamp(0.0, 0.5), (1 - f).clamp(0.5, 1.0), 1],
        ).createShader(rect);
      },
      child: strip,
    );

    return SizedBox(
      height: _F.segmentHeight,
      child: Stack(
        children: [
          Positioned.fill(child: faded),
          if (_canLeft)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: _navButton(
                Icons.chevron_left_rounded,
                'Scroll left',
                () => _scrollBy(-1),
              ),
            ),
          if (_canRight)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: _navButton(
                Icons.chevron_right_rounded,
                'Scroll right',
                () => _scrollBy(1),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _GroupChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Badge = 0: mờ nhưng vẫn bấm được.
    return Opacity(
      opacity: count == 0 && !selected ? _F.zeroCountOpacity : 1,
      child: Material(
        color: selected ? _T.accentStrong : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? _T.accentStrong : _T.border,
            width: _F.chipBorderWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: _F.chipHeight,
            padding: const EdgeInsets.only(left: _F.chipPaddingH, right: 6),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : _T.textPrimary,
                    fontSize: _T.fsMd,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                PatrolReportCountBadge(count: count, selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
