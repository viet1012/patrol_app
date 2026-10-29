import 'package:flutter/foundation.dart';

import 'package:chuphinh/core/api/fixed_asset_backend.dart';
import 'package:chuphinh/core/models/fixed_asset_qr_mismatch.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_audit_flow.dart'
    show fixedAssetErrorText;
import 'package:chuphinh/features/fixed_asset/fixed_asset_location.dart'
    show fixedAssetDash;
import 'package:chuphinh/features/fixed_asset/fixed_asset_qr_parser.dart';
import 'package:chuphinh/features/fixed_asset/reprint/fixed_asset_reprint_strings.dart';

enum FixedAssetReprintQrState {
  /// Đang tra Fac + Floor từ MAP.
  resolving,

  /// Có nội dung QR mới hợp lệ (parse lại đúng vị trí).
  ready,

  /// Thiếu dữ liệu để tạo QR (không có Floor / A / AA, hoặc không tạo được
  /// nội dung parse lại đúng).
  missing,
}

/// Một máy cần in lại QR + QR mới tạo từ VỊ TRÍ ĐANG CHỌN (không dùng QR cũ).
class FixedAssetReprintItem {
  final FixedAssetQrMismatch row;
  final FixedAssetReprintQrState state;

  /// Xưởng của vị trí đang chọn (backend, hoặc tra từ MAP); rỗng = chưa rõ.
  final String fac;

  /// Floor của vị trí đang chọn (backend, hoặc tra từ MAP).
  final String floor;

  /// Nội dung QR mới; rỗng khi không phải [FixedAssetReprintQrState.ready].
  final String qrContent;

  const FixedAssetReprintItem._(
    this.row,
    this.state, {
    this.fac = '',
    this.floor = '',
    this.qrContent = '',
  });

  String get machineCode => row.machineCode;
  bool get isReady => state == FixedAssetReprintQrState.ready;

  /// Lý do cần in lại theo auditMode (NO_QR = không có tem).
  String get reasonLabel => row.isNoQr
      ? FixedAssetReprintStrings.reasonNoQr
      : FixedAssetReprintStrings.reasonWrongLocation;

  /// Vị trí trên QR cũ: Fac / Floor / A / AA.
  String get oldLocationLabel => _locationLabel([
    row.facQr,
    row.qrFloor,
    row.qrPositionA,
    row.qrPositionAA,
  ]);

  /// Vị trí thực tế (đang chọn): Fac / Floor / A / AA.
  String get newLocationLabel =>
      _locationLabel([fac, floor, row.positionA, row.positionAA]);

  /// Giá trị null / rỗng hiển thị "-".
  static String _locationLabel(List<String?> parts) =>
      parts.map((v) => fixedAssetDash(v ?? '')).join(' / ');
}

/// Nhóm hiển thị theo xưởng (fac rỗng = chưa rõ xưởng, luôn ở cuối).
class FixedAssetReprintGroup {
  final String fac;
  final List<FixedAssetReprintItem> items;

  const FixedAssetReprintGroup(this.fac, this.items);
}

/// State màn "In lại QR": danh sách mọi xưởng, tra Fac + Floor, lọc xưởng /
/// tìm kiếm / khu vực, chọn.
class FixedAssetReprintController extends ChangeNotifier {
  FixedAssetReprintController({this.api = const FixedAssetBackend()});

  final FixedAssetBackend api;

  bool _disposed = false;
  int _req = 0;

  bool _loading = true;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  List<FixedAssetReprintItem> _items = const <FixedAssetReprintItem>[];
  List<FixedAssetReprintItem> get items => _items;

  String _search = '';
  String get search => _search;

  /// Xưởng đang lọc; null = tất cả, '' = chưa rõ xưởng.
  String? _fac;
  String? get fac => _fac;

  /// PositionA (của vị trí đang chọn) đang lọc; null = tất cả.
  String? _area;
  String? get area => _area;

  final Set<String> _selected = <String>{};
  int get selectedCount => selectedItems.length;

  /// Request MAP dùng chung trong màn (cùng fac/floor không gọi lại).
  final Map<String, Future<List<String>>> _mapCache =
      <String, Future<List<String>>>{};
  final Map<String, Future<({String fac, String floor})?>> _locationCache =
      <String, Future<({String fac, String floor})?>>{};

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ------------------------------------------------------------
  // LOAD
  // ------------------------------------------------------------

  /// Mọi xưởng (không truyền fac): dữ liệu audit lưu theo xưởng, không theo
  /// nhà máy ở home.
  Future<void> load() async {
    final req = ++_req;
    _loading = true;
    _error = null;
    _notify();

    try {
      final rows = await api.fetchQrMismatch();
      if (_disposed || req != _req) return;
      _items = rows.map(_initialItem).toList(growable: false);
      final codes = _items.map((e) => e.machineCode).toSet();
      _selected.retainWhere(codes.contains);
      _loading = false;
      _dropStaleFilters();
      _notify();
      _resolveLocations(req);
    } catch (error) {
      if (_disposed || req != _req) return;
      _error = fixedAssetErrorText(error);
      _loading = false;
      _notify();
    }
  }

  FixedAssetReprintItem _initialItem(FixedAssetQrMismatch row) {
    final fac = row.facAct ?? '';
    final floor = row.floorAct ?? '';
    if (fac.isNotEmpty && floor.isNotEmpty) {
      return _withLocation(row, (fac: fac, floor: floor));
    }
    if (row.positionA.isEmpty || row.positionAA.isEmpty) {
      return FixedAssetReprintItem._(
        row,
        FixedAssetReprintQrState.missing,
        fac: fac,
        floor: floor,
      );
    }
    return FixedAssetReprintItem._(
      row,
      FixedAssetReprintQrState.resolving,
      fac: fac,
      floor: floor,
    );
  }

  /// QR mới chỉ khi nội dung parse lại đúng machineCode / Floor / AA.
  FixedAssetReprintItem _withLocation(
    FixedAssetQrMismatch row,
    ({String fac, String floor})? location,
  ) {
    final fac = (location?.fac ?? row.facAct ?? '').trim();
    final floor = (location?.floor ?? row.floorAct ?? '').trim();
    final content = floor.isEmpty
        ? null
        : buildFixedAssetQr(
            machineCode: row.machineCode,
            floor: floor,
            positionAA: row.positionAA,
            displayName: row.faName,
          );
    if (content == null) {
      return FixedAssetReprintItem._(
        row,
        FixedAssetReprintQrState.missing,
        fac: fac,
        floor: floor,
      );
    }
    return FixedAssetReprintItem._(
      row,
      FixedAssetReprintQrState.ready,
      fac: fac,
      floor: floor,
      qrContent: content,
    );
  }

  /// Bản ghi cũ chưa có Fac_Act / Floor_Act: tra trong MAP mọi xưởng cặp
  /// (Fac, Floor) DUY NHẤT có đúng PositionA + PositionAA đang chọn.
  /// 0 hoặc nhiều cặp -> thiếu dữ liệu.
  void _resolveLocations(int req) {
    for (final item in _items) {
      if (item.state != FixedAssetReprintQrState.resolving) continue;
      final row = item.row;
      _locationFor(row).then((location) {
        if (_disposed || req != _req) return;
        _items = [
          for (final e in _items)
            identical(e.row, row) ? _withLocation(row, location) : e,
        ];
        _dropStaleFilters();
        _notify();
      });
    }
  }

  Future<({String fac, String floor})?> _locationFor(FixedAssetQrMismatch row) {
    final key = [
      _norm(row.facAct ?? ''),
      _norm(row.floorAct ?? ''),
      _norm(row.positionA),
      _norm(row.positionAA),
    ].join('|');
    return _locationCache.putIfAbsent(key, () => _lookupLocation(row));
  }

  Future<({String fac, String floor})?> _lookupLocation(
    FixedAssetQrMismatch row,
  ) async {
    final wantA = _norm(row.positionA);
    final wantAA = _norm(row.positionAA);
    final wantFloor = _norm(row.floorAct ?? '');
    final rowFac = row.facAct ?? '';
    final found = <({String fac, String floor})>{};
    try {
      final facs = rowFac.isNotEmpty
          ? <String>[rowFac]
          : await _cached('facs', api.fetchFacs);

      await Future.wait(
        facs.map((fac) async {
          final floors = await _cached(
            'floors|$fac',
            () => api.fetchFloors(fac: fac),
          );
          await Future.wait(
            floors
                .where((f) => wantFloor.isEmpty || _norm(f) == wantFloor)
                .map((floor) async {
                  final positionAs = await _cached(
                    'a|$fac|$floor',
                    () => api.fetchPositionA(fac: fac, floor: floor),
                  );
                  for (final a in positionAs.where((a) => _norm(a) == wantA)) {
                    final aas = await _cached(
                      'aa|$fac|$floor|$a',
                      () => api.fetchPositionAA(
                        fac: fac,
                        floor: floor,
                        positionA: a,
                      ),
                    );
                    if (aas.any((aa) => _norm(aa) == wantAA)) {
                      found.add((fac: fac, floor: floor));
                    }
                  }
                }),
          );
        }),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[FA-REPRINT] location lookup failed: $error');
      }
      return null;
    }
    return found.length == 1 ? found.single : null;
  }

  Future<List<String>> _cached(
    String key,
    Future<List<String>> Function() load,
  ) {
    return _mapCache.putIfAbsent(key, () {
      final future = load();
      // Lỗi không bị cache: lần làm mới sau gọi lại.
      future.catchError((Object _) {
        _mapCache.remove(key);
        return const <String>[];
      });
      return future;
    });
  }

  static String _norm(String v) => v.trim().toLowerCase();

  // ------------------------------------------------------------
  // FILTER + SELECTION (chỉ hiển thị, không đổi dữ liệu gốc)
  // ------------------------------------------------------------

  /// Xưởng có trong dữ liệu (đã biết), sắp theo tên + số máy mỗi xưởng.
  /// Máy chưa rõ xưởng đếm riêng ở [unknownFacCount].
  List<({String fac, int count})> get facCounts {
    final counts = <String, int>{};
    for (final e in _items) {
      if (e.fac.isNotEmpty) counts[e.fac] = (counts[e.fac] ?? 0) + 1;
    }
    final facs = counts.keys.toList()..sort();
    return [for (final f in facs) (fac: f, count: counts[f]!)];
  }

  int get unknownFacCount => _items.where((e) => e.fac.isEmpty).length;

  bool _inFac(FixedAssetReprintItem e) => _fac == null || e.fac == _fac;

  /// Khu vực của xưởng đang lọc.
  List<String> get areas {
    final set = <String>{
      for (final e in _items)
        if (_inFac(e) && e.row.positionA.isNotEmpty) e.row.positionA,
    };
    return set.toList()..sort();
  }

  /// Sau lọc xưởng + khu vực + tìm kiếm.
  List<FixedAssetReprintItem> get visibleItems {
    final q = _norm(_search);
    final area = _area;
    return [
      for (final e in _items)
        if (_inFac(e) &&
            (area == null || e.row.positionA == area) &&
            (q.isEmpty ||
                e.machineCode.toLowerCase().contains(q) ||
                e.row.faName.toLowerCase().contains(q)))
          e,
    ];
  }

  /// "Tất cả": nhóm theo xưởng (tên tăng dần, chưa rõ xưởng cuối); đang lọc
  /// một xưởng: một nhóm. Thứ tự máy trong nhóm giữ như backend trả.
  List<FixedAssetReprintGroup> get visibleGroups {
    final visible = visibleItems;
    if (_fac != null) return [FixedAssetReprintGroup(_fac!, visible)];
    final byFac = <String, List<FixedAssetReprintItem>>{};
    for (final e in visible) {
      (byFac[e.fac] ??= <FixedAssetReprintItem>[]).add(e);
    }
    final facs = byFac.keys.toList()
      ..sort((a, b) {
        if (a.isEmpty != b.isEmpty) return a.isEmpty ? 1 : -1;
        return a.compareTo(b);
      });
    return [for (final f in facs) FixedAssetReprintGroup(f, byFac[f]!)];
  }

  /// Máy được chọn TRONG số đang hiển thị (PNG / PDF chỉ lấy các máy này).
  List<FixedAssetReprintItem> get selectedItems => [
    for (final e in visibleItems)
      if (e.isReady && _selected.contains(e.machineCode)) e,
  ];

  bool isSelected(FixedAssetReprintItem item) =>
      item.isReady && _selected.contains(item.machineCode);

  bool get allVisibleSelected {
    final ready = visibleItems.where((e) => e.isReady).toList();
    return ready.isNotEmpty && ready.every(isSelected);
  }

  void setSearch(String value) {
    _search = value;
    _notify();
  }

  void setFac(String? value) {
    if (value == _fac) return;
    _fac = value;
    if (_area != null && !areas.contains(_area)) _area = null;
    _notify();
  }

  void setArea(String? value) {
    _area = value;
    _notify();
  }

  /// Xưởng / khu vực đang lọc không còn trong dữ liệu -> về "tất cả".
  void _dropStaleFilters() {
    final fac = _fac;
    if (fac != null && !_items.any((e) => e.fac == fac)) _fac = null;
    if (_area != null && !areas.contains(_area)) _area = null;
  }

  void toggle(FixedAssetReprintItem item) {
    if (!item.isReady) return;
    if (!_selected.remove(item.machineCode)) _selected.add(item.machineCode);
    _notify();
  }

  /// "Chọn tất cả" các máy đang hiển thị (đã chọn hết thì bỏ chọn).
  void toggleSelectAllVisible() {
    final ready = visibleItems.where((e) => e.isReady);
    if (allVisibleSelected) {
      _selected.removeAll(ready.map((e) => e.machineCode));
    } else {
      _selected.addAll(ready.map((e) => e.machineCode));
    }
    _notify();
  }

  /// Bỏ chọn các máy đang hiển thị.
  void clearSelection() {
    _selected.removeAll(visibleItems.map((e) => e.machineCode));
    _notify();
  }
}
