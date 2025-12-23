class PatrolReportModel {
  final int? id;
  final int stt;
  final String grp;
  final String plant;
  final String division;
  final String area;
  final String machine;
  final String riskFreq;
  final String riskProb;
  final String riskSev;
  final String riskTotal;
  final String comment;
  final String countermeasure;
  final String checkInfo;
  final DateTime? dueDate; // ✅ nullable
  final List<String> imageNames;

  PatrolReportModel({
    this.id,
    required this.stt,
    required this.grp,
    required this.plant,
    required this.division,
    required this.area,
    required this.machine,
    required this.riskFreq,
    required this.riskProb,
    required this.riskSev,
    required this.riskTotal,
    required this.comment,
    required this.countermeasure,
    required this.checkInfo,
    required this.imageNames,
    this.dueDate,
  });

  factory PatrolReportModel.fromJson(Map<String, dynamic> json) {
    return PatrolReportModel(
      id: json['id'] ?? 0,
      stt: json['stt'] ?? 0,
      grp: json['grp'] ?? '',
      plant: json['plant'] ?? '',
      division: json['division'] ?? '',
      area: json['area'] ?? '',
      machine: json['machine'] ?? '',
      riskFreq: json['riskFreq'] ?? '',
      riskProb: json['riskProb'] ?? '',
      riskSev: json['riskSev'] ?? '',
      riskTotal: json['riskTotal'] ?? '',
      comment: json['comment'] ?? '',
      countermeasure: json['countermeasure'] ?? '',
      checkInfo: json['checkInfo'] ?? '',
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'])
          : null,
      imageNames: List<String>.from(json['imageNames'] ?? []),
    );
  }
}
