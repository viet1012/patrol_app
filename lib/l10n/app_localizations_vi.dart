// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get plant => 'Nhà máy(*)';

  @override
  String get group => 'Nhóm(*)';

  @override
  String get fac => 'Phân xưởng(*)';

  @override
  String get area => 'Khu vực(*)';

  @override
  String get machine => 'Máy móc(*)';

  @override
  String get search_or_add_new => 'Tìm kiếm hoặc nhập mới...';

  @override
  String get label_freq => 'Tần suất phát sinh';

  @override
  String get label_prob => 'Khả năng phát sinh';

  @override
  String get label_sev => 'Mức độ chấn thương';

  @override
  String get label_risk => 'Mức độ rủi ro';

  @override
  String get frequency_often => 'Thường xuyên';

  @override
  String get frequency_sometimes => 'Thỉnh thoảng';

  @override
  String get frequency_rare => 'Hầu như không';

  @override
  String get probability_certain => 'Chắc chắn';

  @override
  String get probability_high => 'Khả năng cao';

  @override
  String get probability_possible => 'Có khả năng';

  @override
  String get probability_rare => 'Hầu như không';

  @override
  String get severity_critical => 'Vết thương chí mạng';

  @override
  String get severity_severe => 'Chấn thương nghiêm trọng';

  @override
  String get severity_moderate => 'Chấn thương vừa phải';

  @override
  String get severity_minor => 'Chấn thương nhẹ';

  @override
  String get severity_negligible => 'Không đáng kể';

  @override
  String get risk_low => 'I - Rủi ro thấp';

  @override
  String get risk_medium => 'II - Rủi ro trung bình';

  @override
  String get risk_high => 'III - Rủi ro cao';

  @override
  String get risk_very_high => 'IV - Rủi ro rất cao';

  @override
  String get risk_extreme => 'V - Rủi ro cực kỳ cao';

  @override
  String get needRecheck => 'Cần rà soát lại vấn đề tương tự';

  @override
  String needRecheckWithArea(Object area) {
    return 'Cần rà soát lại vấn đề tương tự ở $area';
  }

  @override
  String get needSelectArea => 'Chưa chọn khu vực';

  @override
  String get commentHint => 'Nội dung...(*)';

  @override
  String get counterMeasureHint => 'Đối sách...';
}
