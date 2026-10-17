import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:chuphinh/shared/widgets/common_ui_helper.dart';
import 'package:chuphinh/shared/widgets/glass_action_button.dart';
import 'package:chuphinh/features/fixed_asset/reprint/fixed_asset_reprint_controller.dart';
import 'package:chuphinh/features/fixed_asset/reprint/fixed_asset_reprint_export.dart';
import 'package:chuphinh/features/fixed_asset/reprint/fixed_asset_reprint_strings.dart';
import 'package:chuphinh/features/fixed_asset/reprint/widgets/fixed_asset_reprint_card.dart';
import 'package:chuphinh/features/fixed_asset/reprint/widgets/fixed_asset_reprint_preview.dart';

/// Màn "In lại QR": máy có lần quét mới nhất QR lệch vị trí. QR mới tạo từ
/// VỊ TRÍ ĐANG CHỌN lúc kiểm kê. Quét lại bằng QR mới đúng vị trí thì máy
/// tự rời danh sách (backend), không có trạng thái "đã in".
///
/// Lấy mọi xưởng (audit lưu theo xưởng Fac_A/B/C, không theo nhà máy ở
/// home); lọc xưởng bằng hàng chip trên UI.
class FixedAssetReprintScreen extends StatefulWidget {
  const FixedAssetReprintScreen({super.key});

  @override
  State<FixedAssetReprintScreen> createState() =>
      _FixedAssetReprintScreenState();
}

class _FixedAssetReprintScreenState extends State<FixedAssetReprintScreen> {
  final FixedAssetReprintController _controller =
      FixedAssetReprintController();
  final TextEditingController _searchController = TextEditingController();

  /// Đang tạo PNG / PDF: chặn bấm lặp.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _run(Future<void> Function() task, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
      if (mounted && success != null) {
        CommonUI.showSnackBar(
          context: context,
          message: success,
          color: const Color(0xFF16A34A),
        );
      }
    } catch (error) {
      debugPrint('[FA-REPRINT] export failed: $error');
      if (mounted) {
        CommonUI.showSnackBar(
          context: context,
          message: '${FixedAssetReprintStrings.exportFailed}: $error',
          color: Colors.redAccent,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadPng(List<FixedAssetReprintItem> items) {
    final labels = items.map(FixedAssetQrLabel.of).toList();
    return _run(
      () => downloadFixedAssetQrPngs(labels),
      success: FixedAssetReprintStrings.downloaded(labels.length),
    );
  }

  Future<void> _print(List<FixedAssetReprintItem> items) {
    final labels = items.map(FixedAssetQrLabel.of).toList();
    return _run(() => printFixedAssetQrLabels(labels));
  }

  void _preview(FixedAssetReprintItem item) {
    showFixedAssetReprintPreview(
      context,
      item: item,
      onDownload: () => _downloadPng([item]),
      onPrint: () => _print([item]),
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
                  _controller.items.isNotEmpty) ...[
                _buildFacChips(),
                _buildToolbar(),
              ],
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: _controller.selectedCount > 0
              ? _buildActionBar()
              : const SizedBox(width: double.infinity),
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
              FixedAssetReprintStrings.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (!_controller.loading && _controller.error == null)
              Text(
                FixedAssetReprintStrings.subtitle(_controller.items.length),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
          ],
        ),
      ),
      actions: [
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => IconButton(
            tooltip: FixedAssetReprintStrings.refresh,
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

  /// "Tất cả (N)" · "Fac_A (n)" · … (xưởng lấy từ dữ liệu, sắp theo tên).
  Widget _buildFacChips() {
    final c = _controller;
    final unknown = c.unknownFacCount;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        children: [
          _facChip(null, FixedAssetReprintStrings.allFacs(c.items.length)),
          for (final f in c.facCounts)
            _facChip(f.fac, FixedAssetReprintStrings.facChip(f.fac, f.count)),
          if (unknown > 0)
            _facChip(
              '',
              FixedAssetReprintStrings.facChip(
                FixedAssetReprintStrings.unknownFac,
                unknown,
              ),
            ),
        ],
      ),
    );
  }

  /// Chip tự vẽ (không dùng ChoiceChip: màu theme sáng mặc định làm chip
  /// chưa chọn nền trắng chữ trắng). Cùng kiểu với chip "Tất cả khu vực".
  Widget _facChip(String? fac, String label) {
    final selected = _controller.fac == fac;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => _controller.setFac(fac),
          child: _pill(
            selected: selected,
            child: Text(
              label,
              style: TextStyle(
                color: _pillText(selected),
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Chưa chọn: nền trong suốt, viền xám 0.2, chữ trắng 0.8.
  /// Đang chọn: nền màu nhấn 0.15, viền màu nhấn 0.6, chữ màu nhấn.
  Widget _pill({required bool selected, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? FixedAssetReprintColors.coral.withValues(alpha: .15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? FixedAssetReprintColors.coral.withValues(alpha: .6)
              : FixedAssetReprintColors.border,
        ),
      ),
      child: child,
    );
  }

  static Color _pillText(bool selected) => selected
      ? FixedAssetReprintColors.coral
      : FixedAssetReprintColors.textMuted;

  Widget _buildToolbar() {
    final c = _controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: TextField(
              controller: _searchController,
              onChanged: c.setSearch,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              cursorColor: FixedAssetReprintColors.coralSoft,
              decoration: InputDecoration(
                isDense: true,
                hintText: FixedAssetReprintStrings.searchHint,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: .5),
                  fontSize: 13.5,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: .08),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: .6),
                ),
                suffixIcon: c.search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          c.setSearch('');
                        },
                      ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: FixedAssetReprintColors.border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: FixedAssetReprintColors.coralSoft.withValues(
                      alpha: .7,
                    ),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Flexible(child: _buildAreaFilter()),
              const Spacer(),
              TextButton.icon(
                onPressed: c.visibleItems.any((e) => e.isReady)
                    ? c.toggleSelectAllVisible
                    : null,
                icon: Icon(
                  c.allVisibleSelected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 18,
                ),
                label: Text(
                  c.allVisibleSelected
                      ? FixedAssetReprintStrings.deselectAll
                      : FixedAssetReprintStrings.selectAll,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: FixedAssetReprintColors.coralSoft,
                  disabledForegroundColor: FixedAssetReprintColors.textDisabled,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAreaFilter() {
    final c = _controller;
    final active = c.area != null;
    return PopupMenuButton<String?>(
      tooltip: FixedAssetReprintStrings.allAreas,
      color: FixedAssetReprintColors.surface,
      onSelected: c.setArea,
      itemBuilder: (_) => [
        const PopupMenuItem<String?>(
          value: null,
          child: Text(
            FixedAssetReprintStrings.allAreas,
            style: TextStyle(color: Colors.white),
          ),
        ),
        for (final area in c.areas)
          PopupMenuItem<String?>(
            value: area,
            child: Text(area, style: const TextStyle(color: Colors.white)),
          ),
      ],
      child: _pill(
        selected: active,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_rounded,
              size: 16,
              color: _pillText(active),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                c.area ?? FixedAssetReprintStrings.allAreas,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _pillText(active),
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: _pillText(active),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final c = _controller;
    if (c.loading) return const _ReprintSkeleton();
    if (c.error != null) return _buildError(c.error!);
    if (c.items.isEmpty) {
      return _message(
        Icons.check_circle_rounded,
        FixedAssetReprintColors.newQr,
        FixedAssetReprintStrings.empty,
      );
    }

    final groups = c.visibleGroups;
    if (groups.every((g) => g.items.isEmpty)) {
      return _message(
        Icons.search_off_rounded,
        Colors.white54,
        FixedAssetReprintStrings.noMatch,
      );
    }
    // "Tất cả": nhóm theo xưởng, mỗi nhóm có tiêu đề nhỏ.
    final showHeaders = c.fac == null;

    Widget card(FixedAssetReprintItem item) => FixedAssetReprintCard(
      key: ValueKey(item.machineCode),
      item: item,
      selected: c.isSelected(item),
      onToggle: () => c.toggle(item),
      onPreview: () => _preview(item),
    );

    // Mobile: 1 cột; tablet / desktop rộng: lưới 2–3 cột.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100 ? 3 : (width >= 700 ? 2 : 1);
        return CustomScrollView(
          slivers: [
            for (final group in groups) ...[
              if (showHeaders)
                SliverToBoxAdapter(child: _groupHeader(group)),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(10, showHeaders ? 0 : 6, 10, 6),
                sliver: columns == 1
                    ? SliverList.separated(
                        itemCount: group.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => card(group.items[i]),
                      )
                    : SliverGrid.builder(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisExtent: 128,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                        itemCount: group.items.length,
                        itemBuilder: (_, i) => card(group.items[i]),
                      ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
          ],
        );
      },
    );
  }

  Widget _groupHeader(FixedAssetReprintGroup group) {
    final name = group.fac.isEmpty
        ? FixedAssetReprintStrings.unknownFac
        : group.fac;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: FixedAssetReprintColors.coralSoft.withValues(alpha: .7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            FixedAssetReprintStrings.facGroup(name, group.items.length),
            style: TextStyle(
              color: Colors.white.withValues(alpha: .75),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
            ),
          ),
        ],
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
              FixedAssetReprintStrings.loadFailed,
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
            // Viền (không tô nền): nút nền màu nhấn chỉ dành cho "In".
            OutlinedButton.icon(
              onPressed: _controller.load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(FixedAssetReprintStrings.retry),
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

  /// Dính đáy khi có chọn: "Đã chọn X" · "Tải PNG" · "In tem (PDF)".
  Widget _buildActionBar() {
    final selected = _controller.selectedItems;
    return Container(
      decoration: BoxDecoration(
        color: FixedAssetReprintColors.surface,
        border: const Border(
          top: BorderSide(color: FixedAssetReprintColors.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              IconButton(
                tooltip: FixedAssetReprintStrings.deselectAll,
                onPressed: _busy ? null : _controller.clearSelection,
                color: FixedAssetReprintColors.textMuted,
                disabledColor: FixedAssetReprintColors.textDisabled,
                icon: const Icon(Icons.close_rounded),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  FixedAssetReprintStrings.selected(selected.length),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: FixedAssetReprintColors.coralSoft,
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _downloadPng(selected),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text(FixedAssetReprintStrings.downloadPng),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: FixedAssetReprintColors.textDisabled,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: Colors.white.withValues(alpha: .3)),
                ),
              ),
              const SizedBox(width: 8),
              // Nút chính duy nhất có nền màu nhấn.
              FilledButton.icon(
                onPressed: _busy ? null : () => _print(selected),
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text(FixedAssetReprintStrings.printLabels),
                style: FilledButton.styleFrom(
                  backgroundColor: FixedAssetReprintColors.coral,
                  foregroundColor: const Color(0xFF111827),
                  disabledBackgroundColor: Colors.white.withValues(alpha: .1),
                  disabledForegroundColor: FixedAssetReprintColors.textDisabled,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton lúc tải danh sách.
class _ReprintSkeleton extends StatelessWidget {
  const _ReprintSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: .06),
      highlightColor: Colors.white.withValues(alpha: .16),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => Container(
          height: 110,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
