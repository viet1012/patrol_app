String fmtNum(double v) {
  if (v == 0) return '-';

  return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
}

String fmtPct(double v) {
  if (v == 0) return '-';

  return '${v.toStringAsFixed(1)}%';
}

/// Tỉ lệ 0..1 -> '72%'; null -> '--'.
String fmtRate(double? v) {
  if (v == null) return '--';

  return '${(v * 100).round()}%';
}
