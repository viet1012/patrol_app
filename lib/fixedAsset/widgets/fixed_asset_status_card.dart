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

  /// [FixedAssetScanStatus.zoneLocked]: "Chuyển Manual" button.
  final VoidCallback? onSwitchManual;

  /// [FixedAssetScanStatus.needsLocation]: primary "Dùng vị trí {label}"
  /// (null label = not offered) and secondary "Chuyển Auto".
  final String? qrLocationLabel;
  final VoidCallback? onUseQrLocation;
  final VoidCallback? onSwitchAuto;

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
    this.onSwitchManual,
    this.qrLocationLabel,
    this.onUseQrLocation,
    this.onSwitchAuto,
  });

  /// "Việt (KVH_IT_Mem_Viet)" / "Việt" / "KVH_IT_Mem_Viet".
  /// null khi không có cả hai -> không hiện phần auditor.
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
    String? alreadyAuditedBy;
    String? alreadyAuditedTime;
    String? label;
    Color color;
    Widget? indicator;

    switch (status) {
      case FixedAssetScanStatus.idle:
        primary = 'Scan machine QR';
        color = Colors.white54;
      case FixedAssetScanStatus.checking:
        primary = machineCode;
        // MANUAL passes "Đang kiểm tra {code}…"; AUTO keeps the default.
        details.add(
          (message ?? '').isNotEmpty ? message! : 'Checking audit status...',
        );
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
        alreadyAuditedBy = auditorLabel(lastAuditedUserName, lastAuditedUserId);
        if (lastAudited != null) {
          alreadyAuditedTime = _dateTimeFormat.format(lastAudited);
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
      case FixedAssetScanStatus.zoneLocked:
        // AUTO khóa ở khu vực khác: QR này không được check / lưu.
        primary = hasCode ? machineCode : 'Khu vực đang khóa';
        if ((message ?? '').isNotEmpty) details.add(message!);
        label = 'Khóa khu vực';
        color = _amber;
        indicator = const Icon(Icons.lock_rounded, color: _amber, size: 20);
      case FixedAssetScanStatus.needsLocation:
        // MANUAL, location not chosen yet: nothing was saved.
        primary = hasCode ? machineCode : 'Chưa chọn vị trí';
        if ((message ?? '').isNotEmpty) details.add(message!);
        label = 'Chọn vị trí';
        color = _amber;
        indicator = const Icon(
          Icons.edit_location_alt_rounded,
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
    final zoneLocked = status == FixedAssetScanStatus.zoneLocked;
    final needsLocation = status == FixedAssetScanStatus.needsLocation;
    final statusIndicator = _statusIndicator(
      label: label,
      color: color,
      indicator: indicator,
    );

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.qr_code_2_rounded, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        primary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: idle
                              ? Colors.white.withOpacity(.6)
                              : Colors.white,
                          fontSize: idle ? 13.5 : 15.5,
                          fontWeight: idle ? FontWeight.w500 : FontWeight.w800,
                        ),
                      ),
                    ),
                    if (statusIndicator != null) ...[
                      const SizedBox(width: 8),
                      statusIndicator,
                    ],
                  ],
                ),
                for (final detail in details)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      detail,
                      maxLines: failed || zoneLocked || needsLocation ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: failed
                            ? Colors.redAccent.shade100
                            : Colors.white.withOpacity(.65),
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (needsLocation)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      children: [
                        if (qrLocationLabel != null && onUseQrLocation != null)
                          FilledButton.icon(
                            onPressed: onUseQrLocation,
                            icon: const Icon(Icons.my_location_rounded, size: 16),
                            label: Text('Dùng vị trí $qrLocationLabel'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _amber,
                              foregroundColor: Colors.black,
                              visualDensity: VisualDensity.compact,
                              textStyle: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        if (onSwitchAuto != null)
                          TextButton(
                            onPressed: onSwitchAuto,
                            style: TextButton.styleFrom(
                              foregroundColor: _amber,
                              visualDensity: VisualDensity.compact,
                              textStyle: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('Chuyển Auto'),
                          ),
                      ],
                    ),
                  ),
                if (zoneLocked && onSwitchManual != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onSwitchManual,
                      icon: const Icon(Icons.touch_app_rounded, size: 16),
                      label: const Text('Chuyển Manual'),
                      style: TextButton.styleFrom(
                        foregroundColor: _amber,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                if (status == FixedAssetScanStatus.alreadyAudited &&
                    (alreadyAuditedBy != null || alreadyAuditedTime != null))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _alreadyAuditedMetadata(
                      auditor: alreadyAuditedBy,
                      time: alreadyAuditedTime,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _statusIndicator({
    required String? label,
    required Color color,
    required Widget? indicator,
  }) {
    if (label == null && indicator == null) return null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        if (label != null && indicator != null) const SizedBox(width: 6),
        if (indicator != null) indicator,
      ],
    );
  }

  Widget _spinner() {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
    );
  }

  Widget _alreadyAuditedMetadata({String? auditor, String? time}) {
    Widget auditorSection() => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.person_outline_rounded,
          size: 12,
          color: Colors.white70,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            auditor!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 10.5),
          ),
        ),
      ],
    );

    Widget timeSection() => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.schedule_rounded, size: 12, color: Colors.white60),
        const SizedBox(width: 3),
        Text(
          time!,
          maxLines: 1,
          style: const TextStyle(color: Colors.white60, fontSize: 10.5),
        ),
      ],
    );

    if (auditor == null) return timeSection();
    if (time == null) return auditorSection();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 230) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              auditorSection(),
              const SizedBox(height: 1),
              timeSection(),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: auditorSection()),
            const SizedBox(width: 8),
            timeSection(),
          ],
        );
      },
    );
  }
}
