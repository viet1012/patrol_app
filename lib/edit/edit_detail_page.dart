import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' hide MultipartFile;

import '../api/api_config.dart';
import '../api/dio_client.dart';
import '../camera_preview_box.dart';
import 'edit_image_item.dart';
import '../homeScreen/patrol_home_screen.dart';
import '../model/patrol_report_model.dart';
import '../widget/glass_action_button.dart';
import 'camera_edit_box.dart';

class EditDetailPage extends StatefulWidget {
  final PatrolReportModel report;
  final PatrolGroup patrolGroup;
  const EditDetailPage({
    super.key,
    required this.report,
    required this.patrolGroup,
  });

  @override
  State<EditDetailPage> createState() => _EditDetailPageState();
}

class _EditDetailPageState extends State<EditDetailPage> {
  final GlobalKey<CameraEditBoxState> _cameraKey =
      GlobalKey<CameraEditBoxState>();

  bool _enableCamera = false;

  final TextEditingController _commentCtrl = TextEditingController();
  final TextEditingController _msnvCtrl = TextEditingController();
  String? _employeeName;
  bool _isLoadingName = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _commentCtrl.dispose();
    _msnvCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 4, // 👈 kéo sát về leading
        leading: GlassActionButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context, true),
        ),
        backgroundColor: const Color(0xFF121826),
        title: Column(
          children: [
            Text(
              'Edit Detail',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
            Text(
              widget.report.plant,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF121826), Color(0xFF1F2937), Color(0xFF374151)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== 2 cột thông tin =====
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoItem('Group', widget.report.grp),
                        _infoItem('Area', widget.report.area),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoItem('Division', widget.report.division),
                        _infoItem('Machine', widget.report.machine),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ===== Comment & Countermeasure =====
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _sectionInline('Comment', widget.report.comment),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: _sectionInline(
                      'Countermeasure',
                      widget.report.countermeasure,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              _buildImageGrid(widget.report.imageNames),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(color: Colors.white.withOpacity(0.85)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionInline(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          content.isEmpty ? '-' : content,
          style: TextStyle(color: Colors.white.withOpacity(0.85)),

          maxLines: 6,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildImageGrid(List<String> images) {
    final h = MediaQuery.of(context).size.height;

    return SizedBox(
      height: 320, // 👈 đủ cho image + camera
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 280,
            child: EditImageItem(
              imageName: images[index],
              report: widget.report,
              patrolGroup: widget.patrolGroup,
              plant: widget.report.plant,

              /// ➕ ADD
              onAdd: (newImage) {
                setState(() {
                  widget.report.imageNames.add(newImage);
                });
              },

              /// 🗑 DELETE
              onDelete: () {
                setState(() {
                  widget.report.imageNames.removeAt(index);
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildThumbPreview() {
    if (_cameraKey.currentState == null ||
        _cameraKey.currentState!.images.isEmpty) {
      return const SizedBox();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _cameraKey.currentState!.images.asMap().entries.map((entry) {
          final idx = entry.key;
          final img = entry.value;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    img,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),

                /// ❌ REMOVE
                Positioned(
                  top: -4,
                  right: -4,
                  child: GestureDetector(
                    onTap: () {
                      _cameraKey.currentState?.removeImage(idx);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
