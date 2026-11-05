import 'dart:async';
import 'dart:typed_data';

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

  /// Phần sau mã máy trên thẻ thông tin camera, vd "· đang dán tại A6-3".
  final String scanPlace;
  final DateTime? doneAt;

  /// Không làm được ở đây (vd chưa rõ vị trí thực tế); null = làm được.
  final String? blockedReason;
  final FixedAssetReplaceOnScan onScan;

  /// Bước quét QR mới (bước cuối, gọi API hoàn tất, chụp ảnh kèm).
  final bool isNew;

  const _ReplaceStep({
    required this.title,
    required this.scanPlace,
    required this.doneAt,
    required this.onScan,
    required this.isNew,
    this.blockedReason,
  });

  bool get done => doneAt != null;
}

/// Màn "Việc cần làm" của một máy: header (mã, tên, vị trí thực tế, loại
/// việc) + checklist đánh số; chỉ ô kế tiếp bấm được, bấm -> camera quét.
/// Sai QR: (1) QR cũ (2) QR mới; Mất QR: (1) QR mới.
///
/// QR cũ đúng: camera đóng, ~600 ms sau tự mở camera bước QR mới. QR mới
/// xong: snackbar "Đã thay QR …" rồi pop true (màn trước tải lại). Tự đóng
/// camera / lưu lỗi: ở lại, bước QR mới bấm lại được.
class FixedAssetReplaceTaskScreen extends StatefulWidget {
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

  @override
  State<FixedAssetReplaceTaskScreen> createState() =>
      _FixedAssetReplaceTaskScreenState();
}

class _FixedAssetReplaceTaskScreenState
    extends State<FixedAssetReplaceTaskScreen> {
  static final DateFormat _time = DateFormat('HH:mm');

  /// Từ lúc đóng camera QR cũ tới lúc tự mở camera QR mới.
  static const Duration _autoNextDelay = Duration(milliseconds: 600);

  FixedAssetReplaceController get controller => widget.controller;
  FixedAssetReplaceTask get task => widget.task;
  String get zoneKey => widget.zoneKey;
  String get accountCode => widget.accountCode;
  String get userName => widget.userName;

  /// Camera đang mở: chặn mở chồng (bấm nhanh / tự mở bước 2).
  bool _cameraOpen = false;

  /// Lỗi lưu ở bước QR mới (camera đã đóng); null = không có.
  String? _saveError;

  @override
  void initState() {
    super.initState();
    // Vào màn: mở ngay camera bước đang chờ (thường là bước 1). Đóng camera
    // thì ở lại, bấm bước để mở lại.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final step in _steps()) {
        if (step.done) continue;
        if (step.blockedReason == null) _openCamera(context, step);
        return;
      }
    });
  }

  List<_ReplaceStep> _steps() {
    final userId = accountCode.trim();
    final name = userName.trim().isEmpty ? userId : userName.trim();
    final newStep = _ReplaceStep(
      title: FixedAssetReplaceStrings.stepNew(task.actShort),
      scanPlace: FixedAssetReplaceStrings.placeNew(task.actShort),
      doneAt: controller.doneAt(task),
      blockedReason: task.location == null
          ? FixedAssetReplaceStrings.unknownAct
          : null,
      onScan: (raw, photo) => controller.scanNewQr(
        task,
        raw,
        userId: userId,
        userName: name,
        photo: photo,
      ),
      isNew: true,
    );
    if (task.kind == FixedAssetReplaceKind.missingQr) return [newStep];
    return [
      _ReplaceStep(
        title: FixedAssetReplaceStrings.stepOld(task.oldQrShort),
        scanPlace: FixedAssetReplaceStrings.placeOld(task.oldQrShort),
        doneAt: controller.oldScannedAt(task),
        onScan: (raw, photo) async {
          final error = controller.scanOldQr(task, raw);
          // Đúng QR cũ: upload ảnh ngầm (type=before), không chờ.
          if (error == null && photo != null) {
            unawaited(_uploadBeforePhoto(photo, userId, raw));
          }
          return FixedAssetReplaceScanOutcome(error);
        },
        isNew: false,
      ),
      newStep,
    ];
  }

  /// Lỗi (đã thử lại 1 lần): snackbar nhỏ, không chặn bước QR mới.
  Future<void> _uploadBeforePhoto(
    Future<Uint8List?> photo,
    String userId,
    String rawQr,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await controller.uploadBeforePhoto(
      task,
      photo,
      userId: userId,
      rawQr: rawQr,
    );
    if (ok || !messenger.mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text(FixedAssetReplaceStrings.beforePhotoFailed),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openCamera(BuildContext context, _ReplaceStep step) async {
    if (_cameraOpen) return;
    _cameraOpen = true;
    setState(() => _saveError = null);
    final twoSteps = task.kind != FixedAssetReplaceKind.missingQr;
    final result = await Navigator.push<FixedAssetReplaceScanResult>(
      context,
      MaterialPageRoute(
        builder: (_) => FixedAssetReplaceScanScreen(
          kind: step.isNew
              ? FixedAssetReplaceQrKind.newQr
              : FixedAssetReplaceQrKind.oldQr,
          machineCode: task.machineCode,
          place: step.scanPlace,
          showSteps: twoSteps,
          capturePhoto: true,
          oldQrScanned:
              step.isNew && twoSteps && controller.oldScannedAt(task) != null
              ? task.oldQrShort
              : null,
          onScan: step.onScan,
        ),
      ),
    );
    _cameraOpen = false;
    // null = tự đóng camera: ở lại, bước đang chờ vẫn bấm được.
    if (!mounted || result == null) return;
    if (!result.done) {
      setState(() => _saveError = result.error);
      return;
    }

    if (!step.isNew) {
      // QR cũ xong (tick xanh): tự mở camera QR mới.
      await Future<void>.delayed(_autoNextDelay);
      if (!mounted || !(ModalRoute.of(this.context)?.isCurrent ?? false)) {
        return;
      }
      for (final next in _steps()) {
        if (next.done) continue;
        if (next.isNew && next.blockedReason == null) {
          await _openCamera(this.context, next);
        }
        return;
      }
      return;
    }

    _afterReplaced();
  }

  /// Thay xong máy này: khu còn máy chờ -> thay màn bằng "Việc cần làm" của
  /// máy kế tiếp; hết máy -> pop về danh sách khu (true, khu tự tải lại).
  void _afterReplaced() {
    final next = controller.nextTask(zoneKey, task);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (next == null) {
      final location = task.location;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            location == null
                ? FixedAssetReplaceStrings.replaced(task.machineCode)
                : FixedAssetReplaceStrings.zoneFinished(
                    '${location.floor}/${location.positionA}/'
                    '${location.positionAA}',
                  ),
          ),
        ),
      );
      // Danh sách khu tải lại; rỗng thì nó tự pop về danh sách khu vực.
      controller.load(silent: true);
      Navigator.pop(context, true);
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          FixedAssetReplaceStrings.replacedNext(
            task.machineCode,
            next.machineCode,
          ),
        ),
      ),
    );
    // Danh sách khu cập nhật ngầm trong lúc làm máy kế tiếp.
    controller.load(silent: true);
    _openNext(context, next, result: true);
  }

  void _openNext(
    BuildContext context,
    FixedAssetReplaceTask next, {
    bool? result,
  }) {
    Navigator.pushReplacement(
      context,
      result: result,
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
    // Lưu lỗi ở bước QR mới: báo dưới bước, bấm lại để quét.
    final saveError = enabled && step.isNew ? _saveError : null;

    final subtitle = done
        ? FixedAssetReplaceStrings.doneAt(_time.format(step.doneAt!))
        : blocked
        ? step.blockedReason!
        : saveError ??
              (enabled ? FixedAssetReplaceStrings.tapToScan : null);

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
                                : saveError != null
                                ? Colors.redAccent
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
