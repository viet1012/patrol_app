import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../camera_preview_box.dart';
import '../homeScreen/patrol_home_screen.dart';
import '../model/patrol_report_model.dart';
import 'ReplaceImagePage.dart';

class ReportDetailPage extends StatefulWidget {
  final PatrolReportModel report;

  const ReportDetailPage({super.key, required this.report});

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  final GlobalKey<CameraPreviewBoxState> _cameraKey =
      GlobalKey<CameraPreviewBoxState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Detail')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Group', widget.report.grp),
            _row('Division', widget.report.division),
            _row('Area', widget.report.area),
            _row('Machine', widget.report.machine),

            const SizedBox(height: 12),
            _section('Comment', widget.report.comment),
            _section('Countermeasure', widget.report.countermeasure),

            const SizedBox(height: 16),
            _section('Images', ''),
            _buildImageGrid(widget.report.imageNames),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _section(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(content),
      ],
    );
  }

  Widget _buildImageGrid(List<String> images) {
    if (images.isEmpty) {
      return const Text('No images');
    }

    return SizedBox(
      height: 160, // 👈 chiều cao cố định cho strip ảnh
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () async {
              final replacedImage = await Navigator.push<Uint8List>(
                context,
                MaterialPageRoute(
                  builder: (_) => ReplaceImagePage(
                    imageUrl: 'http://192.168.122.15:7000/${images[index]}',
                    patrolGroup: PatrolGroup.Audit, // truyền group
                    plant: widget.report.plant,
                  ),
                ),
              );

              if (replacedImage != null) {
                setState(() {
                  // TODO: update imageNames[index] sau khi upload server
                });
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.network(
                  'http://192.168.122.15:7000/${images[index]}',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
