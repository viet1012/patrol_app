import 'package:chuphinh/core/models/fixed_asset_pic.dart';
import 'package:chuphinh/core/models/fixed_asset_scan_info.dart' show parseDate;

// Model cho GET /api/fixed-assets/summary, /summary/pics, /summary/pic-detail
// (tham số period=YYYY-Qn). Parse mềm: field thiếu -> 0 / rỗng / null; một số
// field nhận vài tên tương đương (backend chưa chốt DTO).

int _int(dynamic v) =>
    v is num ? v.toInt() : int.tryParse(v?.toString().trim() ?? '') ?? 0;

int? _optInt(dynamic v) =>
    v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'.trim()));

/// Số máy theo kế hoạch tới hôm nay: round(planPct% × total).
int fixedAssetPlanMachines(double planPct, int total) =>
    (planPct / 100 * total).round();

/// Số máy chậm so với kế hoạch (≥ 0).
int fixedAssetBehindMachines(double planPct, int total, int audited) {
  final behind = fixedAssetPlanMachines(planPct, total) - audited;
  return behind > 0 ? behind : 0;
}

/// Số máy vượt kế hoạch (≥ 0).
int fixedAssetAheadMachines(double planPct, int total, int audited) {
  final ahead = audited - fixedAssetPlanMachines(planPct, total);
  return ahead > 0 ? ahead : 0;
}

double _double(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString().trim() ?? '') ?? 0;

double? _optDouble(dynamic v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'.trim()));

String _str(dynamic v) => (v ?? '').toString().trim();

bool _flag(dynamic v) =>
    v == true ||
    (v is num && v != 0) ||
    (v is String && const {'true', '1'}.contains(v.trim().toLowerCase()));

/// Giá trị của key đầu tiên có mặt (khác null) trong [keys].
dynamic _pick(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null) return value;
  }
  return null;
}

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false)
    : const <Map<String, dynamic>>[];

/// Kỳ kiểm kê theo quý: "YYYY-Qn".
class FixedAssetPeriod implements Comparable<FixedAssetPeriod> {
  final int year;
  final int quarter;

  const FixedAssetPeriod(this.year, this.quarter);

  factory FixedAssetPeriod.of(DateTime date) =>
      FixedAssetPeriod(date.year, (date.month - 1) ~/ 3 + 1);

  /// "2026-Q4" (không phân biệt hoa thường); sai định dạng -> null.
  static FixedAssetPeriod? tryParse(String? value) {
    final m = RegExp(r'^(\d{4})-?Q([1-4])$', caseSensitive: false)
        .firstMatch(value?.trim() ?? '');
    if (m == null) return null;
    return FixedAssetPeriod(int.parse(m[1]!), int.parse(m[2]!));
  }

  FixedAssetPeriod get previous =>
      quarter == 1 ? FixedAssetPeriod(year - 1, 4) : FixedAssetPeriod(year, quarter - 1);

  /// Tham số API.
  String get key => '$year-Q$quarter';

  /// "Quý 4/2026".
  String get label => 'Quý $quarter/$year';

  /// Tháng thứ [index] (1–3) của quý: tháng dương lịch.
  int monthOf(int index) => (quarter - 1) * 3 + index;

  DateTime monthStart(int index) => DateTime(year, monthOf(index));

  /// Ngày cuối tháng thứ [index] (ngày 0 của tháng sau).
  DateTime monthEnd(int index) => DateTime(year, monthOf(index) + 1, 0);

  /// Tháng thứ mấy (1–3) của quý chứa [date]; ngoài quý = 0.
  int monthIndexOf(DateTime date) {
    if (FixedAssetPeriod.of(date) != this) return 0;
    return date.month - (quarter - 1) * 3;
  }

  /// Mục tiêu lũy kế (%) cuối tháng thứ [index]: 1/3, 2/3, 100%.
  static double monthTargetPct(int index) => index.clamp(0, 3) * 100 / 3;

  /// Kế hoạch (%) đến [today]: mục tiêu cuối tháng trước + (ngày đã qua
  /// trong tháng / số ngày của tháng) × 1/3. Trước quý 0, sau quý 100.
  double planPctAt(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    if (day.isBefore(monthStart(1))) return 0;
    if (day.isAfter(monthEnd(3))) return 100;
    final index = monthIndexOf(day);
    final daysInMonth = monthEnd(index).day;
    return monthTargetPct(index - 1) + day.day / daysInMonth * 100 / 3;
  }

  @override
  bool operator ==(Object other) =>
      other is FixedAssetPeriod && other.year == year && other.quarter == quarter;

  @override
  int get hashCode => Object.hash(year, quarter);

  @override
  int compareTo(FixedAssetPeriod other) =>
      year != other.year ? year.compareTo(other.year) : quarter.compareTo(other.quarter);

  @override
  String toString() => key;
}

/// Trạng thái tiến độ so với kế hoạch.
enum FixedAssetPaceStatus {
  done,
  onTrack,
  slightlyBehind,
  behind,
  unknown;

  static FixedAssetPaceStatus parse(dynamic value) =>
      switch (_str(value).toUpperCase()) {
        'DONE' || 'COMPLETED' => done,
        'ON_TRACK' || 'AHEAD' => onTrack,
        'SLIGHTLY_BEHIND' => slightlyBehind,
        'BEHIND' => behind,
        _ => unknown,
      };

  bool get isBehind => this == behind || this == slightlyBehind;
}

/// Tháng dương lịch (1–12) từ 11 / "11" / "2026-11" / "T11"; không đọc
/// được -> null.
int? _monthNumber(dynamic v) {
  if (v is num) return v.toInt();
  final m = RegExp(r'(\d{1,2})$').firstMatch(_str(v));
  return m == null ? null : int.parse(m[1]!);
}

/// Số máy đã kiểm trong một tháng của quý (picRows[].months[]).
class FixedAssetSummaryPicMonth {
  /// Tháng dương lịch (1–12); null = backend không trả.
  final int? month;

  /// null = tháng chưa có số.
  final int? audited;

  const FixedAssetSummaryPicMonth({this.month, this.audited});

  factory FixedAssetSummaryPicMonth.fromJson(Map<String, dynamic> json) =>
      FixedAssetSummaryPicMonth(
        month: _monthNumber(json['month']),
        audited: _optInt(json['audited']),
      );
}

/// Một dòng "Tiến độ theo PIC" (picRows[] của GET /summary).
class FixedAssetSummaryPicRow {
  /// Email PIC; null = dòng tổng hoặc máy chưa có PIC.
  final String? pic;
  final bool isTotal;
  final int total;
  final int audited;

  /// 3 tháng của quý theo thứ tự.
  final List<FixedAssetSummaryPicMonth> months;

  const FixedAssetSummaryPicRow({
    required this.pic,
    required this.isTotal,
    required this.total,
    required this.audited,
    required this.months,
  });

  /// Máy chưa có PIC.
  bool get isUnassigned => pic == null && !isTotal;

  double get pct => total <= 0 ? 0 : audited * 100 / total;

  factory FixedAssetSummaryPicRow.fromJson(Map<String, dynamic> json) {
    final pic = _str(json['pic']);
    return FixedAssetSummaryPicRow(
      pic: pic.isEmpty ? null : pic,
      isTotal: _flag(json['isTotal']),
      total: _int(json['total']),
      audited: _int(json['audited']),
      months: _maps(json['months'])
          .map(FixedAssetSummaryPicMonth.fromJson)
          .toList(growable: false),
    );
  }
}

/// GET /summary: tổng quan kỳ.
class FixedAssetSummaryOverview {
  final FixedAssetPeriod? period;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  final int total;
  final int audited;
  final int remaining;
  final double pct;

  /// Kế hoạch (%) đến hôm nay theo mục tiêu tháng (backend).
  final double planPct;

  /// Backend có trả planPct; false: màn hình tính dự phòng
  /// ([FixedAssetPeriod.planPctAt]).
  final bool hasPlanPct;

  /// Số máy đang chờ thay QR.
  final int pendingQr;

  /// Tiến độ theo PIC (dòng tổng, từng PIC, chưa có PIC).
  final List<FixedAssetSummaryPicRow> picRows;

  /// Các kỳ có dữ liệu (nếu backend trả).
  final List<FixedAssetPeriod> periods;

  /// Ngày hiện tại theo backend (field `today`), không có thì giờ máy.
  final DateTime today;

  const FixedAssetSummaryOverview({
    this.period,
    this.periodStart,
    this.periodEnd,
    required this.total,
    required this.audited,
    required this.remaining,
    required this.pct,
    required this.planPct,
    this.hasPlanPct = true,
    required this.pendingQr,
    this.picRows = const <FixedAssetSummaryPicRow>[],
    this.periods = const <FixedAssetPeriod>[],
    required this.today,
  });

  /// Chênh lệch so với kế hoạch (điểm %); âm = chậm.
  double get diff => pct - planPct;

  int get planMachines => fixedAssetPlanMachines(planPct, total);
  int get behindMachines => fixedAssetBehindMachines(planPct, total, audited);
  int get aheadMachines => fixedAssetAheadMachines(planPct, total, audited);

  /// Bản sao với kế hoạch [value] (dự phòng FE khi backend thiếu planPct).
  FixedAssetSummaryOverview withPlanPct(double value) =>
      FixedAssetSummaryOverview(
        period: period,
        periodStart: periodStart,
        periodEnd: periodEnd,
        total: total,
        audited: audited,
        remaining: remaining,
        pct: pct,
        planPct: value,
        pendingQr: pendingQr,
        picRows: picRows,
        periods: periods,
        today: today,
      );

  /// Số máy mục tiêu lũy kế cuối tháng thứ [index] của quý.
  int monthTargetMachines(int index) => fixedAssetPlanMachines(
    FixedAssetPeriod.monthTargetPct(index),
    total,
  );

  factory FixedAssetSummaryOverview.fromJson(Map<String, dynamic> json) {
    final total = _int(_pick(json, ['total', 'totalMachines']));
    final audited = _int(_pick(json, ['audited', 'auditedMachines']));
    final remaining = _pick(json, ['remaining', 'remainingMachines']);
    final planPct = _optDouble(json['planPct']);
    return FixedAssetSummaryOverview(
      period: FixedAssetPeriod.tryParse(_str(json['period'])),
      periodStart: parseDate(json['periodStart']),
      periodEnd: parseDate(json['periodEnd']),
      total: total,
      audited: audited,
      remaining: remaining == null
          ? (total - audited).clamp(0, total)
          : _int(remaining),
      pct: _double(_pick(json, ['pct', 'completionPercent'])),
      planPct: planPct ?? 0,
      hasPlanPct: planPct != null,
      pendingQr: _int(_pick(json, ['pendingQr', 'pendingQrReplace'])),
      picRows: _maps(json['picRows'])
          .map(FixedAssetSummaryPicRow.fromJson)
          .toList(growable: false),
      periods: (json['periods'] is List ? json['periods'] as List : const [])
          .map((p) => FixedAssetPeriod.tryParse(p?.toString()))
          .whereType<FixedAssetPeriod>()
          .toList(growable: false),
      today: parseDate(json['today']) ?? DateTime.now(),
    );
  }
}

/// Một PIC trong GET /summary/pics.
class FixedAssetSummaryPic {
  final String email;
  final String name;
  final int total;
  final int audited;
  final int remaining;
  final double pct;
  final double planPct;
  final FixedAssetPaceStatus status;
  final int pendingQr;
  final int zoneCount;

  const FixedAssetSummaryPic({
    required this.email,
    required this.name,
    required this.total,
    required this.audited,
    required this.remaining,
    required this.pct,
    required this.planPct,
    required this.status,
    required this.pendingQr,
    required this.zoneCount,
  });

  /// Chênh lệch so với kế hoạch (điểm %); âm = chậm.
  double get diff => pct - planPct;

  int get planMachines => fixedAssetPlanMachines(planPct, total);
  int get behindMachines => fixedAssetBehindMachines(planPct, total, audited);
  int get aheadMachines => fixedAssetAheadMachines(planPct, total, audited);

  /// /summary/pics không trả planPct (kế hoạch theo ngày, chung mọi PIC):
  /// lấy từ /summary.
  FixedAssetSummaryPic withPlanPct(double value) => FixedAssetSummaryPic(
    email: email,
    name: name,
    total: total,
    audited: audited,
    remaining: remaining,
    pct: pct,
    planPct: value,
    status: status,
    pendingQr: pendingQr,
    zoneCount: zoneCount,
  );

  factory FixedAssetSummaryPic.fromJson(Map<String, dynamic> json) {
    final email = _str(_pick(json, ['pic', 'email']));
    final name = _str(json['name']);
    final total = _int(_pick(json, ['total', 'machineCount']));
    final audited = _int(json['audited']);
    final remaining = json['remaining'];
    return FixedAssetSummaryPic(
      email: email,
      name: name.isNotEmpty ? name : FixedAssetPic.nameOf(email),
      total: total,
      audited: audited,
      remaining: remaining == null
          ? (total - audited).clamp(0, total)
          : _int(remaining),
      pct: _double(json['pct']),
      planPct: _double(json['planPct']),
      status: FixedAssetPaceStatus.parse(json['status']),
      pendingQr: _int(_pick(json, ['pendingQr', 'pendingQrReplace'])),
      zoneCount: _int(_pick(json, ['zoneCount', 'zones'])),
    );
  }
}

/// Một khu của PIC (vị trí MASTER).
class FixedAssetSummaryZone {
  final String fac;
  final String floor;
  final String positionA;
  final String positionAA;
  final int total;
  final int audited;

  /// Số máy lệch vị trí (isMoved) trong khu; null = backend chưa trả.
  final int? movedCount;

  const FixedAssetSummaryZone({
    required this.fac,
    required this.floor,
    required this.positionA,
    required this.positionAA,
    required this.total,
    required this.audited,
    this.movedCount,
  });

  int get remaining => total > audited ? total - audited : 0;
  double get pct => total <= 0 ? 0 : audited * 100 / total;

  bool get hasFullLocation =>
      fac.isNotEmpty &&
      floor.isNotEmpty &&
      positionA.isNotEmpty &&
      positionAA.isNotEmpty;

  /// Tên khu hiển thị: AA (thiếu thì A).
  String get label => positionAA.isNotEmpty ? positionAA : positionA;

  factory FixedAssetSummaryZone.fromJson(Map<String, dynamic> json) =>
      FixedAssetSummaryZone(
        fac: _str(json['fac']),
        floor: _str(json['floor']),
        positionA: _str(json['positionA']),
        positionAA: _str(json['positionAA']),
        total: _int(json['total']),
        audited: _int(json['audited']),
        movedCount: _optInt(_pick(json, ['movedCount', 'moved'])),
      );
}

/// Một máy chưa kiểm kê trong kỳ của PIC.
class FixedAssetSummaryMachine {
  final String machineCode;
  final String faName;
  final String fac;
  final String floor;
  final String positionA;
  final String positionAA;

  const FixedAssetSummaryMachine({
    required this.machineCode,
    required this.faName,
    required this.fac,
    required this.floor,
    required this.positionA,
    required this.positionAA,
  });

  factory FixedAssetSummaryMachine.fromJson(Map<String, dynamic> json) =>
      FixedAssetSummaryMachine(
        machineCode: _str(json['machineCode']),
        faName: _str(json['faName']),
        fac: _str(json['fac']),
        floor: _str(json['floor']),
        positionA: _str(json['positionA']),
        positionAA: _str(json['positionAA']),
      );
}

/// Một máy của PIC trong GET /summary/pic-machines (kỳ đang chọn, có thể
/// lọc theo vị trí).
class FixedAssetPicMachine {
  final String machineCode;
  final String machineName;
  final String fac;
  final String floor;
  final String positionA;
  final String positionAA;

  /// Đã kiểm kê trong kỳ.
  final bool audited;

  /// MSNV người kiểm; rỗng khi backend không trả.
  final String auditUserId;
  final String auditUserName;
  final DateTime? auditedAt;
  final String auditMode;

  /// Lần quét gần nhất QR lệch vị trí; [qrLocation] = vị trí in trên QR.
  final bool qrMismatch;
  final String qrLocation;

  /// Đã thay QR xong.
  final bool reprintSts;

  /// Vị trí hiệu lực khác MASTER; [masterLocation] = "Fac/Floor/A/AA".
  final bool isMoved;
  final String masterLocation;
  final String note;

  const FixedAssetPicMachine({
    required this.machineCode,
    required this.machineName,
    required this.fac,
    required this.floor,
    required this.positionA,
    required this.positionAA,
    required this.audited,
    this.auditUserId = '',
    required this.auditUserName,
    required this.auditedAt,
    required this.auditMode,
    required this.qrMismatch,
    required this.qrLocation,
    required this.reprintSts,
    required this.isMoved,
    required this.masterLocation,
    required this.note,
  });

  /// Khu hiển thị: AA (thiếu thì A), như [FixedAssetSummaryZone.label].
  String get zoneLabel => positionAA.isNotEmpty ? positionAA : positionA;

  /// QR lệch vị trí, chưa thay xong.
  bool get pendingQr => qrMismatch && !reprintSts;

  /// Lệch vị trí (đã dời hoặc QR lệch).
  bool get abnormal => isMoved || qrMismatch;

  factory FixedAssetPicMachine.fromJson(Map<String, dynamic> json) =>
      FixedAssetPicMachine(
        machineCode: _str(json['machineCode']),
        machineName: _str(_pick(json, ['machineName', 'faName'])),
        fac: _str(json['fac']),
        floor: _str(json['floor']),
        positionA: _str(_pick(json, ['a', 'positionA'])),
        positionAA: _str(_pick(json, ['aa', 'positionAA'])),
        audited: _flag(json['audited']),
        auditUserId: _str(_pick(json, ['auditUserId', 'auditUserCode'])),
        auditUserName: _str(json['auditUserName']),
        auditedAt: parseDate(json['auditedAt']),
        auditMode: _str(json['auditMode']),
        qrMismatch: _flag(json['qrMismatch']),
        qrLocation: _str(json['qrLocation']),
        reprintSts: _flag(json['reprintSts']),
        isMoved: _flag(json['isMoved']),
        masterLocation: _str(json['masterLocation']),
        note: _str(json['note']),
      );
}

/// GET /summary/pic-detail.
class FixedAssetSummaryPicDetail {
  final FixedAssetSummaryPic pic;

  /// Máy / tuần (tốc độ hiện tại).
  final double? speedPerWeek;

  /// Ngày dự kiến xong theo tốc độ hiện tại; null = chưa ước tính được.
  final DateTime? etaDate;

  final List<FixedAssetSummaryZone> zones;
  final List<FixedAssetSummaryMachine> unaudited;

  const FixedAssetSummaryPicDetail({
    required this.pic,
    required this.speedPerWeek,
    required this.etaDate,
    required this.zones,
    required this.unaudited,
  });

  factory FixedAssetSummaryPicDetail.fromJson(Map<String, dynamic> json) {
    final zones = _maps(json['zones'])
        .map(FixedAssetSummaryZone.fromJson)
        .toList(growable: false);
    final pic = FixedAssetSummaryPic.fromJson(json);
    return FixedAssetSummaryPicDetail(
      // Thiếu zoneCount: đếm theo danh sách khu.
      pic: pic.zoneCount > 0
          ? pic
          : FixedAssetSummaryPic(
              email: pic.email,
              name: pic.name,
              total: pic.total,
              audited: pic.audited,
              remaining: pic.remaining,
              pct: pic.pct,
              planPct: pic.planPct,
              status: pic.status,
              pendingQr: pic.pendingQr,
              zoneCount: zones.length,
            ),
      speedPerWeek: _optDouble(json['speedPerWeek']),
      etaDate: parseDate(json['etaDate']),
      zones: zones,
      unaudited:
          _maps(_pick(json, ['unauditedMachines', 'unaudited', 'machines']))
              .map(FixedAssetSummaryMachine.fromJson)
              .where((m) => m.machineCode.isNotEmpty)
              .toList(growable: false),
    );
  }
}
