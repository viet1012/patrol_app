class PatrolPicSummary {
  final String pic;

  final int totalItems;

  final int doingCount;

  final int proDoneCount;

  final int closedCount;

  final int redoCount;

  PatrolPicSummary({
    required this.pic,
    required this.totalItems,
    required this.doingCount,
    required this.proDoneCount,
    required this.closedCount,
    required this.redoCount,
  });

  factory PatrolPicSummary.fromJson(Map<String, dynamic> json) {
    return PatrolPicSummary(
      pic: json['pic'] ?? '',

      totalItems: json['totalItems'] ?? 0,

      doingCount: json['doingCount'] ?? 0,

      proDoneCount: json['proDoneCount'] ?? 0,

      closedCount: json['closedCount'] ?? 0,

      redoCount: json['redoCount'] ?? 0,
    );
  }
}
