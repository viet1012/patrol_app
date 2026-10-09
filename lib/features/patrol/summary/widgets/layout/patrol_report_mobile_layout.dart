import 'dart:math' as math;

import 'package:chuphinh/features/patrol/summary/widgets/layout/patrol_report_layout_parts.dart';
import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';
import 'package:flutter/material.dart';

class PatrolReportMobileLayout extends StatelessWidget {
  final PatrolReportLayoutParts parts;
  final double maxHeight;
  final ScrollController pageScrollController;

  const PatrolReportMobileLayout({
    super.key,
    required this.parts,
    required this.maxHeight,
    required this.pageScrollController,
  });

  /// Pull-to-refresh: nhận từ trang, hoặc từ bảng khi trang đang ở đầu.
  bool _refreshPredicate(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n.depth == 0) return true;
    return !pageScrollController.hasClients || pageScrollController.offset <= 0;
  }

  @override
  Widget build(BuildContext context) {
    // Summary mở: bảng tối thiểu 62% chiều cao; đóng: lấp phần còn lại.
    final minTableHeight = parts.showSummary
        ? math.max(
            maxHeight * kPatrolReportMobileTableHeightRatio,
            kPatrolReportMobileTableMinHeight,
          )
        : kPatrolReportMobileTableMinHeight;

    return Column(
      children: [
        Expanded(
          child: ScrollbarTheme(
            data: patrolReportScrollbarTheme(
              trackColor: Colors.grey.withValues(alpha: 0.8),
            ),
            child: RefreshIndicator(
              onRefresh: parts.onRefresh,
              notificationPredicate: _refreshPredicate,
              color: PatrolReportTokens.accent,
              backgroundColor: PatrolReportTokens.surface,
              child: Scrollbar(
                controller: pageScrollController,
                thumbVisibility: parts.showSummary,
                trackVisibility: parts.showSummary,
                thickness: 10,
                radius: const Radius.circular(999),
                child: CustomScrollView(
                  controller: pageScrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: parts.groupBar),
                    SliverToBoxAdapter(
                      child: AnimatedSize(
                        duration: kPatrolReportSummaryAnimDuration,
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child: parts.showSummary
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: parts.summaryPage,
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Column(
                        children: parts.toolbarSection(compact: true),
                      ),
                    ),
                    // Chiều cao bảng theo phần viewport còn lại -> mượt khi
                    // summary co/giãn.
                    SliverLayoutBuilder(
                      builder: (context, c) {
                        final remaining =
                            c.viewportMainAxisExtent - c.precedingScrollExtent;
                        return SliverToBoxAdapter(
                          child: SizedBox(
                            height: math.max(remaining, minTableHeight),
                            child: parts.table(compact: true),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        parts.pagination(compact: true),
      ],
    );
  }
}
