import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:chuphinh/shared/widgets/common_ui_helper.dart';
import 'package:chuphinh/shared/widgets/glass_action_button.dart';
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_screen.dart';
import 'package:chuphinh/features/fixed_asset/reprint/fixed_asset_reprint_controller.dart';
import 'package:chuphinh/features/fixed_asset/reprint/fixed_asset_reprint_export.dart';
import 'package:chuphinh/features/fixed_asset/reprint/fixed_asset_reprint_strings.dart';
import 'package:chuphinh/features/fixed_asset/reprint/widgets/fixed_asset_reprint_card.dart';
import 'package:chuphinh/features/fixed_asset/reprint/widgets/fixed_asset_reprint_preview.dart';
import 'package:chuphinh/features/fixed_asset/widgets/fixed_asset_pic_selector.dart';

/// Màn "In lại QR": máy có lần quét mới nhất QR lệch vị trí. QR mới tạo từ
/// VỊ TRÍ ĐANG CHỌN lúc kiểm kê. Quét lại bằng QR mới đúng vị trí thì máy
/// tự rời danh sách (backend), không có trạng thái "đã in".
///
/// Lấy mọi xưởng (audit lưu theo xưởng Fac_A/B/C, không theo nhà máy ở
/// home). Bố cục cho mobile, thao tác 1 tay: một hàng PIC + nút "Lọc"
/// (sheet xưởng / khu vực / tìm kiếm), chip bộ lọc đang áp dụng, thanh
/// "In QR (PDF)" cố định ở đáy.
class FixedAssetReprintScreen extends StatefulWidget {
  /// Mở tới máy này: tìm sẵn theo mã, tải xong thì mở xem trước QR.
  final String? initialMachineCode;

  /// Cho nút "Mở Thay QR" sau khi in; [accountCode] rỗng thì ẩn nút.
  final String accountCode;
  final String? selectedPlant;
  final String userName;
  final String lang;

  const FixedAssetReprintScreen({
    super.key,
    this.initialMachineCode,
    this.accountCode = '',
    this.selectedPlant,
    this.userName = '',
    this.lang = 'VI',
  });

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

  /// [FixedAssetReprintScreen.initialMachineCode] chưa mở xem trước.
  String? _pendingPreview;

  @override
  void initState() {
    super.initState();
    final code = widget.initialMachineCode?.trim() ?? '';
    if (code.isNotEmpty) {
      _pendingPreview = code;
      _searchController.text = code;
      _controller.setSearch(code);
      _controller.addListener(_openPendingPreview);
    }
    _controller.load();
  }

  /// Mở xem trước một lần khi máy đã có trong danh sách và hết tra vị trí.
  void _openPendingPreview() {
    final code = _pendingPreview;
    if (code == null || !mounted || _controller.loading) return;
    final want = code.toLowerCase();
    FixedAssetReprintItem? item;
    for (final e in _controller.items) {
      if (e.machineCode.trim().toLowerCase() == want) item = e;
    }
    if (item == null) {
      // Tải xong mà không có máy (hoặc lỗi): giữ ô tìm kiếm, thôi chờ.
      _pendingPreview = null;
      return;
    }
    if (item.state == FixedAssetReprintQrState.resolving) return;
    _pendingPreview = null;
    if (!item.isReady) return;
    final ready = item;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _preview(ready);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_openPendingPreview);
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  /// [onDone]: chạy khi xong không lỗi (thay cho snackbar [success]).
  Future<void> _run(
    Future<void> Function() task, {
    String? success,
    VoidCallback? onDone,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
      if (!mounted) return;
      if (onDone != null) {
        onDone();
      } else if (success != null) {
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
    return _run(
      () => printFixedAssetQrLabels(labels),
      onDone: () => _showPrintedSheet(labels.length),
    );
  }

  void _preview(FixedAssetReprintItem item) {
    showFixedAssetReprintPreview(
      context,
      item: item,
      onDownload: () => _downloadPng([item]),
      onPrint: () => _print([item]),
    );
  }

  /// Sau khi xuất PDF: nhắc dán + quét ở "3) Thay QR", nút mở thẳng màn đó
  /// (PIC dùng chung trong phiên nên giữ nguyên).
  void _showPrintedSheet(int count) {
    final canOpenReplace = widget.accountCode.trim().isNotEmpty;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FixedAssetReprintColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: FixedAssetReprintColors.newQr,
                size: 40,
              ),
              const SizedBox(height: 10),
              Text(
                FixedAssetReprintStrings.printed(count),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              if (canOpenReplace) ...[
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openReplace();
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text(FixedAssetReprintStrings.openReplace),
                  style: FilledButton.styleFrom(
                    backgroundColor: FixedAssetReprintColors.coral,
                    foregroundColor: const Color(0xFF111827),
                    minimumSize: const Size.fromHeight(48),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                style: TextButton.styleFrom(
                  foregroundColor: FixedAssetReprintColors.textMuted,
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text(FixedAssetReprintStrings.close),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openReplace() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FixedAssetReplaceScreen(
          accountCode: widget.accountCode,
          selectedPlant: widget.selectedPlant,
          userName: widget.userName,
          lang: widget.lang,
        ),
      ),
    ).then((_) {
      // Máy thay xong rời danh sách: tải lại, không nháy skeleton.
      if (mounted) _controller.load(silent: true);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _controller.setSearch('');
  }

  void _clearFilters() {
    _clearSearch();
    _controller.setFac(null);
    _controller.setArea(null);
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
          builder: (context, _) {
            final c = _controller;
            final hasData = !c.loading && c.error == null && c.items.isNotEmpty;
            return Column(
              children: [
                if (hasData) ...[
                  _buildFilterRow(),
                  _buildActiveFilterChips(),
                ],
                Expanded(child: _buildContent()),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final c = _controller;
          final hasData = !c.loading && c.error == null && c.items.isNotEmpty;
          return hasData ? _buildActionBar() : const SizedBox.shrink();
        },
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
                FixedAssetReprintStrings.subtitle(_controller.picItemCount),
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

  // ------------------------------------------------------------
  // BỘ LỌC: một hàng PIC + "Lọc", chip đang áp dụng, sheet lọc
  // ------------------------------------------------------------

  Widget _buildFilterRow() {
    final pics = _controller.picFilter;
    final count = _controller.activeFilterCount;
    final active = count > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Row(
        children: [
          Expanded(
            child: FixedAssetPicSelector(
              pics: pics.pics,
              selectedEmail: pics.selectedEmail,
              loading: pics.loading,
              onChanged: pics.select,
              compact: true,
              allCount: pics.allCount,
              machineUnit: 'máy chờ',
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _openFilterSheet,
              icon: Badge(
                isLabelVisible: active,
                label: Text('$count'),
                backgroundColor: FixedAssetReprintColors.coral,
                textColor: const Color(0xFF111827),
                child: const Icon(Icons.tune_rounded, size: 18),
              ),
              label: const Text(FixedAssetReprintStrings.filter),
              style: OutlinedButton.styleFrom(
                foregroundColor: active
                    ? FixedAssetReprintColors.coral
                    : Colors.white,
                side: BorderSide(
                  color: active
                      ? FixedAssetReprintColors.coral.withValues(alpha: .6)
                      : Colors.white.withValues(alpha: .3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "PIC: phua.ho ✕", "Fac_A ✕", "A40 ✕", "\"abc\" ✕". Không có gì thì ẩn.
  Widget _buildActiveFilterChips() {
    final c = _controller;
    final picEmail = c.picFilter.selectedEmail;
    final chips = <Widget>[
      if (picEmail != null)
        _activeChip(
          FixedAssetReprintStrings.picChip(c.picFilter.nameOf(picEmail)),
          () => c.picFilter.select(null),
        ),
      if (c.fac != null)
        _activeChip(
          c.fac!.isEmpty ? FixedAssetReprintStrings.unknownFac : c.fac!,
          () => c.setFac(null),
        ),
      if (c.area != null) _activeChip(c.area!, () => c.setArea(null)),
      if (c.search.trim().isNotEmpty)
        _activeChip(
          FixedAssetReprintStrings.searchChip(c.search.trim()),
          _clearSearch,
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _activeChip(String label, VoidCallback onRemove) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onRemove,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
          decoration: BoxDecoration(
            color: FixedAssetReprintColors.coral.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: FixedAssetReprintColors.coral.withValues(alpha: .6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FixedAssetReprintColors.coral,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.close_rounded,
                size: 15,
                color: FixedAssetReprintColors.coral,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sheet "Bộ lọc": tìm kiếm, xưởng, khu vực (áp dụng ngay khi bấm).
  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FixedAssetReprintColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .8,
          ),
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _buildFilterSheet(sheetContext),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSheet(BuildContext sheetContext) {
    final c = _controller;
    final unknown = c.unknownFacCount;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    FixedAssetReprintStrings.filterTitle,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: c.activeFilterCount > 0 ? _clearFilters : null,
                  style: TextButton.styleFrom(
                    foregroundColor: FixedAssetReprintColors.coralSoft,
                    disabledForegroundColor:
                        FixedAssetReprintColors.textDisabled,
                  ),
                  child: const Text(FixedAssetReprintStrings.clearFilters),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
              children: [
                _sheetLabel(FixedAssetReprintStrings.search),
                _buildSearchField(),
                const SizedBox(height: 14),
                _sheetLabel(FixedAssetReprintStrings.fac),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _choice(
                      FixedAssetReprintStrings.allFacs(c.picItemCount),
                      c.fac == null,
                      () => c.setFac(null),
                    ),
                    for (final f in c.facCounts)
                      _choice(
                        FixedAssetReprintStrings.facChip(f.fac, f.count),
                        c.fac == f.fac,
                        () => c.setFac(f.fac),
                      ),
                    if (unknown > 0)
                      _choice(
                        FixedAssetReprintStrings.facChip(
                          FixedAssetReprintStrings.unknownFac,
                          unknown,
                        ),
                        c.fac == '',
                        () => c.setFac(''),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _sheetLabel(FixedAssetReprintStrings.area),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _choice(
                      FixedAssetReprintStrings.allAreas,
                      c.area == null,
                      () => c.setArea(null),
                    ),
                    for (final area in c.areas)
                      _choice(area, c.area == area, () => c.setArea(area)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: FilledButton(
              onPressed: () => Navigator.pop(sheetContext),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: .12),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text(FixedAssetReprintStrings.applyFilters),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: .6),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: .5,
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final c = _controller;
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        onChanged: c.setSearch,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        cursorColor: FixedAssetReprintColors.coralSoft,
        decoration: InputDecoration(
          isDense: true,
          hintText: FixedAssetReprintStrings.searchHint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: .5),
            fontSize: 14,
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
                  onPressed: _clearSearch,
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
              color: FixedAssetReprintColors.coralSoft.withValues(alpha: .7),
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  /// Chip chọn tự vẽ (không dùng ChoiceChip: màu theme sáng mặc định làm
  /// chip chưa chọn nền trắng chữ trắng). Cao ≥ 36 để dễ bấm.
  Widget _choice(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? FixedAssetReprintColors.coral
                  : FixedAssetReprintColors.textMuted,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // DANH SÁCH
  // ------------------------------------------------------------

  Widget _buildContent() {
    final c = _controller;
    if (c.loading) return const _ReprintSkeleton();
    if (c.error != null) return _buildError(c.error!);
    if (c.items.isEmpty) {
      return _refreshable(
        _message(
          Icons.check_circle_rounded,
          FixedAssetReprintColors.newQr,
          FixedAssetReprintStrings.empty,
        ),
      );
    }

    final picEmail = c.picFilter.selectedEmail;
    if (c.picItemCount == 0 && picEmail != null) {
      return _refreshable(
        _message(
          Icons.check_circle_rounded,
          FixedAssetReprintColors.newQr,
          FixedAssetReprintStrings.emptyForPic(c.picFilter.nameOf(picEmail)),
        ),
      );
    }

    final groups = c.visibleGroups.where((g) => g.items.isNotEmpty).toList();
    if (groups.isEmpty) {
      return _refreshable(
        _message(
          Icons.search_off_rounded,
          Colors.white54,
          FixedAssetReprintStrings.noMatch,
          action: c.activeFilterCount > 0
              ? TextButton(
                  onPressed: _clearFilters,
                  style: TextButton.styleFrom(
                    foregroundColor: FixedAssetReprintColors.coralSoft,
                  ),
                  child: const Text(FixedAssetReprintStrings.clearFilters),
                )
              : null,
        ),
      );
    }

    Widget card(FixedAssetReprintItem item) => FixedAssetReprintCard(
      key: ValueKey(item.machineCode),
      item: item,
      selected: c.isSelected(item),
      onToggle: () => c.toggle(item),
      onPreview: () => _preview(item),
    );

    final visibleCount = groups.fold<int>(0, (n, g) => n + g.items.length);

    // Mobile: 1 cột; tablet / desktop rộng: 2–3 cột. Card cao theo nội dung
    // (không chiều cao cố định): nhiều cột dùng Wrap với width theo số cột.
    const hPadding = 10.0;
    const spacing = 10.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100 ? 3 : (width >= 700 ? 2 : 1);
        final cardWidth =
            ((width - hPadding * 2 - spacing * (columns - 1)) / columns)
                .floorToDouble();
        return RefreshIndicator(
          color: FixedAssetReprintColors.coral,
          onRefresh: () => c.load(silent: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildListHeader(visibleCount)),
              for (final group in groups) ...[
                SliverToBoxAdapter(child: _groupHeader(group)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    hPadding,
                    0,
                    hPadding,
                    6,
                  ),
                  sliver: columns == 1
                      ? SliverList.separated(
                          itemCount: group.items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => card(group.items[i]),
                        )
                      : SliverToBoxAdapter(
                          child: Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              for (final item in group.items)
                                SizedBox(width: cardWidth, child: card(item)),
                            ],
                          ),
                        ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        );
      },
    );
  }

  /// "N máy" + "Chọn tất cả" (các máy đang hiển thị).
  Widget _buildListHeader(int count) {
    final c = _controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              FixedAssetReprintStrings.listCount(count),
              style: TextStyle(
                color: Colors.white.withValues(alpha: .6),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: c.visibleItems.any((e) => e.isReady)
                ? c.toggleSelectAllVisible
                : null,
            icon: Icon(
              c.allVisibleSelected
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 20,
            ),
            label: Text(
              c.allVisibleSelected
                  ? FixedAssetReprintStrings.deselectAll
                  : FixedAssetReprintStrings.selectAll,
            ),
            style: TextButton.styleFrom(
              foregroundColor: FixedAssetReprintColors.coralSoft,
              disabledForegroundColor: FixedAssetReprintColors.textDisabled,
              minimumSize: const Size(0, 40),
              textStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Fac_A · 1 máy ☐": bấm cả hàng = chọn / bỏ chọn cả nhóm.
  Widget _groupHeader(FixedAssetReprintGroup group) {
    final c = _controller;
    final name = group.fac.isEmpty
        ? FixedAssetReprintStrings.unknownFac
        : group.fac;
    final selectable = c.groupSelectable(group);
    final selected = c.isGroupSelected(group);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: selectable ? () => c.toggleGroup(group) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 0, 2),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: FixedAssetReprintColors.coralSoft.withValues(
                      alpha: .7,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    FixedAssetReprintStrings.facGroup(name, group.items.length),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .8),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .3,
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Checkbox(
                    value: selected,
                    onChanged: selectable ? (_) {} : null,
                    fillColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? FixedAssetReprintColors.coralSoft
                          : Colors.transparent,
                    ),
                    checkColor: const Color(0xFF111827),
                    side: WidgetStateBorderSide.resolveWith(
                      (states) => BorderSide(
                        color: states.contains(WidgetState.disabled)
                            ? Colors.white.withValues(alpha: .2)
                            : Colors.white.withValues(alpha: .55),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Nội dung không phải danh sách vẫn kéo xuống để tải lại được.
  Widget _refreshable(Widget child) {
    return RefreshIndicator(
      color: FixedAssetReprintColors.coral,
      onRefresh: () => _controller.load(silent: true),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
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

  Widget _message(IconData icon, Color color, String text, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 48),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 8), action],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // THANH HÀNH ĐỘNG (cố định đáy)
  // ------------------------------------------------------------

  /// "Đã chọn x máy" + PNG + "In QR (PDF)"; chưa chọn: "Chọn máy để in",
  /// các nút disabled.
  Widget _buildActionBar() {
    final selected = _controller.selectedItems;
    final hasSelection = selected.isNotEmpty;
    final enabled = hasSelection && !_busy;
    return Container(
      decoration: const BoxDecoration(
        color: FixedAssetReprintColors.surface,
        border: Border(top: BorderSide(color: FixedAssetReprintColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: Row(
            children: [
              if (hasSelection)
                IconButton(
                  tooltip: FixedAssetReprintStrings.deselectAll,
                  onPressed: _busy ? null : _controller.clearSelection,
                  color: FixedAssetReprintColors.textMuted,
                  disabledColor: FixedAssetReprintColors.textDisabled,
                  icon: const Icon(Icons.close_rounded),
                )
              else
                const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasSelection
                      ? FixedAssetReprintStrings.selected(selected.length)
                      : FixedAssetReprintStrings.selectToPrint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasSelection
                        ? Colors.white
                        : FixedAssetReprintColors.textDisabled,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: FixedAssetReprintColors.coralSoft,
                    ),
                  ),
                ),
              IconButton(
                tooltip: FixedAssetReprintStrings.downloadPng,
                onPressed: enabled ? () => _downloadPng(selected) : null,
                color: Colors.white,
                disabledColor: FixedAssetReprintColors.textDisabled,
                icon: const Icon(Icons.download_rounded),
              ),
              const SizedBox(width: 4),
              // Nút chính duy nhất có nền màu nhấn.
              FilledButton.icon(
                onPressed: enabled ? () => _print(selected) : null,
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text(FixedAssetReprintStrings.printLabels),
                style: FilledButton.styleFrom(
                  backgroundColor: FixedAssetReprintColors.coral,
                  foregroundColor: const Color(0xFF111827),
                  disabledBackgroundColor: Colors.white.withValues(alpha: .1),
                  disabledForegroundColor: FixedAssetReprintColors.textDisabled,
                  minimumSize: const Size(0, 46),
                  textStyle: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
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
