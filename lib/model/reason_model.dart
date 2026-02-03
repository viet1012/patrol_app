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

final List<RiskOption> fiveMOptions = [
  RiskOption(labelKey: 'm_material', score: 0),
  RiskOption(labelKey: 'm_machine', score: 0),
  RiskOption(labelKey: 'm_man', score: 0),
  RiskOption(labelKey: 'm_method', score: 0),
  RiskOption(labelKey: 'm_measuring', score: 0),
  RiskOption(labelKey: 'm_df_5s', score: 0),
];

final List<RiskOption> qualityImpactOptions = [
  RiskOption(labelKey: 'impact_claim', score: 5),
  RiskOption(labelKey: 'impact_defect_in_process', score: 4),
  RiskOption(labelKey: 'impact_accident_risk', score: 6),
  RiskOption(labelKey: 'impact_gauge_damage', score: 3),
];

final List<RiskOption> qaFrequencyOptions = const [
  RiskOption(labelKey: "frequency_often", score: 0),
  RiskOption(labelKey: "frequency_rare", score: 0),
];
