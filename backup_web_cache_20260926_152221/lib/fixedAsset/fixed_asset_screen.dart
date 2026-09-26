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
import 'widgets/fixed_asset_selector.dart';
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
    );

    // AUTO là mặc định: Fac chỉ load khi chuyển sang MANUAL.
    // Summary chạy độc lập, không chặn camera.
    _controller.loadAuditSummary();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  // Mỗi section là một rebuild boundary riêng: màn hình không còn
  // setState theo controller, chỉ section có giá trị liên quan đổi mới
  // rebuild (camera, AppBar không bao giờ rebuild theo controller).

  /// Map chỉ rebuild khi location hiển thị đổi (AUTO: autoLocation,
  /// MANUAL: 4 dropdown), không theo summary/machine/search/status.
  Widget _buildDetectedMap() {
    final c = _controller;
    return FixedAssetSelector<
      ({String? fac, String? floor, String? positionA, String? positionAA})
    >(
      listenable: c,
      select: () {
        if (c.isAutoMode) {
          final location = c.autoLocation;
          return (
            fac: location?.fac,
            floor: location?.floor,
            positionA: location?.positionA,
            positionAA: location?.positionAA,
          );
        }
        final manual = c.manual;
        return (
          fac: manual.selectedFac,
          floor: manual.selectedFloor,
          positionA: manual.selectedPositionA,
          positionAA: manual.selectedPositionAA,
        );
      },
      builder: (context, map) {
        final showDetectedMap = map.positionA?.trim().isNotEmpty == true;
        if (!showDetectedMap) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: FixedAssetDetectedMap(
            fac: map.fac,
            floor: map.floor,
            positionA: map.positionA,
            positionAA: map.positionAA,
          ),
        );
      },
    );
  }

  Widget _buildStatusCard() {
    final c = _controller;
    return FixedAssetSelector(
      listenable: c,
      select: () => (
        status: c.scanStatus,
        machineCode: c.scannedCode,
        faName: c.scannedFaName,
        message: c.statusMessage,
        lastAuditedAt: c.lastAuditedAt,
        lastAuditedUserId: c.lastAuditedUserId,
        lastAuditedUserName: c.lastAuditedUserName,
        mismatchMaster: c.mismatchMaster,
      ),
      builder: (context, v) => FixedAssetStatusCard(
        status: v.status,
        machineCode: v.machineCode,
        faName: v.faName,
        message: v.message,
        lastAuditedAt: v.lastAuditedAt,
        lastAuditedUserId: v.lastAuditedUserId,
        lastAuditedUserName: v.lastAuditedUserName,
        mismatchMaster: v.mismatchMaster,
      ),
    );
  }

  Widget _buildAuditProgressCard() {
    final c = _controller;
    return FixedAssetSelector(
      listenable: c,
      select: () => (
        summary: c.auditSummary,
        loading: c.loadingAuditSummary,
        error: c.auditSummaryError,
      ),
      builder: (context, v) => FixedAssetAuditProgressCard(
        summary: v.summary,
        loading: v.loading,
        error: v.error,
        onRetry: c.loadAuditSummary,
      ),
    );
  }

  /// Location + MANUAL cascade phụ thuộc ~20 field (mode, auto location,
  /// 4 dropdown + list + loading): rebuild theo mọi notify cho chắc chắn
  /// đúng; section nhẹ, không chứa map/machine list.
  Widget _buildLocationSection() {
    final c = _controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final manual = c.manual;
        return FixedAssetLocationSection(
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
        );
      },
    );
  }

  /// auditedMachineCodes bị mutate tại chỗ (chỉ thêm): length là version.
  /// Filter/sort vẫn cache bên trong FixedAssetMachineSection.
  Widget _buildMachineSection() {
    final c = _controller;
    return FixedAssetSelector(
      listenable: c,
      select: () => (
        visible: c.activeLocation != null,
        machines: c.machines,
        loading: c.loadingMachines,
        error: c.machineError,
        search: c.machineSearch,
        audited: c.auditedMachineCodes,
        auditedCount: c.auditedMachineCodes.length,
      ),
      builder: (context, v) => FixedAssetMachineSection(
        visible: v.visible,
        machines: v.machines,
        loading: v.loading,
        error: v.error,
        search: v.search,
        searchController: c.machineSearchController,
        auditedMachineCodes: v.audited,
        onSearchChanged: c.setMachineSearch,
        onClearSearch: c.clearMachineSearch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

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
              _buildDetectedMap(),
              const SizedBox(height: 6),
              _buildStatusCard(),
              const SizedBox(height: 6),
              _buildAuditProgressCard(),
              SizedBox(height: isMobile ? 6 : 8),
              _buildLocationSection(),
              SizedBox(height: isMobile ? 6 : 8),
              _buildMachineSection(),
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
          showQrNumber: false,
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
