import 'package:flutter/material.dart';

import '../fixed_asset_location.dart';

/// Dialog "Sai vị trí máy": MASTER vs VỊ TRÍ ĐANG QUÉT. Dùng chung AUTO/MANUAL.
/// Pop true = "Vẫn lưu", false = "Hủy" (không cho tap ra ngoài để đóng).
///
/// Hai trường hợp:
/// - [actual] có (mapped mismatch): ACTUAL đầy đủ Fac · Floor / A / AA.
/// - [unmappedActual] có (vị trí đang quét không có trong MAP): chỉ raw
///   Floor / PositionAA + "Không tìm thấy trong MAP".
class FixedAssetMismatchDialog extends StatelessWidget {
  final String machineCode;
  final String faName;
  final FixedAssetAuditLocation? master;
  final FixedAssetAuditLocation? actual;
  final FixedAssetUnmappedActual? unmappedActual;

  const FixedAssetMismatchDialog({
    super.key,
    required this.machineCode,
    required this.faName,
    required this.master,
    required this.actual,
    this.unmappedActual,
  });

  bool get _isUnmapped => actual == null && unmappedActual != null;

  static const Color _amber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1F2937),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: _amber.withOpacity(.6)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: _amber,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isUnmapped ? 'Vị trí không có trong MAP' : 'Sai vị trí máy',
                    style: const TextStyle(
                      color: _amber,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                machineCode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (faName.isNotEmpty)
                Text(
                  faName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.65),
                    fontSize: 13,
                  ),
                ),
              const SizedBox(height: 12),
              _locationBlock(
                title: 'MASTER',
                line1: master == null
                    ? '-'
                    : '${fixedAssetDash(master!.fac)} · ${fixedAssetDash(master!.floor)}',
                line2: master == null
                    ? ''
                    : '${fixedAssetDash(master!.positionA)} / '
                          '${fixedAssetDash(master!.positionAA)}',
                color: Colors.white.withOpacity(.55),
                background: Colors.white.withOpacity(.05),
              ),
              const SizedBox(height: 8),
              if (_isUnmapped)
                _locationBlock(
                  title: 'VỊ TRÍ ĐANG QUÉT',
                  line1: fixedAssetDash(unmappedActual!.floor),
                  line2: fixedAssetDash(unmappedActual!.positionAA),
                  warning: 'Không tìm thấy trong MAP',
                  color: _amber,
                  background: _amber.withOpacity(.10),
                )
              else
                _locationBlock(
                  title: 'VỊ TRÍ ĐANG QUÉT',
                  line1: actual == null
                      ? '-'
                      : '${fixedAssetDash(actual!.fac)} · ${fixedAssetDash(actual!.floor)}',
                  line2: actual == null
                      ? ''
                      : '${fixedAssetDash(actual!.positionA)} / '
                            '${fixedAssetDash(actual!.positionAA)}',
                  color: _amber,
                  background: _amber.withOpacity(.10),
                ),
              const SizedBox(height: 12),
              Text(
                _isUnmapped
                    ? 'Không tìm thấy vị trí đang quét trong MAP.\n'
                          'Bạn có muốn vẫn lưu kết quả kiểm kê không?'
                    : 'Vị trí đang quét không trùng MASTER.\n'
                          'Bạn có muốn vẫn lưu kết quả kiểm kê này?',
                style: TextStyle(
                  color: Colors.white.withOpacity(.8),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(.3)),
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: _amber,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Vẫn lưu',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationBlock({
    required String title,
    required String line1,
    String line2 = '',
    String? warning,
    required Color color,
    required Color background,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            line1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (line2.isNotEmpty)
            Text(
              line2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (warning != null) ...[
            const SizedBox(height: 2),
            Text(
              warning,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
