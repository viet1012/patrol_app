import 'package:chuphinh/features/patrol/summary/widgets/header/patrol_report_header_filter_cell.dart';
import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';
import 'package:flutter/material.dart';

typedef _T = PatrolReportTokens;

/// Bảng có header dính + (tuỳ chọn) nhóm cột pinned bên trái.
///
/// Phần pinned và phần cuộn ngang là 2 ListView dọc riêng, đồng bộ offset
/// với nhau; header của mỗi phần dùng cùng danh sách cột với các dòng.
class PatrolReportTableViewport extends StatefulWidget {
  final ScrollController horizontalController;
  final ScrollController verticalController;

  final double pinnedWidth;
  final double scrollWidth;
  final Widget? pinnedHeader;
  final Widget header;
  final int itemCount;
  final IndexedWidgetBuilder? pinnedRowBuilder;
  final IndexedWidgetBuilder rowBuilder;

  /// Hiện dưới header (không cuộn ngang) khi `itemCount == 0`.
  final Widget? emptyPlaceholder;

  const PatrolReportTableViewport({
    super.key,
    required this.horizontalController,
    required this.verticalController,
    required this.scrollWidth,
    required this.header,
    required this.itemCount,
    required this.rowBuilder,
    this.pinnedWidth = 0,
    this.pinnedHeader,
    this.pinnedRowBuilder,
    this.emptyPlaceholder,
  });

  @override
  State<PatrolReportTableViewport> createState() =>
      _PatrolReportTableViewportState();
}

class _PatrolReportTableViewportState extends State<PatrolReportTableViewport> {
  static const double _headerExtent = PatrolReportHeaderFilterCell.height + 1;

  final ScrollController _pinnedVertical = ScrollController();
  bool _syncing = false;
  bool _scrolledH = false;

  bool get _hasPinned =>
      widget.pinnedRowBuilder != null &&
      widget.pinnedHeader != null &&
      widget.pinnedWidth > 0;

  @override
  void initState() {
    super.initState();
    _attach(widget);
  }

  @override
  void didUpdateWidget(PatrolReportTableViewport old) {
    super.didUpdateWidget(old);
    if (old.verticalController != widget.verticalController ||
        old.horizontalController != widget.horizontalController) {
      _detach(old);
      _attach(widget);
    }
  }

  @override
  void dispose() {
    _detach(widget);
    _pinnedVertical.dispose();
    super.dispose();
  }

  void _attach(PatrolReportTableViewport w) {
    w.verticalController.addListener(_onMainVertical);
    _pinnedVertical.addListener(_onPinnedVertical);
    w.horizontalController.addListener(_onHorizontal);
  }

  void _detach(PatrolReportTableViewport w) {
    w.verticalController.removeListener(_onMainVertical);
    _pinnedVertical.removeListener(_onPinnedVertical);
    w.horizontalController.removeListener(_onHorizontal);
  }

  void _sync(ScrollController from, ScrollController to) {
    if (_syncing || !from.hasClients || !to.hasClients) return;
    if (to.offset == from.offset) return;
    _syncing = true;
    to.jumpTo(from.offset.clamp(0, to.position.maxScrollExtent));
    _syncing = false;
  }

  void _onMainVertical() => _sync(widget.verticalController, _pinnedVertical);

  void _onPinnedVertical() => _sync(_pinnedVertical, widget.verticalController);

  void _onHorizontal() {
    final c = widget.horizontalController;
    final scrolled = c.hasClients && c.offset > 0.5;
    if (scrolled != _scrolledH) setState(() => _scrolledH = scrolled);
  }

  Widget _list({
    required ScrollController controller,
    required IndexedWidgetBuilder builder,
    required bool showScrollbar,
  }) {
    final list = ListView.builder(
      controller: controller,
      primary: false,
      itemCount: widget.itemCount,
      itemBuilder: builder,
    );
    if (!showScrollbar) {
      // Ẩn scrollbar của list pinned (đã có ở phần cuộn).
      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: list,
      );
    }
    return PrimaryScrollController(
      controller: controller,
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        child: list,
      ),
    );
  }

  Widget _section({required Widget header, required Widget body}) {
    return Column(
      children: [
        header,
        const Divider(height: 1, thickness: 1, color: _T.tableDivider),
        Expanded(child: body),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scrolling = Scrollbar(
      controller: widget.horizontalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: widget.horizontalController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: widget.scrollWidth,
          child: _section(
            header: widget.header,
            body: _list(
              controller: widget.verticalController,
              builder: widget.rowBuilder,
              showScrollbar: true,
            ),
          ),
        ),
      ),
    );

    Widget table = scrolling;
    if (_hasPinned) {
      final pinned = AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _T.surface,
          // Bóng mờ ở mép phải khi đã cuộn ngang.
          boxShadow: _scrolledH
              ? const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 8,
                    offset: Offset(3, 0),
                  ),
                ]
              : const [],
        ),
        child: _section(
          header: widget.pinnedHeader!,
          body: _list(
            controller: _pinnedVertical,
            builder: widget.pinnedRowBuilder!,
            showScrollbar: false,
          ),
        ),
      );

      // Pinned vẽ sau để bóng đổ đè lên phần cuộn.
      table = Stack(
        children: [
          Positioned.fill(
            left: widget.pinnedWidth,
            child: ClipRect(child: scrolling),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: widget.pinnedWidth,
            child: pinned,
          ),
        ],
      );
    }

    final empty = widget.emptyPlaceholder;

    return Card(
      elevation: 2,
      color: _T.surface,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.fromLTRB(_T.s12, _T.s8, _T.s12, _T.s8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_T.r10),
        side: const BorderSide(color: _T.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: widget.itemCount == 0 && empty != null
          ? Stack(
              children: [
                table,
                Positioned.fill(top: _headerExtent, child: empty),
              ],
            )
          : table,
    );
  }
}
