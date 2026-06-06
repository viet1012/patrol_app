class PatrolReportModel {
  final int? id;
  final int stt;
  final String? qr_key;
  final String? type;

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
  final String? patrol_user;

  // Due Date update tracking
  final int dueDateUpdateCount;
  final String? dueDateUpdatedBy;
  final DateTime? dueDateUpdatedAt;

  // PATROL_AFTER fields
  final List<String> atImageNames;
  final String? atComment;
  final DateTime? atDate;
  final String? atPic;
  final String? atStatus;
  final String? atAssign;

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
    this.patrol_user,
    required this.imageNames,

    this.dueDateUpdateCount = 0,
    this.dueDateUpdatedBy,
    this.dueDateUpdatedAt,

    required this.atImageNames,
    this.atComment,
    this.atDate,
    this.atPic,
    this.atStatus,
    this.atAssign,

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

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    return PatrolReportModel(
      id: parseInt(json['id']),
      stt: parseInt(json['stt']),
      type: json['type'],
      qr_key: json['qr_key']?.toString(),

      grp: json['grp']?.toString() ?? '',
      plant: json['plant']?.toString() ?? '',
      division: json['division']?.toString() ?? '',
      area: json['area']?.toString() ?? '',
      machine: json['machine']?.toString() ?? '',

      riskFreq: json['riskFreq']?.toString() ?? '',
      riskProb: json['riskProb']?.toString() ?? '',
      riskSev: json['riskSev']?.toString() ?? '',
      riskTotal: json['riskTotal']?.toString() ?? '',

      comment: json['comment']?.toString() ?? '',
      countermeasure: json['countermeasure']?.toString() ?? '',
      checkInfo: json['checkInfo']?.toString() ?? '',

      createdAt: parseDate(json['createdAt']),
      pic: json['pic']?.toString(),
      dueDate: parseDate(json['dueDate']),
      imageNames: parseImageList(json['imageNames']),
      patrol_user: json['patrol_user']?.toString(),

      dueDateUpdateCount: parseInt(json['dueDateUpdateCount']),
      dueDateUpdatedBy: json['dueDateUpdatedBy']?.toString(),
      dueDateUpdatedAt: parseDate(json['dueDateUpdatedAt']),

      atImageNames: parseImageList(json['at_imageNames']),
      atComment: json['at_comment']?.toString(),
      atDate: parseDate(json['at_date']),
      atPic: json['at_pic']?.toString(),
      atStatus: json['at_status']?.toString(),
      atAssign: json['at_assign']?.toString(),

      hseJudge: json['hse_judge']?.toString(),
      hseImageNames: parseImageList(json['hse_imageNames']),
      hseComment: json['hse_comment']?.toString(),
      hseDate: parseDate(json['hse_date']),

      loadStatus: json['load_status']?.toString(),
    );
  }

  PatrolReportModel copyWith({
    int? id,
    int? stt,
    String? qr_key,
    String? type,
    String? grp,
    String? plant,
    String? division,
    String? area,
    String? machine,
    String? riskFreq,
    String? riskProb,
    String? riskSev,
    String? riskTotal,
    String? comment,
    String? countermeasure,
    String? checkInfo,
    DateTime? createdAt,
    String? pic,
    DateTime? dueDate,
    List<String>? imageNames,
    String? patrol_user,

    int? dueDateUpdateCount,
    String? dueDateUpdatedBy,
    DateTime? dueDateUpdatedAt,

    List<String>? atImageNames,
    String? atComment,
    DateTime? atDate,
    String? atPic,
    String? atStatus,
    String? atAssign,

    String? hseJudge,
    List<String>? hseImageNames,
    String? hseComment,
    DateTime? hseDate,

    String? loadStatus,
  }) {
    return PatrolReportModel(
      id: id ?? this.id,
      stt: stt ?? this.stt,
      qr_key: qr_key ?? this.qr_key,
      type: type ?? this.type,
      grp: grp ?? this.grp,
      plant: plant ?? this.plant,
      division: division ?? this.division,
      area: area ?? this.area,
      machine: machine ?? this.machine,
      riskFreq: riskFreq ?? this.riskFreq,
      riskProb: riskProb ?? this.riskProb,
      riskSev: riskSev ?? this.riskSev,
      riskTotal: riskTotal ?? this.riskTotal,
      comment: comment ?? this.comment,
      countermeasure: countermeasure ?? this.countermeasure,
      checkInfo: checkInfo ?? this.checkInfo,
      createdAt: createdAt ?? this.createdAt,
      pic: pic ?? this.pic,
      dueDate: dueDate ?? this.dueDate,
      imageNames: imageNames ?? this.imageNames,
      patrol_user: patrol_user ?? this.patrol_user,

      dueDateUpdateCount: dueDateUpdateCount ?? this.dueDateUpdateCount,
      dueDateUpdatedBy: dueDateUpdatedBy ?? this.dueDateUpdatedBy,
      dueDateUpdatedAt: dueDateUpdatedAt ?? this.dueDateUpdatedAt,

      atImageNames: atImageNames ?? this.atImageNames,
      atComment: atComment ?? this.atComment,
      atDate: atDate ?? this.atDate,
      atPic: atPic ?? this.atPic,
      atStatus: atStatus ?? this.atStatus,
      atAssign: atAssign ?? this.atAssign,

      hseJudge: hseJudge ?? this.hseJudge,
      hseImageNames: hseImageNames ?? this.hseImageNames,
      hseComment: hseComment ?? this.hseComment,
      hseDate: hseDate ?? this.hseDate,

      loadStatus: loadStatus ?? this.loadStatus,
    );
  }
}
