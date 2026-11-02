import 'package:flutter/material.dart';

import 'package:chuphinh/features/fixed_asset/fixed_asset_location.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_screen.dart';
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_screen.dart';

/// Thông tin người dùng cần để từ Summary mở các màn Fixed Asset khác
/// ("Kiểm kê", "3) Thay QR"); truyền qua các màn B → A → C.
class FixedAssetSummaryNav {
  final String accountCode;
  final String? selectedPlant;
  final String userName;
  final String lang;

  const FixedAssetSummaryNav({
    required this.accountCode,
    this.selectedPlant,
    this.userName = '',
    this.lang = 'VI',
  });

  /// "3) Thay QR" (PIC dùng chung trong phiên).
  Future<void> openReplace(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FixedAssetReplaceScreen(
          accountCode: accountCode,
          selectedPlant: selectedPlant,
          userName: userName,
          lang: lang,
        ),
      ),
    );
  }

  /// "Kiểm kê" với PIC + 4 ô vị trí chọn sẵn (camera bật ngay).
  Future<void> openAudit(
    BuildContext context, {
    required String pic,
    required FixedAssetAuditLocation location,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FixedAssetScreen(
          accountCode: accountCode,
          selectedPlant: selectedPlant,
          userName: userName,
          lang: lang,
          initialPic: pic,
          initialLocation: location,
        ),
      ),
    );
  }
}
