import 'dart:io';
import 'package:chuphinh/reason_model.dart';
import 'package:chuphinh/take_picture_screen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import 'machine_model.dart';

// ===================== MAIN SCREEN =====================
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  XFile? _image;
  String? _selectedDiv = 'PE';
  String? _selectedMachine;
  String _comment = '';
  String? _selectedReason1;
  String? _selectedReason2;

  List<String> getDivisions() {
    return machines
        .map((m) => m.division?.toString())
        .where((d) => d != null && d!.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
  }

  List<String> getMachineByDivision(String division) {
    return machines
        .where((m) => m.division?.toString() == division)
        .map((m) => m.machineType?.toString())
        .where((g) => g != null && g.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
  }

  Future<void> _openCamera() async {
    final result = await Navigator.push<XFile?>(
      context,
      MaterialPageRoute(builder: (context) => const TakePictureScreen()),
    );

    if (result != null) {
      setState(() {
        _image = result;
      });
    }
  }

  void _clearImage() {
    setState(() {
      _image = null;
    });
  }

  void _showSubmitDialog() {
    if (_image == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chụp hình trước')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận thông tin'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_image != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_image!.path),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 16),
              _buildDialogText('Division:', _selectedDiv),
              _buildDialogText('Machine:', _selectedMachine),
              _buildDialogText('Comment:', _comment),
              _buildDialogText('Tiêu chuẩn 1:', _selectedReason1),
              _buildDialogText('Tiêu chuẩn 2:', _selectedReason2),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✓ Dữ liệu đã được gửi')),
              );
              _resetForm();
            },
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _image = null;
      _selectedDiv = 'PE';
      _selectedMachine = null;
      _comment = '';
      _selectedReason1 = null;
      _selectedReason2 = null;
    });
  }

  Widget _buildDialogText(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            TextSpan(
              text: ' ${value ?? 'N/A'}',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final divs = getDivisions();
    final machineList = _selectedDiv != null
        ? getMachineByDivision(_selectedDiv!)
        : <String>[];

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Responsive sizes
    final imageHeight = isTablet
        ? (isLandscape ? 300.0 : 400.0)
        : (isLandscape ? 200.0 : 300.0);
    final padding = isTablet ? 24.0 : 16.0;
    final labelFontSize = isTablet ? 14.0 : 13.0;
    final buttonHeight = isTablet ? 56.0 : 48.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Inspection'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Preview Section
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: imageHeight,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade300, width: 2),
                  ),
                  child: _image != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(_image!.path),
                            fit: BoxFit.contain,
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported_outlined,
                                size: isTablet ? 64 : 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ảnh sẽ hiển thị ở đây',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: isTablet ? 16 : 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                // Camera Button (Floating)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _openCamera,
                    child: Container(
                      width: isTablet ? 68 : 56,
                      height: isTablet ? 68 : 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.shade600,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade600.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: isTablet ? 32 : 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: padding),

            // Form Section - Responsive Grid
            _buildLabel('Div Group Machine', labelFontSize),
            _buildDropdownContainer(
              child: DropdownButton<String>(
                value: _selectedDiv,
                isExpanded: true,
                underline: const SizedBox(),
                items: divs.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        value,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: isTablet ? 16 : 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedDiv = newValue;
                    _selectedMachine = null;
                  });
                },
              ),
            ),
            SizedBox(height: padding * 0.67),

            _buildLabel('Machine', labelFontSize),
            _buildDropdownContainer(
              child: DropdownButton<String>(
                value: _selectedMachine,
                isExpanded: true,
                underline: const SizedBox(),
                hint: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "Chọn máy",
                    style: TextStyle(fontSize: isTablet ? 16 : 14),
                  ),
                ),
                items: machineList.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        value,
                        style: TextStyle(fontSize: isTablet ? 16 : 14),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedMachine = newValue;
                  });
                },
              ),
            ),
            SizedBox(height: padding * 0.67),

            _buildLabel('Comment', labelFontSize),
            TextField(
              onChanged: (value) => setState(() => _comment = value),
              decoration: InputDecoration(
                hintText: 'Ghi chú thêm...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.all(12),
              ),
              minLines: 3,
              maxLines: 5,
              style: TextStyle(fontSize: isTablet ? 16 : 14),
            ),
            SizedBox(height: padding * 0.67),

            // Responsive Standards Section
            isTablet
                ? Row(
                    children: [
                      Expanded(
                        child: _buildStandardColumn(
                          'Tiêu chuẩn 1',
                          _selectedReason1,
                          (v) => setState(() => _selectedReason1 = v),
                          labelFontSize,
                          isTablet,
                        ),
                      ),
                      SizedBox(width: padding * 0.5),
                      Expanded(
                        child: _buildStandardColumn(
                          'Tiêu chuẩn 2',
                          _selectedReason2,
                          (v) => setState(() => _selectedReason2 = v),
                          labelFontSize,
                          isTablet,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildStandardColumn(
                        'Tiêu chuẩn 1',
                        _selectedReason1,
                        (v) => setState(() => _selectedReason1 = v),
                        labelFontSize,
                        isTablet,
                      ),
                      SizedBox(height: padding * 0.67),
                      _buildStandardColumn(
                        'Tiêu chuẩn 2',
                        _selectedReason2,
                        (v) => setState(() => _selectedReason2 = v),
                        labelFontSize,
                        isTablet,
                      ),
                    ],
                  ),

            SizedBox(height: padding),

            // Button Section - Responsive
            SizedBox(
              width: double.infinity,
              height: buttonHeight,
              child: ElevatedButton(
                onPressed: _showSubmitDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Gửi',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(height: padding * 0.5),

            if (_image != null)
              SizedBox(
                width: double.infinity,
                height: buttonHeight,
                child: OutlinedButton(
                  onPressed: _clearImage,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade400, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Xóa ảnh',
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
              ),
            SizedBox(height: padding),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardColumn(
    String label,
    String? value,
    Function(String?) onChanged,
    double fontSize,
    bool isTablet,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, fontSize),
        _buildDropdownContainer(
          child: DropdownButton<String>(
            isExpanded: true,
            hint: Text(
              "Chọn mức độ",
              style: TextStyle(fontSize: isTablet ? 16 : 14),
            ),
            underline: const SizedBox(),
            value: value,
            items: reasonList.map((r) {
              return DropdownMenuItem(
                value: r.reason1,
                child: Text(
                  r.reason1,
                  style: TextStyle(fontSize: isTablet ? 16 : 14),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade300, width: 1.5),
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue.shade50,
      ),
      child: child,
    );
  }

  Widget _buildLabel(String text, double fontSize) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }
}

// ===================== TAKE PICTURE SCREEN =====================
