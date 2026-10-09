import 'package:chuphinh/features/patrol/summary/widgets/layout/patrol_report_layout_parts.dart';
import 'package:flutter/material.dart';

class PatrolReportDesktopLayout extends StatelessWidget {
  final PatrolReportLayoutParts parts;
  final double maxHeight;
  final ScrollController summaryScrollController;

  const PatrolReportDesktopLayout({
    super.key,
    required this.parts,
    required this.maxHeight,
    required this.summaryScrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ScrollbarTheme(
            data: patrolReportScrollbarTheme(trackColor: Colors.grey),
            child: Column(
              children: [
                parts.groupBar,
                AnimatedSwitcher(
                  duration: kPatrolReportSummaryAnimDuration,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: parts.showSummary
                      ? Padding(
                          key: const ValueKey('summary'),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight:
                                  maxHeight *
                                  kPatrolReportSummaryMaxHeightRatio,
                            ),
                            child: Scrollbar(
                              controller: summaryScrollController,
                              child: SingleChildScrollView(
                                controller: summaryScrollController,
                                child: parts.summaryPage,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox(key: ValueKey('summary_empty')),
                ),
                ...parts.toolbarSection(compact: false),
                Expanded(child: parts.table(compact: false)),
              ],
            ),
          ),
        ),
        parts.pagination(compact: false),
      ],
    );
  }
}
