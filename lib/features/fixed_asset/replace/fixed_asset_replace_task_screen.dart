import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:chuphinh/shared/widgets/glass_action_button.dart';
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_controller.dart';
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_models.dart';
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_scan_screen.dart';
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_strings.dart';
import 'package:chuphinh/features/fixed_asset/reprint/widgets/fixed_asset_reprint_card.dart'
    show FixedAssetReprintColors;

/// Một bước trong checklist thay QR của một máy.
class _ReplaceStep {
  final String title;

  /// Tiêu đề camera (đang chờ quét gì).
  final String scanTitle;
  final DateTime? doneAt;

  /// Không làm được ở đây (vd chưa rõ vị trí thực tế); null = làm được.
  final String? blockedReason;
  final Future<String?> Function(String rawQr) onScan;

  const _ReplaceStep({
    required this.title,
    required this.scanTitle,
    required this.doneAt,
    required this.onScan,
    this.blockedReason,
  });

  bool get done => doneAt != null;
}

/// Màn "Việc cần làm" của một máy: header (mã, tên, vị trí thực tế, loại
/// việc) + checklist đánh số; chỉ ô kế tiếp bấm được, bấm -> camera quét.
/// Sai QR: (1) QR cũ (2) QR mới; Mất QR: (1) QR mới.
class FixedAssetReplaceTaskScreen extends StatelessWidget {
  final FixedAssetReplaceController controller;
  final FixedAssetReplaceTask task;

  /// Khu của máy (tìm "Máy tiếp theo").
  final String zoneKey;
  final String accountCode;
  final String userName;

  const FixedAssetReplaceTaskScreen({
    super.key,
    required this.controller,
    required this.task,
    required this.zoneKey,
    required this.accountCode,
    this.userName = '',
  });

  static final DateFormat _time = DateFormat('HH:mm');

  List<_ReplaceStep> _steps() {
    final userId = accountCode.trim();
    final name = userName.trim().isEmpty ? userId : userName.trim();
    final newStep = _ReplaceStep(
      title: FixedAssetReplaceStrings.stepNew(task.actShort),
      scanTitle: FixedAssetReplaceStrings.scanNewTitle(
        task.machineCode,
        task.actShort,
      ),
      doneAt: controller.doneAt(task),
      blockedReason: task.location == null
          ? FixedAssetReplaceStrings.unknownAct
          : null,
      onScan: (raw) => controller.scanNewQr(
        task,
        raw,
        userId: userId,
        userName: name,
      ),
    );
    if (task.kind == FixedAssetReplaceKind.missingQr) return [newStep];
    return [
      _ReplaceStep(
        title: FixedAssetReplaceStrings.stepOld(task.oldQrShort),
        scanTitle: FixedAssetReplaceStrings.scanOldTitle(
          task.machineCode,
          task.oldQrShort,
        ),
        doneAt: controller.oldScannedAt(task),
        onScan: (raw) async => controller.scanOldQr(task, raw),
      ),
      newStep,
    ];
  }

  Future<void> _openCamera(BuildContext context, _ReplaceStep step) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FixedAssetReplaceScanScreen(
          title: step.scanTitle,
          onScan: step.onScan,
        ),
      ),
    );
  }

  void _openNext(BuildContext context, FixedAssetReplaceTask next) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FixedAssetReplaceTaskScreen(
          controller: controller,
          task: next,
          zoneKey: zoneKey,
          accountCode: accountCode,
          userName: userName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final steps = _steps();
        final activeIndex = steps.indexWhere((s) => !s.done);
        final allDone = activeIndex < 0;

        return Scaffold(
          backgroundColor: FixedAssetReprintColors.appBar,
          appBar: AppBar(
            backgroundColor: FixedAssetReprintColors.appBar,
            centerTitle: false,
            titleSpacing: 4,
            leading: GlassActionButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.pop(context),
            ),
            title: const Text(
              FixedAssetReplaceStrings.tasksTitle,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF121826),
                  Color(0xFF1F2937),
                  Color(0xFF374151),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                for (var i = 0; i < steps.length; i++) ...[
                  _buildStep(
                    context,
                    number: i + 1,
                    step: steps[i],
                    active: i == activeIndex,
                  ),
                  const SizedBox(height: 12),
                ],
                if (allDone) ...[
                  const SizedBox(height: 4),
                  _buildDone(context),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final missing = task.kind == FixedAssetReplaceKind.missingQr;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.machineCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: FixedAssetReprintColors.amber.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: FixedAssetReprintColors.amber.withValues(alpha: .7),
                  ),
                ),
                child: Text(
                  missing
                      ? FixedAssetReplaceStrings.kindMissing
                      : FixedAssetReplaceStrings.kindWrongShort,
                  style: const TextStyle(
                    color: FixedAssetReprintColors.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (task.faName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              task.faName,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .7),
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            FixedAssetReplaceStrings.actual(task.actLabel),
            style: const TextStyle(
              color: FixedAssetReprintColors.newQr,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// Ô xong: tick xanh + giờ. Ô đang chờ: viền nổi bật + camera. Ô sau: mờ.
  Widget _buildStep(
    BuildContext context, {
    required int number,
    required _ReplaceStep step,
    required bool active,
  }) {
    final done = step.done;
    final blocked = active && step.blockedReason != null;
    final enabled = active && !blocked;
    final accent = done
        ? FixedAssetReprintColors.newQr
        : enabled
        ? FixedAssetReprintColors.coral
        : Colors.white.withValues(alpha: .3);

    final subtitle = done
        ? FixedAssetReplaceStrings.doneAt(_time.format(step.doneAt!))
        : blocked
        ? step.blockedReason!
        : enabled
        ? FixedAssetReplaceStrings.tapToScan
        : null;

    return Opacity(
      opacity: done || active ? 1 : .4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? () => _openCamera(context, step) : null,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
            decoration: BoxDecoration(
              color: enabled
                  ? FixedAssetReprintColors.coral.withValues(alpha: .12)
                  : Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent, width: enabled ? 2.5 : 1.2),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done ? accent : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 2),
                  ),
                  child: done
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 26,
                        )
                      : Text(
                          '$number',
                          style: TextStyle(
                            color: accent,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: done
                                ? FixedAssetReprintColors.newQr
                                : blocked
                                ? FixedAssetReprintColors.amber
                                : Colors.white.withValues(alpha: .7),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (enabled)
                  const Icon(
                    Icons.photo_camera_rounded,
                    color: FixedAssetReprintColors.coral,
                    size: 34,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Banner xanh "Đã thay QR xong" + "Máy tiếp theo" / "Về danh sách"; hết
  /// máy trong khu -> "Khu {AA} đã thay xong QR".
  Widget _buildDone(BuildContext context) {
    final next = controller.nextTask(zoneKey, task);
    final positionAA = task.location?.positionAA ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FixedAssetReprintColors.newQr.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: FixedAssetReprintColors.newQr),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: FixedAssetReprintColors.newQr,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      FixedAssetReplaceStrings.allDone,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (next == null && positionAA.isNotEmpty)
                      Text(
                        FixedAssetReplaceStrings.zoneDone(positionAA),
                        style: const TextStyle(
                          color: FixedAssetReprintColors.newQr,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (next != null) ...[
          FilledButton.icon(
            onPressed: () => _openNext(context, next),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(
              '${FixedAssetReplaceStrings.nextMachine}: ${next.machineCode}',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: FixedAssetReprintColors.coral,
              foregroundColor: const Color(0xFF111827),
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.list_rounded),
          label: const Text(FixedAssetReplaceStrings.backToList),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
            side: BorderSide(color: Colors.white.withValues(alpha: .4)),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
