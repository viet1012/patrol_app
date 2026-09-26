import 'package:flutter/material.dart';

import '../fixed_asset_audit_flow.dart';
import '../fixed_asset_location.dart';

/// Location card: header + toggle Auto/Manual + vị trí hiện tại.
/// - AUTO: CURRENT LOCATION (ACTUAL) chỉ đọc; unmapped -> Floor/PositionAA.
/// - MANUAL: [manualSelectors] (dropdown cascade).
/// Chỉ hiển thị + callback, không gọi API.
class FixedAssetLocationSection extends StatelessWidget {
  final FixedAssetLocationMode locationMode;
  final FixedAssetAuditLocation? autoLocation;
  final FixedAssetUnmappedActual? autoUnmappedActual;
  final bool autoLocationMismatch;
  final Widget manualSelectors;
  final ValueChanged<FixedAssetLocationMode> onModeChanged;

  const FixedAssetLocationSection({
    super.key,
    required this.locationMode,
    required this.autoLocation,
    required this.autoUnmappedActual,
    required this.autoLocationMismatch,
    required this.manualSelectors,
    required this.onModeChanged,
  });

  static const Color _accent = Color(0xFF4DD0E1);
  static const Color _amber = Color(0xFFF59E0B);

  bool get _isAuto => locationMode == FixedAssetLocationMode.auto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  _isAuto ? 'CURRENT LOCATION' : 'LOCATION',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
              ),
              if (_isAuto && autoLocationMismatch) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _amber.withOpacity(.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _amber.withOpacity(.6)),
                  ),
                  child: const Text(
                    'MASTER MISMATCH',
                    style: TextStyle(
                      color: _amber,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .4,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              _buildModeToggle(),
            ],
          ),
          const SizedBox(height: 8),
          if (_isAuto)
            _buildMasterLocation()
          else
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: manualSelectors,
            ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeChip(
            FixedAssetLocationMode.auto,
            'Auto',
            Icons.qr_code_scanner_rounded,
          ),
          _modeChip(
            FixedAssetLocationMode.manual,
            'Manual',
            Icons.tune_rounded,
          ),
        ],
      ),
    );
  }

  Widget _modeChip(FixedAssetLocationMode mode, String label, IconData icon) {
    final selected = locationMode == mode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: selected ? null : () => onModeChanged(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? _accent.withOpacity(.20) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? _accent : Colors.white.withOpacity(.55),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white.withOpacity(.6),
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMasterLocation() {
    final location = autoLocation;
    final unmapped = autoUnmappedActual;

    // Vị trí đang quét không có trong MAP: chỉ hiện raw Floor / PositionAA,
    // không hiện Fac / PositionA (không có, không suy ra).
    if (location == null && unmapped != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _locationValue('Floor', unmapped.floor)),
              const SizedBox(width: 12),
              Expanded(
                child: _locationValue('Position AA', unmapped.positionAA),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(Icons.wrong_location_rounded, color: _amber, size: 14),
              SizedBox(width: 4),
              Text(
                'Không tìm thấy trong MAP',
                style: TextStyle(
                  color: _amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (location == null) {
      return Text(
        'Scan a machine to resolve location',
        style: TextStyle(color: Colors.white.withOpacity(.5), fontSize: 12.5),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _locationValue('Fac', location.fac)),
            const SizedBox(width: 12),
            Expanded(child: _locationValue('Floor', location.floor)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _locationValue('Position A', location.positionA)),
            const SizedBox(width: 12),
            Expanded(child: _locationValue('Position AA', location.positionAA)),
          ],
        ),
      ],
    );
  }

  Widget _locationValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          style: TextStyle(color: Colors.white.withOpacity(.5), fontSize: 11),
        ),
        Text(
          value.isEmpty ? '-' : value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
