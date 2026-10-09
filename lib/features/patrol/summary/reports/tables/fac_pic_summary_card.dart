import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:chuphinh/shared/utils/plant_constants.dart';
import 'package:chuphinh/core/models/pic_summary_response_dto.dart';
import 'package:chuphinh/features/patrol/summary/reports/mobile/pic_summary_mobile_tables.dart';
import 'package:chuphinh/features/patrol/summary/reports/widgets/summary_grid_style.dart';
import 'package:chuphinh/features/patrol/summary/reports/tables/pic_after_table.dart';
import 'package:chuphinh/features/patrol/summary/reports/tables/pic_before_table.dart';
import 'package:chuphinh/features/patrol/summary/reports/tables/pic_recheck_table.dart';

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

  /// Khoảng chừa dưới bảng cho thanh cuộn ngang (desktop), không đè dòng cuối.
  static const double _scrollbarGap = 12;

  /// Vừa khít số dòng; tối đa như mức cũ, quá thì bảng tự cuộn dọc.
  double get _tableHeight {
    final rowCount = widget.fac.displayRows.length;

    final double maxHeight;
    if (rowCount <= 5) {
      maxHeight = 300;
    } else if (rowCount >= 8) {
      maxHeight = 480;
    } else {
      maxHeight = 370;
    }

    return math.min(SummaryGridStyle.fittedTableHeight(rowCount), maxHeight);
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
      height: _tableHeight + _scrollbarGap,
      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        trackVisibility: true,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: _scrollbarGap),
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
    const tone = SummaryGridStyle.summaryTitleText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.45)),
      ),
      child: Text(
        name,
        style: const TextStyle(
          color: tone,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
