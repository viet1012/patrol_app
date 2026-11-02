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
/// quay về thì tải lại /qr-mismatch (máy đã gỡ cờ biến mất, có animation).
/// Tải xong mà khu rỗng: tự pop (result true) về danh sách khu.
class FixedAssetReplaceZoneScreen extends StatefulWidget {
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

  @override
  State<FixedAssetReplaceZoneScreen> createState() =>
      _FixedAssetReplaceZoneScreenState();
}

class _FixedAssetReplaceZoneScreenState
    extends State<FixedAssetReplaceZoneScreen> {
  static const Duration _removeDuration = Duration(milliseconds: 300);

  FixedAssetReplaceController get controller => widget.controller;
  FixedAssetReplaceZone get zone => widget.zone;

  /// Máy đang hiện (chưa xong), đồng bộ với controller qua [_sync].
  List<FixedAssetReplaceTask> _items = <FixedAssetReplaceTask>[];

  /// Đổi key khi thứ tự lệch (không animate được): dựng lại list.
  GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  /// Đã pop vì khu rỗng: chỉ xử lý 1 lần dù reload nhiều lần.
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _items = _pending();
    controller.addListener(_onControllerChanged);
  }

  /// Hoạt ảnh route phía trên (task screen): về dismissed = màn này hiển
  /// thị lại -> đồng bộ list (thấy animation xóa) + kiểm khu rỗng.
  Animation<double>? _coveredBy;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.secondaryAnimation;
    if (animation == _coveredBy) return;
    _coveredBy?.removeStatusListener(_onCoverStatus);
    _coveredBy = animation?..addStatusListener(_onCoverStatus);
  }

  void _onCoverStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) _onControllerChanged();
  }

  @override
  void dispose() {
    _coveredBy?.removeStatusListener(_onCoverStatus);
    controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  bool get _isCurrent => ModalRoute.of(context)?.isCurrent ?? false;

  String get _title {
    final location = zone.location;
    if (location == null) return FixedAssetReplaceStrings.unknownLocation;
    return '${location.floor} / ${location.positionA} / ${location.positionAA}';
  }

  List<FixedAssetReplaceTask> _pending() => [
    for (final t in controller.zoneByKey(zone.key, zone).tasks)
      if (!controller.isDone(t)) t,
  ];

  /// Đang bị màn khác che: hoãn tới khi hiển thị lại ([_onCoverStatus]).
  void _onControllerChanged() {
    if (!mounted || !_isCurrent) return;
    setState(_sync);
    _closeIfEmpty();
  }

  /// Máy biến mất (xong / reload): xóa khỏi list có animation; máy mới:
  /// chèn vào. Thứ tự lệch: dựng lại list không animation.
  void _sync() {
    final next = _pending();
    String code(FixedAssetReplaceTask t) => t.code;
    final nextCodes = next.map(code).toSet();

    for (var i = _items.length - 1; i >= 0; i--) {
      if (nextCodes.contains(_items[i].code)) continue;
      final removed = _items.removeAt(i);
      _listKey.currentState?.removeItem(
        i,
        (context, animation) => _animatedTile(removed, animation),
        duration: _removeDuration,
      );
    }
    for (var i = 0; i < next.length; i++) {
      if (_items.any((t) => t.code == next[i].code)) continue;
      final index = i.clamp(0, _items.length);
      _items.insert(index, next[i]);
      _listKey.currentState?.insertItem(index, duration: Duration.zero);
    }

    if (_items.map(code).join('|') != next.map(code).join('|')) {
      _listKey = GlobalKey<AnimatedListState>();
    }
    _items = next;
  }

  /// Tải xong, không lỗi, khu không còn máy, màn này đang hiển thị: pop
  /// (result true) sau khi animation xóa chạy xong.
  void _closeIfEmpty() {
    if (_closing ||
        controller.loading ||
        controller.error != null ||
        _items.isNotEmpty ||
        !_isCurrent) {
      return;
    }
    _closing = true;
    Future<void>.delayed(_removeDuration, () {
      if (mounted) Navigator.pop(context, true);
    });
  }

  Future<void> _openTask(FixedAssetReplaceTask task) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FixedAssetReplaceTaskScreen(
          controller: controller,
          task: task,
          zoneKey: zone.key,
          accountCode: widget.accountCode,
          userName: widget.userName,
        ),
      ),
    );
    if (!mounted) return;
    // Luôn tải lại (tiến độ có thể đổi dở dang); rỗng thì tự pop.
    await controller.load(silent: true);
    if (mounted) _onControllerChanged();
  }

  Widget _animatedTile(
    FixedAssetReplaceTask task,
    Animation<double> animation,
  ) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: FixedAssetReplaceTaskTile(
            key: ValueKey(task.machineCode),
            task: task,
            done: controller.isDone(task),
            oldScanned: controller.oldScannedAt(task) != null,
            onTap: () => _openTask(task),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                FixedAssetReplaceStrings.waiting(_items.length),
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
        child: Stack(
          children: [
            AnimatedList(
              key: _listKey,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
              initialItemCount: _items.length,
              itemBuilder: (context, i, animation) =>
                  _animatedTile(_items[i], animation),
            ),
            if (_items.isEmpty)
              const Center(
                child: Text(
                  FixedAssetReplaceStrings.zoneEmpty,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
