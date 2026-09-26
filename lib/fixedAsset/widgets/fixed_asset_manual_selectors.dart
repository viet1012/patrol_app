import 'package:flutter/material.dart';

import '../../common/common_searchable_dropdown.dart';

/// 4 dropdown MANUAL (Fac / Floor / PositionA / PositionAA), bố cục 2x2.
/// Chỉ hiển thị + callback; load hierarchy do controller lo.
class FixedAssetManualSelectors extends StatelessWidget {
  final String? selectedFac;
  final String? selectedFloor;
  final String? selectedPositionA;
  final String? selectedPositionAA;

  final List<String> facs;
  final List<String> floors;
  final List<String> positionAs;
  final List<String> positionAAs;

  final bool loadingFacs;
  final bool loadingFloors;
  final bool loadingPositionA;
  final bool loadingPositionAA;

  final ValueChanged<String?> onFacChanged;
  final ValueChanged<String?> onFloorChanged;
  final ValueChanged<String?> onPositionAChanged;
  final ValueChanged<String?> onPositionAAChanged;

  const FixedAssetManualSelectors({
    super.key,
    required this.selectedFac,
    required this.selectedFloor,
    required this.selectedPositionA,
    required this.selectedPositionAA,
    required this.facs,
    required this.floors,
    required this.positionAs,
    required this.positionAAs,
    required this.loadingFacs,
    required this.loadingFloors,
    required this.loadingPositionA,
    required this.loadingPositionAA,
    required this.onFacChanged,
    required this.onFloorChanged,
    required this.onPositionAChanged,
    required this.onPositionAAChanged,
  });

  static const Color _accent = Color(0xFF4DD0E1);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _selector(
                label: 'Fac',
                value: selectedFac,
                items: facs,
                enabled: true,
                loading: loadingFacs,
                onChanged: onFacChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _selector(
                label: 'Floor',
                value: selectedFloor,
                items: floors,
                enabled: selectedFac != null,
                loading: loadingFloors,
                onChanged: onFloorChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _selector(
                label: 'PositionA',
                value: selectedPositionA,
                items: positionAs,
                enabled: selectedFloor != null,
                loading: loadingPositionA,
                onChanged: onPositionAChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _selector(
                label: 'PositionAA',
                value: selectedPositionAA,
                items: positionAAs,
                enabled: selectedPositionA != null,
                loading: loadingPositionAA,
                onChanged: onPositionAAChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _selector({
    required String label,
    required String? value,
    required List<String> items,
    required bool enabled,
    required bool loading,
    required ValueChanged<String?> onChanged,
  }) {
    final active = enabled && !loading;

    return Stack(
      alignment: Alignment.centerRight,
      children: [
        IgnorePointer(
          ignoring: !active,
          child: Opacity(
            opacity: enabled ? 1 : .45,
            child: CommonSearchableDropdown(
              label: label,
              selectedValue: value,
              items: items,
              allowAddNew: false,
              onChanged: onChanged,
            ),
          ),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(right: 36),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
            ),
          ),
      ],
    );
  }
}
