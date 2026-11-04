import 'dart:typed_data';

import 'package:chuphinh/core/models/fixed_asset_audit_check_response.dart';
import 'package:chuphinh/core/models/fixed_asset_audit_save_response.dart';
import 'package:chuphinh/core/models/fixed_asset_audit_summary.dart';
import 'package:chuphinh/core/models/fixed_asset_machine.dart';
import 'package:chuphinh/core/models/fixed_asset_pic.dart';
import 'package:chuphinh/core/models/fixed_asset_qr_mismatch.dart';
import 'package:chuphinh/core/models/fixed_asset_scan_info.dart';
import 'package:chuphinh/core/models/fixed_asset_summary.dart';
import 'package:chuphinh/core/models/fixed_asset_zone_lock.dart';
import 'package:chuphinh/core/models/fixed_asset_zone_progress.dart';
import 'package:chuphinh/core/api/fixed_asset_api.dart';

/// Các endpoint Fixed Asset mà FixedAssetController dùng, dạng instance để
/// test có thể thay bằng bản giả. Bản mặc định gọi thẳng [FixedAssetApi].
class FixedAssetBackend {
  const FixedAssetBackend();

  // Summary (period "YYYY-Qn"; null = kỳ hiện tại).
  Future<FixedAssetSummaryOverview> fetchSummary({String? period}) =>
      FixedAssetApi.fetchSummary(period: period);

  Future<List<FixedAssetSummaryPic>> fetchSummaryPics({String? period}) =>
      FixedAssetApi.fetchSummaryPics(period: period);

  Future<FixedAssetSummaryPicDetail> fetchSummaryPicDetail({
    required String pic,
    String? period,
  }) => FixedAssetApi.fetchSummaryPicDetail(pic: pic, period: period);

  /// Máy của PIC trong kỳ; vị trí null = không lọc.
  Future<List<FixedAssetPicMachine>> fetchSummaryPicMachines({
    required String pic,
    String? period,
    String? fac,
    String? floor,
    String? positionA,
    String? positionAA,
  }) => FixedAssetApi.fetchSummaryPicMachines(
    pic: pic,
    period: period,
    fac: fac,
    floor: floor,
    positionA: positionA,
    positionAA: positionAA,
  );

  /// PIC (người phụ trách) + số máy / số khu.
  Future<List<FixedAssetPic>> fetchPics() => FixedAssetApi.fetchPics();

  // MAP hierarchy (cascade dropdown). [pic] null = mọi PIC.
  Future<List<String>> fetchFacs({String? pic}) =>
      FixedAssetApi.fetchFacs(pic: pic);

  /// Máy cần in lại QR (màn "In lại QR" + badge ở home).
  /// Chỉ giữ máy đang chờ thay QR theo needsQrReprint của backend (dòng
  /// ReprintSts = 1 đã thay xong): một nguồn cho badge home, "In lại QR",
  /// "Thay QR".
  Future<List<FixedAssetQrMismatch>> fetchQrMismatch({String? fac}) async {
    final rows = await FixedAssetApi.fetchQrMismatch(fac: fac);
    return rows.where((r) => r.needsQrReprint).toList(growable: false);
  }

  Future<List<String>> fetchFloors({required String fac, String? pic}) =>
      FixedAssetApi.fetchFloors(fac: fac, pic: pic);

  Future<List<String>> fetchPositionA({
    required String fac,
    required String floor,
    String? pic,
  }) => FixedAssetApi.fetchPositionA(fac: fac, floor: floor, pic: pic);

  Future<List<String>> fetchPositionAA({
    required String fac,
    required String floor,
    required String positionA,
    String? pic,
  }) => FixedAssetApi.fetchPositionAA(
    fac: fac,
    floor: floor,
    positionA: positionA,
    pic: pic,
  );

  Future<FixedAssetAuditSummary> fetchAuditSummary({String? pic}) =>
      FixedAssetApi.fetchAuditSummary(pic: pic);

  Future<List<FixedAssetZoneProgressRow>> fetchZoneProgress({
    required String fac,
    required String floor,
    String? pic,
  }) => FixedAssetApi.fetchZoneProgress(fac: fac, floor: floor, pic: pic);

  Future<FixedAssetZoneLock> fetchZoneLock({required String userId}) =>
      FixedAssetApi.fetchZoneLock(userId: userId);

  /// MASTER location + period status of one machine (no retry).
  Future<FixedAssetScanInfo> fetchScanInfo(String machineCode) =>
      FixedAssetApi.fetchScanInfo(machineCode);

  Future<FixedAssetAuditCheckResponse> checkAudit({
    required String machineCode,
    required String floor,
    required String positionAA,
  }) => FixedAssetApi.checkAudit(
    machineCode: machineCode,
    floor: floor,
    positionAA: positionAA,
  );

  Future<FixedAssetAuditSaveResponse> saveAudit({
    required String? fac,
    required String floor,
    required String? positionA,
    required String positionAA,
    required String machineCode,
    required String userId,
    required String userName,
    String note = '',
    bool confirmLocationMismatch = false,
    String? mode,
    String? qrFloor,
    String? qrPositionA,
    String? qrPositionAA,
    bool? qrLocationMismatch,
    bool? needsQrReprint,
    bool? qrReplace,
    String? pic,
    Uint8List? photo,
  }) => FixedAssetApi.saveAudit(
    fac: fac,
    floor: floor,
    positionA: positionA,
    positionAA: positionAA,
    machineCode: machineCode,
    userId: userId,
    userName: userName,
    note: note,
    confirmLocationMismatch: confirmLocationMismatch,
    mode: mode,
    qrFloor: qrFloor,
    qrPositionA: qrPositionA,
    qrPositionAA: qrPositionAA,
    qrLocationMismatch: qrLocationMismatch,
    needsQrReprint: needsQrReprint,
    qrReplace: qrReplace,
    pic: pic,
    photo: photo,
  );

  Future<List<FixedAssetMachine>> fetchMachines({
    required String fac,
    required String floor,
    required String positionA,
    required String positionAA,
    String? pic,
  }) => FixedAssetApi.fetchMachines(
    fac: fac,
    floor: floor,
    positionA: positionA,
    positionAA: positionAA,
    pic: pic,
  );
}
