import 'package:flutter/material.dart';

import 'package:chuphinh/core/api/fixed_asset_backend.dart';
import 'package:chuphinh/core/models/fixed_asset_machine.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_audit_flow.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_location.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_manual_cascade.dart';
import 'package:chuphinh/features/fixed_asset/no_qr/no_qr_report.dart';
import 'package:chuphinh/features/fixed_asset/no_qr/no_qr_strings.dart';
import 'package:chuphinh/features/fixed_asset/widgets/fixed_asset_manual_selectors.dart';
import 'package:chuphinh/shared/speech/voice_input_button.dart';
import 'package:chuphinh/shared/widgets/required_field_flash.dart';

/// Các cấp vị trí đã chọn (có thể dở dang) để điền sẵn cascade của form.
typedef NoQrLocationDraft = ({
  String? fac,
  String? floor,
  String? positionA,
  String? positionAA,
});

/// Mở form "máy thiếu QR". Trả về report đã lưu ([onSubmit] xong), null =
/// "Hủy" / đóng.
///
/// [location] null (chưa đủ vị trí): form hiện 4 dropdown ở đầu, điền sẵn
/// [initialSelection]. [machines] = danh sách máy của [location] (rỗng thì
/// form tự tải). [initialMachineCode] điền sẵn mã máy (từ dòng trong danh
/// sách máy): có trong [machines] thì vào thẳng trạng thái đã chọn.
Future<NoQrReport?> showNoQrReportSheet({
  required BuildContext context,
  required FixedAssetAuditLocation? location,
  required List<FixedAssetMachine> machines,
  required Future<void> Function(NoQrReport report) onSubmit,
  NoQrLocationDraft? initialSelection,
  String? initialMachineCode,
  String lang = 'VI',
  String? plant,
  FixedAssetBackend api = const FixedAssetBackend(),
}) {
  return showModalBottomSheet<NoQrReport>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF1F2937),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => NoQrReportSheet(
      location: location,
      machines: machines,
      onSubmit: onSubmit,
      initialSelection: initialSelection,
      initialMachineCode: initialMachineCode,
      lang: lang,
      plant: plant,
      api: api,
    ),
  );
}

/// Form ghi máy không có / không quét được QR: vị trí (đủ 4 cấp: breadcrumb
/// + "Đổi"; thiếu: 4 dropdown), mã máy (chọn từ danh sách hoặc nhập tay),
/// lý do, 1-3 ảnh, ghi chú.
///
/// Lỗi bắt buộc chỉ hiện sau lần bấm "Lưu" đầu tiên khi còn thiếu (nút Lưu
/// luôn bấm được). Pop report sau khi lưu, null = "Hủy". API chỉ dùng để tải
/// cascade vị trí + danh sách máy.
class NoQrReportSheet extends StatefulWidget {
  final FixedAssetAuditLocation? location;
  final List<FixedAssetMachine> machines;
  final Future<void> Function(NoQrReport report) onSubmit;
  final NoQrLocationDraft? initialSelection;
  final String? initialMachineCode;
  final String lang;
  final String? plant;
  final FixedAssetBackend api;

  const NoQrReportSheet({
    super.key,
    required this.location,
    required this.machines,
    required this.onSubmit,
    this.initialSelection,
    this.initialMachineCode,
    this.lang = 'VI',
    this.plant,
    this.api = const FixedAssetBackend(),
  });

  @override
  State<NoQrReportSheet> createState() => _NoQrReportSheetState();
}

class _NoQrReportSheetState extends State<NoQrReportSheet> {
  static const Color _accent = Color(0xFF4DD0E1);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _success = Color(0xFF22C55E);
  static const Color _errorColor = Colors.redAccent;

  /// Danh sách gợi ý: tối đa ~4 dòng (mã + mô tả), cuộn bên trong.
  static const double _suggestionsMaxHeight = 4 * 52;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _manualController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  // Nhấp nháy + cuộn tới mục còn thiếu khi bấm Lưu.
  final _locationFlashKey = GlobalKey<RequiredFieldFlashState>();
  final _machineFlashKey = GlobalKey<RequiredFieldFlashState>();
  final _facFlashKey = GlobalKey<RequiredFieldFlashState>();
  final _floorFlashKey = GlobalKey<RequiredFieldFlashState>();
  final _positionAFlashKey = GlobalKey<RequiredFieldFlashState>();
  final _positionAAFlashKey = GlobalKey<RequiredFieldFlashState>();

  bool _disposed = false;

  // ---------------- Vị trí ----------------

  /// null khi đang đổi và chưa chọn đủ 4 cấp.
  late FixedAssetAuditLocation? _location = widget.location;

  /// Cascade riêng của form (cùng nguồn + logic phụ thuộc cấp với Location
  /// section); khác null = đang hiện 4 dropdown. Tự đóng khi chọn đủ 4 cấp.
  FixedAssetManualCascade? _cascade;
  String? _locationError;

  /// Đã bấm "Lưu" khi vị trí chưa đủ: hiện lỗi + viền đỏ ô trống đầu tiên.
  bool _locationAttempted = false;
  int _locationTick = 0;

  // ---------------- Máy ----------------

  late List<FixedAssetMachine> _machines = widget.location == null
      ? const <FixedAssetMachine>[]
      : widget.machines;

  /// Vị trí của [_machines]; null = chưa có danh sách (form tự tải).
  late FixedAssetAuditLocation? _machinesLocation =
      widget.machines.isEmpty ? null : widget.location;
  bool _loadingMachines = false;
  String? _machinesError;
  int _machinesReq = 0;

  /// true = "Máy không có trong danh sách": nhập tay thay cho chọn từ list.
  bool _manualCode = false;
  FixedAssetMachine? _selectedMachine;

  // ---------------- Còn lại ----------------

  bool _saving = false;
  String? _error;

  /// Đã bấm Lưu khi còn thiếu: từ đây lỗi bắt buộc hiện (và tự ẩn khi đủ).
  bool _submitted = false;

  @override
  void initState() {
    super.initState();

    if (widget.location == null) {
      final cascade = _cascade = _newCascade();
      _prefillCascade(cascade, widget.initialSelection);
    }
    // Tải sau frame đầu: loader báo onChanged (setState) ngay khi gọi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cascade = _cascade;
      if (cascade != null) _loadCascadeLists(cascade);
      final location = _location;
      if (location != null && _machinesLocation != location) {
        _loadMachines(location);
      }
    });

    final initial = widget.initialMachineCode?.trim() ?? '';
    if (initial.isEmpty) return;
    final match = _findMachine(initial);
    if (match != null) {
      _selectedMachine = match;
    } else {
      _manualCode = true;
      _manualController.text = initial;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _searchController.dispose();
    _manualController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  FixedAssetMachine? _findMachine(String code) {
    final key = code.trim().toLowerCase();
    for (final machine in _machines) {
      if (machine.machineCode.trim().toLowerCase() == key) return machine;
    }
    return null;
  }

  String get _machineCode => _manualCode
      ? _manualController.text.trim()
      : (_selectedMachine?.machineCode.trim() ?? '');

  bool get _locationMissing => _location == null;
  bool get _machineMissing => _machineCode.isEmpty;


  // ============================================================
  // VỊ TRÍ
  // ============================================================

  FixedAssetManualCascade _newCascade() => FixedAssetManualCascade(
    onChanged: _onCascadeChanged,
    onError: (message) {
      if (mounted) setState(() => _locationError = message);
    },
    isDisposed: () => _disposed,
    api: widget.api,
  );

  /// Chọn sẵn các cấp liên tiếp đã có, dừng ở cấp trống đầu tiên.
  static void _prefillCascade(
    FixedAssetManualCascade cascade,
    NoQrLocationDraft? draft,
  ) {
    final fac = draft?.fac;
    if (fac == null) return;
    cascade.selectFac(fac);
    final floor = draft?.floor;
    if (floor == null) return;
    cascade.selectFloor(floor);
    final positionA = draft?.positionA;
    if (positionA == null) return;
    cascade.selectPositionA(positionA);
    final positionAA = draft?.positionAA;
    if (positionAA != null) cascade.selectPositionAA(positionAA);
  }

  /// Tải danh sách mọi cấp đang chọn được (song song).
  static void _loadCascadeLists(FixedAssetManualCascade cascade) {
    cascade.loadFacs();
    final fac = cascade.selectedFac;
    if (fac == null) return;
    cascade.loadFloors(fac);
    final floor = cascade.selectedFloor;
    if (floor == null) return;
    cascade.loadPositionA(fac, floor);
    final positionA = cascade.selectedPositionA;
    if (positionA != null) cascade.loadPositionAA(fac, floor, positionA);
  }

  /// "Đổi": mở 4 dropdown, chọn sẵn vị trí hiện tại.
  void _startEditLocation() {
    final current = _location;
    final cascade = _newCascade();
    if (current != null) {
      _prefillCascade(cascade, (
        fac: current.fac,
        floor: current.floor,
        positionA: current.positionA,
        positionAA: current.positionAA,
      ));
    }
    setState(() {
      _cascade = cascade;
      _locationError = null;
    });
    _loadCascadeLists(cascade);
  }

  /// "Xong" (chỉ hiện khi vị trí đủ): đóng dropdown, giữ vị trí.
  void _finishEditLocation() {
    if (_location == null) return;
    setState(() {
      _cascade = null;
      _locationError = null;
      _locationAttempted = false;
    });
  }

  void _onCascadeChanged() {
    if (mounted) setState(() {});
  }

  void _onFacChanged(String? value) {
    final c = _cascade;
    if (c == null || !c.selectFac(value)) return;
    _onLocationEdited();
    if (value != null) c.loadFloors(value);
  }

  void _onFloorChanged(String? value) {
    final c = _cascade;
    if (c == null || !c.selectFloor(value)) return;
    _onLocationEdited();
    final fac = c.selectedFac;
    if (fac != null && value != null) c.loadPositionA(fac, value);
  }

  void _onPositionAChanged(String? value) {
    final c = _cascade;
    if (c == null || !c.selectPositionA(value)) return;
    _onLocationEdited();
    final fac = c.selectedFac;
    final floor = c.selectedFloor;
    if (fac != null && floor != null && value != null) {
      c.loadPositionAA(fac, floor, value);
    }
  }

  void _onPositionAAChanged(String? value) {
    final c = _cascade;
    if (c == null || !c.selectPositionAA(value)) return;
    _onLocationEdited();
  }

  /// Chọn cấp trên đã reset cấp dưới (trong cascade). Đủ 4 cấp: đóng dropdown
  /// về breadcrumb + "Đổi", tải danh sách máy của vị trí mới.
  void _onLocationEdited() {
    final next = _cascade?.selectedLocation;
    setState(() {
      _location = next;
      _locationError = null;
      if (next != null) {
        _cascade = null;
        _locationAttempted = false;
      }
    });
    if (next != null && next != _machinesLocation) _loadMachines(next);
  }

  FixedAssetManualField? get _firstMissingSelector {
    final c = _cascade;
    if (c == null) return null;
    if (c.selectedFac == null) return FixedAssetManualField.fac;
    if (c.selectedFloor == null) return FixedAssetManualField.floor;
    if (c.selectedPositionA == null) return FixedAssetManualField.positionA;
    if (c.selectedPositionAA == null) return FixedAssetManualField.positionAA;
    return null;
  }

  GlobalKey<RequiredFieldFlashState>? get _firstMissingSelectorKey =>
      switch (_firstMissingSelector) {
        FixedAssetManualField.fac => _facFlashKey,
        FixedAssetManualField.floor => _floorFlashKey,
        FixedAssetManualField.positionA => _positionAFlashKey,
        FixedAssetManualField.positionAA => _positionAAFlashKey,
        null => null,
      };

  Future<void> _loadMachines(FixedAssetAuditLocation location) async {
    final req = ++_machinesReq;
    setState(() {
      _loadingMachines = true;
      _machinesError = null;
    });

    List<FixedAssetMachine> result = const <FixedAssetMachine>[];
    String? error;
    try {
      result = await widget.api.fetchMachines(
        fac: location.fac,
        floor: location.floor,
        positionA: location.positionA,
        positionAA: location.positionAA,
      );
    } catch (_) {
      error = NoQrStrings.machinesFailed;
    }
    if (!mounted || req != _machinesReq) return;

    setState(() {
      _machines = result;
      _machinesLocation = location;
      _loadingMachines = false;
      _machinesError = error;
      _rebindSelectedMachine();
    });
  }

  /// Danh sách máy đổi theo vị trí mới: máy đang chọn còn trong danh sách
  /// thì giữ, không thì chuyển sang nhập tay với chính mã đó.
  void _rebindSelectedMachine() {
    final selected = _selectedMachine;
    if (selected == null) return;
    final match = _findMachine(selected.machineCode);
    if (match != null) {
      _selectedMachine = match;
      return;
    }
    _selectedMachine = null;
    _manualCode = true;
    _manualController.text = selected.machineCode;
  }

  // ============================================================
  // MÁY / ẢNH / LƯU
  // ============================================================

  void _setManualCode(bool manual) {
    if (manual == _manualCode) return;
    setState(() {
      _manualCode = manual;
      if (manual) {
        // Mang theo chữ đang tìm (thường chính là mã máy cần nhập).
        if (_manualController.text.trim().isEmpty) {
          _manualController.text = _searchController.text.trim();
        }
      } else {
        _selectedMachine = null;
      }
    });
  }

  /// Nhấp nháy + cuộn tới [key] sau frame (lỗi vừa hiện có thể đổi layout).
  void _flash(GlobalKey<RequiredFieldFlashState> key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) key.currentState?.flash(scrollTo: true);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();

    final location = _location;
    if (location == null || _machineMissing) {
      setState(() {
        _submitted = true;
        if (location == null) {
          _locationAttempted = true;
          _locationTick++;
        }
      });
      _flash(
        location == null
            ? (_firstMissingSelectorKey ?? _locationFlashKey)
            : _machineFlashKey,
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final report = NoQrReport(
      location: location,
      machineCode: _machineCode,
      isManualCode: _manualCode,
      note: _noteController.text.trim(),
      createdAt: DateTime.now(),
    );

    try {
      await widget.onSubmit(report);
      if (!mounted) return;
      Navigator.of(context).pop(report);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = NoQrStrings.saveFailed;
      });
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * .9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHandle(),
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionLabel(NoQrStrings.location, required: true),
                      _buildLocation(),
                      const SizedBox(height: 14),
                      _sectionLabel(NoQrStrings.machineCode, required: true),
                      _buildMachineField(),
                      const SizedBox(height: 14),
                      _sectionLabel(NoQrStrings.note),
                      _buildNote(),
                    ],
                  ),
                ),
              ),
              _buildButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 8, bottom: 6),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: _amber, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              NoQrStrings.sheetTitle,
              style: TextStyle(
                color: _amber,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, {bool required = false, String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: .6),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
            ),
          ),
          if (required)
            const Text(
              ' *',
              style: TextStyle(
                color: _amber,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .6),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  /// Lỗi bắt buộc dưới một mục (đỏ).
  Widget _fieldError(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _errorColor, size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _errorColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _flashBox({
    required GlobalKey<RequiredFieldFlashState> key,
    required Widget child,
  }) => RequiredFieldFlash(key: key, color: _errorColor, radius: 12, child: child);

  BoxDecoration _boxDecoration({Color? borderColor, Color? color}) =>
      BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: .12),
        ),
      );

  InputDecoration _inputDecoration({
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool bordered = true,
  }) {
    final InputBorder border = bordered
        ? OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _accent.withValues(alpha: .35)),
          )
        : InputBorder.none;

    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: .5),
        fontSize: 13,
      ),
      filled: true,
      fillColor: bordered
          ? Colors.white.withValues(alpha: .08)
          : Colors.transparent,
      hoverColor: Colors.white.withValues(alpha: .04),
      focusColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      prefixIcon: prefixIcon,
      prefixIconColor: Colors.white.withValues(alpha: .6),
      prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      suffixIcon: suffixIcon,
      suffixIconColor: Colors.white70,
      border: border,
      enabledBorder: border,
      focusedBorder: bordered
          ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _accent, width: 1.2),
            )
          : InputBorder.none,
      disabledBorder: bordered
          ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: .12),
              ),
            )
          : InputBorder.none,
    );
  }

  Widget _smallTextButton(String label, VoidCallback? onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: _accent,
        disabledForegroundColor: Colors.white30,
        backgroundColor: Colors.transparent,
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }

  // ---------------- Vị trí ----------------

  /// Đủ 4 cấp (và không đang đổi): breadcrumb + "Đổi". Còn lại: 4 dropdown
  /// (+ "Xong" khi vị trí vẫn đủ, tức vừa bấm "Đổi" mà chưa đổi gì).
  Widget _buildLocation() {
    final c = _cascade;
    final location = _location;

    if (c == null && location != null) {
      final path = [
        location.fac,
        location.floor,
        location.positionA,
        location.positionAA,
      ].map(fixedAssetDash).join('  ›  ');

      return _flashBox(
        key: _locationFlashKey,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          decoration: _boxDecoration(),
          child: Row(
            children: [
              const Icon(Icons.place_rounded, color: _accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  path,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _smallTextButton(
                NoQrStrings.change,
                _saving ? null : _startEditLocation,
              ),
            ],
          ),
        ),
      );
    }

    // Không xảy ra (thiếu vị trí luôn có cascade); phòng hờ: mở dropdown.
    if (c == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: _smallTextButton(NoQrStrings.change, _startEditLocation),
      );
    }

    final showError = _locationAttempted && _locationMissing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _flashBox(
          key: _locationFlashKey,
          child: FixedAssetManualSelectors(
            selectedFac: c.selectedFac,
            selectedFloor: c.selectedFloor,
            selectedPositionA: c.selectedPositionA,
            selectedPositionAA: c.selectedPositionAA,
            facs: c.facs,
            floors: c.floors,
            positionAs: c.positionAs,
            positionAAs: c.positionAAs,
            loadingFacs: c.loadingFacs,
            loadingFloors: c.loadingFloors,
            loadingPositionA: c.loadingPositionA,
            loadingPositionAA: c.loadingPositionAA,
            onFacChanged: _onFacChanged,
            onFloorChanged: _onFloorChanged,
            onPositionAChanged: _onPositionAChanged,
            onPositionAAChanged: _onPositionAAChanged,
            facFlashKey: _facFlashKey,
            floorFlashKey: _floorFlashKey,
            positionAFlashKey: _positionAFlashKey,
            positionAAFlashKey: _positionAAFlashKey,
            missingField: _locationAttempted ? _firstMissingSelector : null,
            missingTick: _locationTick,
          ),
        ),
        if (_locationError != null) _fieldError(_locationError!),
        if (showError) _fieldError(NoQrStrings.locationRequired),
        if (location != null)
          Align(
            alignment: Alignment.centerRight,
            child: _smallTextButton(
              NoQrStrings.done,
              _saving ? null : _finishEditLocation,
            ),
          ),
      ],
    );
  }

  // ---------------- Mã máy ----------------

  Widget _buildMachineField() {
    final Widget field;
    if (_manualCode) {
      field = TextField(
        controller: _manualController,
        enabled: !_saving,
        autofocus: _manualController.text.isEmpty,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        cursorColor: _accent,
        decoration: _inputDecoration(
          hint: NoQrStrings.machineManualHint,
          prefixIcon: const Icon(Icons.edit_rounded, size: 17),
        ),
      );
    } else if (_selectedMachine != null) {
      field = _buildSelectedMachine(_selectedMachine!);
    } else {
      field = _buildMachinePicker();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _flashBox(key: _machineFlashKey, child: field),
        if (_submitted && _machineMissing)
          _fieldError(NoQrStrings.machineRequired),
        const SizedBox(height: 2),
        _buildNotInListToggle(),
      ],
    );
  }

  Widget _buildSelectedMachine(FixedAssetMachine machine) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: _boxDecoration(
        color: _success.withValues(alpha: .08),
        borderColor: _success.withValues(alpha: .55),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: _success, size: 20),
          const SizedBox(width: 10),
          Expanded(child: _machineTexts(machine)),
          _smallTextButton(
            NoQrStrings.change,
            _saving ? null : () => setState(() => _selectedMachine = null),
          ),
        ],
      ),
    );
  }

  /// Mã đầy đủ (đậm, không cắt) + mô tả 1 dòng.
  Widget _machineTexts(FixedAssetMachine machine) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          machine.machineCode,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (machine.faName.isNotEmpty)
          Text(
            machine.faName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .62),
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  /// Ô tìm + danh sách gợi ý chung một khung có viền; danh sách cuộn bên
  /// trong, cao tối đa ~4 dòng.
  Widget _buildMachinePicker() {
    final query = _searchController.text.trim().toLowerCase();
    final matches = query.isEmpty
        ? _machines
        : _machines
              .where(
                (m) =>
                    m.machineCode.toLowerCase().contains(query) ||
                    m.faName.toLowerCase().contains(query),
              )
              .toList();

    final Widget body;
    if (_location == null) {
      body = _pickerMessage(NoQrStrings.machinesNeedLocation);
    } else if (_loadingMachines) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
          ),
        ),
      );
    } else if (_machinesError != null) {
      body = _pickerMessage(_machinesError!, color: _errorColor);
    } else if (_machines.isEmpty) {
      body = _pickerMessage(NoQrStrings.noMachines);
    } else if (matches.isEmpty) {
      body = _pickerMessage(NoQrStrings.noMachineMatch);
    } else {
      body = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _suggestionsMaxHeight),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: matches.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: .08),
          ),
          itemBuilder: (context, index) {
            final machine = matches[index];
            return InkWell(
              onTap: _saving
                  ? null
                  : () => setState(() => _selectedMachine = machine),
              hoverColor: Colors.white.withValues(alpha: .04),
              splashColor: _accent.withValues(alpha: .12),
              highlightColor: _accent.withValues(alpha: .08),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: _machineTexts(machine),
              ),
            );
          },
        ),
      );
    }

    // Chưa đủ vị trí: khung mờ, ô tìm khóa (nhập tay vẫn dùng được).
    final searchEnabled = !_saving && _location != null;

    return Material(
      color: Colors.white.withValues(alpha: .05),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _location != null
              ? _accent.withValues(alpha: .35)
              : Colors.white.withValues(alpha: .12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Opacity(
            opacity: _location != null ? 1 : .45,
            child: TextField(
              controller: _searchController,
              enabled: searchEnabled,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              cursorColor: _accent,
              decoration: _inputDecoration(
                hint: NoQrStrings.machineSearchHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                bordered: false,
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: .1),
          ),
          body,
        ],
      ),
    );
  }

  Widget _pickerMessage(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? Colors.white.withValues(alpha: .65),
          fontSize: 12.5,
        ),
      ),
    );
  }

  Widget _buildNotInListToggle() {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _saving ? null : () => _setManualCode(!_manualCode),
      child: Row(
        children: [
          Checkbox(
            value: _manualCode,
            onChanged: _saving ? null : (v) => _setManualCode(v ?? false),
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (!states.contains(WidgetState.selected)) {
                return Colors.transparent;
              }
              return states.contains(WidgetState.disabled)
                  ? _amber.withValues(alpha: .45)
                  : _amber;
            }),
            checkColor: Colors.black87,
            overlayColor: WidgetStatePropertyAll(
              _amber.withValues(alpha: .12),
            ),
            side: WidgetStateBorderSide.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? const BorderSide(color: Colors.transparent)
                  : BorderSide(
                      color: Colors.white.withValues(
                        alpha: states.contains(WidgetState.disabled) ? .2 : .5,
                      ),
                      width: 1.5,
                    ),
            ),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Text(
              NoQrStrings.notInList,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .85),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Ghi chú ----------------

  Widget _buildNote() {
    return TextField(
      controller: _noteController,
      enabled: !_saving,
      minLines: 3,
      maxLines: 3,
      keyboardType: TextInputType.multiline,
      style: const TextStyle(color: Colors.white, fontSize: 13.5),
      cursorColor: _accent,
      decoration: _inputDecoration(
        hint: NoQrStrings.noteHint,
        suffixIcon: VoiceInputButton.suffixIcon(
          controller: _noteController,
          lang: widget.lang,
          plant: widget.plant,
          enabled: !_saving,
        ),
      ),
    );
  }

  // ---------------- Nút ----------------

  Widget _buildButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: .08)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Colors.redAccent.shade100,
                  fontSize: 12.5,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white30,
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: .3),
                    ),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    NoQrStrings.cancel,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                // Luôn bấm được (trừ lúc đang lưu): bấm khi còn thiếu thì
                // hiện lỗi bắt buộc.
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _amber,
                    foregroundColor: Colors.black87,
                    disabledBackgroundColor: _amber.withValues(alpha: .45),
                    disabledForegroundColor: Colors.black54,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black87,
                          ),
                        )
                      : const Text(
                          NoQrStrings.save,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
