class RiskOption {
  final String label;
  final int score;

  RiskOption({required this.label, required this.score});
}

// 3 danh sách theo bảng
final List<RiskOption> frequencyOptions = [
  RiskOption(label: "Thường xuyên", score: 4),
  RiskOption(label: "Thỉnh thoảng", score: 2),
  RiskOption(label: "Hầu như không", score: 1),
];

final List<RiskOption> probabilityOptions = [
  RiskOption(label: "Chắc chắn", score: 6),
  RiskOption(label: "Khả năng cao", score: 4),
  RiskOption(label: "Có khả năng", score: 2),
  RiskOption(label: "Hầu như không", score: 1),
];

final List<RiskOption> severityOptions = [
  RiskOption(label: "Vết thương chí mạng", score: 10),
  RiskOption(label: "Chấn thương nghiêm trọng", score: 7),
  RiskOption(label: "Chấn thương vừa phải", score: 5),
  RiskOption(label: "Chấn thương nhẹ", score: 3),
  RiskOption(label: "Không đáng kể", score: 1),
];
