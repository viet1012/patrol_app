import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

class RiskSummary {
  final String grp;
  final String division;
  final int minus;
  final int i;
  final int ii;
  final int iii;
  final int iv;
  final int v;

  RiskSummary({
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

class PatrolApi {
  final Dio dio;
  final String baseUrl; // ví dụ: http://192.168.122.15:9299

  PatrolApi({required this.dio, required this.baseUrl});

  Future<List<RiskSummary>> fetchRiskSummary({
    required String fromD,
    required String toD,
    required String fac,
    required String type,
  }) async {
    final uri = Uri.parse('$baseUrl/api/patrol_report/risk_summary').replace(
      queryParameters: {'fromD': fromD, 'toD': toD, 'fac': fac, 'type': type},
    );

    // 🔥 LOG FULL URL
    debugPrint('👉 GET $uri');

    final res = await dio.getUri(uri);

    final data = res.data;
    if (data is! List) return [];

    return data
        .whereType<Map>()
        .map((e) => RiskSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
