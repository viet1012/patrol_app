class RiskOption {
  final String labelKey; // Dùng để dịch theo locale
  final int score;

  const RiskOption({required this.labelKey, required this.score});
}

final List<RiskOption> frequencyOptions = [
  RiskOption(labelKey: "frequency_often", score: 4),
  RiskOption(labelKey: "frequency_sometimes", score: 2),
  RiskOption(labelKey: "frequency_rare", score: 1),
];

final List<RiskOption> probabilityOptions = [
  RiskOption(labelKey: "probability_certain", score: 6),
  RiskOption(labelKey: "probability_high", score: 4),
  RiskOption(labelKey: "probability_possible", score: 2),
  RiskOption(labelKey: "probability_rare", score: 1),
];

final List<RiskOption> severityOptions = [
  RiskOption(labelKey: "severity_critical", score: 10),
  RiskOption(labelKey: "severity_severe", score: 7),
  RiskOption(labelKey: "severity_moderate", score: 5),
  RiskOption(labelKey: "severity_minor", score: 3),
  RiskOption(labelKey: "severity_negligible", score: 1),
];
