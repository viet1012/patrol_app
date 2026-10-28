import 'package:flutter/material.dart';

import 'package:chuphinh/core/models/patrol_group.dart';

/// Cấu hình hiển thị của một [PatrolGroup] (card ở Home + màn con).
class PatrolGroupUi {
  final String title;
  final IconData icon;
  final Color color;
  final String prefix;
  final String titleScreen;
  final String recheckTitle;

  /// Các nút (chức năng) group này có ở Home. Fixed Asset không dùng field này.
  final Set<PatrolAction> actions;

  const PatrolGroupUi({
    required this.title,
    required this.icon,
    required this.color,
    required this.prefix,
    required this.titleScreen,
    required this.recheckTitle,
    this.actions = kPatrolWorkflowActions,
  });
}

/// Đủ 4 bước workflow Patrol.
const Set<PatrolAction> kPatrolWorkflowActions = {
  PatrolAction.before,
  PatrolAction.after,
  PatrolAction.recheck,
  PatrolAction.summary,
};

/// Nguồn duy nhất cho title / icon / màu của từng group.
const Map<PatrolGroup, PatrolGroupUi> kPatrolGroupUi = {
  PatrolGroup.Patrol: PatrolGroupUi(
    title: 'Weekly Safety Patrol',
    icon: Icons.security,
    color: Color(0xFF00B0FF), // lightBlueAccent.shade400
    prefix: 'Patrol',
    titleScreen: 'Safety Patrol',
    recheckTitle: 'HSE ReCheck',
  ),
  PatrolGroup.Audit: PatrolGroupUi(
    title: 'SRG Safety Audit',
    icon: Icons.groups,
    color: Color(0xFF66BB6A), // green.shade400
    prefix: 'Audit',
    titleScreen: 'Safety Audit',
    recheckTitle: 'SRG Recheck',
  ),
  PatrolGroup.QualityPatrol: PatrolGroupUi(
    title: 'QA Quality Patrol',
    icon: Icons.verified,
    color: Color(0xFFEA80FC), // purpleAccent.shade100
    prefix: 'QA Patrol',
    titleScreen: 'QA Patrol',
    recheckTitle: 'QA Recheck',
  ),
  PatrolGroup.AssetUpdate: PatrolGroupUi(
    title: 'MA Machine Patrol',
    icon: Icons.inventory_rounded,
    color: Color(0xFFFFB300), // amber.shade600 – vàng máy móc
    prefix: 'Machine Patrol',
    titleScreen: 'MA Machine Patrol',
    recheckTitle: 'Asset Recheck',
    // Machine Patrol chỉ có Before + Data Table.
    actions: {PatrolAction.before, PatrolAction.summary},
  ),
  PatrolGroup.FixedAsset: PatrolGroupUi(
    title: 'Fixed Asset Audit',
    icon: Icons.precision_manufacturing_rounded,
    color: Color(0xFFF77368), // coral
    prefix: 'Fixed Asset Audit',
    titleScreen: 'Fixed Asset Audit',
    recheckTitle: 'Recheck',
  ),
};

// Fixed Asset không theo workflow Patrol: BE chưa có action riêng nên
// map 2 chức năng của nó vào action sẵn có (quyền vẫn lấy từ AuthMe).

/// Quyền mở màn kiểm kê Fixed Asset.
const kFixedAssetAuditAction = PatrolAction.before;

/// Quyền mở màn in lại QR Fixed Asset.
const kFixedAssetReprintAction = PatrolAction.recheck;
