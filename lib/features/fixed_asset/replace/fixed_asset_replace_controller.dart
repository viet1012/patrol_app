import 'package:flutter/foundation.dart';

import 'package:chuphinh/core/api/fixed_asset_backend.dart';
import 'package:chuphinh/core/models/fixed_asset_audit_save_response.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_audit_flow.dart'
    show fixedAssetErrorText, fixedAssetManualQrCheck;
import 'package:chuphinh/features/fixed_asset/fixed_asset_location.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_qr_parser.dart';
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_models.dart';
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_strings.dart';

/// Nhóm theo PositionA thực tế: các khu AA bên trong.
class FixedAssetReplaceArea {
  final String positionA;
  final List<FixedAssetReplaceZone> zones;

  const FixedAssetReplaceArea(this.positionA, this.zones);

  int get count => zones.fold(0, (sum, z) => sum + z.tasks.length);
}

/// Nhóm theo (Fac, Floor) thực tế.
class FixedAssetReplaceFloor {
  final String fac;
  final String floor;
  final List<FixedAssetReplaceArea> areas;

  const FixedAssetReplaceFloor(this.fac, this.floor, this.areas);

  int get count => areas.fold(0, (sum, a) => sum + a.count);
}

/// State màn "Thay QR": máy còn chờ thay QR (GET /qr-mismatch, mọi xưởng),
/// lọc xưởng, gom Floor → A → AA theo vị trí thực tế (*_Act).
class FixedAssetReplaceController extends ChangeNotifier {
  FixedAssetReplaceController({this.api = const FixedAssetBackend()});

  final FixedAssetBackend api;

  bool _disposed = false;
  int _req = 0;

  bool _loading = true;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  List<FixedAssetReplaceTask> _tasks = const <FixedAssetReplaceTask>[];
  List<FixedAssetReplaceTask> get tasks => _tasks;

  /// Xưởng đang lọc; null = tất cả.
  String? _fac;
  String? get fac => _fac;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// [silent]: tải lại khi quay về từ màn quét, giữ danh sách cũ tới khi có
  /// kết quả (lỗi thì giữ nguyên).
  Future<void> load({bool silent = false}) async {
    final req = ++_req;
    if (!silent) {
      _loading = true;
      _error = null;
      _notify();
    }

    try {
      final rows = await api.fetchQrMismatch();
      if (_disposed || req != _req) return;
      _tasks = rows
          .where((r) => r.machineCode.isNotEmpty)
          .map(FixedAssetReplaceTask.new)
          .toList(growable: false);
      _error = null;
      _loading = false;
      if (_fac != null && !facs.contains(_fac)) _fac = null;
      _notify();
    } catch (error) {
      if (_disposed || req != _req) return;
      _loading = false;
      if (!silent) _error = fixedAssetErrorText(error);
      _notify();
    }
  }

  void setFac(String? value) {
    if (value == _fac) return;
    _fac = value;
    _notify();
  }

  /// Xưởng (thực tế) có trong dữ liệu, sắp theo tên.
  List<String> get facs {
    final set = <String>{
      for (final t in _tasks)
        if ((t.row.facAct ?? '').isNotEmpty) t.row.facAct!,
    };
    return set.toList()..sort();
  }

  bool _inFac(String? fac) => _fac == null || (fac ?? '') == _fac;

  /// Máy của xưởng đang lọc (kể cả chưa rõ vị trí).
  int get visibleCount =>
      _tasks.where((t) => _inFac(t.row.facAct) || t.row.facAct == null).length;

  /// Floor → A → AA của xưởng đang lọc (chỉ dòng có đủ vị trí thực tế).
  List<FixedAssetReplaceFloor> get floors {
    final byZone = <String, List<FixedAssetReplaceTask>>{};
    final locationOf = <String, FixedAssetAuditLocation>{};
    for (final task in _tasks) {
      final location = fixedAssetReplaceLocationOf(task.row);
      if (location == null || !_inFac(location.fac)) continue;
      final key = fixedAssetReplaceZoneKey(location);
      (byZone[key] ??= <FixedAssetReplaceTask>[]).add(task);
      locationOf[key] ??= location;
    }

    // (fac|floor) -> A -> zones.
    final tree = <String, Map<String, List<FixedAssetReplaceZone>>>{};
    final floorOf = <String, (String, String)>{};
    for (final entry in byZone.entries) {
      final location = locationOf[entry.key]!;
      final zone = FixedAssetReplaceZone(location, entry.value);
      final floorKey = '${location.fac}|${location.floor}';
      floorOf[floorKey] = (location.fac, location.floor);
      ((tree[floorKey] ??= {})[location.positionA] ??= []).add(zone);
    }

    final floorKeys = tree.keys.toList()..sort(_natural);
    return [
      for (final fk in floorKeys)
        FixedAssetReplaceFloor(floorOf[fk]!.$1, floorOf[fk]!.$2, [
          for (final a in tree[fk]!.keys.toList()..sort(_natural))
            FixedAssetReplaceArea(
              a,
              tree[fk]![a]!..sort(
                (x, y) =>
                    _natural(x.location!.positionAA, y.location!.positionAA),
              ),
            ),
        ]),
    ];
  }

  /// Nhóm "Chưa rõ vị trí": *_Act thiếu Fac / Floor / A / AA. Xưởng đang
  /// lọc: gồm cả dòng không có Fac. null = không có máy nào.
  FixedAssetReplaceZone? get unknownZone {
    final tasks = [
      for (final t in _tasks)
        if (fixedAssetReplaceLocationOf(t.row) == null &&
            (_inFac(t.row.facAct) || (t.row.facAct ?? '').isEmpty))
          t,
    ];
    return tasks.isEmpty ? null : FixedAssetReplaceZone(null, tasks);
  }

  /// Khu theo [FixedAssetReplaceZone.key] trong dữ liệu hiện tại (mọi xưởng
  /// với khu đã biết); khu hết máy -> danh sách rỗng.
  FixedAssetReplaceZone zoneByKey(String key, FixedAssetReplaceZone fallback) {
    if (key.isEmpty) {
      return unknownZone ?? FixedAssetReplaceZone(null, const []);
    }
    final tasks = [
      for (final t in _tasks)
        if (fixedAssetReplaceZoneKey(fixedAssetReplaceLocationOf(t.row)) ==
            key)
          t,
    ];
    return FixedAssetReplaceZone(fallback.location, tasks);
  }

  // ------------------------------------------------------------
  // TIẾN ĐỘ THAY QR (chỉ bộ nhớ, sống tới khi đóng tab "Thay QR")
  // ------------------------------------------------------------

  final Map<String, DateTime> _oldScannedAt = <String, DateTime>{};
  final Map<String, DateTime> _doneAt = <String, DateTime>{};

  /// Bước "Quét QR cũ" xong lúc nào (null = chưa).
  DateTime? oldScannedAt(FixedAssetReplaceTask task) => _oldScannedAt[task.code];

  /// Gỡ cờ thành công lúc nào (null = chưa).
  DateTime? doneAt(FixedAssetReplaceTask task) => _doneAt[task.code];

  bool isDone(FixedAssetReplaceTask task) => _doneAt.containsKey(task.code);

  /// Máy chưa xong kế tiếp trong khu [zoneKey] (sau [current], vòng về đầu);
  /// null = khu đã xong hết.
  FixedAssetReplaceTask? nextTask(
    String zoneKey,
    FixedAssetReplaceTask current,
  ) {
    final tasks = zoneByKey(
      zoneKey,
      FixedAssetReplaceZone(current.location, const []),
    ).tasks;
    final pending = [
      for (final t in tasks)
        if (!isDone(t) && t.code != current.code) t,
    ];
    if (pending.isEmpty) return null;
    final index = tasks.indexWhere((t) => t.code == current.code);
    if (index < 0) return pending.first;
    for (final t in [...tasks.skip(index + 1), ...tasks.take(index)]) {
      if (pending.contains(t)) return t;
    }
    return pending.first;
  }

  /// Bước QR cũ: chỉ kiểm ở FE (mã máy + vị trí = *_Qr), không gọi save.
  /// null = đúng (đã ghi nhận), còn lại = câu báo lỗi.
  String? scanOldQr(FixedAssetReplaceTask task, String rawQr) {
    final qr = parseFixedAssetQr(rawQr);
    final error = _machineError(task, qr);
    if (error != null) return error;
    if (!task.isOldQr(qr)) {
      return FixedAssetReplaceStrings.notOldQr(task.oldQrShort);
    }
    _oldScannedAt[task.code] = DateTime.now();
    _notify();
    return null;
  }

  /// Bước QR mới: kiểm ở FE (đúng máy, không phải QR cũ, vị trí = *_Act) rồi
  /// POST /audit (MANUAL, vị trí chọn = *_Act). Chỉ tính xong khi backend gỡ
  /// cờ. Không hỏi "Máy đã dời?". null = xong, còn lại = câu báo lỗi.
  Future<String?> scanNewQr(
    FixedAssetReplaceTask task,
    String rawQr, {
    required String userId,
    required String userName,
  }) async {
    final location = task.location;
    if (location == null) return FixedAssetReplaceStrings.unknownAct;

    final qr = parseFixedAssetQr(rawQr);
    final error = _machineError(task, qr);
    if (error != null) return error;
    if (task.isOldQr(qr)) return FixedAssetReplaceStrings.stillOldQr;
    if (!qr.hasLocation) {
      return FixedAssetReplaceStrings.newQrNoLocation(task.actShort);
    }
    if (!task.qrMatchesAct(qr)) {
      return FixedAssetReplaceStrings.newQrWrongLocation(
        '${qr.floor}/${qr.positionAA}',
        task.actShort,
      );
    }

    final qrCheck = fixedAssetManualQrCheck(qr, location);
    final FixedAssetAuditSaveResponse result;
    try {
      result = await api.saveAudit(
        fac: location.fac,
        floor: location.floor,
        positionA: location.positionA,
        positionAA: location.positionAA,
        machineCode: task.machineCode,
        userId: userId,
        userName: userName,
        mode: 'MANUAL',
        qrFloor: qrCheck.floor,
        // QR mới không in A: dùng A thực tế (QR in cho đúng vị trí này), để
        // backend không phải tra A từ MAP.
        qrPositionA: qrCheck.positionA ?? location.positionA,
        qrPositionAA: qrCheck.positionAA,
        qrLocationMismatch: false,
        qrReplace: true,
      );
    } catch (error) {
      return FixedAssetReplaceStrings.saveFailed(fixedAssetErrorText(error));
    }
    if (_disposed) return null;

    if (result.qrLabelNotReplaced) return FixedAssetReplaceStrings.stillOldQr;
    final cleared =
        (result.saved || result.alreadyAudited) &&
        !result.needsQrReprint &&
        !result.requiresConfirmation &&
        !result.pendingQrReplace;
    if (!cleared) {
      return FixedAssetReplaceStrings.notCleared(result.message.trim());
    }
    _doneAt[task.code] = DateTime.now();
    _notify();
    return null;
  }

  String? _machineError(FixedAssetReplaceTask task, FixedAssetQrData qr) {
    if (qr.machineCode.isEmpty) return FixedAssetReplaceStrings.invalidQr;
    if (!task.isMachine(qr.machineCode)) {
      return FixedAssetReplaceStrings.otherMachine(
        qr.machineCode,
        task.machineCode,
      );
    }
    return null;
  }

  /// So sánh chuỗi có số theo giá trị số ("A2" < "A10").
  static int _natural(String a, String b) {
    final re = RegExp(r'(\d+)|(\D+)');
    final pa = re.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
    final pb = re.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
    for (var i = 0; i < pa.length && i < pb.length; i++) {
      final na = int.tryParse(pa[i]);
      final nb = int.tryParse(pb[i]);
      final c = na != null && nb != null
          ? na.compareTo(nb)
          : pa[i].compareTo(pb[i]);
      if (c != 0) return c;
    }
    return pa.length.compareTo(pb.length);
  }
}
