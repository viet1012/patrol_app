import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../camera_preview_box.dart';
import '../homeScreen/patrol_home_screen.dart';
import 'CameraBox.dart';

class ReplaceImagePage extends StatefulWidget {
  final String imageUrl;
  final PatrolGroup patrolGroup;
  final String? plant;

  const ReplaceImagePage({
    super.key,
    required this.imageUrl,
    required this.patrolGroup,
    this.plant,
  });

  @override
  State<ReplaceImagePage> createState() => _ReplaceImagePageState();
}

class _ReplaceImagePageState extends State<ReplaceImagePage> {
  Uint8List? _newImage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Replace Image"),
        actions: [
          if (_newImage != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                Navigator.pop(context, _newImage);
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Current Image",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(widget.imageUrl),
            ),

            const SizedBox(height: 20),
            const Text(
              "Take new image",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            CameraUpdateBox(
              size: 320,
              plant: widget.plant,
              type: "REPLACE",
              patrolGroup: widget.patrolGroup,
              onImagesChanged: (images) {
                if (images.isNotEmpty) {
                  setState(() {
                    _newImage = images.last;
                  });
                }
              },
            ),

            if (_newImage != null) ...[
              const SizedBox(height: 20),
              const Text(
                "Preview new image",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_newImage!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
