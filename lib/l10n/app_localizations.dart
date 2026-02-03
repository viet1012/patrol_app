import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('vi')
  ];

  /// No description provided for @plant.
  ///
  /// In en, this message translates to:
  /// **'Factory'**
  String get plant;

  /// No description provided for @group.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group;

  /// No description provided for @fac.
  ///
  /// In en, this message translates to:
  /// **'Factory'**
  String get fac;

  /// No description provided for @area.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get area;

  /// No description provided for @machine.
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get machine;

  /// No description provided for @search_or_add_new.
  ///
  /// In en, this message translates to:
  /// **'Search or add new...'**
  String get search_or_add_new;

  /// No description provided for @label_freq.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get label_freq;

  /// No description provided for @label_prob.
  ///
  /// In en, this message translates to:
  /// **'Probability'**
  String get label_prob;

  /// No description provided for @label_sev.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get label_sev;

  /// No description provided for @label_risk.
  ///
  /// In en, this message translates to:
  /// **'Risk Level'**
  String get label_risk;

  /// No description provided for @frequency_often.
  ///
  /// In en, this message translates to:
  /// **'Frequent'**
  String get frequency_often;

  /// No description provided for @frequency_sometimes.
  ///
  /// In en, this message translates to:
  /// **'Occasional'**
  String get frequency_sometimes;

  /// No description provided for @frequency_rare.
  ///
  /// In en, this message translates to:
  /// **'Rare'**
  String get frequency_rare;

  /// No description provided for @probability_certain.
  ///
  /// In en, this message translates to:
  /// **'Certain'**
  String get probability_certain;

  /// No description provided for @probability_high.
  ///
  /// In en, this message translates to:
  /// **'Likely'**
  String get probability_high;

  /// No description provided for @probability_possible.
  ///
  /// In en, this message translates to:
  /// **'Possible'**
  String get probability_possible;

  /// No description provided for @probability_rare.
  ///
  /// In en, this message translates to:
  /// **'Unlikely'**
  String get probability_rare;

  /// No description provided for @severity_critical.
  ///
  /// In en, this message translates to:
  /// **'Catastrophic'**
  String get severity_critical;

  /// No description provided for @severity_severe.
  ///
  /// In en, this message translates to:
  /// **'Severe Injury'**
  String get severity_severe;

  /// No description provided for @severity_moderate.
  ///
  /// In en, this message translates to:
  /// **'Moderate Injury'**
  String get severity_moderate;

  /// No description provided for @severity_minor.
  ///
  /// In en, this message translates to:
  /// **'Minor Injury'**
  String get severity_minor;

  /// No description provided for @severity_negligible.
  ///
  /// In en, this message translates to:
  /// **'Negligible'**
  String get severity_negligible;

  /// No description provided for @risk_low.
  ///
  /// In en, this message translates to:
  /// **'I - Low Risk'**
  String get risk_low;

  /// No description provided for @risk_medium.
  ///
  /// In en, this message translates to:
  /// **'II - Medium Risk'**
  String get risk_medium;

  /// No description provided for @risk_high.
  ///
  /// In en, this message translates to:
  /// **'III - High Risk'**
  String get risk_high;

  /// No description provided for @risk_very_high.
  ///
  /// In en, this message translates to:
  /// **'IV - Very High Risk'**
  String get risk_very_high;

  /// No description provided for @risk_extreme.
  ///
  /// In en, this message translates to:
  /// **'V - Extreme Risk'**
  String get risk_extreme;

  /// No description provided for @needRecheck.
  ///
  /// In en, this message translates to:
  /// **'Need to recheck similar issues'**
  String get needRecheck;

  /// No description provided for @needRecheckWithArea.
  ///
  /// In en, this message translates to:
  /// **'Need to recheck similar issues in {area}'**
  String needRecheckWithArea(Object area);

  /// No description provided for @needSelectArea.
  ///
  /// In en, this message translates to:
  /// **'Area not selected'**
  String get needSelectArea;

  /// No description provided for @commentHint.
  ///
  /// In en, this message translates to:
  /// **'Note...'**
  String get commentHint;

  /// No description provided for @counterMeasureHint.
  ///
  /// In en, this message translates to:
  /// **'Countermeasure...'**
  String get counterMeasureHint;

  /// No description provided for @label_5m.
  ///
  /// In en, this message translates to:
  /// **'5M（発生要因）'**
  String get label_5m;

  /// No description provided for @m_material.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get m_material;

  /// No description provided for @m_machine.
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get m_machine;

  /// No description provided for @m_man.
  ///
  /// In en, this message translates to:
  /// **'Man'**
  String get m_man;

  /// No description provided for @m_method.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get m_method;

  /// No description provided for @m_measuring.
  ///
  /// In en, this message translates to:
  /// **'Measuring'**
  String get m_measuring;

  /// No description provided for @m_df_5s.
  ///
  /// In en, this message translates to:
  /// **'DF_5S'**
  String get m_df_5s;

  /// No description provided for @label_quality_impact.
  ///
  /// In en, this message translates to:
  /// **'製品品質への影響度'**
  String get label_quality_impact;

  /// No description provided for @impact_claim.
  ///
  /// In en, this message translates to:
  /// **'クレーム発生'**
  String get impact_claim;

  /// No description provided for @impact_defect_in_process.
  ///
  /// In en, this message translates to:
  /// **'工程内不良（不良品）発生'**
  String get impact_defect_in_process;

  /// No description provided for @impact_accident_risk.
  ///
  /// In en, this message translates to:
  /// **'労働災害発生リスクあり'**
  String get impact_accident_risk;

  /// No description provided for @impact_gauge_damage.
  ///
  /// In en, this message translates to:
  /// **'検査治具／測定器の破損発生'**
  String get impact_gauge_damage;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ja', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'ja': return AppLocalizationsJa();
    case 'vi': return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
