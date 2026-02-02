class DivisionSummary {
  final String division;

  final double allTtl, allI, allII, allIII, allIV, allV;

  final double proDoneTtl, proDoneI, proDoneII, proDoneIII, proDoneIV, proDoneV;
  final double hseDoneTtl, hseDoneI, hseDoneII, hseDoneIII, hseDoneIV, hseDoneV;

  final double remainTtl, remainI, remainII, remainIII, remainIV, remainV;

  DivisionSummary({
    required this.division,
    required this.allTtl,
    required this.allI,
    required this.allII,
    required this.allIII,
    required this.allIV,
    required this.allV,
    required this.proDoneTtl,
    required this.proDoneI,
    required this.proDoneII,
    required this.proDoneIII,
    required this.proDoneIV,
    required this.proDoneV,
    required this.hseDoneTtl,
    required this.hseDoneI,
    required this.hseDoneII,
    required this.hseDoneIII,
    required this.hseDoneIV,
    required this.hseDoneV,
    required this.remainTtl,
    required this.remainI,
    required this.remainII,
    required this.remainIII,
    required this.remainIV,
    required this.remainV,
  });

  factory DivisionSummary.fromJson(Map<String, dynamic> j) => DivisionSummary(
    division: (j['division'] ?? '').toString(),
    allTtl: (j['allTtl'] ?? 0) as double,
    allI: (j['allI'] ?? 0) as double,
    allII: (j['allII'] ?? 0) as double,
    allIII: (j['allIII'] ?? 0) as double,
    allIV: (j['allIV'] ?? 0) as double,
    allV: (j['allV'] ?? 0) as double,
    proDoneTtl: (j['proDoneTtl'] ?? 0) as double,
    proDoneI: (j['proDoneI'] ?? 0) as double,
    proDoneII: (j['proDoneII'] ?? 0) as double,
    proDoneIII: (j['proDoneIII'] ?? 0) as double,
    proDoneIV: (j['proDoneIV'] ?? 0) as double,
    proDoneV: (j['proDoneV'] ?? 0) as double,
    hseDoneTtl: (j['hseDoneTtl'] ?? 0) as double,
    hseDoneI: (j['hseDoneI'] ?? 0) as double,
    hseDoneII: (j['hseDoneII'] ?? 0) as double,
    hseDoneIII: (j['hseDoneIII'] ?? 0) as double,
    hseDoneIV: (j['hseDoneIV'] ?? 0) as double,
    hseDoneV: (j['hseDoneV'] ?? 0) as double,
    remainTtl: (j['remainTtl'] ?? 0) as double,
    remainI: (j['remainI'] ?? 0) as double,
    remainII: (j['remainII'] ?? 0) as double,
    remainIII: (j['remainIII'] ?? 0) as double,
    remainIV: (j['remainIV'] ?? 0) as double,
    remainV: (j['remainV'] ?? 0) as double,
  );
}
