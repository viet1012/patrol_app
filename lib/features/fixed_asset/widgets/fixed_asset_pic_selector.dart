import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';

import 'package:chuphinh/core/models/fixed_asset_pic.dart';
import 'package:chuphinh/features/fixed_asset/widgets/fixed_asset_manual_selectors.dart';

/// Dropdown PIC (full width, có ô tìm kiếm). Mục đầu "Tất cả PIC"; mỗi mục:
/// name + email + "x máy · y khu". Chỉ hiển thị + callback (null = tất cả).
class FixedAssetPicSelector extends StatelessWidget {
  final List<FixedAssetPic> pics;

  /// Email PIC đang chọn; null = "Tất cả PIC".
  final String? selectedEmail;
  final bool loading;
  final ValueChanged<String?> onChanged;

  /// Thu gọn (đặt chung một hàng với nút khác): ô thấp hơn, chỉ hiện tên PIC
  /// (không số máy / khu). Danh sách mở ra vẫn đầy đủ.
  final bool compact;

  /// Có giá trị: mục đầu ghi "Tất cả PIC (N)".
  final int? allCount;

  /// Đơn vị số máy của mỗi mục ("máy" / "máy chờ").
  final String machineUnit;

  /// false: PIC bắt buộc – không có mục "Tất cả PIC"; null hiện hint
  /// "Chọn PIC".
  final bool allowAll;

  const FixedAssetPicSelector({
    super.key,
    required this.pics,
    required this.selectedEmail,
    required this.loading,
    required this.onChanged,
    this.compact = false,
    this.allCount,
    this.machineUnit = 'máy',
    this.allowAll = true,
  });

  static const Color _accent = Color(0xFF4DD0E1);

  /// Mục "Tất cả PIC" (email rỗng).
  static const FixedAssetPic _all = FixedAssetPic(email: '', name: 'Tất cả PIC');

  bool _isAll(FixedAssetPic pic) => pic.email.isEmpty;

  FixedAssetPic? get _selected {
    final email = selectedEmail;
    if (email == null) return allowAll ? _all : null;
    for (final pic in pics) {
      if (FixedAssetPic.sameEmail(pic.email, email)) return pic;
    }
    // PIC nhớ trong phiên nhưng danh sách chưa tải / không còn.
    return FixedAssetPic(email: email, name: FixedAssetPic.nameOf(email));
  }

  String _counts(FixedAssetPic pic) =>
      '${pic.machineCount} $machineUnit · ${pic.zoneCount} khu';

  String get _allLabel =>
      allCount == null ? 'Tất cả PIC' : 'Tất cả PIC ($allCount)';

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        DropdownSearch<FixedAssetPic>(
          items: allowAll ? [_all, ...pics] : pics,
          selectedItem: _selected,
          compareFn: (a, b) =>
              a.email.trim().toLowerCase() == b.email.trim().toLowerCase(),
          itemAsString: (pic) => pic.name,
          filterFn: (pic, filter) {
            final q = filter.trim().toLowerCase();
            return q.isEmpty ||
                _isAll(pic) ||
                pic.name.toLowerCase().contains(q) ||
                pic.email.toLowerCase().contains(q);
          },
          onChanged: (pic) =>
              onChanged(pic == null || _isAll(pic) ? null : pic.email),
          popupProps: PopupProps.menu(
            showSearchBox: true,
            fit: FlexFit.loose,
            menuProps: MenuProps(
              backgroundColor: const Color(0xFF161D23),
              elevation: 12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                hintText: 'Tìm PIC (tên / email)',
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.white.withOpacity(0.7),
                ),
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            emptyBuilder: (context, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Không tìm thấy PIC',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              ),
            ),
            itemBuilder: (context, pic, isSelected) =>
                _item(pic, isSelected),
          ),
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              isDense: compact,
              contentPadding: compact
                  ? const EdgeInsets.fromLTRB(10, 8, 6, 8)
                  : const EdgeInsets.fromLTRB(12, 10, 12, 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _accent.withOpacity(0.45)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _accent, width: 1.6),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          dropdownButtonProps: FixedAssetManualSelectors.dropdownButton(
            enabled: true,
          ),
          dropdownBuilder: (context, pic) => pic == null && !allowAll
              ? _hintView()
              : _selectedView(pic ?? _all),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(right: 36),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
            ),
          ),
      ],
    );
  }

  Widget _hintView() {
    return Row(
      children: [
        Icon(
          Icons.person_outline_rounded,
          size: 18,
          color: FixedAssetManualSelectors.dropdownIconColor(enabled: true),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Chọn PIC',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(.6),
              fontSize: compact ? 13.5 : 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _selectedView(FixedAssetPic pic) {
    final all = _isAll(pic);
    return Row(
      children: [
        Icon(
          all ? Icons.groups_rounded : Icons.person_rounded,
          size: 18,
          color: FixedAssetManualSelectors.dropdownIconColor(enabled: true),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: all ? 'PIC: Tất cả' : 'PIC: ${pic.name}',
                  style: TextStyle(
                    color: all ? Colors.white.withOpacity(.75) : Colors.white,
                    fontSize: compact ? 13.5 : 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!compact && !all && pic.machineCount + pic.zoneCount > 0)
                  TextSpan(
                    text: '  ${_counts(pic)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.55),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _item(FixedAssetPic pic, bool isSelected) {
    final all = _isAll(pic);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? Colors.white.withOpacity(0.12) : Colors.transparent,
      ),
      child: all
          ? Text(
              _allLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pic.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      Text(
                        pic.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.55),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _counts(pic),
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    );
  }
}
