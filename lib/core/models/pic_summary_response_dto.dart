// DTO của API /api/patrol_report/summary: summary theo PIC, chia theo fac.

int _toInt(dynamic value) => value is num ? value.toInt() : 0;

double? _toDouble(dynamic value) => value is num ? value.toDouble() : null;

Map<String, dynamic> _toMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _toMapList(dynamic value) =>
    value is List ? value.map(_toMap).toList() : const [];

class RiskCountDto {
  final int total;
  final int i;
  final int ii;
  final int iii;
  final int iv;
  final int v;

  const RiskCountDto({
    required this.total,
    required this.i,
    required this.ii,
    required this.iii,
    required this.iv,
    required this.v,
  });

  factory RiskCountDto.fromJson(Map<String, dynamic> json) {
    return RiskCountDto(
      total: _toInt(json['total']),
      i: _toInt(json['i']),
      ii: _toInt(json['ii']),
      iii: _toInt(json['iii']),
      iv: _toInt(json['iv']),
      v: _toInt(json['v']),
    );
  }
}

class PicSummaryRowDto {
  final String pic;
  final RiskCountDto before;
  final RiskCountDto finished;
  final RiskCountDto remain;
  final int recheckAllTotal;
  final RiskCountDto recheckOk;
  final RiskCountDto recheckNg;

  final int stillTimeTtl;
  final int threeDaysTtl;
  final int lateTtl;

  const PicSummaryRowDto({
    required this.pic,
    required this.before,
    required this.finished,
    required this.remain,
    required this.recheckAllTotal,
    required this.recheckOk,
    required this.recheckNg,
    required this.stillTimeTtl,
    required this.threeDaysTtl,
    required this.lateTtl,
  });

  factory PicSummaryRowDto.fromJson(Map<String, dynamic> json) {
    RiskCountDto risk(String key) => RiskCountDto.fromJson(_toMap(json[key]));

    return PicSummaryRowDto(
      pic: (json['pic'] ?? '').toString(),
      before: risk('before'),
      finished: risk('finished'),
      remain: risk('remain'),
      recheckAllTotal: _toInt(json['recheckAllTotal']),
      recheckOk: risk('recheckOk'),
      recheckNg: risk('recheckNg'),
      stillTimeTtl: _toInt(json['stillTimeTtl']),
      threeDaysTtl: _toInt(json['threeDaysTtl']),
      lateTtl: _toInt(json['lateTtl']),
    );
  }
}

class FacPicSummaryDto {
  final String plant;
  final String fac;
  final double? finishedRate;
  final double? remainRate;
  final double? okRate;
  final double? ngRate;
  final List<PicSummaryRowDto> rows;
  final PicSummaryRowDto? total;

  const FacPicSummaryDto({
    this.plant = '',
    required this.fac,
    required this.finishedRate,
    required this.remainRate,
    required this.okRate,
    required this.ngRate,
    required this.rows,
    required this.total,
  });

  /// Dòng hiển thị: các PIC rồi tới dòng tổng (lấy từ [total]).
  List<({PicSummaryRowDto row, bool isTotal})> get displayRows => [
    for (final row in rows) (row: row, isTotal: false),
    if (total != null) (row: total!, isTotal: true),
  ];

  factory FacPicSummaryDto.fromJson(Map<String, dynamic> json) {
    return FacPicSummaryDto(
      plant: (json['plant'] ?? '').toString(),
      fac: (json['fac'] ?? '').toString(),
      finishedRate: _toDouble(json['finishedRate']),
      remainRate: _toDouble(json['remainRate']),
      okRate: _toDouble(json['okRate']),
      ngRate: _toDouble(json['ngRate']),
      rows: _toMapList(json['rows']).map(PicSummaryRowDto.fromJson).toList(),
      total: json['total'] == null
          ? null
          : PicSummaryRowDto.fromJson(_toMap(json['total'])),
    );
  }
}

class PicSummaryResponseDto {
  final String fromD;
  final String toD;
  final String plant;
  final String type;
  final List<FacPicSummaryDto> facs;

  const PicSummaryResponseDto({
    required this.fromD,
    required this.toD,
    required this.plant,
    required this.type,
    required this.facs,
  });

  factory PicSummaryResponseDto.fromJson(Map<String, dynamic> json) {
    return PicSummaryResponseDto(
      fromD: (json['fromD'] ?? '').toString(),
      toD: (json['toD'] ?? '').toString(),
      plant: (json['plant'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      facs: _toMapList(json['facs']).map(FacPicSummaryDto.fromJson).toList(),
    );
  }
}
