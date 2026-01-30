class DivisionSummary {
  final String division;

  final int allTtl, allI, allII, allIII, allIV, allV;

  final int proDoneTtl, proDoneI, proDoneII, proDoneIII, proDoneIV, proDoneV;
  final int hseDoneTtl, hseDoneI, hseDoneII, hseDoneIII, hseDoneIV, hseDoneV;

  final int remainTtl, remainI, remainII, remainIII, remainIV, remainV;

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
    allTtl: (j['allTtl'] ?? 0) as int,
    allI: (j['allI'] ?? 0) as int,
    allII: (j['allII'] ?? 0) as int,
    allIII: (j['allIII'] ?? 0) as int,
    allIV: (j['allIV'] ?? 0) as int,
    allV: (j['allV'] ?? 0) as int,
    proDoneTtl: (j['proDoneTtl'] ?? 0) as int,
    proDoneI: (j['proDoneI'] ?? 0) as int,
    proDoneII: (j['proDoneII'] ?? 0) as int,
    proDoneIII: (j['proDoneIII'] ?? 0) as int,
    proDoneIV: (j['proDoneIV'] ?? 0) as int,
    proDoneV: (j['proDoneV'] ?? 0) as int,
    hseDoneTtl: (j['hseDoneTtl'] ?? 0) as int,
    hseDoneI: (j['hseDoneI'] ?? 0) as int,
    hseDoneII: (j['hseDoneII'] ?? 0) as int,
    hseDoneIII: (j['hseDoneIII'] ?? 0) as int,
    hseDoneIV: (j['hseDoneIV'] ?? 0) as int,
    hseDoneV: (j['hseDoneV'] ?? 0) as int,
    remainTtl: (j['remainTtl'] ?? 0) as int,
    remainI: (j['remainI'] ?? 0) as int,
    remainII: (j['remainII'] ?? 0) as int,
    remainIII: (j['remainIII'] ?? 0) as int,
    remainIV: (j['remainIV'] ?? 0) as int,
    remainV: (j['remainV'] ?? 0) as int,
  );
}
