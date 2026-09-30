import 'dart:async';

import 'package:chuphinh/api/fixed_asset_backend.dart';
import 'package:chuphinh/fixedAsset/fixed_asset_audit_flow.dart';
import 'package:chuphinh/fixedAsset/fixed_asset_controller.dart';
import 'package:chuphinh/fixedAsset/fixed_asset_location.dart';
import 'package:chuphinh/model/fixed_asset_audit_check_response.dart';
import 'package:chuphinh/model/fixed_asset_audit_save_response.dart';
import 'package:chuphinh/model/fixed_asset_audit_summary.dart';
import 'package:chuphinh/model/fixed_asset_machine.dart';
import 'package:chuphinh/model/fixed_asset_zone_lock.dart';
import 'package:chuphinh/model/fixed_asset_zone_progress.dart';
import 'package:flutter_test/flutter_test.dart';

const _a351 = FixedAssetAuditLocation(
  fac: 'Fac_C',
  floor: '1F',
  positionA: 'A35',
  positionAA: 'A35-1',
);

Map<String, dynamic> _lockJson({
  bool locked = true,
  String reason = 'INCOMPLETE',
  int audited = 1,
  int total = 24,
}) => {
  'locked': locked,
  'reason': reason,
  'fac': 'Fac_C',
  'floor': '1F',
  'positionA': 'A35',
  'positionAA': 'A35-1',
  'total': total,
  'audited': audited,
};

FixedAssetZoneProgressRow _row(String aa, int audited, int total) =>
    FixedAssetZoneProgressRow(
      positionA: 'A35',
      positionAA: aa,
      total: total,
      audited: audited,
    );

class _SaveCall {
  final String positionAA;
  final bool confirm;
  final String? mode;
  _SaveCall(this.positionAA, this.confirm, this.mode);
}

/// Backend double: every response is configurable; calls are recorded.
class _FakeBackend extends FixedAssetBackend {
  FixedAssetZoneLock Function() zoneLock = () =>
      FixedAssetZoneLock.fromJson({'locked': false, 'reason': 'NO_AUTO_AUDIT'});
  List<FixedAssetZoneProgressRow> zoneRows = [_row('A35-1', 1, 24)];

  /// positionAA of the QR -> check response (defaults: direct save there).
  bool mismatch = false;

  /// Manual: first POST asks for confirmation.
  bool manualNeedsConfirm = false;

  int checkCalls = 0;
  int zoneLockCalls = 0;
  int machineCalls = 0;

  /// When set, fetchZoneLock waits for this (late response simulation).
  Completer<FixedAssetZoneLock>? pendingLock;
  final List<_SaveCall> saves = [];

  @override
  Future<FixedAssetAuditSummary> fetchAuditSummary() async =>
      FixedAssetAuditSummary.fromJson(const {});

  @override
  Future<List<FixedAssetZoneProgressRow>> fetchZoneProgress({
    required String fac,
    required String floor,
  }) async => zoneRows;

  @override
  Future<FixedAssetZoneLock> fetchZoneLock({required String userId}) async {
    zoneLockCalls++;
    final pending = pendingLock;
    if (pending != null) return pending.future;
    return zoneLock();
  }

  @override
  Future<FixedAssetAuditCheckResponse> checkAudit({
    required String machineCode,
    required String floor,
    required String positionAA,
  }) async {
    checkCalls++;
    return FixedAssetAuditCheckResponse.fromJson({
      'machineCode': machineCode,
      'existsInMaster': true,
      'actualLocationResolved': true,
      'locationMatch': !mismatch,
      'requiresConfirmation': mismatch,
      'masterFac': 'Fac_C',
      'masterFloor': '1F',
      'masterPositionA': 'A35',
      'masterPositionAA': 'A35-2',
      'actualFac': 'Fac_C',
      'actualFloor': floor,
      'actualPositionA': 'A35',
      'actualPositionAA': positionAA,
    });
  }

  @override
  Future<FixedAssetAuditSaveResponse> saveAudit({
    required String? fac,
    required String floor,
    required String? positionA,
    required String positionAA,
    required String machineCode,
    required String userId,
    required String userName,
    bool confirmLocationMismatch = false,
    String? mode,
  }) async {
    saves.add(_SaveCall(positionAA, confirmLocationMismatch, mode));
    if (manualNeedsConfirm && !confirmLocationMismatch) {
      return FixedAssetAuditSaveResponse.fromJson({
        'saved': false,
        'requiresConfirmation': true,
      });
    }
    return FixedAssetAuditSaveResponse.fromJson({
      'success': true,
      'saved': true,
      'locationMismatch': confirmLocationMismatch,
    });
  }

  @override
  Future<List<FixedAssetMachine>> fetchMachines({
    required String fac,
    required String floor,
    required String positionA,
    required String positionAA,
  }) async {
    machineCalls++;
    return const <FixedAssetMachine>[];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeBackend api;
  late FixedAssetController c;
  late List<String> unlocked;
  var qrSeq = 0;

  String qr(String aa) => 'KVH_M-${++qrSeq}_1F_${aa}_Test machine';

  FixedAssetController makeController({bool zoneLockEnabled = true}) =>
      FixedAssetController(
        accountCode: 'user1',
        userName: 'User One',
        confirmMismatch: (_) async => true,
        showError: (_) {},
        resetQr: () {},
        onZoneUnlocked: unlocked.add,
        api: api,
        zoneLockEnabled: zoneLockEnabled,
      );

  setUp(() {
    api = _FakeBackend();
    unlocked = <String>[];
    c = makeController();
  });

  tearDown(() => c.dispose());

  Future<void> lockedOnA351() async {
    api.zoneLock = () => FixedAssetZoneLock.fromJson(_lockJson());
    await c.loadZoneLock();
    expect(c.lockedZone, _a351);
  }

  test('1. INCOMPLETE blocks another zone without calling checkAudit', () async {
    await lockedOnA351();
    await c.processScannedQr(qr('A35-2'));

    expect(api.checkCalls, 0);
    expect(api.saves, isEmpty);
    expect(c.scanStatus, FixedAssetScanStatus.zoneLocked);
    expect(
      c.statusMessage,
      'Khu vực A35-1 chưa hoàn thành (1/24). '
      'Hoàn thành khu vực này hoặc chuyển sang Manual.',
    );
  });

  test('2. same zone is processed normally', () async {
    await lockedOnA351();
    await c.processScannedQr(qr('a35-1')); // case-insensitive

    expect(api.checkCalls, 1);
    expect(api.saves.single.positionAA, 'a35-1');
    expect(c.scanStatus, FixedAssetScanStatus.saved);
  });

  test('3. optimistic lock right after the first AUTO save', () async {
    await c.loadZoneLock(); // NO_AUTO_AUDIT
    await c.loadZoneProgress('Fac_C', '1F'); // A35-1 1/24
    expect(c.lockedZone, isNull);

    await c.processScannedQr(qr('A35-1'));

    expect(api.saves.single.mode, 'AUTO');
    expect(c.lockedZone, _a351);
    expect(c.lockedZoneProgress, const ZoneProgress(audited: 1, total: 24));

    // Another zone is now blocked before the server confirms.
    await c.processScannedQr(qr('A35-2'));
    expect(api.checkCalls, 1);
    expect(c.scanStatus, FixedAssetScanStatus.zoneLocked);
  });

  test('4. zone-progress reaching 100% unlocks once', () async {
    await lockedOnA351();
    await c.loadZoneProgress('Fac_C', '1F');
    expect(c.lockedZone, _a351);

    api.zoneRows = [_row('A35-1', 24, 24)]; // audited by someone else
    await c.loadZoneProgress('Fac_C', '1F', force: true);
    await pumpEventQueue(); // the follow-up zone-lock reload

    expect(c.lockedZone, isNull);
    expect(unlocked, ['A35-1']);

    // Server still says INCOMPLETE (lag) and zones reload again: no repeat.
    await c.loadZoneLock();
    await c.loadZoneProgress('Fac_C', '1F', force: true);
    expect(c.lockedZone, isNull);
    expect(unlocked, ['A35-1']);
  });

  test('5a. locked -> COMPLETED: snackbar exactly once', () async {
    await lockedOnA351();
    api.zoneLock = () => FixedAssetZoneLock.fromJson(
      _lockJson(locked: false, reason: 'COMPLETED', audited: 24),
    );
    await c.loadZoneLock();
    await c.loadZoneLock();

    expect(c.lockedZone, isNull);
    expect(unlocked, ['A35-1']);
  });

  test('5b. first load already COMPLETED or NO_AUTO_AUDIT: no snackbar', () async {
    api.zoneLock = () => FixedAssetZoneLock.fromJson(
      _lockJson(locked: false, reason: 'COMPLETED', audited: 24),
    );
    await c.loadZoneLock();
    api.zoneLock = () =>
        FixedAssetZoneLock.fromJson({'locked': false, 'reason': 'NO_AUTO_AUDIT'});
    await c.loadZoneLock();

    expect(c.lockedZone, isNull);
    expect(unlocked, isEmpty);
    expect(c.isZoneLockUnverified, isFalse);
  });

  test('6. MANUAL is not blocked; back to AUTO the lock is still there', () async {
    await lockedOnA351();

    c.setLocationMode(FixedAssetLocationMode.manual);
    c.manual
      ..selectedFac = 'Fac_C'
      ..selectedFloor = '1F'
      ..selectedPositionA = 'A35'
      ..selectedPositionAA = 'A35-2';
    await c.processScannedQr(qr('A35-2'));

    expect(api.checkCalls, 0); // MANUAL never checks
    expect(api.saves.single.positionAA, 'A35-2');
    expect(api.saves.single.mode, 'MANUAL');
    expect(c.lockedZone, _a351); // MANUAL save does not move the lock

    final callsBefore = api.zoneLockCalls;
    c.setLocationMode(FixedAssetLocationMode.auto);
    await pumpEventQueue();
    expect(api.zoneLockCalls, callsBefore + 1);
    expect(c.lockedZone, _a351);
  });

  test('7a. network error: not blocked, warning shown', () async {
    await lockedOnA351();
    api.zoneLock = () => throw Exception('offline');
    await c.loadZoneLock();

    expect(c.isZoneLockUnverified, isTrue);
    expect(c.lockedZone, isNull);
    await c.processScannedQr(qr('A35-2'));
    expect(api.checkCalls, 1);
  });

  test('7b. UNRESOLVED: not blocked, warning; NO_AUTO_AUDIT: no warning', () async {
    api.zoneLock = () => FixedAssetZoneLock.fromJson(
      {'locked': true, 'reason': 'UNRESOLVED', 'lastAuditedAt': '2026-09-01'},
    );
    await c.loadZoneLock();
    expect(c.isZoneLockUnverified, isTrue);
    expect(c.lockedZone, isNull);
    await c.processScannedQr(qr('A35-2'));
    expect(api.checkCalls, 1);

    api.zoneLock = () =>
        FixedAssetZoneLock.fromJson({'locked': false, 'reason': 'NO_AUTO_AUDIT'});
    await c.loadZoneLock();
    expect(c.isZoneLockUnverified, isFalse);
    expect(c.lockedZone, isNull);
  });

  test('8a. AUTO mismatch re-POST keeps mode AUTO', () async {
    api.mismatch = true;
    await c.processScannedQr(qr('A35-1'));

    expect(api.saves, hasLength(1));
    expect(api.saves.single.confirm, isTrue);
    expect(api.saves.single.mode, 'AUTO');
  });

  test('8b. MANUAL confirmation re-POST keeps mode MANUAL', () async {
    api.manualNeedsConfirm = true;
    c.setLocationMode(FixedAssetLocationMode.manual);
    c.manual
      ..selectedFac = 'Fac_C'
      ..selectedFloor = '1F'
      ..selectedPositionA = 'A35'
      ..selectedPositionAA = 'A35-2';
    await c.processScannedQr(qr('A35-2'));

    expect(api.saves.map((s) => s.confirm), [false, true]);
    expect(api.saves.map((s) => s.mode), ['MANUAL', 'MANUAL']);
  });

  group('feature flag', () {
    test('F1. zoneLockEnabled = false: no zone-lock call, nothing blocked', () async {
      c.dispose();
      c = makeController(zoneLockEnabled: false);
      api.zoneLock = () => FixedAssetZoneLock.fromJson(_lockJson());

      await c.loadZoneLock();
      expect(api.zoneLockCalls, 0);
      expect(c.lockedZone, isNull);
      expect(c.isZoneLockUnverified, isFalse);
      expect(c.autoLocation, isNull); // no resume either

      await c.loadZoneProgress('Fac_C', '1F');
      await c.processScannedQr(qr('A35-1'));
      await c.processScannedQr(qr('A35-2'));
      expect(api.checkCalls, 2); // other zone not blocked
      expect(api.saves.map((s) => s.mode), ['AUTO', 'AUTO']); // mode still sent
      expect(c.lockedZone, isNull); // no optimistic lock
      expect(unlocked, isEmpty);
    });
  });

  group('resume unfinished zone', () {
    test('R2. INCOMPLETE A35-1 on open: location + machines, no check', () async {
      api.zoneLock = () => FixedAssetZoneLock.fromJson(_lockJson());
      await c.loadZoneLock();
      await pumpEventQueue();

      expect(c.activeLocation, _a351);
      expect(c.autoLocation, _a351);
      expect(c.isResumedFromLock, isTrue);
      expect(api.machineCalls, 1);
      expect(api.checkCalls, 0);
      expect(api.saves, isEmpty);
      expect(c.scanStatus, FixedAssetScanStatus.idle);
      expect(c.scannedCode, isEmpty);
      expect(c.zoneProgress, isNotNull); // loaded with the machines

      // First scan clears the hint and is processed normally.
      await c.processScannedQr(qr('A35-1'));
      expect(c.isResumedFromLock, isFalse);
      expect(api.checkCalls, 1);
    });

    test('R3. scanned in session: a later zone-lock result does not overwrite', () async {
      await c.processScannedQr(qr('A35-2')); // NO_AUTO_AUDIT so far
      final scanned = c.autoLocation;
      expect(scanned?.positionAA, 'A35-2');

      api.zoneLock = () => FixedAssetZoneLock.fromJson(_lockJson());
      await c.loadZoneLock();
      expect(c.autoLocation, scanned);
      expect(c.isResumedFromLock, isFalse);
    });

    test('R3b. late zone-lock response after a scan does not overwrite', () async {
      final late = Completer<FixedAssetZoneLock>();
      api.pendingLock = late;
      final loading = c.loadZoneLock(); // request in flight
      api.pendingLock = null;

      await c.processScannedQr(qr('A35-2')); // user scans meanwhile
      final scanned = c.autoLocation;
      expect(scanned?.positionAA, 'A35-2');

      // The old request only now returns INCOMPLETE A35-1.
      late.complete(FixedAssetZoneLock.fromJson(_lockJson()));
      await loading;
      await pumpEventQueue();

      expect(c.autoLocation, scanned);
      expect(c.isResumedFromLock, isFalse);
    });

    test('R3c. late zone-lock after a scan with no location: no resume', () async {
      final late = Completer<FixedAssetZoneLock>();
      api.pendingLock = late;
      final loading = c.loadZoneLock();
      api.pendingLock = null;

      // The user scans an invalid QR meanwhile: no location, but a scan.
      await c.processScannedQr('NOT-A-KVH-QR');
      expect(c.autoLocation, isNull);
      expect(c.scanStatus, FixedAssetScanStatus.failed);

      late.complete(FixedAssetZoneLock.fromJson(_lockJson()));
      await loading;
      await pumpEventQueue();

      expect(c.autoLocation, isNull); // the scan wins over the late result
      expect(api.machineCalls, 0);
      expect(c.lockedZone, _a351); // the lock itself still applies
    });

    test('R4. Manual -> Auto restores A35-1', () async {
      api.zoneLock = () => FixedAssetZoneLock.fromJson(_lockJson());
      await c.loadZoneLock();
      expect(c.activeLocation, _a351);

      c.setLocationMode(FixedAssetLocationMode.manual);
      expect(c.activeLocation, isNull);
      c.setLocationMode(FixedAssetLocationMode.auto);
      expect(c.autoLocation, isNull); // cleared by the switch...
      await pumpEventQueue();
      expect(c.activeLocation, _a351); // ...restored from zone-lock
      expect(c.isResumedFromLock, isTrue);
    });

    for (final (name, lockFactory) in <(String, FixedAssetZoneLock Function())>[
      (
        'COMPLETED',
        () => FixedAssetZoneLock.fromJson(
          _lockJson(locked: false, reason: 'COMPLETED', audited: 24),
        ),
      ),
      (
        'NO_AUTO_AUDIT',
        () => FixedAssetZoneLock.fromJson(
          {'locked': false, 'reason': 'NO_AUTO_AUDIT'},
        ),
      ),
      ('error', () => throw Exception('offline')),
    ]) {
      test('R5. $name: no resume', () async {
        api.zoneLock = lockFactory;
        await c.loadZoneLock();
        await pumpEventQueue();
        expect(c.autoLocation, isNull);
        expect(c.isResumedFromLock, isFalse);
        expect(api.machineCalls, 0);
      });
    }

    test('R6. unlock at 100% keeps the shown location', () async {
      api.zoneLock = () => FixedAssetZoneLock.fromJson(_lockJson());
      await c.loadZoneLock();
      await pumpEventQueue();
      api.zoneRows = [_row('A35-1', 24, 24)];
      await c.loadZoneProgress('Fac_C', '1F', force: true);
      await pumpEventQueue();

      expect(c.lockedZone, isNull);
      expect(c.activeLocation, _a351);
      expect(unlocked, ['A35-1']);
    });
  });

  group('9. FixedAssetZoneLock.fromJson', () {
    test('missing fields -> null, unknown reason -> UNRESOLVED', () {
      final lock = FixedAssetZoneLock.fromJson({'reason': 'SOMETHING_NEW'});
      expect(lock.locked, isFalse);
      expect(lock.reason, FixedAssetZoneLockReason.unresolved);
      expect(lock.fac, isNull);
      expect(lock.positionAA, isNull);
      expect(lock.total, isNull);
      expect(lock.audited, isNull);
      expect(lock.lastAuditedAt, isNull);
      expect(lock.hasLocation, isFalse);
    });

    test('num / string counts, trimmed codes, known reasons', () {
      final lock = FixedAssetZoneLock.fromJson({
        'locked': true,
        'reason': 'incomplete',
        'fac': ' Fac_C ',
        'floor': '1F',
        'positionA': 'A35',
        'positionAA': 'A35-1 ',
        'total': '24',
        'audited': 1.0,
        'lastAuditedAt': '2026-09-28T10:00:00',
      });
      expect(lock.locked, isTrue);
      expect(lock.reason, FixedAssetZoneLockReason.incomplete);
      expect(lock.fac, 'Fac_C');
      expect(lock.positionAA, 'A35-1');
      expect(lock.total, 24);
      expect(lock.audited, 1);
      expect(lock.lastAuditedAt, isNotNull);
      expect(lock.hasLocation, isTrue);
      expect(
        FixedAssetZoneLock.fromJson({'reason': 'COMPLETED'}).reason,
        FixedAssetZoneLockReason.completed,
      );
      expect(
        FixedAssetZoneLock.fromJson({'reason': 'NO_AUTO_AUDIT'}).reason,
        FixedAssetZoneLockReason.noAutoAudit,
      );
      expect(FixedAssetZoneLock.fromJson({'total': 'x'}).total, isNull);
    });
  });
}
