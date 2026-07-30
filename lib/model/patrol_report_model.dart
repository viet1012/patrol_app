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

  /// N?i dung Vi?t + Nh?t dã ghép d? tuong thích code cu.
  final String comment;
  final String countermeasure;

  /// N?i dung ti?ng Nh?t riêng.
  final String? commentJapanese;
  final String? countermeasureJp;

  final String checkInfo;

  final DateTime? createdAt;
  final String? pic;
  final DateTime? dueDate;
  final List<String> imageNames;
  final String? patrol_user;

  // Due Date update tracking
  final int? dueDateUpdateCount;
  final String? dueDateUpdatedBy;
  final DateTime? dueDateUpdatedAt;

  // PATROL_AFTER fields
  final List<String> atImageNames;

  /// N?i dung at_comment Vi?t + Nh?t dã ghép.
  final String? atComment;

  /// N?i dung ti?ng Nh?t riêng c?a at_comment.
  final String? atCommentJp;

  final DateTime? atDate;
  final String? atPic;
  final String? atStatus;
  final String? atAssign;

  // HSE_CHECK fields
  final String? hseJudge;
  final List<String> hseImageNames;

  /// N?i dung hse_comment Vi?t + Nh?t dã ghép.
  final String? hseComment;

  /// N?i dung ti?ng Nh?t riêng c?a hse_comment.
  final String? hseCommentJp;

  final DateTime? hseDate;
  final String? hseUser;

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

    this.commentJapanese,
    this.countermeasureJp,

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
    this.atCommentJp,
    this.atDate,
    this.atPic,
    this.atStatus,
    this.atAssign,

    this.hseJudge,
    required this.hseImageNames,
    this.hseComment,
    this.hseCommentJp,
    this.hseDate,
    this.hseUser,

    this.loadStatus,
  });

  /// Ghép n?i dung g?c và b?n d?ch.
  ///
  /// Ví d?:
  ///
  /// source:
  /// S?a ch?a l?i
  ///
  /// translated:
  /// ?????
  ///
  /// K?t qu?:
  ///
  /// S?a ch?a l?i
  /// ?????
  static String combineTranslation(dynamic source, dynamic translated) {
    final sourceText = source?.toString().trim() ?? '';
    final translatedText = translated?.toString().trim() ?? '';

    if (sourceText.isEmpty) {
      return translatedText;
    }

    if (translatedText.isEmpty) {
      return sourceText;
    }

    // Tránh ghép trùng n?u hai n?i dung gi?ng nhau.
    if (sourceText.toLowerCase() == translatedText.toLowerCase()) {
      return sourceText;
    }

    // H? tr? d? li?u cu dã ch?a s?n b?n d?ch.
    if (sourceText.contains(translatedText)) {
      return sourceText;
    }

    return '$sourceText\n$translatedText';
  }

  /// L?y giá tr? d?u tiên t?n t?i trong danh sách key.
  ///
  /// Giúp h? tr? d?ng th?i:
  /// - snake_case t? database/API cu
  /// - camelCase t? DTO Java
  static dynamic getJsonValue(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key) && json[key] != null) {
        return json[key];
      }
    }

    return null;
  }

  factory PatrolReportModel.fromJson(Map<String, dynamic> json) {
    List<String> parseImageList(dynamic value) {
      if (value == null) {
        return [];
      }

      if (value is List) {
        return value
            .where((item) => item != null)
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }

      if (value is String && value.trim().isNotEmpty) {
        return value
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }

      return [];
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) {
        return null;
      }

      if (value is DateTime) {
        return value;
      }

      if (value is String && value.trim().isNotEmpty) {
        return DateTime.tryParse(value.trim());
      }

      return null;
    }

    int parseInt(dynamic value) {
      if (value == null) {
        return 0;
      }

      if (value is int) {
        return value;
      }

      if (value is num) {
        return value.toInt();
      }

      return int.tryParse(value.toString()) ?? 0;
    }

    String? parseNullableString(dynamic value) {
      if (value == null) {
        return null;
      }

      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    // =========================================================
    // COMMENT
    // =========================================================

    final rawComment = getJsonValue(json, const ['comment']);

    final rawCommentJp = getJsonValue(json, const [
      'comment_jp',
      'commentJp',
      'commentJapanese',
      'comment_japanese',
    ]);

    final combinedComment = combineTranslation(rawComment, rawCommentJp);

    // =========================================================
    // COUNTERMEASURE
    // =========================================================

    final rawCountermeasure = getJsonValue(json, const ['countermeasure']);

    final rawCountermeasureJp = getJsonValue(json, const [
      'countermeasure_jp',
      'countermeasureJp',
      'countermeasureJapanese',
      'countermeasure_japanese',
    ]);

    final combinedCountermeasure = combineTranslation(
      rawCountermeasure,
      rawCountermeasureJp,
    );

    // =========================================================
    // AT COMMENT
    // =========================================================

    final rawAtComment = getJsonValue(json, const ['at_comment', 'atComment']);

    final rawAtCommentJp = getJsonValue(json, const [
      'at_comment_jp',
      'atCommentJp',
      'atCommentJapanese',
      'at_comment_japanese',
    ]);

    final combinedAtComment = combineTranslation(rawAtComment, rawAtCommentJp);

    // =========================================================
    // HSE COMMENT
    // =========================================================

    final rawHseComment = getJsonValue(json, const [
      'hse_comment',
      'hseComment',
    ]);

    final rawHseCommentJp = getJsonValue(json, const [
      'hse_comment_jp',
      'hseCommentJp',
      'hseCommentJapanese',
      'hse_comment_japanese',
    ]);

    final combinedHseComment = combineTranslation(
      rawHseComment,
      rawHseCommentJp,
    );

    return PatrolReportModel(
      id: json['id'] == null ? null : parseInt(json['id']),
      stt: parseInt(json['stt']),
      type: parseNullableString(json['type']),
      qr_key: parseNullableString(
        getJsonValue(json, const ['qr_key', 'qrKey']),
      ),

      grp: json['grp']?.toString() ?? '',
      plant: json['plant']?.toString() ?? '',
      division: json['division']?.toString() ?? '',
      area: json['area']?.toString() ?? '',
      machine: json['machine']?.toString() ?? '',

      riskFreq:
          getJsonValue(json, const ['riskFreq', 'risk_freq'])?.toString() ?? '',
      riskProb:
          getJsonValue(json, const ['riskProb', 'risk_prob'])?.toString() ?? '',
      riskSev:
          getJsonValue(json, const ['riskSev', 'risk_sev'])?.toString() ?? '',
      riskTotal:
          getJsonValue(json, const ['riskTotal', 'risk_total'])?.toString() ??
          '',

      // Comment dã ghép Vi?t + Nh?t.
      comment: combinedComment,
      countermeasure: combinedCountermeasure,

      // B?n ti?ng Nh?t riêng.
      commentJapanese: parseNullableString(rawCommentJp),
      countermeasureJp: parseNullableString(rawCountermeasureJp),

      checkInfo:
          getJsonValue(json, const ['checkInfo', 'check_info'])?.toString() ??
          '',

      createdAt: parseDate(
        getJsonValue(json, const ['createdAt', 'created_at']),
      ),
      pic: parseNullableString(json['pic']),
      dueDate: parseDate(getJsonValue(json, const ['dueDate', 'due_date'])),
      imageNames: parseImageList(
        getJsonValue(json, const ['imageNames', 'image_names']),
      ),
      patrol_user: parseNullableString(
        getJsonValue(json, const ['patrol_user', 'patrolUser']),
      ),

      dueDateUpdateCount: parseInt(
        getJsonValue(json, const [
          'dueDateUpdateCount',
          'due_date_update_count',
        ]),
      ),
      dueDateUpdatedBy: parseNullableString(
        getJsonValue(json, const ['dueDateUpdatedBy', 'due_date_updated_by']),
      ),
      dueDateUpdatedAt: parseDate(
        getJsonValue(json, const ['dueDateUpdatedAt', 'due_date_updated_at']),
      ),

      atImageNames: parseImageList(
        getJsonValue(json, const [
          'at_imageNames',
          'atImageNames',
          'at_image_names',
        ]),
      ),

      // atComment dã ghép Vi?t + Nh?t gi?ng comment.
      atComment: combinedAtComment,

      // Gi? riêng ti?ng Nh?t.
      atCommentJp: parseNullableString(rawAtCommentJp),

      atDate: parseDate(getJsonValue(json, const ['at_date', 'atDate'])),
      atPic: parseNullableString(
        getJsonValue(json, const ['at_pic', 'atPic', 'at_user', 'atUser']),
      ),
      atStatus: parseNullableString(
        getJsonValue(json, const ['at_status', 'atStatus']),
      ),
      atAssign: parseNullableString(
        getJsonValue(json, const ['at_assign', 'atAssign']),
      ),

      hseJudge: parseNullableString(
        getJsonValue(json, const ['hse_judge', 'hseJudge']),
      ),
      hseImageNames: parseImageList(
        getJsonValue(json, const [
          'hse_imageNames',
          'hseImageNames',
          'hse_image_names',
        ]),
      ),

      // hseComment dã ghép Vi?t + Nh?t gi?ng comment.
      hseComment: combinedHseComment,

      // Gi? riêng ti?ng Nh?t.
      hseCommentJp: parseNullableString(rawHseCommentJp),

      hseDate: parseDate(getJsonValue(json, const ['hse_date', 'hseDate'])),
      hseUser: parseNullableString(
        getJsonValue(json, const ['hse_user', 'hseUser']),
      ),

      loadStatus: parseNullableString(
        getJsonValue(json, const ['load_status', 'loadStatus']),
      ),
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
    String? commentJapanese,
    String? countermeasureJp,

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
    String? atCommentJp,
    DateTime? atDate,
    String? atPic,
    String? atStatus,
    String? atAssign,

    String? hseJudge,
    List<String>? hseImageNames,
    String? hseComment,
    String? hseCommentJp,
    DateTime? hseDate,
    String? hseUser,

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
      commentJapanese: commentJapanese ?? this.commentJapanese,
      countermeasureJp: countermeasureJp ?? this.countermeasureJp,

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
      atCommentJp: atCommentJp ?? this.atCommentJp,
      atDate: atDate ?? this.atDate,
      atPic: atPic ?? this.atPic,
      atStatus: atStatus ?? this.atStatus,
      atAssign: atAssign ?? this.atAssign,

      hseJudge: hseJudge ?? this.hseJudge,
      hseImageNames: hseImageNames ?? this.hseImageNames,
      hseComment: hseComment ?? this.hseComment,
      hseCommentJp: hseCommentJp ?? this.hseCommentJp,
      hseDate: hseDate ?? this.hseDate,
      hseUser: hseUser ?? this.hseUser,

      loadStatus: loadStatus ?? this.loadStatus,
    );
  }
}
