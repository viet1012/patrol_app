import 'package:flutter/foundation.dart';

import 'package:chuphinh/core/api/fixed_asset_backend.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_audit_flow.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_location.dart';

/// Tự chọn khi danh sách vừa tải có đúng 1 option, ô đang trống
/// ([hasValue] false) và người dùng chưa tự xóa ô đó ([userCleared]).
/// Trả option cần chọn, null = không tự chọn. Dùng chung cho 4 dropdown vị
/// trí ([FixedAssetManualCascade.singleOption]) và dropdown PIC.
T? fixedAssetAutoPick<T>(
  List<T>? options, {
  required bool hasValue,
  bool userCleared = false,
}) {
  if (hasValue || userCleared || options == null || options.length != 1) {
    return null;
  }
  return options.single;
}

/// State + loaders của cascade MANUAL: Fac -> Floor -> PositionA -> PositionAA.
///
/// Chỉ lo dropdown hierarchy (giữ request token riêng từng level). Việc reset machine list / scan state và load
/// machines khi đổi lựa chọn do FixedAssetController điều phối.
class FixedAssetManualCascade {
  FixedAssetManualCascade({
    required this.onChanged,
    required this.onError,
    required this.isDisposed,
    this.api = const FixedAssetBackend(),
  });

  /// MAP endpoints (replaceable in tests).
  final FixedAssetBackend api;

  /// Báo UI rebuild (tương đương setState).
  final VoidCallback onChanged;

  /// Hiện lỗi load dropdown (snackbar).
  final ValueChanged<String> onError;

  final bool Function() isDisposed;

  /// Email PIC lọc các danh sách (null = mọi PIC). Màn "Kiểm kê" đặt theo
  /// dropdown PIC; form máy thiếu QR để null.
  String? pic;

  String? selectedFac;
  String? selectedFloor;
  String? selectedPositionA;
  String? selectedPositionAA;

  /// Fac được cache: chỉ load một lần khi mở màn hình.
  List<String> facs = const <String>[];
  List<String> floors = const <String>[];
  List<String> positionAs = const <String>[];
  List<String> positionAAs = const <String>[];

  bool loadingFacs = false;
  bool loadingFloors = false;
  bool loadingPositionA = false;
  bool loadingPositionAA = false;

  // Request tokens: mỗi lần parent đổi thì tăng token của các level con,
  // response cũ có token khác sẽ bị bỏ qua.
  int _facReq = 0;
  int _floorReq = 0;
  int _positionAReq = 0;
  int _positionAAReq = 0;

  FixedAssetAuditLocation? get selectedLocation {
    final fac = selectedFac;
    final floor = selectedFloor;
    final positionA = selectedPositionA;
    final positionAA = selectedPositionAA;

    if (fac == null ||
        floor == null ||
        positionA == null ||
        positionAA == null) {
      return null;
    }

    return FixedAssetAuditLocation(
      fac: fac,
      floor: floor,
      positionA: positionA,
      positionAA: positionAA,
    );
  }

  bool get needsFacs => facs.isEmpty && !loadingFacs;

  /// Cấp vừa bị xóa về rỗng (có giá trị -> null): không tự chọn lại cho tới
  /// khi cấp đó được chọn lại hoặc cấp cha đổi.
  final Set<FixedAssetManualField> _cleared = <FixedAssetManualField>{};

  String? _selectedOf(FixedAssetManualField field) => switch (field) {
    FixedAssetManualField.fac => selectedFac,
    FixedAssetManualField.floor => selectedFloor,
    FixedAssetManualField.positionA => selectedPositionA,
    FixedAssetManualField.positionAA => selectedPositionAA,
  };

  /// Ghi nhận xóa / chọn ở [field]; cấp sau (cha mới) được tự chọn lại.
  void _trackSelect(FixedAssetManualField field, String? previous, String? value) {
    if (value == null && previous != null) {
      _cleared.add(field);
    } else if (value != null) {
      _cleared.remove(field);
    }
    _cleared.removeWhere((f) => f.index > field.index);
  }

  /// [options] vừa tải của [field] có đúng 1 và ô đang trống, chưa bị xóa
  /// tay: option cần tự chọn (caller chọn + tải cấp sau); còn lại null.
  String? singleOption(FixedAssetManualField field, List<String>? options) =>
      fixedAssetAutoPick(
        options,
        hasValue: _selectedOf(field) != null,
        userCleared: _cleared.contains(field),
      );

  /// Đổi PIC: xoá mọi lựa chọn + danh sách; request đang chạy bị bỏ.
  void clear() {
    _facReq++;
    _floorReq++;
    _positionAReq++;
    _positionAAReq++;

    selectedFac = null;
    selectedFloor = null;
    selectedPositionA = null;
    selectedPositionAA = null;

    facs = const <String>[];
    floors = const <String>[];
    positionAs = const <String>[];
    positionAAs = const <String>[];

    loadingFacs = false;
    loadingFloors = false;
    loadingPositionA = false;
    loadingPositionAA = false;

    _cleared.clear();
  }

  // ------------------------------------------------------------
  // SELECTION (false = không đổi, caller dừng như cũ)
  // ------------------------------------------------------------

  bool selectFac(String? value) {
    if (value == selectedFac) return false;
    _trackSelect(FixedAssetManualField.fac, selectedFac, value);

    // Vô hiệu hóa mọi request con đang chạy.
    _floorReq++;
    _positionAReq++;
    _positionAAReq++;

    selectedFac = value;
    selectedFloor = null;
    selectedPositionA = null;
    selectedPositionAA = null;

    floors = const <String>[];
    positionAs = const <String>[];
    positionAAs = const <String>[];

    loadingFloors = false;
    loadingPositionA = false;
    loadingPositionAA = false;
    return true;
  }

  bool selectFloor(String? value) {
    if (value == selectedFloor) return false;
    _trackSelect(FixedAssetManualField.floor, selectedFloor, value);

    _positionAReq++;
    _positionAAReq++;

    selectedFloor = value;
    selectedPositionA = null;
    selectedPositionAA = null;

    positionAs = const <String>[];
    positionAAs = const <String>[];

    loadingPositionA = false;
    loadingPositionAA = false;
    return true;
  }

  bool selectPositionA(String? value) {
    if (value == selectedPositionA) return false;
    _trackSelect(FixedAssetManualField.positionA, selectedPositionA, value);

    _positionAAReq++;

    selectedPositionA = value;
    selectedPositionAA = null;

    positionAAs = const <String>[];

    loadingPositionAA = false;
    return true;
  }

  bool selectPositionAA(String? value) {
    if (value == selectedPositionAA) return false;
    _trackSelect(FixedAssetManualField.positionAA, selectedPositionAA, value);

    selectedPositionAA = value;
    return true;
  }

  // ------------------------------------------------------------
  // LOADERS
  // ------------------------------------------------------------

  // [silent] (mọi loader): tải ngầm – không bật loading, lỗi thì giữ danh
  // sách cũ và không báo.

  /// Returns the accepted options, or null when the request failed/stale.
  Future<List<String>?> loadFacs({bool silent = false}) async {
    final req = ++_facReq;
    if (!silent) {
      loadingFacs = true;
      onChanged();
    }

    try {
      final result = await api.fetchFacs(pic: pic);
      if (isDisposed() || req != _facReq) return null;
      facs = result;
      return result;
    } catch (error) {
      if (isDisposed() || req != _facReq || silent) return null;
      facs = const <String>[];
      onError('Load Fac failed: ${fixedAssetErrorText(error)}');
      return null;
    } finally {
      if (!isDisposed() && req == _facReq) {
        loadingFacs = false;
        onChanged();
      }
    }
  }

  /// Returns the accepted options, or null when the request failed/stale.
  Future<List<String>?> loadFloors(String fac, {bool silent = false}) async {
    final req = _floorReq;
    if (!silent) {
      loadingFloors = true;
      onChanged();
    }

    try {
      final result = await api.fetchFloors(fac: fac, pic: pic);
      if (isDisposed() || req != _floorReq) return null;
      floors = result;
      return result;
    } catch (error) {
      if (isDisposed() || req != _floorReq || silent) return null;
      floors = const <String>[];
      onError('Load Floor failed: ${fixedAssetErrorText(error)}');
      return null;
    } finally {
      if (!isDisposed() && req == _floorReq) {
        loadingFloors = false;
        onChanged();
      }
    }
  }

  /// Returns the accepted options, or null when the request failed/stale.
  Future<List<String>?> loadPositionA(
    String fac,
    String floor, {
    bool silent = false,
  }) async {
    final req = _positionAReq;
    if (!silent) {
      loadingPositionA = true;
      onChanged();
    }

    try {
      final result = await api.fetchPositionA(
        fac: fac,
        floor: floor,
        pic: pic,
      );
      if (isDisposed() || req != _positionAReq) return null;
      positionAs = result;
      return result;
    } catch (error) {
      if (isDisposed() || req != _positionAReq || silent) return null;
      positionAs = const <String>[];
      onError('Load PositionA failed: ${fixedAssetErrorText(error)}');
      return null;
    } finally {
      if (!isDisposed() && req == _positionAReq) {
        loadingPositionA = false;
        onChanged();
      }
    }
  }

  /// Returns the accepted options, or null when the request failed/stale.
  Future<List<String>?> loadPositionAA(
    String fac,
    String floor,
    String positionA, {
    bool silent = false,
  }) async {
    final req = _positionAAReq;
    if (!silent) {
      loadingPositionAA = true;
      onChanged();
    }

    try {
      final result = await api.fetchPositionAA(
        fac: fac,
        floor: floor,
        positionA: positionA,
        pic: pic,
      );
      if (isDisposed() || req != _positionAAReq) return null;
      positionAAs = result;
      return result;
    } catch (error) {
      if (isDisposed() || req != _positionAAReq || silent) return null;
      positionAAs = const <String>[];
      onError('Load PositionAA failed: ${fixedAssetErrorText(error)}');
      return null;
    } finally {
      if (!isDisposed() && req == _positionAAReq) {
        loadingPositionAA = false;
        onChanged();
      }
    }
  }
}
