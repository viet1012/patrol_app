import 'package:flutter/foundation.dart';

import '../api/fixed_asset_api.dart';
import 'fixed_asset_audit_flow.dart';
import 'fixed_asset_location.dart';

/// State + loaders của cascade MANUAL: Fac -> Floor -> PositionA -> PositionAA.
///
/// Chỉ lo dropdown hierarchy (giữ request token riêng từng level). Việc reset machine list / scan state và load
/// machines khi đổi lựa chọn do FixedAssetController điều phối.
class FixedAssetManualCascade {
  FixedAssetManualCascade({
    required this.onChanged,
    required this.onError,
    required this.isDisposed,
  });

  /// Báo UI rebuild (tương đương setState).
  final VoidCallback onChanged;

  /// Hiện lỗi load dropdown (snackbar).
  final ValueChanged<String> onError;

  final bool Function() isDisposed;

  String? selectedFac;
  String? selectedFloor;
  String? selectedPositionA;
  String? selectedPositionAA;

  /// Fac được cache: chỉ load lần đầu vào MANUAL, tái sử dụng khi toggle.
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

  /// Đổi mode: vô hiệu hóa request con, xóa lựa chọn (giữ cache Fac).
  void resetForModeSwitch() {
    _floorReq++;
    _positionAReq++;
    _positionAAReq++;

    selectedFac = null;
    selectedFloor = null;
    selectedPositionA = null;
    selectedPositionAA = null;
    floors = const <String>[];
    positionAs = const <String>[];
    positionAAs = const <String>[];

    loadingFloors = false;
    loadingPositionA = false;
    loadingPositionAA = false;
  }

  // ------------------------------------------------------------
  // SELECTION (false = không đổi, caller dừng như cũ)
  // ------------------------------------------------------------

  bool selectFac(String? value) {
    if (value == selectedFac) return false;

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

    _positionAAReq++;

    selectedPositionA = value;
    selectedPositionAA = null;

    positionAAs = const <String>[];

    loadingPositionAA = false;
    return true;
  }

  bool selectPositionAA(String? value) {
    if (value == selectedPositionAA) return false;

    selectedPositionAA = value;
    return true;
  }

  // ------------------------------------------------------------
  // LOADERS
  // ------------------------------------------------------------

  /// Returns the accepted options, or null when the request failed/stale.
  Future<List<String>?> loadFacs() async {
    final req = ++_facReq;
    loadingFacs = true;
    onChanged();

    try {
      final result = await FixedAssetApi.fetchFacs();
      if (isDisposed() || req != _facReq) return null;
      facs = result;
      return result;
    } catch (error) {
      if (isDisposed() || req != _facReq) return null;
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
  Future<List<String>?> loadFloors(String fac) async {
    final req = _floorReq;
    loadingFloors = true;
    onChanged();

    try {
      final result = await FixedAssetApi.fetchFloors(fac: fac);
      if (isDisposed() || req != _floorReq) return null;
      floors = result;
      return result;
    } catch (error) {
      if (isDisposed() || req != _floorReq) return null;
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
  Future<List<String>?> loadPositionA(String fac, String floor) async {
    final req = _positionAReq;
    loadingPositionA = true;
    onChanged();

    try {
      final result = await FixedAssetApi.fetchPositionA(
        fac: fac,
        floor: floor,
      );
      if (isDisposed() || req != _positionAReq) return null;
      positionAs = result;
      return result;
    } catch (error) {
      if (isDisposed() || req != _positionAReq) return null;
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
    String positionA,
  ) async {
    final req = _positionAAReq;
    loadingPositionAA = true;
    onChanged();

    try {
      final result = await FixedAssetApi.fetchPositionAA(
        fac: fac,
        floor: floor,
        positionA: positionA,
      );
      if (isDisposed() || req != _positionAAReq) return null;
      positionAAs = result;
      return result;
    } catch (error) {
      if (isDisposed() || req != _positionAAReq) return null;
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
