/// So sánh "tự nhiên": phần số so theo giá trị, phần chữ không phân biệt
/// hoa/thường. `Group 2` < `Group 10`, `Fac_1` < `Fac_10`.
int naturalCompare(String a, String b) {
  final ra = _chunk.allMatches(a).map((m) => m[0]!).toList();
  final rb = _chunk.allMatches(b).map((m) => m[0]!).toList();

  for (var i = 0; i < ra.length && i < rb.length; i++) {
    final x = ra[i], y = rb[i];
    final nx = int.tryParse(x), ny = int.tryParse(y);

    final int c;
    if (nx != null && ny != null) {
      c = nx != ny ? nx.compareTo(ny) : x.length.compareTo(y.length);
    } else {
      c = x.toLowerCase().compareTo(y.toLowerCase());
    }
    if (c != 0) return c;
  }

  final byLength = ra.length.compareTo(rb.length);
  return byLength != 0 ? byLength : a.compareTo(b);
}

final _chunk = RegExp(r'\d+|\D+');
