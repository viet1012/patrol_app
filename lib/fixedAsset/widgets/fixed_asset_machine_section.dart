import 'package:flutter/material.dart';

import '../../model/fixed_asset_machine.dart';

/// Machine list của location đang dùng: search cục bộ, audited-first,
/// ✓ = đã kiểm kê trong kỳ (session). Rows chỉ đọc. Không gọi API.
class FixedAssetMachineSection extends StatefulWidget {
  /// false khi chưa có location (AUTO chưa scan / MANUAL chưa chọn đủ).
  final bool visible;
  final List<FixedAssetMachine> machines;
  final bool loading;
  final String? error;
  final String search;
  final TextEditingController searchController;
  final Set<String> auditedMachineCodes;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  const FixedAssetMachineSection({
    super.key,
    required this.visible,
    required this.machines,
    required this.loading,
    required this.error,
    required this.search,
    required this.searchController,
    required this.auditedMachineCodes,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  @override
  State<FixedAssetMachineSection> createState() =>
      _FixedAssetMachineSectionState();
}

class _FixedAssetMachineSectionState extends State<FixedAssetMachineSection> {
  static const Color _accent = Color(0xFF4DD0E1);

  // Cache filter + audited-first order. Recomputed only when the source
  // list instance, the query, or the audited set (grows in place, so its
  // length is the version signal) changes; unrelated parent rebuilds reuse
  // it.
  List<FixedAssetMachine>? _cacheSource;
  String? _cacheQuery;
  Set<String>? _cacheAuditedSet;
  int _cacheAuditedLength = -1;
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
        auditedSet.length == _cacheAuditedLength) {
      return;
    }
    _cacheSource = machines;
    _cacheQuery = query;
    _cacheAuditedSet = auditedSet;
    _cacheAuditedLength = auditedSet.length;

    if (!identical(machines, _normalizedSource)) {
      _normalizedSource = machines;
      _codeLower = <String>[
        for (final m in machines) m.machineCode.toLowerCase(),
      ];
      _nameLower = <String>[for (final m in machines) m.faName.toLowerCase()];
    }

    // Machine đã audit lên đầu. Chia nhóm (stable) để giữ nguyên thứ tự
    // gốc trong từng nhóm; không mutate `machines`.
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
      (_isAuditedMachine(machine) ? audited : notAudited).add(machine);
    }
    _filteredCount = filteredCount;
    _displayMachines = List<FixedAssetMachine>.unmodifiable(<FixedAssetMachine>[
      ...audited,
      ...notAudited,
    ]);
  }

  static const Color _success = Color(0xFF22C55E);

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

    if (widget.machines.isEmpty) {
      return _compactMessage('No machines found.');
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
        _buildMachineHeader(filteredCount),
        const SizedBox(height: 6),
        if (filteredCount == 0)
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

  Widget _buildMachineHeader(int visibleCount) {
    final total = widget.machines.length;
    final countText = widget.search.trim().isEmpty
        ? '$total'
        : '$visibleCount / $total';

    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Machines',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          countText,
          style: const TextStyle(
            color: _accent,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    return Row(
      children: [
        Padding(padding: const EdgeInsets.only(left: 4), child: title),
        const SizedBox(width: 8),
        Expanded(child: _buildMachineSearchField()),
      ],
    );
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

  Widget _buildMachineRow(FixedAssetMachine machine) {
    final audited = _isAuditedMachine(machine);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(.12)),
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
          if (audited) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle_rounded, size: 18, color: _success),
          ],
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
