import 'package:flutter/widgets.dart';
import 'l10n/app_localizations.dart';
import 'l10n/app_localizations_en.dart';
import 'l10n/app_localizations_vi.dart';
import 'l10n/app_localizations_ja.dart';

extension TranslateExtension on String {

  // -----------------------------------------
  // 1. HÀM DỊCH THEO LOCALE HIỆN TẠI
  // -----------------------------------------
  String tr(BuildContext context, {Map<String, dynamic>? params}) {
    final t = AppLocalizations.of(context);
    late String value;

    switch (this) {
      case 'plant': value = t!.plant; break;
      case 'group': value = t!.group; break;
      case 'fac': value = t!.fac; break;
      case 'area': value = t!.area; break;
      case 'machine': value = t!.machine; break;
      case 'search_or_add_new': value = t!.search_or_add_new; break;
      case 'label_freq': value = t!.label_freq; break;
      case 'label_prob': value = t!.label_prob; break;
      case 'label_sev': value = t!.label_sev; break;
      case 'label_risk': value = t!.label_risk; break;
      case 'frequency_often': value = t!.frequency_often; break;
      case 'frequency_sometimes': value = t!.frequency_sometimes; break;
      case 'frequency_rare': value = t!.frequency_rare; break;
      case 'probability_certain': value = t!.probability_certain; break;
      case 'probability_high': value = t!.probability_high; break;
      case 'probability_possible': value = t!.probability_possible; break;
      case 'probability_rare': value = t!.probability_rare; break;
      case 'severity_critical': value = t!.severity_critical; break;
      case 'severity_severe': value = t!.severity_severe; break;
      case 'severity_moderate': value = t!.severity_moderate; break;
      case 'severity_minor': value = t!.severity_minor; break;
      case 'severity_negligible': value = t!.severity_negligible; break;
      case 'risk_low': value = t!.risk_low; break;
      case 'risk_medium': value = t!.risk_medium; break;
      case 'risk_high': value = t!.risk_high; break;
      case 'risk_very_high': value = t!.risk_very_high; break;
      case 'risk_extreme': value = t!.risk_extreme; break;
      case 'needRecheck': value = t!.needRecheck; break;
      case 'needRecheckWithArea': value = t!.needRecheckWithArea(params?['area'] ?? ''); break;
      case 'needSelectArea': value = t!.needSelectArea; break;
      case 'commentHint': value = t!.commentHint; break;
      case 'counterMeasureHint': value = t!.counterMeasureHint; break;
      case 'label_5m': value = t!.label_5m; break;
      case 'm_material': value = t!.m_material; break;
      case 'm_machine': value = t!.m_machine; break;
      case 'm_man': value = t!.m_man; break;
      case 'm_method': value = t!.m_method; break;
      case 'm_measuring': value = t!.m_measuring; break;
      case 'm_df_5s': value = t!.m_df_5s; break;
      case 'label_quality_impact': value = t!.label_quality_impact; break;
      case 'impact_claim': value = t!.impact_claim; break;
      case 'impact_defect_in_process': value = t!.impact_defect_in_process; break;
      case 'impact_accident_risk': value = t!.impact_accident_risk; break;
      case 'impact_gauge_damage': value = t!.impact_gauge_damage; break;
      default:
        value = this;
    }

    // Replace placeholders
    if (params != null) {
      params.forEach((k, v) {
        value = value.replaceAll('{$k}', v.toString());
      });
    }

    return value;
  }

  // -----------------------------------------
  // 2. HÀM DỊCH THEO LOCALE CỤ THỂ (VI / JA)
  // -----------------------------------------
  String _trLocale(String key, Locale locale, {Map<String, dynamic>? params}) {
    final t = lookupAppLocalizations(locale);
    if (t == null) return key;

    switch (key) {

      case 'plant': return t.plant;
      case 'group': return t.group;
      case 'fac': return t.fac;
      case 'area': return t.area;
      case 'machine': return t.machine;
      case 'search_or_add_new': return t.search_or_add_new;
      case 'label_freq': return t.label_freq;
      case 'label_prob': return t.label_prob;
      case 'label_sev': return t.label_sev;
      case 'label_risk': return t.label_risk;
      case 'frequency_often': return t.frequency_often;
      case 'frequency_sometimes': return t.frequency_sometimes;
      case 'frequency_rare': return t.frequency_rare;
      case 'probability_certain': return t.probability_certain;
      case 'probability_high': return t.probability_high;
      case 'probability_possible': return t.probability_possible;
      case 'probability_rare': return t.probability_rare;
      case 'severity_critical': return t.severity_critical;
      case 'severity_severe': return t.severity_severe;
      case 'severity_moderate': return t.severity_moderate;
      case 'severity_minor': return t.severity_minor;
      case 'severity_negligible': return t.severity_negligible;
      case 'risk_low': return t.risk_low;
      case 'risk_medium': return t.risk_medium;
      case 'risk_high': return t.risk_high;
      case 'risk_very_high': return t.risk_very_high;
      case 'risk_extreme': return t.risk_extreme;
      case 'needRecheck': return t.needRecheck;
      case 'needRecheckWithArea': return t.needRecheckWithArea(params?['area'] ?? '');
      case 'needSelectArea': return t.needSelectArea;
      case 'commentHint': return t.commentHint;
      case 'counterMeasureHint': return t.counterMeasureHint;
      case 'label_5m': return t.label_5m;
      case 'm_material': return t.m_material;
      case 'm_machine': return t.m_machine;
      case 'm_man': return t.m_man;
      case 'm_method': return t.m_method;
      case 'm_measuring': return t.m_measuring;
      case 'm_df_5s': return t.m_df_5s;
      case 'label_quality_impact': return t.label_quality_impact;
      case 'impact_claim': return t.impact_claim;
      case 'impact_defect_in_process': return t.impact_defect_in_process;
      case 'impact_accident_risk': return t.impact_accident_risk;
      case 'impact_gauge_damage': return t.impact_gauge_damage;
    }

    return key;
  }

  // -----------------------------------------
  // 3. TRẢ VỀ { vi: x, ja: y }
  // -----------------------------------------
  Map<String, String> multiLang(BuildContext context, String key,
      {Map<String, dynamic>? params}) {
    return {
      'vi': _trLocale(key, const Locale('vi'), params: params),
      'ja': _trLocale(key, const Locale('ja'), params: params),
    };
  }

  // -----------------------------------------
  // 4. TRẢ VỀ "VI\nJA"
  // -----------------------------------------
  String combinedViJa(BuildContext context, String key,
      {Map<String, dynamic>? params}) {
    final vi = _trLocale(key, const Locale('vi'), params: params);
    final ja = _trLocale(key, const Locale('ja'), params: params);
    return "$vi\n$ja";
  }
}

