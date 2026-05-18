import 'package:flutter/material.dart';

import '../patrol_summary_chart_page.dart';
import 'patrol_pic_summary_page.dart';

class PatrolSummaryTabPage extends StatelessWidget {
  final String plant;

  final String patrolGroup;

  final DateTime? fromD;

  final DateTime? toD;

  final void Function(String grp, String division)? onSelect;

  final void Function(DateTime from, DateTime to)? onDateChanged;

  const PatrolSummaryTabPage({
    super.key,
    required this.plant,
    required this.patrolGroup,
    this.fromD,
    this.toD,
    this.onSelect,
    this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,

      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          ////////////////////////////////////////////////////////////
          /// TAB BAR
          ////////////////////////////////////////////////////////////
          Container(
            height: 52,

            padding: const EdgeInsets.all(4),

            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),

              borderRadius: BorderRadius.circular(14),

              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),

            child: TabBar(
              dividerColor: Colors.transparent,

              indicator: BoxDecoration(
                color: Colors.white,

                borderRadius: BorderRadius.circular(10),

                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Colors.black87,
              unselectedLabelColor: Colors.black54,
              tabs: const [
                Tab(
                  icon: Icon(Icons.warning_amber_rounded, size: 18),
                  text: 'Risk Summary',
                ),

                Tab(
                  icon: Icon(Icons.person_outline_rounded, size: 18),
                  text: 'PIC Summary',
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          ////////////////////////////////////////////////////////////
          /// TAB VIEW
          ////////////////////////////////////////////////////////////
          SizedBox(
            height: 520,

            child: TabBarView(
              physics: const BouncingScrollPhysics(),

              children: [
                //////////////////////////////////////////////////////
                /// TAB 1
                //////////////////////////////////////////////////////
                SingleChildScrollView(
                  child: PatrolRiskSummarySfPage(
                    onSelect: onSelect,
                    onDateChanged: onDateChanged,
                    plant: plant,
                    patrolGroup: patrolGroup,
                    fromD: fromD,
                    toD: toD,
                  ),
                ),

                //////////////////////////////////////////////////////
                /// TAB 2
                //////////////////////////////////////////////////////
                SingleChildScrollView(
                  child: PatrolPicSummaryPage(
                    plant: plant,
                    fromD: fromD,
                    toD: toD,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
