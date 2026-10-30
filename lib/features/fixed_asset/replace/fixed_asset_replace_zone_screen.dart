import 'package:flutter/material.dart';

import 'package:chuphinh/shared/widgets/glass_action_button.dart';
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_controller.dart';
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_models.dart';
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_strings.dart';
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_task_screen.dart';
import 'package:chuphinh/features/fixed_asset/replace/widgets/fixed_asset_replace_task_tile.dart';
import 'package:chuphinh/features/fixed_asset/reprint/widgets/fixed_asset_reprint_card.dart'
    show FixedAssetReprintColors;

/// Danh sách máy chờ thay QR của một khu. Bấm máy -> màn "Việc cần làm";
/// quay về thì tải lại /qr-mismatch (máy đã gỡ cờ biến mất).
class FixedAssetReplaceZoneScreen extends StatelessWidget {
  final FixedAssetReplaceController controller;
  final FixedAssetReplaceZone zone;
  final String accountCode;
  final String userName;

  const FixedAssetReplaceZoneScreen({
    super.key,
    required this.controller,
    required this.zone,
    required this.accountCode,
    this.userName = '',
  });

  String get _title {
    final location = zone.location;
    if (location == null) return FixedAssetReplaceStrings.unknownLocation;
    return '${location.floor} / ${location.positionA} / ${location.positionAA}';
  }

  Future<void> _openTask(
    BuildContext context,
    FixedAssetReplaceTask task,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FixedAssetReplaceTaskScreen(
          controller: controller,
          task: task,
          zoneKey: zone.key,
          accountCode: accountCode,
          userName: userName,
        ),
      ),
    );
    controller.load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final current = controller.zoneByKey(zone.key, zone);
        final tasks = current.tasks;
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
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  [
                    if (zone.location != null) zone.location!.fac,
                    FixedAssetReplaceStrings.waiting(
                      tasks.where((t) => !controller.isDone(t)).length,
                    ),
                  ].join(' · '),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
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
            child: tasks.isEmpty
                ? const Center(
                    child: Text(
                      FixedAssetReplaceStrings.zoneEmpty,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final task = tasks[i];
                      return FixedAssetReplaceTaskTile(
                        key: ValueKey(task.machineCode),
                        task: task,
                        done: controller.isDone(task),
                        oldScanned: controller.oldScannedAt(task) != null,
                        onTap: () => _openTask(context, task),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}
