import 'package:flutter/material.dart';

import '../../../api/summary_api.dart';
import '../../../model/division_summary.dart';
import '../../../widget/glass_action_button.dart';
import '../tables/patrol_facility_summary_table.dart';
import '../widgets/division_summary_table.dart';

class BeforeAfterSummaryDialog extends StatefulWidget {
  final String fromD;
  final String toD;
  final String fac;
  final String type;

  const BeforeAfterSummaryDialog({
    super.key,
    required this.fromD,
    required this.toD,
    required this.fac,
    required this.type,
  });

  static Future<void> show(
    BuildContext context, {
    required String fromD,
    required String toD,
    required String fac,
    required String type,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => BeforeAfterSummaryDialog(
        fromD: fromD,
        toD: toD,
        fac: fac,
        type: type,
      ),
    );
  }

  @override
  State<BeforeAfterSummaryDialog> createState() =>
      _BeforeAfterSummaryDialogState();
}

class _BeforeAfterSummaryDialogState extends State<BeforeAfterSummaryDialog> {
  static const double _compactHeaderBreakpoint = 520;

  final SummaryApi _api = const SummaryApi();
  final ScrollController _tableHCtrl = ScrollController();
  late final Future<List<DivisionSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchDivisionSummary(
      fromD: widget.fromD,
      toD: widget.toD,
      fac: widget.fac,
      type: widget.type,
    );
  }

  @override
  void dispose() {
    _tableHCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screen.width - 16,
          maxHeight: screen.height,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF121826), Color(0xFF1F2937), Color(0xFF374151)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                blurRadius: 24,
                spreadRadius: 2,
                color: Colors.black.withOpacity(0.35),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(),
              Divider(color: Colors.white.withOpacity(0.08), height: 1),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassActionButton(
                icon: Icons.close_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryHeaderText(
                  fac: widget.fac,
                  fromD: widget.fromD,
                  toD: widget.toD,
                  type: widget.type,
                  compact: constraints.maxWidth < _compactHeaderBreakpoint,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<List<DivisionSummary>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snap.hasError) {
                return Text(
                  'Load failed: ${snap.error}',
                  style: const TextStyle(color: Colors.redAccent),
                );
              }

              final rows = snap.data ?? const <DivisionSummary>[];
              if (rows.isEmpty) {
                return const Text(
                  'No data',
                  style: TextStyle(color: Colors.white70),
                );
              }

              return DivisionSummaryTable(rows: rows, controller: _tableHCtrl);
            },
          ),
          const SizedBox(height: 8),
          PatrolFacilitySummaryTable(
            fromD: widget.fromD,
            toD: widget.toD,
            plant: widget.fac,
            type: widget.type,
          ),
        ],
      ),
    );
  }
}

/// Tiêu đề + khoảng ngày của dialog; [compact] xếp dọc cho màn hình hẹp.
class _SummaryHeaderText extends StatelessWidget {
  final String fac;
  final String fromD;
  final String toD;
  final String type;
  final bool compact;

  const _SummaryHeaderText({
    required this.fac,
    required this.fromD,
    required this.toD,
    required this.type,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final title = 'HSE PATROL SUMMARY → $fac';

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$fromD → $toD • $type',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            '$fromD → $toD   •   $type',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
