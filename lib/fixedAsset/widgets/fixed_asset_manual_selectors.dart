import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../common/common_searchable_dropdown.dart';
import '../fixed_asset_audit_flow.dart';

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

  /// New value (entering MANUAL): empty dropdowns pulse an accent border
  /// once.
  final int promptTick;

  /// First empty dropdown after a scan without location: red border, and a
  /// ~300 ms shake (+ scrolled into view) on each new [missingTick].
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
    this.promptTick = 0,
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
    required String label,
    required String? value,
    required List<String> items,
    required bool enabled,
    required bool loading,
    required ValueChanged<String?> onChanged,
  }) {
    final active = enabled && !loading;

    return _AttentionField(
      isEmpty: value == null,
      promptTick: promptTick,
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

/// Attention decoration around one dropdown: a one-off accent pulse when
/// [promptTick] changes while empty, and — while [isMissing] — a red border
/// plus a ~300 ms shake (scrolled into view) on each new [missingTick].
class _AttentionField extends StatefulWidget {
  final Widget child;
  final bool isEmpty;
  final int promptTick;
  final bool isMissing;
  final int missingTick;

  const _AttentionField({
    required this.child,
    required this.isEmpty,
    required this.promptTick,
    required this.isMissing,
    required this.missingTick,
  });

  @override
  State<_AttentionField> createState() => _AttentionFieldState();
}

class _AttentionFieldState extends State<_AttentionField>
    with TickerProviderStateMixin {
  static const Color _accent = Color(0xFF4DD0E1);
  static const Color _error = Colors.redAccent;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void initState() {
    super.initState();
    // Built when MANUAL opens: empty fields pulse once.
    if (widget.isEmpty && widget.promptTick > 0) _pulse.forward();
  }

  @override
  void didUpdateWidget(covariant _AttentionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.promptTick != oldWidget.promptTick && widget.isEmpty) {
      _pulse.forward(from: 0);
    }
    if (widget.isMissing && widget.missingTick != oldWidget.missingTick) {
      _shake.forward(from: 0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(
          context,
          alignment: 0.3,
          duration: const Duration(milliseconds: 250),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      });
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _shake]),
      builder: (context, child) {
        // Pulse: 0 -> 1 -> 0 over the run; shake: damped sine, ±4 px.
        final pulse = _pulse.isAnimating
            ? 1 - (2 * _pulse.value - 1).abs()
            : 0.0;
        final s = _shake.value;
        final dx = _shake.isAnimating
            ? 4 * (1 - s) * math.sin(s * math.pi * 6)
            : 0.0;
        final Color? border = widget.isMissing
            ? _error
            : (pulse > 0 ? _accent.withValues(alpha: pulse) : null);
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
