import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../fixed_asset_audit_flow.dart';
import '../fixed_asset_location.dart';

/// Status card của scan gần nhất (MachineCode là dòng chính). Chỉ hiển thị, không gọi API / đổi state.
///
/// cyan = đang xử lý, green = save mới, amber = đã kiểm kê / ngoài master /
/// sai vị trí, red = lỗi thật.
class FixedAssetStatusCard extends StatelessWidget {
  final FixedAssetScanStatus status;
  final String machineCode;
  final String faName;
  final String? message;
  final DateTime? lastAuditedAt;
  final String? lastAuditedUserId;
  final String? lastAuditedUserName;
  final FixedAssetAuditLocation? mismatchMaster;

  const FixedAssetStatusCard({
    super.key,
    required this.status,
    required this.machineCode,
    required this.faName,
    required this.message,
    required this.lastAuditedAt,
    this.lastAuditedUserId,
    this.lastAuditedUserName,
    required this.mismatchMaster,
  });

  /// "Việt (KVH_IT_Mem_Viet)" / "Việt" / "KVH_IT_Mem_Viet".
  /// null khi không có cả hai -> không hiện dòng "Bởi:".
  static String? auditorLabel(String? userName, String? userId) {
    final name = userName?.trim() ?? '';
    final id = userId?.trim() ?? '';

    if (name.isNotEmpty && id.isNotEmpty) return '$name ($id)';
    if (name.isNotEmpty) return name;
    if (id.isNotEmpty) return id;
    return null;
  }

  static const Color _accent = Color(0xFF4DD0E1);
  static const Color _success = Color(0xFF22C55E);
  static const Color _amber = Color(0xFFF59E0B);

  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final hasCode = machineCode.isNotEmpty;
    final lastAudited = lastAuditedAt;
    final mismatchMaster = this.mismatchMaster;

    final String primary;
    final List<String> details = <String>[];
    String? label;
    Color color;
    Widget? indicator;

    switch (status) {
      case FixedAssetScanStatus.idle:
        primary = 'Scan machine QR';
        color = Colors.white54;
      case FixedAssetScanStatus.checking:
        primary = machineCode;
        details.add('Checking audit status...');
        color = _accent;
        indicator = _spinner();
      case FixedAssetScanStatus.saving:
        primary = machineCode;
        if (faName.isNotEmpty) details.add(faName);
        label = 'Saving...';
        color = _accent;
        indicator = _spinner();
      case FixedAssetScanStatus.saved:
        primary = machineCode;
        if (faName.isNotEmpty) details.add(faName);
        label = 'Saved';
        color = _success;
        indicator = const Icon(
          Icons.check_circle_rounded,
          color: _success,
          size: 20,
        );
      case FixedAssetScanStatus.alreadyAudited:
        primary = machineCode;
        if (faName.isNotEmpty) details.add(faName);
        final auditor = auditorLabel(lastAuditedUserName, lastAuditedUserId);
        if (auditor != null) details.add('Bởi: $auditor');
        if (lastAudited != null) {
          details.add('Lúc: ${_dateTimeFormat.format(lastAudited)}');
        }
        label = 'Đã kiểm kê';
        color = _amber;
        indicator = const Icon(Icons.task_alt_rounded, color: _amber, size: 20);
      case FixedAssetScanStatus.locationMismatch:
        // Đang chờ xác nhận, hoặc đã Hủy (message = "chưa lưu").
        primary = machineCode;
        if (faName.isNotEmpty) details.add(faName);
        if (mismatchMaster != null) {
          details.add(
            'MASTER: ${fixedAssetDash(mismatchMaster.positionA)} / '
            '${fixedAssetDash(mismatchMaster.positionAA)}',
          );
        }
        if ((message ?? '').isNotEmpty) details.add(message!);
        label = 'Sai vị trí máy';
        color = _amber;
        indicator = const Icon(
          Icons.wrong_location_rounded,
          color: _amber,
          size: 20,
        );
      case FixedAssetScanStatus.mismatchSaved:
        primary = machineCode;
        if (faName.isNotEmpty) details.add(faName);
        if (mismatchMaster != null) {
          details.add(
            'MASTER: ${fixedAssetDash(mismatchMaster.positionA)} / '
            '${fixedAssetDash(mismatchMaster.positionAA)}',
          );
        }
        label = 'Đã lưu - sai vị trí';
        color = _amber;
        indicator = const Icon(
          Icons.check_circle_rounded,
          color: _amber,
          size: 20,
        );
      case FixedAssetScanStatus.unknownSaved:
        primary = machineCode;
        details.add('Saved outside master');
        label = 'Không có trong MASTER';
        color = _amber;
        indicator = const Icon(
          Icons.warning_amber_rounded,
          color: _amber,
          size: 20,
        );
      case FixedAssetScanStatus.failed:
        // Invalid QR: không có MachineCode, message là dòng chính.
        primary = hasCode ? machineCode : (message ?? 'Scan failed');
        if (hasCode && (message ?? '').isNotEmpty) {
          details.add(message!);
        }
        color = Colors.redAccent;
        indicator = const Icon(
          Icons.error_rounded,
          color: Colors.redAccent,
          size: 20,
        );
    }

    final idle = status == FixedAssetScanStatus.idle;
    final failed = status == FixedAssetScanStatus.failed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: idle ? Colors.white.withOpacity(.06) : color.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: idle ? Colors.white.withOpacity(.14) : color.withOpacity(.45),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.qr_code_2_rounded, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  primary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: idle ? Colors.white.withOpacity(.6) : Colors.white,
                    fontSize: idle ? 13.5 : 15.5,
                    fontWeight: idle ? FontWeight.w500 : FontWeight.w800,
                  ),
                ),
                for (final detail in details)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      detail,
                      maxLines: failed ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: failed
                            ? Colors.redAccent.shade100
                            : Colors.white.withOpacity(.65),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (indicator != null) ...[const SizedBox(width: 6), indicator],
        ],
      ),
    );
  }

  Widget _spinner() {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
    );
  }
}
