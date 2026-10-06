String fmtNum(double v) {
  if (v == 0) return '-';

  return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
}

String fmtPct(double v) {
  if (v == 0) return '-';

  return '${v.toStringAsFixed(1)}%';
}
