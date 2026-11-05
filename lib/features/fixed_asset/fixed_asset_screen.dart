import 'package:chuphinh/shared/camera/camera_preview_box.dart';
import 'package:chuphinh/shared/widgets/glass_action_button.dart';
import 'package:chuphinh/shared/widgets/required_field_flash.dart';
import 'package:flutter/material.dart';

import 'package:chuphinh/shared/widgets/common_ui_helper.dart';
import 'package:chuphinh/core/models/patrol_group.dart';
import 'package:chuphinh/core/models/fixed_asset_zone_progress.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_audit_flow.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_controller.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_location.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_pic_filter.dart';
import 'package:chuphinh/features/fixed_asset/map/fixed_asset_detected_map.dart';
import 'package:chuphinh/features/fixed_asset/no_qr/no_qr_entry.dart';
import 'package:chuphinh/features/fixed_asset/no_qr/no_qr_report.dart';
import 'package:chuphinh/features/fixed_asset/no_qr/no_qr_report_service.dart';
import 'package:chuphinh/features/fixed_asset/no_qr/no_qr_report_sheet.dart';
import 'package:chuphinh/features/fixed_asset/no_qr/no_qr_strings.dart';
import 'package:chuphinh/features/fixed_asset/widgets/fixed_asset_audit_progress_card.dart';
import 'package:chuphinh/features/fixed_asset/widgets/fixed_asset_location_section.dart';
import 'package:chuphinh/features/fixed_asset/widgets/fixed_asset_machine_section.dart';
import 'package:chuphinh/features/fixed_asset/widgets/fixed_asset_manual_selectors.dart';
import 'package:chuphinh/features/fixed_asset/widgets/fixed_asset_mismatch_dialog.dart';
import 'package:chuphinh/features/fixed_asset/widgets/fixed_asset_pic_selector.dart';
import 'package:chuphinh/features/fixed_asset/widgets/fixed_asset_qr_mismatch_dialog.dart';
import 'package:chuphinh/features/fixed_asset/widgets/fixed_asset_reprint_move_dialog.dart';
import 'package:chuphinh/features/fixed_asset/widgets/fixed_asset_selector.dart';
import 'package:chuphinh/features/fixed_asset/widgets/fixed_asset_scan_chip.dart';
import 'package:chuphinh/features/fixed_asset/widgets/fixed_asset_status_card.dart';

/// Màn hình kiểm kê Fixed Asset: chọn đủ Fac / Floor / PositionA /
/// PositionAA thì camera mới bật và QR mới được xử lý.
///
/// Screen = composition root: tạo [FixedAssetController], tích hợp camera,
/// hiển thị dialog/snackbar (cần BuildContext) và ghép các widget con.
/// Nghiệp vụ scan / audit / save / cascade nằm trong controller.
class FixedAssetScreen extends StatefulWidget {
  final String accountCode;
  final String? selectedPlant;
  final String userName;

  /// currentLang của app (VI / EN / JA), cho nhập giọng nói.
  final String lang;

  /// Mở sẵn theo PIC (email; ghi vào PIC chung của phiên) và vị trí đủ 4 ô
  /// (camera bật ngay). null = như bình thường.
  final String? initialPic;
  final FixedAssetAuditLocation? initialLocation;

  const FixedAssetScreen({
    super.key,
    required this.accountCode,
    this.selectedPlant,
    this.userName = '',
    this.lang = 'VI',
    this.initialPic,
    this.initialLocation,
  });

  @override
  State<FixedAssetScreen> createState() => _FixedAssetScreenState();
}

class _FixedAssetScreenState extends State<FixedAssetScreen>
    with WidgetsBindingObserver {
  final GlobalKey<CameraPreviewBoxState> _cameraKey =
      GlobalKey<CameraPreviewBoxState>();

  late final FixedAssetController _controller;

  /// Case "máy thiếu QR" của phiên (lưu qua POST /audit, mode NO_QR).
  late final NoQrReportService _noQrService = NoQrReportService(
    userId: widget.accountCode,
    userName: widget.userName,
  );
  static const String _noQrPauseReason = 'no_qr_sheet';
  bool _noQrSheetOpen = false;

  /// Machine list: rebuild theo controller và theo case thiếu QR.
  late final Listenable _machineListenable = Listenable.merge([
    _controller,
    _noQrService,
  ]);

  final _facFlashKey = GlobalKey<RequiredFieldFlashState>();
  final _floorFlashKey = GlobalKey<RequiredFieldFlashState>();
  final _positionAFlashKey = GlobalKey<RequiredFieldFlashState>();
  final _positionAAFlashKey = GlobalKey<RequiredFieldFlashState>();
  QrDetectionGeometry? _latestQrDetection;

  /// Camera chỉ rebuild khi [FixedAssetController.canScan] đổi: rebuild của
  /// màn hình (search, check, status...) không rebuild CameraPreviewBox.
  late final Widget _cameraSection = FixedAssetSelector(
    listenable: _controller,
    select: () => _controller.canScan,
    builder: (context, canScan) => _buildCameraSection(canScan),
  );

  @override
  void initState() {
    super.initState();

    // PIC phải có trước khi tạo controller (controller đọc PIC của phiên).
    final initialPic = widget.initialPic?.trim() ?? '';
    if (initialPic.isNotEmpty) {
      FixedAssetPicSession.selected.value = initialPic;
    }
    _controller = FixedAssetController(
      accountCode: widget.accountCode,
      userName: widget.userName,
      confirmMismatch: _showMismatchDialog,
      confirmQrMismatch: _showQrMismatchDialog,
      confirmReprintMove: _showReprintMoveDialog,
      showError: _showError,
      showNotice: _showNotice,
      resetQr: () => _cameraKey.currentState?.resetQr(),
      onScanAccepted: (rawQr, machineCode) {
        final detailedMatches = _latestQrDetection?.value == rawQr;
        if (!detailedMatches) _latestQrDetection = null;
        _cameraKey.currentState?.showAcceptedQrLock(rawQr, machineCode);
      },
      // Cùng cách chụp ảnh ở Thay QR: frame của camera đang mở.
      capturePhoto: () =>
          _cameraKey.currentState?.captureFrameJpeg(
            maxEdge: 1280,
            quality: .75,
          ) ??
          Future.value(),
      showScanNotice: (message) =>
          _cameraKey.currentState?.showQrNotice(message),
    );

    // Summary chạy độc lập, không chặn camera.
    _controller.loadAuditSummary();
    // Tải Fac + nhấp nháy ô trống đầu tiên.
    _controller.start(initialLocation: widget.initialLocation);
    _flashFirstMissingManualField();

    WidgetsBinding.instance.addObserver(this);
  }

  /// Gỡ observer ở deactivate: nếu dispose() của một widget con ném lỗi,
  /// Flutter bỏ dở unmount và dispose() của màn này không chạy, nhưng
  /// deactivate() luôn chạy. Không thì resume app vẫn gọi API Fixed Asset.
  @override
  void deactivate() {
    WidgetsBinding.instance.removeObserver(this);
    super.deactivate();
  }

  /// Reparent (GlobalKey): deactivate -> activate, gắn lại observer.
  @override
  void activate() {
    super.activate();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _noQrService.dispose();
    super.dispose();
  }

  /// Quay lại foreground: tải lại số theo kỳ (có thể đã sang kỳ mới).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _controller.refreshZoneProgress();
    _controller.loadAuditSummary();
  }

  // ============================================================
  // UI CALLBACKS CHO CONTROLLER (cần BuildContext)
  // ============================================================

  GlobalKey<RequiredFieldFlashState> _flashKeyFor(
    FixedAssetManualField field,
  ) => switch (field) {
    FixedAssetManualField.fac => _facFlashKey,
    FixedAssetManualField.floor => _floorFlashKey,
    FixedAssetManualField.positionA => _positionAFlashKey,
    FixedAssetManualField.positionAA => _positionAAFlashKey,
  };

  /// Mở màn hình: ô trống đầu tiên nhấp nháy một lần (không cuộn).
  void _flashFirstMissingManualField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final field = _controller.firstMissingManualField;
      if (field != null) _flashKeyFor(field).currentState?.flash();
    });
  }

  void _onQrDetected(String qr) {
    _controller.uxLog('camera detect "$qr"');
    // Chốt chặn chung (chưa đủ vị trí -> bỏ qua) nằm trong controller.
    final camera = _cameraKey.currentState;
    _controller.processScannedQr(
      qr,
      candidates: camera?.lastQrCandidates ?? const [],
      engine: camera?.lastQrEngine ?? '',
    );
  }

  void _onQrDetectedDetailed(QrDetectionGeometry detection) {
    _latestQrDetection = detection;
  }

  /// Dialog xác nhận sai vị trí (mapped mismatch / unmapped ACTUAL).
  /// true = "Vẫn lưu".
  Future<bool> _showMismatchDialog(FixedAssetMismatchPrompt prompt) async {
    if (!mounted) {
      _controller.uxLog('dialog NOT shown: screen unmounted');
      return false;
    }

    var shown = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        if (!shown) {
          shown = true;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _controller.uxLog('dialog visible'),
          );
        }
        return FixedAssetMismatchDialog(
          machineCode: prompt.machineCode,
          faName: prompt.faName,
          master: prompt.master,
          actual: prompt.actual,
          unmappedActual: prompt.unmappedActual,
          masterUpdates: prompt.masterUpdates,
          manual: prompt.manual,
        );
      },
    );

    // null = closed without a choice (e.g. system back): treated as skip.
    return result == true;
  }

  /// Dialog "QR không khớp vị trí đang chọn".
  /// true = "Vẫn lưu (đánh dấu in lại QR)".
  Future<bool> _showQrMismatchDialog(FixedAssetQrMismatchPrompt prompt) async {
    if (!mounted) {
      _controller.uxLog('QR dialog NOT shown: screen unmounted');
      return false;
    }
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FixedAssetQrMismatchDialog(
        machineCode: prompt.machineCode,
        faName: prompt.faName,
        selected: prompt.selected,
        qr: prompt.qr,
      ),
    );
    // null = closed without a choice (e.g. system back): treated as skip.
    return result == true;
  }

  /// Dialog "Máy đã dời vị trí?" (máy đang chờ in lại tem).
  /// true = "Xác nhận đã dời".
  Future<bool> _showReprintMoveDialog(FixedAssetReprintMovePrompt prompt) async {
    if (!mounted) {
      _controller.uxLog('reprint move dialog NOT shown: screen unmounted');
      return false;
    }
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FixedAssetReprintMoveDialog(prompt: prompt),
    );
    // null = closed without a choice (e.g. system back): treated as cancel.
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

  void _showNotice(String message) {
    if (!mounted) return;
    CommonUI.showSnackBar(
      context: context,
      message: message,
      color: const Color(0xFF16A34A),
    );
  }

  /// Form "máy thiếu QR": luôn mở, kể cả chưa đủ vị trí (form tự hiện 4
  /// dropdown, điền sẵn các cấp đã chọn). Quét QR tạm dừng trong
  /// lúc form mở. Lưu xong với vị trí khác màn hình: màn hình theo vị trí đó.
  Future<void> _openNoQrSheet({String? machineCode}) async {
    // Sheet đang mở (che màn hình): lần bấm này không tới được đây.
    if (_noQrSheetOpen || !mounted) return;
    final c = _controller;
    final location = c.activeLocation;
    final manual = c.manual;
    final NoQrLocationDraft? draft = location == null
        ? (
            fac: manual.selectedFac,
            floor: manual.selectedFloor,
            positionA: manual.selectedPositionA,
            positionAA: manual.selectedPositionAA,
          )
        : null;

    _noQrSheetOpen = true;
    c.pauseQrScan(_noQrPauseReason);
    NoQrReport? saved;
    NoQrSubmitOutcome? outcome;
    try {
      saved = await showNoQrReportSheet(
        context: context,
        location: location,
        // List màn chính đã lọc theo PIC đang chọn = PIC điền sẵn của form.
        machines: location == null ? const [] : c.machines,
        pics: c.pics,
        initialPic: c.selectedPicEmail,
        loadingPics: c.loadingPics,
        initialSelection: draft,
        initialMachineCode: machineCode,
        onSubmit: (report) async {
          outcome = await _noQrService.submit(
            report,
            confirmMismatch: _showMismatchDialog,
          );
          return outcome != NoQrSubmitOutcome.cancelled;
        },
        lang: widget.lang,
        plant: widget.selectedPlant,
      );
    } catch (error, stackTrace) {
      debugPrint('No-QR sheet error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showError(NoQrStrings.openFailed);
    } finally {
      _noQrSheetOpen = false;
      c.resumeQrScan(_noQrPauseReason);
    }

    if (saved == null || !mounted) return;
    CommonUI.showSnackBar(
      context: context,
      message: outcome == NoQrSubmitOutcome.alreadyAudited
          ? NoQrStrings.alreadyAudited
          : NoQrStrings.saved,
      color: const Color(0xFF16A34A),
    );
    // Bản ghi mới / bản ghi được đánh dấu in tem đã vào backend.
    c.loadAuditSummary();
    c.refreshZoneProgress();
    if (saved.location != c.activeLocation) c.applyLocation(saved.location);
  }

  // ============================================================
  // UI
  // ============================================================

  // Mỗi section là một rebuild boundary riêng: màn hình không còn
  // setState theo controller, chỉ section có giá trị liên quan đổi mới
  // rebuild (camera, AppBar không bao giờ rebuild theo controller).

  /// Map chỉ rebuild khi 4 dropdown đổi, không theo
  /// summary/machine/search/status.
  Widget _buildDetectedMap() {
    final c = _controller;
    return FixedAssetSelector<
      ({
        String? fac,
        String? floor,
        String? positionA,
        String? positionAA,
        Map<String, ZoneProgress>? zoneProgress,
      })
    >(
      listenable: c,
      select: () {
        // zoneProgress: a new map instance per load (identity compare).
        final manual = c.manual;
        return (
          fac: manual.selectedFac,
          floor: manual.selectedFloor,
          positionA: manual.selectedPositionA,
          positionAA: manual.selectedPositionAA,
          zoneProgress: c.zoneProgress,
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
            onExpand: c.refreshZoneProgress,
            zoneProgress: map.zoneProgress,
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
        needsQrReprint: c.needsQrReprint,
        reprintInfo: c.reprintInfo,
        qrReplacedAt: c.qrReplacedAt,
        otherPicName: c.scannedOtherPicName,
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
        needsQrReprint: v.needsQrReprint,
        reprintInfo: v.reprintInfo,
        qrReplacedAt: v.qrReplacedAt,
        otherPicName: v.otherPicName,
      ),
    );
  }

  Widget _buildNoQrEntry() {
    return ListenableBuilder(
      listenable: _noQrService,
      builder: (context, _) =>
          NoQrEntryTile(count: _noQrService.count, onTap: _openNoQrSheet),
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
        picName: c.selectedPicEmail == null
            ? null
            : c.picNameOf(c.selectedPicEmail!),
      ),
      builder: (context, v) => FixedAssetAuditProgressCard(
        summary: v.summary,
        loading: v.loading,
        error: v.error,
        onRetry: c.loadAuditSummary,
        picName: v.picName,
      ),
    );
  }

  /// Cascade phụ thuộc ~13 field (4 dropdown + list + loading): rebuild
  /// theo mọi notify cho chắc chắn đúng; section nhẹ, không chứa
  /// map/machine list.
  Widget _buildLocationSection() {
    final c = _controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final manual = c.manual;
        return FixedAssetLocationSection(
          picSelector: FixedAssetPicSelector(
            pics: c.pics,
            selectedEmail: c.selectedPicEmail,
            loading: c.loadingPics,
            onChanged: c.onPicChanged,
            // PIC bắt buộc chọn trước vị trí.
            allowAll: false,
          ),
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
            facFlashKey: _facFlashKey,
            floorFlashKey: _floorFlashKey,
            positionAFlashKey: _positionAFlashKey,
            positionAAFlashKey: _positionAAFlashKey,
            // Chưa đủ vị trí: ô cần chọn tiếp được làm nổi bật.
            missingField: c.firstMissingManualField,
            enabled: c.hasPic,
          ),
        );
      },
    );
  }

  /// auditedMachineCodes / qrReprintMachineCodes bị mutate tại chỗ:
  /// auditedVersion là version (noQrMachineCodes: noQrCount). Filter/sort
  /// vẫn cache bên trong FixedAssetMachineSection.
  Widget _buildMachineSection() {
    final c = _controller;
    return FixedAssetSelector(
      listenable: _machineListenable,
      select: () => (
        visible: c.activeLocation != null,
        machines: c.machines,
        loading: c.loadingMachines,
        error: c.machineError,
        search: c.machineSearch,
        audited: c.auditedMachineCodes,
        reprint: c.qrReprintMachineCodes,
        auditedVersion: c.auditedVersion,
        noQr: _noQrService.machineCodes,
        noQrCount: _noQrService.count,
      ),
      builder: (context, v) => FixedAssetMachineSection(
        visible: v.visible,
        machines: v.machines,
        loading: v.loading,
        error: v.error,
        search: v.search,
        searchController: c.machineSearchController,
        auditedMachineCodes: v.audited,
        qrReprintMachineCodes: v.reprint,
        auditedVersion: v.auditedVersion,
        onSearchChanged: c.setMachineSearch,
        onClearSearch: c.clearMachineSearch,
        noQrMachineCodes: v.noQr,
        onReportNoQr: (code) => _openNoQrSheet(machineCode: code),
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
              const SizedBox(height: 6),
              _buildStatusCard(),
              const SizedBox(height: 6),
              _buildNoQrEntry(),
              _buildDetectedMap(),
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

  /// [canScan] false: camera không bật (không xin quyền / mở stream), khung
  /// hiện hướng dẫn chọn vị trí; true: bật camera, quét như bình thường.
  Widget _buildCameraSection(bool canScan) {
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
          onQrDetectedDetailed: _onQrDetectedDetailed,
          qrOnly: true,
          enableZoomControls: true,
          enableQrLockAnimation: true,
          enablePowerControl: true,
          useSwitchPowerControl: true,
          cameraAllowed: canScan,
          blockedPlaceholder: const _ChooseLocationPlaceholder(),
          showQrNumber: false,
          // Fixed Asset draws its own parsed, colour-coded chip.
          showQrBadge: false,
        ),
      ),
    );
  }

  /// Overlay above the camera: the parsed scan chip. Pointer events pass
  /// through to the camera controls.
  Widget _buildCameraOverlays() {
    final c = _controller;
    return Stack(
      children: [
        Positioned(
          top: 12,
          left: 12,
          right: 70, // keep clear of the power switch
          child: Align(
            alignment: Alignment.centerLeft,
            child: FixedAssetSelector(
              listenable: c,
              select: () => (
                text: c.scanChipText,
                tick: c.scanChipTick,
                status: c.scanStatus,
                settled: c.isScanSettled,
              ),
              builder: (context, v) => FixedAssetScanChip(
                text: v.text,
                tick: v.tick,
                status: v.status,
                settled: v.settled,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveCameraSection(bool isMobile) {
    final displaySize = isMobile ? 260.0 : 340.0;
    return SizedBox.square(
      dimension: displaySize,
      child: FittedBox(
        fit: BoxFit.contain,
        // Same camera instance (GlobalKey); only the overlays rebuild.
        child: SizedBox.square(
          dimension: 340,
          child: Stack(
            children: [
              _cameraSection,
              Positioned.fill(child: _buildCameraOverlays()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Khung camera khi chưa chọn đủ vị trí (camera chưa bật).
class _ChooseLocationPlaceholder extends StatelessWidget {
  const _ChooseLocationPlaceholder();

  static const Color _amber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111827),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(28),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_location_alt_rounded, color: _amber, size: 44),
          SizedBox(height: 12),
          Text(
            'Chọn Fac / Floor / PositionA / PositionAA để bật camera',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
