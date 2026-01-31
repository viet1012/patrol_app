class PicSummary {
  final String pic;

  final int allTtl, allOk, allNg, allNy, allNyPct;
  final int facATtl, facAOk, facANg, facANy, facANyPct;
  final int facBTtl, facBOk, facBNg, facBNy, facBNyPct;
  final int facCTtl, facCOk, facCNg, facCNy, facCNyPct;
  final int outsideTtl, outsideOk, outsideNg, outsideNy, outsideNyPct;

  PicSummary({
    required this.pic,
    required this.allTtl,
    required this.allOk,
    required this.allNg,
    required this.allNy,
    required this.allNyPct,
    required this.facATtl,
    required this.facAOk,
    required this.facANg,
    required this.facANy,
    required this.facANyPct,
    required this.facBTtl,
    required this.facBOk,
    required this.facBNg,
    required this.facBNy,
    required this.facBNyPct,
    required this.facCTtl,
    required this.facCOk,
    required this.facCNg,
    required this.facCNy,
    required this.facCNyPct,
    required this.outsideTtl,
    required this.outsideOk,
    required this.outsideNg,
    required this.outsideNy,
    required this.outsideNyPct,
  });

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory PicSummary.fromJson(Map<String, dynamic> j) {
    return PicSummary(
      pic: (j['pic'] ?? '').toString(),

      allTtl: _asInt(j['allTtl']),
      allOk: _asInt(j['allOk']),
      allNg: _asInt(j['allNg']),
      allNy: _asInt(j['allNy']),
      allNyPct: _asInt(j['allNyPct']),

      facATtl: _asInt(j['facATtl']),
      facAOk: _asInt(j['facAOk']),
      facANg: _asInt(j['facANg']),
      facANy: _asInt(j['facANy']),
      facANyPct: _asInt(j['facANyPct']),

      facBTtl: _asInt(j['facBTtl']),
      facBOk: _asInt(j['facBOk']),
      facBNg: _asInt(j['facBNg']),
      facBNy: _asInt(j['facBNy']),
      facBNyPct: _asInt(j['facBNyPct']),

      facCTtl: _asInt(j['facCTtl']),
      facCOk: _asInt(j['facCOk']),
      facCNg: _asInt(j['facCNg']),
      facCNy: _asInt(j['facCNy']),
      facCNyPct: _asInt(j['facCNyPct']),

      outsideTtl: _asInt(j['outsideTtl']),
      outsideOk: _asInt(j['outsideOk']),
      outsideNg: _asInt(j['outsideNg']),
      outsideNy: _asInt(j['outsideNy']),
      outsideNyPct: _asInt(j['outsideNyPct']),
    );
  }
}
