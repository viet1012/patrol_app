import 'package:flutter/material.dart';

class PatrolReportTableViewport extends StatelessWidget {
  final ScrollController horizontalController;
  final ScrollController verticalController;
  final double totalWidth;
  final Widget header;
  final int itemCount;
  final IndexedWidgetBuilder rowBuilder;

  const PatrolReportTableViewport({
    super.key,
    required this.horizontalController,
    required this.verticalController,
    required this.totalWidth,
    required this.header,
    required this.itemCount,
    required this.rowBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: horizontalController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: horizontalController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: Column(
              children: [
                header,
                const Divider(height: 1, thickness: 1),
                Expanded(
                  child: PrimaryScrollController(
                    controller: verticalController,
                    child: Scrollbar(
                      controller: verticalController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: verticalController,
                        primary: false,
                        itemCount: itemCount,
                        itemBuilder: rowBuilder,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
