// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get plant => '工場';

  @override
  String get group => 'グループ';

  @override
  String get fac => '工場';

  @override
  String get area => 'エリア';

  @override
  String get machine => '機械';

  @override
  String get search_or_add_new => '検索または新規入力...';

  @override
  String get label_freq => '発生頻度';

  @override
  String get label_prob => '発生可能性';

  @override
  String get label_sev => 'ケガの重大性';

  @override
  String get label_risk => 'リスクレベル';

  @override
  String get frequency_often => '頻繁';

  @override
  String get frequency_sometimes => '時々';

  @override
  String get frequency_rare => '殆どない';

  @override
  String get probability_certain => '確実';

  @override
  String get probability_high => '可能性が高い';

  @override
  String get probability_possible => '可能性がある';

  @override
  String get probability_rare => 'ほとんどない';

  @override
  String get severity_critical => '致命傷';

  @override
  String get severity_severe => '重症';

  @override
  String get severity_moderate => '中等傷';

  @override
  String get severity_minor => '軽傷';

  @override
  String get severity_negligible => '軽微';

  @override
  String get risk_low => 'I - 低リスク';

  @override
  String get risk_medium => 'II - 中リスク';

  @override
  String get risk_high => 'III - 高リスク';

  @override
  String get risk_very_high => 'IV - 非常に高いリスク';

  @override
  String get risk_extreme => 'V - 極めて高いリスク';

  @override
  String get needRecheck => '類似問題を再確認する必要があります';

  @override
  String needRecheckWithArea(Object area) {
    return '$areaラインで類似問題を再確認する必要があります';
  }

  @override
  String get needSelectArea => 'エリアが選択されていません';

  @override
  String get commentHint => 'コンテンツ...';

  @override
  String get counterMeasureHint => '対策...';

  @override
  String get label_5m => '5M（発生要因）';

  @override
  String get m_material => 'Material';

  @override
  String get m_machine => 'Machine';

  @override
  String get m_man => 'Man';

  @override
  String get m_method => 'Method';

  @override
  String get m_measuring => 'Measuring';

  @override
  String get m_df_5s => 'DF_5S';

  @override
  String get label_quality_impact => '製品品質への影響度';

  @override
  String get impact_claim => 'クレーム発生';

  @override
  String get impact_defect_in_process => '工程内不良（不良品）発生';

  @override
  String get impact_accident_risk => '労働災害発生リスクあり';

  @override
  String get impact_gauge_damage => '検査治具／測定器の破損発生';
}
