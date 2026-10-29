import 'package:flutter/material.dart';

import 'package:chuphinh/core/models/fixed_asset_machine.dart';
import 'package:chuphinh/features/fixed_asset/no_qr/no_qr_entry.dart';
import 'package:chuphinh/features/fixed_asset/no_qr/no_qr_strings.dart';

/// Machine list của location đang dùng: search cục bộ, audited-first,
/// ✓ = đã kiểm kê trong kỳ (session), nhãn tím "In lại QR" = lần quét mới
/// nhất QR lệch vị trí (đã kiểm kê, cần in lại QR), nhãn vàng "Thiếu QR" =
/// đã ghi máy thiếu QR trong phiên. Icon ⚠ cuối dòng mở form máy thiếu QR.
/// Không gọi API.
class FixedAssetMachineSection extends StatefulWidget {
  /// false khi chưa có location (AUTO chưa scan / MANUAL chưa chọn đủ).
  final bool visible;
  final List<FixedAssetMachine> machines;
  final bool loading;
  final String? error;
  final String search;
  final TextEditingController searchController;
  final Set<String> auditedMachineCodes;
  final Set<String> qrReprintMachineCodes;

  /// Đổi khi một trong hai tập trên đổi (tập được mutate tại chỗ).
  final int auditedVersion;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  /// MachineCode đã ghi thiếu QR (trim().toLowerCase()).
  final Set<String> noQrMachineCodes;

  /// Icon ⚠ cuối dòng: mở form máy thiếu QR với mã máy điền sẵn. null = ẩn.
  final ValueChanged<String>? onReportNoQr;

  const FixedAssetMachineSection({
    super.key,
    required this.visible,
    required this.machines,
    required this.loading,
    required this.error,
    required this.search,
    required this.searchController,
    required this.auditedMachineCodes,
    this.qrReprintMachineCodes = const <String>{},
    required this.auditedVersion,
    required this.onSearchChanged,
    required this.onClearSearch,
    this.noQrMachineCodes = const <String>{},
    this.onReportNoQr,
  });

  @override
  State<FixedAssetMachineSection> createState() =>
      _FixedAssetMachineSectionState();
}

class _FixedAssetMachineSectionState extends State<FixedAssetMachineSection> {
  static const Color _accent = Color(0xFF4DD0E1);

  // Cache filter + not-audited-first order. Recomputed only when the source
  // list instance, the query, or the audited sets (mutated in place, so
  // [auditedVersion] is the version signal) change; unrelated parent
  // rebuilds reuse it.
  List<FixedAssetMachine>? _cacheSource;
  String? _cacheQuery;
  Set<String>? _cacheAuditedSet;
  int _cacheAuditedVersion = -1;
  int _filteredCount = 0;
  List<FixedAssetMachine> _displayMachines = const <FixedAssetMachine>[];

  // Lower-cased search fields, built once per source list (not per
  // keystroke).
  List<FixedAssetMachine>? _normalizedSource;
  List<String> _codeLower = const <String>[];
  List<String> _nameLower = const <String>[];

  void _syncDisplayMachines() {
    final machines = widget.machines;
    final query = widget.search.trim().toLowerCase();
    final auditedSet = widget.auditedMachineCodes;
    if (identical(machines, _cacheSource) &&
        query == _cacheQuery &&
        identical(auditedSet, _cacheAuditedSet) &&
        widget.auditedVersion == _cacheAuditedVersion) {
      return;
    }
    _cacheSource = machines;
    _cacheQuery = query;
    _cacheAuditedSet = auditedSet;
    _cacheAuditedVersion = widget.auditedVersion;

    if (!identical(machines, _normalizedSource)) {
      _normalizedSource = machines;
      _codeLower = <String>[
        for (final m in machines) m.machineCode.toLowerCase(),
      ];
      _nameLower = <String>[for (final m in machines) m.faName.toLowerCase()];
    }

    // Chưa kiểm kê (kể cả cần in lại QR) lên đầu, đã kiểm kê (✓) xuống
    // cuối. Chia nhóm (stable) để giữ nguyên thứ tự gốc trong từng nhóm;
    // không mutate `machines`.
    final audited = <FixedAssetMachine>[];
    final notAudited = <FixedAssetMachine>[];
    var filteredCount = 0;
    for (var i = 0; i < machines.length; i++) {
      if (query.isNotEmpty &&
          !_codeLower[i].contains(query) &&
          !_nameLower[i].contains(query)) {
        continue;
      }
      filteredCount++;
      final machine = machines[i];
      final checked =
          !_needsQrReprint(machine) && _isAuditedMachine(machine);
      (checked ? audited : notAudited).add(machine);
    }
    _filteredCount = filteredCount;
    _displayMachines = List<FixedAssetMachine>.unmodifiable(<FixedAssetMachine>[
      ...notAudited,
      ...audited,
    ]);
  }

  static const Color _success = Color(0xFF22C55E);
  static const Color _violet = Color(0xFFA78BFA);
  static const Color _amber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) {
      return const SizedBox.shrink();
    }

    if (widget.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
          ),
        ),
      );
    }

    if (widget.error != null) {
      return _compactMessage(
        widget.error!,
        icon: Icons.error_outline_rounded,
        iconColor: Colors.redAccent,
      );
    }

    _syncDisplayMachines();
    final filteredCount = _filteredCount;
    final displayMachines = _displayMachines;

    // Chiều cao list có giới hạn, list tự cuộn bên trong.
    final maxListHeight = (MediaQuery.of(context).size.height * 0.38).clamp(
      160.0,
      300.0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMachineHeader(),
        const SizedBox(height: 6),
        if (widget.machines.isEmpty)
          _compactMessage('No machines found.')
        else if (filteredCount == 0)
          _compactMessage('No matching machines.')
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxListHeight),
            child: ListView.separated(
              primary: false,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: displayMachines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) =>
                  _buildMachineRow(displayMachines[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildMachineHeader() {
    return _buildMachineSearchField();
  }

  Widget _buildMachineSearchField() {
    final hasText = widget.search.isNotEmpty;

    return SizedBox(
      height: 38,
      child: TextField(
        controller: widget.searchController,
        onChanged: widget.onSearchChanged,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        cursorColor: _accent,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search machine...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(.5),
            fontSize: 13,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(.08),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: Colors.white.withOpacity(.6),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 34,
            minHeight: 34,
          ),
          suffixIcon: hasText
              ? InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: widget.onClearSearch,
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white.withOpacity(.7),
                  ),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _accent.withOpacity(.35)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _accent, width: 1.2),
          ),
        ),
      ),
    );
  }

  /// MachineCode đã có trong audit history (exact, không phân biệt hoa
  /// thường). Chỉ là feedback hiển thị, không phải selection.
  bool _isAuditedMachine(FixedAssetMachine machine) {
    final code = machine.machineCode.trim().toLowerCase();
    return code.isNotEmpty && widget.auditedMachineCodes.contains(code);
  }

  bool _needsQrReprint(FixedAssetMachine machine) {
    final code = machine.machineCode.trim().toLowerCase();
    return code.isNotEmpty && widget.qrReprintMachineCodes.contains(code);
  }

  bool _isNoQr(FixedAssetMachine machine) {
    final code = machine.machineCode.trim().toLowerCase();
    return code.isNotEmpty && widget.noQrMachineCodes.contains(code);
  }

  Widget _buildMachineRow(FixedAssetMachine machine) {
    final reprint = _needsQrReprint(machine);
    final audited = !reprint && _isAuditedMachine(machine);
    final noQr = _isNoQr(machine);
    final onReportNoQr = widget.onReportNoQr;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        12,
        7,
        onReportNoQr != null ? 2 : 12,
        7,
      ),
      // Cần in tem: nền + viền tím riêng để nổi giữa các dòng.
      decoration: BoxDecoration(
        color: reprint
            ? _violet.withOpacity(.10)
            : Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: reprint
              ? _violet.withOpacity(.55)
              : Colors.white.withOpacity(.12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  machine.machineCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (machine.faName.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    machine.faName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.62),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (reprint) ...[
            const SizedBox(width: 8),
            _reprintTag(),
          ] else if (audited) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle_rounded, size: 18, color: _success),
          ],
          if (noQr) ...[const SizedBox(width: 6), const NoQrTag()],
          if (onReportNoQr != null)
            IconButton(
              tooltip: NoQrStrings.rowAction,
              onPressed: () => onReportNoQr(machine.machineCode),
              icon: const Icon(Icons.warning_amber_rounded),
              iconSize: 18,
              color: _amber.withOpacity(.85),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            ),
        ],
      ),
    );
  }

  Widget _reprintTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _violet.withOpacity(.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _violet.withOpacity(.6)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.print_rounded, color: _violet, size: 12),
          SizedBox(width: 4),
          Text(
            'Cần in QR',
            style: TextStyle(
              color: _violet,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactMessage(String message, {IconData? icon, Color? iconColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white.withOpacity(.65),
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
