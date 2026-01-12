class PatrolReportModel {
  final int? id;
  final int stt;
  final String? qr_key;
  final String? type; // thêm type (nullable)
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
  final DateTime? createdAt;
  final String? pic;
  final DateTime? dueDate;
  final List<String> imageNames;

  // PATROL_AFTER fields
  final List<String> atImageNames;
  final String? atComment;
  final DateTime? atDate;
  final String? atPic;
  final String? atStatus;

  // HSE_CHECK fields
  final String? hseJudge;
  final List<String> hseImageNames;
  final String? hseComment;
  final DateTime? hseDate;

  final String? loadStatus;

  PatrolReportModel({
    this.id,
    required this.stt,
    this.type,
    this.qr_key,
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
    this.createdAt,
    this.pic,
    this.dueDate,
    required this.imageNames,
    required this.atImageNames,
    this.atComment,
    this.atDate,
    this.atPic,
    this.atStatus,
    this.hseJudge,
    required this.hseImageNames,
    this.hseComment,
    this.hseDate,
    this.loadStatus,
  });

  factory PatrolReportModel.fromJson(Map<String, dynamic> json) {
    List<String> parseImageList(dynamic value) {
      if (value == null) return [];
      if (value is List) return List<String>.from(value);
      if (value is String && value.isNotEmpty) {
        return value.split(',').map((e) => e.trim()).toList();
      }
      return [];
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return PatrolReportModel(
      id: json['id'],
      stt: json['stt'] ?? 0,
      type: json['type'],
      grp: json['grp'] ?? '',
      qr_key: json['qr_key'] ?? '',
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
      createdAt: parseDate(json['createdAt']),
      pic: json['pic'],
      dueDate: parseDate(json['dueDate']),
      imageNames: parseImageList(json['imageNames']),
      atImageNames: parseImageList(json['at_imageNames']),
      atComment: json['at_comment'],
      atDate: parseDate(json['at_date']),
      atPic: json['at_pic'],
      atStatus: json['at_status'],
      hseJudge: json['hse_judge'],
      hseImageNames: parseImageList(json['hse_imageNames']),
      hseComment: json['hse_comment'],
      hseDate: parseDate(json['hse_date']),
      loadStatus: json['load_status'],
    );
  }
}
