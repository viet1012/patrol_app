// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get plant => 'Factory';

  @override
  String get group => 'Group';

  @override
  String get fac => 'Factory';

  @override
  String get area => 'Area';

  @override
  String get machine => 'Machine';

  @override
  String get search_or_add_new => 'Search or add new...';

  @override
  String get label_freq => 'Frequency';

  @override
  String get label_prob => 'Probability';

  @override
  String get label_sev => 'Severity';

  @override
  String get label_risk => 'Risk Level';

  @override
  String get frequency_often => 'Frequent';

  @override
  String get frequency_sometimes => 'Occasional';

  @override
  String get frequency_rare => 'Rare';

  @override
  String get probability_certain => 'Certain';

  @override
  String get probability_high => 'Likely';

  @override
  String get probability_possible => 'Possible';

  @override
  String get probability_rare => 'Unlikely';

  @override
  String get severity_critical => 'Catastrophic';

  @override
  String get severity_severe => 'Severe Injury';

  @override
  String get severity_moderate => 'Moderate Injury';

  @override
  String get severity_minor => 'Minor Injury';

  @override
  String get severity_negligible => 'Negligible';

  @override
  String get risk_low => 'I - Low Risk';

  @override
  String get risk_medium => 'II - Medium Risk';

  @override
  String get risk_high => 'III - High Risk';

  @override
  String get risk_very_high => 'IV - Very High Risk';

  @override
  String get risk_extreme => 'V - Extreme Risk';

  @override
  String get needRecheck => 'Need to recheck similar issues';

  @override
  String needRecheckWithArea(Object area) {
    return 'Need to recheck similar issues in $area';
  }

  @override
  String get needSelectArea => 'Area not selected';

  @override
  String get commentHint => 'Note...';

  @override
  String get counterMeasureHint => 'Countermeasure...';

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
