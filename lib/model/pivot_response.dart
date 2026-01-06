class RiskPivotRow {
  final String pic;
  final int i, ii, iii, iv, v, total;

  RiskPivotRow({
    required this.pic,
    required this.i,
    required this.ii,
    required this.iii,
    required this.iv,
    required this.v,
    required this.total,
  });

  factory RiskPivotRow.fromJson(Map<String, dynamic> json) {
    int _toInt(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;

    return RiskPivotRow(
      pic: (json['pic'] ?? '').toString(),
      i: _toInt(json['i']),
      ii: _toInt(json['ii']),
      iii: _toInt(json['iii']),
      iv: _toInt(json['iv']),
      v: _toInt(json['v']),
      total: _toInt(json['total']),
    );
  }
}

class RiskPivotResponse {
  final String plant;
  final String atStatus;
  final int grandTotal;
  final RiskPivotRow totals;
  final List<RiskPivotRow> rows;

  RiskPivotResponse({
    required this.plant,
    required this.atStatus,
    required this.grandTotal,
    required this.totals,
    required this.rows,
  });

  factory RiskPivotResponse.fromJson(Map<String, dynamic> json) {
    int _toInt(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;

    return RiskPivotResponse(
      plant: (json['plant'] ?? '').toString(),
      atStatus: (json['atStatus'] ?? '').toString(),
      grandTotal: _toInt(json['grandTotal']),
      totals: RiskPivotRow.fromJson(json['totals'] ?? const {}),
      rows: (json['rows'] as List? ?? const [])
          .map((e) => RiskPivotRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
