class AutoCmp {
  final int no;
  final String inputText;
  final String note;
  final int sortOrder;
  final String countermeasure;

  AutoCmp({
    required this.no,
    required this.inputText,
    required this.note,
    required this.sortOrder,
    required this.countermeasure,
  });

  factory AutoCmp.fromJson(Map<String, dynamic> json) {
    return AutoCmp(
      no: json['no'] as int? ?? 0,
      inputText: json['inputText'] as String? ?? '',
      note: json['note'] as String? ?? 'N/A',
      sortOrder: json['sortOrder'] as int? ?? 0,
      countermeasure: json['countermeasure'] as String? ?? 'N/A',
    );
  }
}
