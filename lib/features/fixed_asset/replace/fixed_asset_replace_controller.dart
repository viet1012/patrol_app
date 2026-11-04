import 'package:flutter/foundation.dart';

import 'package:chuphinh/core/api/fixed_asset_api.dart' show FixedAssetApi;
import 'package:chuphinh/core/api/fixed_asset_backend.dart';
import 'package:chuphinh/core/models/fixed_asset_audit_save_response.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_audit_flow.dart'
    show fixedAssetErrorText, fixedAssetManualQrCheck;
import 'package:chuphinh/features/fixed_asset/fixed_asset_location.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_pic_filter.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_qr_parser.dart';
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_models.dart';
import 'package:chuphinh/features/fixed_asset/replace/fixed_asset_replace_strings.dart';

/// Lỗi một lần quét ở bước thay QR. [apiFailed] false: QR sai, camera vẫn
/// mở để quét tiếp; true: POST lỗi / backend chưa gỡ cờ, đóng camera và báo
/// ở màn "Việc cần làm".
class FixedAssetReplaceScanError {
  final String message;
  final bool apiFailed;

  const FixedAssetReplaceScanError(this.message, {this.apiFailed = false});
}

/// Kết quả một lần quét: [error] null = đúng. Bước QR mới thành công:
/// [photoUrl] = ảnh đã lưu (photoSaved); [photoFailed] = chụp / lưu ảnh lỗi.
class FixedAssetReplaceScanOutcome {
  final FixedAssetReplaceScanError? error;
  final String? photoUrl;
  final bool photoFailed;

  const FixedAssetReplaceScanOutcome([this.error])
    : photoUrl = null,
      photoFailed = false;

  const FixedAssetReplaceScanOutcome.photo(String this.photoUrl)
    : error = null,
      photoFailed = false;

  const FixedAssetReplaceScanOutcome.photoFailed()
    : error = null,
      photoUrl = null,
      photoFailed = true;
}

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
/// lọc PIC + xưởng, gom Floor → A → AA theo vị trí thực tế (*_Act).
class FixedAssetReplaceController extends ChangeNotifier {
  FixedAssetReplaceController({this.api = const FixedAssetBackend()}) {
    // PIC rút từ chính danh sách chờ (không gọi GET /pics).
    picFilter = FixedAssetPicFilter(api: api, localOnly: true)
      ..addListener(_onPicChanged);
  }

  final FixedAssetBackend api;

  /// PIC (chung các màn trong phiên); lọc phía FE theo pic của dòng.
  late final FixedAssetPicFilter picFilter;

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
    picFilter.dispose();
    super.dispose();
  }

  /// PIC đổi (ở màn này hoặc màn khác) / danh sách PIC tải xong.
  void _onPicChanged() {
    if (_fac != null && !facs.contains(_fac)) _fac = null;
    _notify();
  }

  /// Máy của PIC đang chọn (máy không có PIC chỉ có ở "Tất cả PIC").
  Iterable<FixedAssetReplaceTask> get _picTasks =>
      _tasks.where((t) => picFilter.matches(t.row.pic));

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
      // Tính lại danh sách PIC + số máy chờ.
      picFilter.setFromRows(_tasks.map((t) => t.row));
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
      for (final t in _picTasks)
        if ((t.row.facAct ?? '').isNotEmpty) t.row.facAct!,
    };
    return set.toList()..sort();
  }

  bool _inFac(String? fac) => _fac == null || (fac ?? '') == _fac;

  /// Máy của xưởng đang lọc (kể cả chưa rõ vị trí).
  int get visibleCount => _picTasks
      .where((t) => _inFac(t.row.facAct) || t.row.facAct == null)
      .length;

  /// Floor → A → AA của xưởng đang lọc (chỉ dòng có đủ vị trí thực tế).
  List<FixedAssetReplaceFloor> get floors {
    final byZone = <String, List<FixedAssetReplaceTask>>{};
    final locationOf = <String, FixedAssetAuditLocation>{};
    for (final task in _picTasks) {
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
      for (final t in _picTasks)
        if (fixedAssetReplaceLocationOf(t.row) == null &&
            (_inFac(t.row.facAct) || (t.row.facAct ?? '').isEmpty))
          t,
    ];
    return tasks.isEmpty ? null : FixedAssetReplaceZone(null, tasks);
  }

  /// Khu theo [FixedAssetReplaceZone.key] trong dữ liệu hiện tại (mọi xưởng
  /// với khu đã biết, theo PIC đang chọn); khu hết máy -> danh sách rỗng.
  FixedAssetReplaceZone zoneByKey(String key, FixedAssetReplaceZone fallback) {
    if (key.isEmpty) {
      return unknownZone ?? FixedAssetReplaceZone(null, const []);
    }
    final tasks = [
      for (final t in _picTasks)
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
  /// null = đúng (đã ghi nhận), còn lại = QR sai (camera quét tiếp).
  FixedAssetReplaceScanError? scanOldQr(
    FixedAssetReplaceTask task,
    String rawQr,
  ) {
    final qr = parseFixedAssetQr(rawQr);
    if (qr.machineCode.isEmpty) {
      return const FixedAssetReplaceScanError(FixedAssetReplaceStrings.invalidQr);
    }
    if (!task.isMachine(qr.machineCode) || !task.isOldQr(qr)) {
      return _mismatch(qr, task, task.oldQrShort);
    }
    _oldScannedAt[task.code] = DateTime.now();
    _notify();
    return null;
  }

  /// Bước QR mới: kiểm ở FE (đúng máy, không phải QR cũ, vị trí = *_Act) rồi
  /// POST /audit (MANUAL, vị trí chọn = *_Act). Chỉ tính xong khi backend gỡ
  /// cờ. Không hỏi "Máy đã dời?". error null = xong; QR sai: camera quét
  /// tiếp; POST lỗi / chưa gỡ cờ: [FixedAssetReplaceScanError.apiFailed].
  ///
  /// [photo]: JPEG chụp lúc đọc được QR; gửi kèm (multipart) khi QR hợp lệ.
  /// Chụp lỗi / quá 5MB: vẫn gửi, không kèm ảnh.
  Future<FixedAssetReplaceScanOutcome> scanNewQr(
    FixedAssetReplaceTask task,
    String rawQr, {
    required String userId,
    required String userName,
    Future<Uint8List?>? photo,
  }) async {
    final location = task.location;
    if (location == null) {
      return const FixedAssetReplaceScanOutcome(
        FixedAssetReplaceScanError(
          FixedAssetReplaceStrings.unknownAct,
          apiFailed: true,
        ),
      );
    }

    final qr = parseFixedAssetQr(rawQr);
    if (qr.machineCode.isEmpty) {
      return const FixedAssetReplaceScanOutcome(
        FixedAssetReplaceScanError(FixedAssetReplaceStrings.invalidQr),
      );
    }
    if (!task.isMachine(qr.machineCode) ||
        task.isOldQr(qr) ||
        !task.qrMatchesAct(qr)) {
      return FixedAssetReplaceScanOutcome(_mismatch(qr, task, task.actShort));
    }

    final photoBytes = await _photoBytes(photo);
    if (_disposed) return const FixedAssetReplaceScanOutcome();

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
        photo: photoBytes,
      );
    } catch (error) {
      return FixedAssetReplaceScanOutcome(
        FixedAssetReplaceScanError(
          FixedAssetReplaceStrings.saveFailed(fixedAssetErrorText(error)),
          apiFailed: true,
        ),
      );
    }
    if (_disposed) return const FixedAssetReplaceScanOutcome();

    // Backend: vẫn là tem cũ -> QR sai, quét tiếp.
    if (result.qrLabelNotReplaced) {
      return FixedAssetReplaceScanOutcome(_mismatch(qr, task, task.actShort));
    }
    final cleared =
        (result.saved || result.alreadyAudited) &&
        !result.needsQrReprint &&
        !result.requiresConfirmation &&
        !result.pendingQrReplace;
    if (!cleared) {
      return FixedAssetReplaceScanOutcome(
        FixedAssetReplaceScanError(
          FixedAssetReplaceStrings.notCleared(result.message.trim()),
          apiFailed: true,
        ),
      );
    }
    final receivedAt = DateTime.now();
    _doneAt[task.code] = receivedAt;
    _notify();
    final photo3 = result.photo3;
    // ?v= = lúc nhận response (không dùng updatedAt: có thể chỉ là ngày /
    // bản ghi cũ khi alreadyAudited, chụp lại vẫn ra URL trùng).
    return result.photoSaved && photo3 != null
        ? FixedAssetReplaceScanOutcome.photo(
            FixedAssetApi.photoUrl(photo3, version: receivedAt),
          )
        : const FixedAssetReplaceScanOutcome.photoFailed();
  }

  /// Ảnh chụp lúc quét; null = không có / lỗi / quá giới hạn backend.
  static Future<Uint8List?> _photoBytes(Future<Uint8List?>? photo) async {
    if (photo == null) return null;
    try {
      final bytes = await photo.timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      if (bytes == null || bytes.isEmpty) return null;
      if (bytes.length > FixedAssetApi.maxPhotoBytes) {
        debugPrint('Replace QR photo too large: ${bytes.length} bytes');
        return null;
      }
      return bytes;
    } catch (error) {
      debugPrint('Replace QR photo error: $error');
      return null;
    }
  }

  /// "QR không khớp: đang quét {mã · AA}, cần {mã · [expected]}".
  static FixedAssetReplaceScanError _mismatch(
    FixedAssetQrData qr,
    FixedAssetReplaceTask task,
    String expected,
  ) {
    final aa = qr.positionAA.trim();
    final scanned = aa.isEmpty ? qr.machineCode : '${qr.machineCode} · $aa';
    return FixedAssetReplaceScanError(
      FixedAssetReplaceStrings.mismatch(
        scanned,
        '${task.machineCode} · $expected',
      ),
    );
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
