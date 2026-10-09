import 'dart:convert';

import 'package:chuphinh/features/patrol/summary/core/patrol_report_table_columns.dart';
import 'package:flutter/foundation.dart';

/// Tuỳ chỉnh cột theo user: thứ tự, cột ẩn, độ rộng. Bất biến.
@immutable
class PatrolReportColumnLayout {
  /// Cột dính trái khi cuộn ngang (desktop); luôn đứng đầu, không kéo thả.
  static const pinnedLabels = ['STT', 'QR'];

  /// Không cho ẩn.
  static const lockedLabels = {'STT'};

  final List<String> order;
  final Set<String> hidden;
  final Map<String, double> widths;

  const PatrolReportColumnLayout({
    this.order = const [],
    this.hidden = const {},
    this.widths = const {},
  });

  static bool isPinned(String label) => pinnedLabels.contains(label);

  /// Chuẩn hoá theo danh sách cột hiện có: bỏ label lạ, thêm cột mới,
  /// đưa cột pinned lên đầu.
  PatrolReportColumnLayout normalized(List<PatrolReportColumnSpec> all) {
    final known = {for (final c in all) c.label};
    final seen = <String>{};
    final rest = <String>[
      for (final l in order)
        if (known.contains(l) && !isPinned(l) && seen.add(l)) l,
    ];
    // Cột mới (chưa có trong layout đã lưu) chèn theo vị trí mặc định.
    for (var i = 0; i < all.length; i++) {
      final l = all[i].label;
      if (isPinned(l) || seen.contains(l)) continue;
      final prev = all
          .take(i)
          .map((c) => c.label)
          .lastWhere(rest.contains, orElse: () => '');
      rest.insert(prev.isEmpty ? 0 : rest.indexOf(prev) + 1, l);
      seen.add(l);
    }

    return PatrolReportColumnLayout(
      order: [
        for (final l in pinnedLabels)
          if (known.contains(l)) l,
        ...rest,
      ],
      hidden: {
        for (final l in hidden)
          if (known.contains(l) && !lockedLabels.contains(l)) l,
      },
      widths: {
        for (final e in widths.entries)
          if (known.contains(e.key))
            e.key: e.value.clamp(
              PatrolReportColumnSpec.minWidth,
              PatrolReportColumnSpec.maxWidth,
            ),
      },
    );
  }

  PatrolReportColumnLayout copyWith({
    List<String>? order,
    Set<String>? hidden,
    Map<String, double>? widths,
  }) {
    return PatrolReportColumnLayout(
      order: order ?? this.order,
      hidden: hidden ?? this.hidden,
      widths: widths ?? this.widths,
    );
  }

  String toJson() => jsonEncode({
    'v': 1,
    'order': order,
    'hidden': hidden.toList(),
    'widths': widths,
  });

  static PatrolReportColumnLayout? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return PatrolReportColumnLayout(
        order: [for (final l in (map['order'] as List? ?? const [])) '$l'],
        hidden: {for (final l in (map['hidden'] as List? ?? const [])) '$l'},
        widths: {
          for (final e in (map['widths'] as Map? ?? const {}).entries)
            if (e.value is num) '${e.key}': (e.value as num).toDouble(),
        },
      );
    } catch (_) {
      return null;
    }
  }
}
