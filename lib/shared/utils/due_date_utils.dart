import 'package:flutter/material.dart';

class DueDateUtils {
  DueDateUtils._(); // ❌ không cho new

  static Color getDueDateColor(DateTime? dueDate) {
    if (dueDate == null) {
      return Colors.white.withValues(alpha: 0.85);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

    final diffDays = due.difference(today).inDays;

    if (diffDays < 0) {
      // 🔴 Trễ hạn
      return Colors.redAccent;
    } else if (diffDays <= 3) {
      // 🟠 Gần tới hạn
      return Colors.orangeAccent;
    } else {
      // ⚪ Bình thường
      return Colors.white.withValues(alpha: 0.85);
    }
  }
}
