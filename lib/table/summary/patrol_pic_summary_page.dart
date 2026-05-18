import 'package:flutter/material.dart';

import '../../api/patrol_pic_summary_api.dart';
import '../../model/patrol_pic_summary.dart';
import 'patrol_pic_summary_chart.dart';

class PatrolPicSummaryPage extends StatefulWidget {
  final String plant;

  final DateTime? fromD;

  final DateTime? toD;

  const PatrolPicSummaryPage({
    super.key,
    required this.plant,
    this.fromD,
    this.toD,
  });

  @override
  State<PatrolPicSummaryPage> createState() => _PatrolPicSummaryPageState();
}

class _PatrolPicSummaryPageState extends State<PatrolPicSummaryPage> {
  late final PatrolPicSummaryApi api;

  bool loading = true;

  String? error;

  List<PatrolPicSummary> items = [];

  @override
  void initState() {
    super.initState();

    api = PatrolPicSummaryApi();

    _fetch();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _fetch() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final now = DateTime.now();

      final from = widget.fromD ?? DateTime(now.year, now.month, 1);

      final to = widget.toD ?? DateTime(now.year, now.month, now.day);

      final res = await api.fetchPicSummary(
        fromDate: _fmt(from),
        toDate: _fmt(to),
        plant: widget.plant,
      );

      if (!mounted) return;

      setState(() {
        loading = false;
        items = res;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(child: Text(error!));
    }

    if (items.isEmpty) {
      return const Center(child: Text('No data'));
    }

    return Padding(
      padding: const EdgeInsets.all(12),

      child: Card(
        elevation: 1.5,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),

        child: Padding(
          padding: const EdgeInsets.all(12),

          child: SizedBox(
            height: items.length * 70,

            child: PatrolPicSummaryChart(items: items),
          ),
        ),
      ),
    );
  }
}
