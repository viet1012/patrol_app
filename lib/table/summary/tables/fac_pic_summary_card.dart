import 'package:flutter/material.dart';

import '../../../common/plant_constants.dart';
import '../../../model/pic_summary_response_dto.dart';
import '../mobile/pic_summary_mobile_tables.dart';
import '../widgets/summary_grid_style.dart';
import 'pic_after_table.dart';
import 'pic_before_table.dart';
import 'pic_recheck_table.dart';

/// Card summary theo PIC của 1 fac: desktop 3 bảng cạnh nhau, mobile xếp dọc.
class FacPicSummaryCard extends StatefulWidget {
  static const double mobileBreakpoint = 900;

  final FacPicSummaryDto fac;

  /// Plant đang chọn; SPC thì chip hiện kèm plant của fac.
  final String selectedPlant;

  const FacPicSummaryCard({
    super.key,
    required this.fac,
    required this.selectedPlant,
  });

  @override
  State<FacPicSummaryCard> createState() => _FacPicSummaryCardState();
}

class _FacPicSummaryCardState extends State<FacPicSummaryCard> {
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  String get _facLabel {
    final fac = widget.fac;
    if (isAllPlant(widget.selectedPlant) && fac.plant.isNotEmpty) {
      return '${fac.plant} · ${fac.fac}';
    }
    return fac.fac;
  }

  double get _tableHeight {
    final rowCount = widget.fac.displayRows.length;

    if (rowCount <= 5) return 300;
    if (rowCount >= 8) return 480;

    return 370;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile =
            constraints.maxWidth < FacPicSummaryCard.mobileBreakpoint;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(SummaryGridStyle.borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FacNameChip(name: _facLabel),
              const SizedBox(height: 10),
              if (isMobile)
                PicSummaryMobileTables(
                  fac: widget.fac,
                  tableHeight: _tableHeight,
                )
              else
                _buildDesktop(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktop() {
    return SizedBox(
      height: _tableHeight,
      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        trackVisibility: true,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: SummaryGridStyle.tableWidth(
                  SummaryGridStyle.beforeColumns,
                ),
                child: PicBeforeTable(fac: widget.fac),
              ),
              const SizedBox(width: SummaryGridStyle.gapBetweenTables),
              SizedBox(
                width: SummaryGridStyle.tableWidth(
                  SummaryGridStyle.afterColumns,
                ),
                child: PicAfterTable(fac: widget.fac),
              ),
              const SizedBox(width: SummaryGridStyle.gapBetweenTables),
              SizedBox(
                width: SummaryGridStyle.tableWidth(
                  SummaryGridStyle.recheckColumns,
                ),
                child: PicRecheckTable(fac: widget.fac),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FacNameChip extends StatelessWidget {
  final String name;

  const _FacNameChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
