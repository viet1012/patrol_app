class RiskSummary {
  final String plant;
  final String grp;
  final String division;
  final int minus;
  final int i;
  final int ii;
  final int iii;
  final int iv;
  final int v;

  RiskSummary({
    this.plant = '',
    required this.grp,
    required this.division,
    required this.minus,
    required this.i,
    required this.ii,
    required this.iii,
    required this.iv,
    required this.v,
  });

  String get shortLabel => '${grp}  (${division})';

  factory RiskSummary.fromJson(Map<String, dynamic> j) {
    int _int(dynamic x) => (x is num) ? x.toInt() : int.tryParse('$x') ?? 0;

    return RiskSummary(
      plant: (j['plant'] ?? '').toString(),
      grp: (j['grp'] ?? '').toString(),
      division: (j['division'] ?? '').toString(),
      minus: _int(j['minus']),
      i: _int(j['i']),
      ii: _int(j['ii']),
      iii: _int(j['iii']),
      iv: _int(j['iv']),
      v: _int(j['v']),
    );
  }

  int get total => minus + i + ii + iii + iv + v;

  String get label => '${division}\n${grp}';
}
