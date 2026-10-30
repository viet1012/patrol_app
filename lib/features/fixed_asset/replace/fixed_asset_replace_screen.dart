import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:chuphinh/shared/widgets/glass_action_button.dart';
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_controller.dart';
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_models.dart';
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_strings.dart';
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_zone_screen.dart';
import 'package:chuphinh/features/fixed_asset/reprint/widgets/fixed_asset_reprint_card.dart'
    show FixedAssetReprintColors;

/// Màn "Thay QR": máy còn chờ thay QR theo khu vực thực tế. Lọc xưởng,
/// gom Floor → A → AA (số máy chờ mỗi khu); bấm khu -> danh sách máy.
class FixedAssetReplaceScreen extends StatefulWidget {
  final String accountCode;
  final String? selectedPlant;
  final String userName;
  final String lang;

  const FixedAssetReplaceScreen({
    super.key,
    required this.accountCode,
    this.selectedPlant,
    this.userName = '',
    this.lang = 'VI',
  });

  @override
  State<FixedAssetReplaceScreen> createState() =>
      _FixedAssetReplaceScreenState();
}

class _FixedAssetReplaceScreenState extends State<FixedAssetReplaceScreen> {
  final FixedAssetReplaceController _controller = FixedAssetReplaceController();

  /// Đã chọn xưởng mặc định sau lần tải đầu.
  bool _facDefaulted = false;

  @override
  void initState() {
    super.initState();
    _controller.load().then((_) {
      if (_facDefaulted) return;
      _facDefaulted = true;
      final facs = _controller.facs;
      if (facs.length == 1) _controller.setFac(facs.single);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openZone(FixedAssetReplaceZone zone) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FixedAssetReplaceZoneScreen(
          controller: _controller,
          zone: zone,
          accountCode: widget.accountCode,
          userName: widget.userName,
        ),
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FixedAssetReprintColors.appBar,
      appBar: _buildAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF121826), Color(0xFF1F2937), Color(0xFF374151)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Column(
            children: [
              if (!_controller.loading &&
                  _controller.error == null &&
                  _controller.tasks.isNotEmpty)
                _buildFacFilter(),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: FixedAssetReprintColors.appBar,
      centerTitle: false,
      titleSpacing: 4,
      leading: GlassActionButton(
        icon: Icons.arrow_back_rounded,
        onTap: () => Navigator.pop(context),
      ),
      title: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              FixedAssetReplaceStrings.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (!_controller.loading && _controller.error == null)
              Text(
                FixedAssetReplaceStrings.subtitle(_controller.visibleCount),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
          ],
        ),
      ),
      actions: [
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => IconButton(
            tooltip: FixedAssetReplaceStrings.refresh,
            onPressed: _controller.loading ? null : _controller.load,
            color: Colors.white,
            disabledColor: FixedAssetReprintColors.textDisabled,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildFacFilter() {
    final c = _controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          const Text(
            '${FixedAssetReplaceStrings.fac}:',
            style: TextStyle(
              color: FixedAssetReprintColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FixedAssetReprintColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: c.fac,
                  isExpanded: true,
                  dropdownColor: FixedAssetReprintColors.surface,
                  iconEnabledColor: Colors.white70,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text(FixedAssetReplaceStrings.allFacs),
                    ),
                    for (final fac in c.facs)
                      DropdownMenuItem<String?>(value: fac, child: Text(fac)),
                  ],
                  onChanged: c.setFac,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final c = _controller;
    if (c.loading) return const _ReplaceSkeleton();
    if (c.error != null) return _buildError(c.error!);

    final floors = c.floors;
    final unknown = c.unknownZone;
    if (floors.isEmpty && unknown == null) {
      return _message(
        Icons.check_circle_rounded,
        FixedAssetReprintColors.newQr,
        FixedAssetReplaceStrings.empty,
      );
    }
    // "Tất cả xưởng": tiêu đề tầng kèm xưởng.
    final showFac = c.fac == null;

    return RefreshIndicator(
      onRefresh: c.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 16),
        children: [
          for (final floor in floors) ...[
            _floorHeader(
              showFac ? '${floor.fac} · ${floor.floor}' : floor.floor,
              floor.count,
            ),
            for (final area in floor.areas) ...[
              _areaHeader(area),
              for (final zone in area.zones)
                _zoneTile(zone.location!.positionAA, zone),
            ],
          ],
          if (unknown != null) ...[
            _floorHeader(
              FixedAssetReplaceStrings.unknownLocation,
              unknown.tasks.length,
            ),
            _zoneTile(FixedAssetReplaceStrings.unknownLocation, unknown),
          ],
        ],
      ),
    );
  }

  Widget _floorHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: FixedAssetReprintColors.coralSoft.withValues(alpha: .8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _count(count),
        ],
      ),
    );
  }

  Widget _areaHeader(FixedAssetReplaceArea area) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              area.positionA,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .75),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            FixedAssetReplaceStrings.waiting(area.count),
            style: TextStyle(
              color: Colors.white.withValues(alpha: .55),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoneTile(String title, FixedAssetReplaceZone zone) {
    final known = zone.isKnown;
    return Padding(
      padding: EdgeInsets.only(left: known ? 14 : 0, bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openZone(zone),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: known
                    ? Colors.white.withValues(alpha: .14)
                    : FixedAssetReprintColors.amber.withValues(alpha: .5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  known ? Icons.place_rounded : Icons.help_outline_rounded,
                  size: 18,
                  color: known
                      ? FixedAssetReprintColors.coralSoft
                      : FixedAssetReprintColors.amber,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  FixedAssetReplaceStrings.waiting(zone.tasks.length),
                  style: const TextStyle(
                    color: FixedAssetReprintColors.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white54,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _count(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: FixedAssetReprintColors.coral.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: FixedAssetReprintColors.coral.withValues(alpha: .6),
        ),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: FixedAssetReprintColors.coral,
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Colors.redAccent,
              size: 40,
            ),
            const SizedBox(height: 10),
            const Text(
              FixedAssetReplaceStrings.loadFailed,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              error,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .6),
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _controller.load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(FixedAssetReplaceStrings.retry),
              style: OutlinedButton.styleFrom(
                foregroundColor: FixedAssetReprintColors.coralSoft,
                side: BorderSide(
                  color: FixedAssetReprintColors.coralSoft.withValues(
                    alpha: .6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(IconData icon, Color color, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 44),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton lúc tải danh sách.
class _ReplaceSkeleton extends StatelessWidget {
  const _ReplaceSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: .06),
      highlightColor: Colors.white.withValues(alpha: .16),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
        itemCount: 8,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
