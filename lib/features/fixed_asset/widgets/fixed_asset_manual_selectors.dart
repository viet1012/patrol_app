import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:chuphinh/shared/widgets/common_searchable_dropdown.dart';
import 'package:chuphinh/shared/widgets/required_field_flash.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_audit_flow.dart';

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

  /// Keys held by the screen: flash (+ scroll to) one dropdown.
  final GlobalKey<RequiredFieldFlashState> facFlashKey;
  final GlobalKey<RequiredFieldFlashState> floorFlashKey;
  final GlobalKey<RequiredFieldFlashState> positionAFlashKey;
  final GlobalKey<RequiredFieldFlashState> positionAAFlashKey;

  /// First empty dropdown after a scan without location: red border, and a
  /// ~300 ms shake on each new [missingTick].
  final FixedAssetManualField? missingField;
  final int missingTick;

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
    required this.facFlashKey,
    required this.floorFlashKey,
    required this.positionAFlashKey,
    required this.positionAAFlashKey,
    this.missingField,
    this.missingTick = 0,
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
                field: FixedAssetManualField.fac,
                flashKey: facFlashKey,
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
                field: FixedAssetManualField.floor,
                flashKey: floorFlashKey,
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
                field: FixedAssetManualField.positionA,
                flashKey: positionAFlashKey,
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
                field: FixedAssetManualField.positionAA,
                flashKey: positionAAFlashKey,
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
    required FixedAssetManualField field,
    required GlobalKey<RequiredFieldFlashState> flashKey,
    required String label,
    required String? value,
    required List<String> items,
    required bool enabled,
    required bool loading,
    required ValueChanged<String?> onChanged,
  }) {
    final active = enabled && !loading;

    return RequiredFieldFlash(
      key: flashKey,
      radius: 14,
      child: _AttentionField(
        isMissing: missingField == field,
        missingTick: missingTick,
        child: _dropdown(
          label: label,
          value: value,
          items: items,
          enabled: enabled,
          active: active,
          loading: loading,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required bool enabled,
    required bool active,
    required bool loading,
    required ValueChanged<String?> onChanged,
  }) {
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

/// While [isMissing]: a red border plus a ~300 ms shake on each new
/// [missingTick]. Flash / scroll-into-view is [RequiredFieldFlash]'s job.
class _AttentionField extends StatefulWidget {
  final Widget child;
  final bool isMissing;
  final int missingTick;

  const _AttentionField({
    required this.child,
    required this.isMissing,
    required this.missingTick,
  });

  @override
  State<_AttentionField> createState() => _AttentionFieldState();
}

class _AttentionFieldState extends State<_AttentionField>
    with SingleTickerProviderStateMixin {
  static const Color _error = Colors.redAccent;

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void didUpdateWidget(covariant _AttentionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMissing && widget.missingTick != oldWidget.missingTick) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        // Shake: damped sine, ±4 px.
        final s = _shake.value;
        final dx = _shake.isAnimating
            ? 4 * (1 - s) * math.sin(s * math.pi * 6)
            : 0.0;
        final Color? border = widget.isMissing ? _error : null;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Stack(
            children: [
              child!,
              if (border != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: border, width: 1.6),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}
