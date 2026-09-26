import 'package:chuphinh/camera_preview_box.dart';
import 'package:chuphinh/widget/glass_action_button.dart';
import 'package:flutter/material.dart';

import '../common/common_ui_helper.dart';
import '../homeScreen/patrol_home_screen.dart';
import 'fixed_asset_audit_flow.dart';
import 'fixed_asset_controller.dart';
import 'map/fixed_asset_detected_map.dart';
import 'widgets/fixed_asset_audit_progress_card.dart';
import 'widgets/fixed_asset_location_section.dart';
import 'widgets/fixed_asset_machine_section.dart';
import 'widgets/fixed_asset_manual_selectors.dart';
import 'widgets/fixed_asset_mismatch_dialog.dart';
import 'widgets/fixed_asset_status_card.dart';

export 'fixed_asset_audit_flow.dart' show FixedAssetLocationMode;

/// Màn hình kiểm kê Fixed Asset (AUTO / MANUAL).
///
/// Screen = composition root: tạo [FixedAssetController], tích hợp camera,
/// hiển thị dialog/snackbar (cần BuildContext) và ghép các widget con.
/// Nghiệp vụ scan / audit / save / cascade nằm trong controller.
class FixedAssetScreen extends StatefulWidget {
  final String accountCode;
  final String? selectedPlant;
  final String userName;

  const FixedAssetScreen({
    super.key,
    required this.accountCode,
    this.selectedPlant,
    this.userName = '',
  });

  @override
  State<FixedAssetScreen> createState() => _FixedAssetScreenState();
}

class _FixedAssetScreenState extends State<FixedAssetScreen> {
  final GlobalKey<CameraPreviewBoxState> _cameraKey =
      GlobalKey<CameraPreviewBoxState>();

  late final FixedAssetController _controller;

  /// Camera chỉ build một lần: rebuild của màn hình (search, check,
  /// status...) không rebuild CameraPreviewBox.
  late final Widget _cameraSection = _buildCameraSection();

  @override
  void initState() {
    super.initState();

    _controller = FixedAssetController(
      accountCode: widget.accountCode,
      userName: widget.userName,
      confirmMismatch: _showMismatchDialog,
      showError: _showError,
      resetQr: () => _cameraKey.currentState?.resetQr(),
    )..addListener(_onControllerChanged);

    // AUTO là mặc định: Fac chỉ load khi chuyển sang MANUAL.
    // Summary chạy độc lập, không chặn camera.
    _controller.loadAuditSummary();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  // ============================================================
  // UI CALLBACKS CHO CONTROLLER (cần BuildContext)
  // ============================================================

  void _onQrDetected(String qr) {
    _controller.processScannedQr(qr);
  }

  /// Dialog xác nhận sai vị trí (mapped mismatch / unmapped ACTUAL).
  /// true = "Vẫn lưu".
  Future<bool> _showMismatchDialog(FixedAssetMismatchPrompt prompt) async {
    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FixedAssetMismatchDialog(
        machineCode: prompt.machineCode,
        faName: prompt.faName,
        master: prompt.master,
        actual: prompt.actual,
        unmappedActual: prompt.unmappedActual,
      ),
    );

    return result == true;
  }

  void _showError(String message) {
    if (!mounted) return;
    CommonUI.showSnackBar(
      context: context,
      message: message,
      color: Colors.redAccent,
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final manual = c.manual;
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final String? mapFac;
    final String? mapFloor;
    final String? mapPositionA;
    final String? mapPositionAA;

    if (c.isAutoMode) {
      final location = c.autoLocation;
      mapFac = location?.fac;
      mapFloor = location?.floor;
      mapPositionA = location?.positionA;
      mapPositionAA = location?.positionAA;
    } else {
      mapFac = manual.selectedFac;
      mapFloor = manual.selectedFloor;
      mapPositionA = manual.selectedPositionA;
      mapPositionAA = manual.selectedPositionAA;
    }

    final showDetectedMap = mapPositionA?.trim().isNotEmpty == true;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121826),
        centerTitle: false,
        titleSpacing: 4,
        leading: GlassActionButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fixed Asset',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
            if ((widget.selectedPlant ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.selectedPlant!,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
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
            children: [
              _buildResponsiveCameraSection(isMobile),
              if (showDetectedMap) ...[
                const SizedBox(height: 6),
                FixedAssetDetectedMap(
                  fac: mapFac,
                  floor: mapFloor,
                  positionA: mapPositionA,
                  positionAA: mapPositionAA,
                ),
              ],
              const SizedBox(height: 6),
              FixedAssetStatusCard(
                status: c.scanStatus,
                machineCode: c.scannedCode,
                faName: c.scannedFaName,
                message: c.statusMessage,
                lastAuditedAt: c.lastAuditedAt,
                lastAuditedUserId: c.lastAuditedUserId,
                lastAuditedUserName: c.lastAuditedUserName,
                mismatchMaster: c.mismatchMaster,
              ),
              const SizedBox(height: 6),
              FixedAssetAuditProgressCard(
                summary: c.auditSummary,
                loading: c.loadingAuditSummary,
                error: c.auditSummaryError,
                onRetry: c.loadAuditSummary,
              ),
              SizedBox(height: isMobile ? 6 : 8),
              FixedAssetLocationSection(
                locationMode: c.locationMode,
                autoLocation: c.autoLocation,
                autoUnmappedActual: c.autoUnmappedActual,
                autoLocationMismatch: c.autoLocationMismatch,
                onModeChanged: c.setLocationMode,
                manualSelectors: FixedAssetManualSelectors(
                  selectedFac: manual.selectedFac,
                  selectedFloor: manual.selectedFloor,
                  selectedPositionA: manual.selectedPositionA,
                  selectedPositionAA: manual.selectedPositionAA,
                  facs: manual.facs,
                  floors: manual.floors,
                  positionAs: manual.positionAs,
                  positionAAs: manual.positionAAs,
                  loadingFacs: manual.loadingFacs,
                  loadingFloors: manual.loadingFloors,
                  loadingPositionA: manual.loadingPositionA,
                  loadingPositionAA: manual.loadingPositionAA,
                  onFacChanged: c.onFacChanged,
                  onFloorChanged: c.onFloorChanged,
                  onPositionAChanged: c.onPositionAChanged,
                  onPositionAAChanged: c.onPositionAAChanged,
                ),
              ),
              SizedBox(height: isMobile ? 6 : 8),
              FixedAssetMachineSection(
                visible: c.activeLocation != null,
                machines: c.machines,
                loading: c.loadingMachines,
                error: c.machineError,
                search: c.machineSearch,
                searchController: c.machineSearchController,
                auditedMachineCodes: c.auditedMachineCodes,
                onSearchChanged: c.setMachineSearch,
                onClearSearch: c.clearMachineSearch,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraSection() {
    return SizedBox(
      width: 340,
      height: 340,
      child: RepaintBoundary(
        child: CameraPreviewBox(
          key: _cameraKey,
          size: 340,
          plant: widget.selectedPlant,
          type: PatrolGroup.AssetUpdate.name,
          patrolGroup: PatrolGroup.AssetUpdate,
          onQrDetected: _onQrDetected,
          qrOnly: true,
          enableZoomControls: true,
        ),
      ),
    );
  }

  Widget _buildResponsiveCameraSection(bool isMobile) {
    final displaySize = isMobile ? 260.0 : 340.0;
    return SizedBox.square(
      dimension: displaySize,
      child: FittedBox(fit: BoxFit.contain, child: _cameraSection),
    );
  }
}
