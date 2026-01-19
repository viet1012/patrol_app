import 'package:chuphinh/model/reason_model.dart';

class RiskScoreCalculator {
  /// Lấy score từ labelKey + option list
  static int _scoreOf(String? key, List<RiskOption> options) {
    if (key == null) return 0;

    return options
        .firstWhere(
          (e) => e.labelKey == key,
          orElse: () => const RiskOption(labelKey: "", score: 0),
        )
        .score;
  }

  /// Tổng điểm rủi ro
  static int totalScore({
    required String? freqKey,
    required String? probKey,
    required String? sevKey,
    required List<RiskOption> frequencyOptions,
    required List<RiskOption> probabilityOptions,
    required List<RiskOption> severityOptions,
  }) {
    final f = _scoreOf(freqKey, frequencyOptions);
    final p = _scoreOf(probKey, probabilityOptions);
    final s = _scoreOf(sevKey, severityOptions);

    return f + p + s;
  }

  /// Ký hiệu mức độ rủi ro (I → V)
  static String scoreSymbol({
    required String? freqKey,
    required String? probKey,
    required String? sevKey,
    required List<RiskOption> frequencyOptions,
    required List<RiskOption> probabilityOptions,
    required List<RiskOption> severityOptions,
  }) {
    // Chưa chọn đủ
    if (freqKey == null || probKey == null || sevKey == null) {
      return "";
    }

    final score = totalScore(
      freqKey: freqKey,
      probKey: probKey,
      sevKey: sevKey,
      frequencyOptions: frequencyOptions,
      probabilityOptions: probabilityOptions,
      severityOptions: severityOptions,
    );

    if (score >= 16) return "V";
    if (score >= 12) return "IV";
    if (score >= 9) return "III";
    if (score >= 6) return "II";
    if (score >= 3) return "I";
    return "-";
  }
}
