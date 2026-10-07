import 'package:flutter/material.dart';

import 'package:chuphinh/core/api/pic_summary_api.dart';
import 'package:chuphinh/core/models/pic_summary_response_dto.dart';
import 'package:chuphinh/features/patrol/summary/reports/tables/fac_pic_summary_card.dart';

/// Summary theo PIC, mỗi fac 1 card. Tự load lại khi tham số đổi.
class PicSummaryView extends StatefulWidget {
  final String fromD;
  final String toD;
  final String plant;
  final String type;

  const PicSummaryView({
    super.key,
    required this.fromD,
    required this.toD,
    required this.plant,
    required this.type,
  });

  @override
  State<PicSummaryView> createState() => _PicSummaryViewState();
}

class _PicSummaryViewState extends State<PicSummaryView> {
  final PicSummaryApi _api = const PicSummaryApi();
  late Future<PicSummaryResponseDto> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  @override
  void didUpdateWidget(covariant PicSummaryView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final changed =
        oldWidget.fromD != widget.fromD ||
        oldWidget.toD != widget.toD ||
        oldWidget.plant != widget.plant ||
        oldWidget.type != widget.type;

    if (changed) _future = _fetch();
  }

  Future<PicSummaryResponseDto> _fetch() {
    return _api.fetchSummary(
      from: widget.fromD,
      to: widget.toD,
      plant: widget.plant,
      type: widget.type,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PicSummaryResponseDto>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Load failed: ${snapshot.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final facs = snapshot.data?.facs ?? const <FacPicSummaryDto>[];
        if (facs.isEmpty) {
          return const Center(
            child: Text('No data', style: TextStyle(color: Colors.white70)),
          );
        }

        return Column(
          children: [
            for (var i = 0; i < facs.length; i++) ...[
              FacPicSummaryCard(fac: facs[i], selectedPlant: widget.plant),
              if (i != facs.length - 1) const SizedBox(height: 14),
            ],
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
