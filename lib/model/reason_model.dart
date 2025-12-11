// class RiskOption {
//   final String label;
//   final int score;
//
//   RiskOption({required this.label, required this.score});
// }

// // 3 danh sách theo bảng
// final List<RiskOption> frequencyOptions = [
//   RiskOption(label: "Thường xuyên", score: 4),
//   RiskOption(label: "Thỉnh thoảng", score: 2),
//   RiskOption(label: "Hầu như không", score: 1),
// ];
//
// final List<RiskOption> probabilityOptions = [
//   RiskOption(label: "Chắc chắn", score: 6),
//   RiskOption(label: "Khả năng cao", score: 4),
//   RiskOption(label: "Có khả năng", score: 2),
//   RiskOption(label: "Hầu như không", score: 1),
// ];
//
// final List<RiskOption> severityOptions = [
//   RiskOption(label: "Vết thương chí mạng", score: 10),
//   RiskOption(label: "Chấn thương nghiêm trọng", score: 7),
//   RiskOption(label: "Chấn thương vừa phải", score: 5),
//   RiskOption(label: "Chấn thương nhẹ", score: 3),
//   RiskOption(label: "Không đáng kể", score: 1),
// ];
//
// final List<RiskOption> totalRiskOptions = [
//   RiskOption(label: "I - Rủi ro thấp", score: 1),
//   RiskOption(label: "II - Rủi ro trung bình", score: 2),
//   RiskOption(label: "III - Rủi ro cao", score: 3),
//   RiskOption(label: "IV - Rủi ro rất cao", score: 4),
//   RiskOption(label: "V - Rủi ro cực kỳ cao", score: 5),
// ];

class RiskOption {
  final String labelKey; // Dùng để dịch theo locale
  final int score;

  const RiskOption({required this.labelKey, required this.score});
}

final List<RiskOption> frequencyOptions = [
  RiskOption(labelKey: "frequency_often", score: 5),
  RiskOption(labelKey: "frequency_sometimes", score: 3),
  RiskOption(labelKey: "frequency_rare", score: 1),
];

final List<RiskOption> probabilityOptions = [
  RiskOption(labelKey: "probability_certain", score: 5),
  RiskOption(labelKey: "probability_high", score: 4),
  RiskOption(labelKey: "probability_possible", score: 3),
  RiskOption(labelKey: "probability_rare", score: 1),
];

final List<RiskOption> severityOptions = [
  RiskOption(labelKey: "severity_critical", score: 5),
  RiskOption(labelKey: "severity_severe", score: 4),
  RiskOption(labelKey: "severity_moderate", score: 3),
  RiskOption(labelKey: "severity_minor", score: 2),
  RiskOption(labelKey: "severity_negligible", score: 1),
];
