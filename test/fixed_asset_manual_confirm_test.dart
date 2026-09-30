import 'dart:async';

import 'package:chuphinh/api/fixed_asset_backend.dart';
import 'package:chuphinh/fixedAsset/fixed_asset_audit_flow.dart';
import 'package:chuphinh/fixedAsset/fixed_asset_controller.dart';
import 'package:chuphinh/model/fixed_asset_audit_save_response.dart';
import 'package:chuphinh/model/fixed_asset_audit_summary.dart';
import 'package:chuphinh/model/fixed_asset_machine.dart';
import 'package:chuphinh/model/fixed_asset_scan_info.dart';
import 'package:chuphinh/model/fixed_asset_zone_progress.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the order of backend calls and dialog prompts.
final List<String> _events = <String>[];

class _FakeBackend extends FixedAssetBackend {
  List<FixedAssetMachine> machines = const [
    FixedAssetMachine(machineCode: 'M-IN', faName: 'In zone'),
  ];

  /// When set, fetchMachines waits for this (list "not loaded yet").
  Completer<List<FixedAssetMachine>>? pendingMachines;

  /// Server asks for confirmation on the first (unconfirmed) POST.
  bool serverNeedsConfirm = false;

  final List<({String code, bool confirm, String? mode})> saves = [];

  @override
  Future<FixedAssetAuditSummary> fetchAuditSummary() async =>
      FixedAssetAuditSummary.fromJson(const {});

  @override
  Future<List<FixedAssetZoneProgressRow>> fetchZoneProgress({
    required String fac,
    required String floor,
  }) async => const [];

  @override
  Future<List<FixedAssetMachine>> fetchMachines({
    required String fac,
    required String floor,
    required String positionA,
    required String positionAA,
  }) async {
    final pending = pendingMachines;
    if (pending != null) return pending.future;
    return machines;
  }

  @override
  Future<FixedAssetScanInfo> fetchScanInfo(String machineCode) async {
    _events.add('scanInfo $machineCode');
    return FixedAssetScanInfo.fromJson({
      'machineCode': machineCode,
      'existsInMaster': true,
      'fac': 'Fac_C',
      'floor': '1F',
      'positionA': 'A32',
      'positionAA': 'A32-2',
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
    _events.add('POST $machineCode confirm=$confirmLocationMismatch');
    saves.add((code: machineCode, confirm: confirmLocationMismatch, mode: mode));
    if (serverNeedsConfirm && !confirmLocationMismatch) {
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeBackend api;
  late FixedAssetController c;

  /// Dialog answers; a Completer keeps the dialog "open".
  late Completer<bool> Function() nextAnswer;
  final prompts = <FixedAssetMismatchPrompt>[];

  String qr(String code) => 'KVH_${code}_1F_A35-2_Test machine';

  setUp(() {
    _events.clear();
    prompts.clear();
    api = _FakeBackend();
    nextAnswer = () => Completer<bool>()..complete(true);
    c = FixedAssetController(
      accountCode: 'user1',
      userName: 'User One',
      confirmMismatch: (prompt) {
        _events.add('dialog ${prompt.machineCode}');
        prompts.add(prompt);
        return nextAnswer().future;
      },
      showError: (_) {},
      resetQr: () {},
      api: api,
      zoneLockEnabled: false,
    );
  });

  tearDown(() => c.dispose());

  /// MANUAL with Fac_C / 1F / A35 / A35-2 selected; machines loading.
  Future<void> selectManualA352({bool waitForList = true}) async {
    c.setLocationMode(FixedAssetLocationMode.manual);
    c.manual
      ..selectedFac = 'Fac_C'
      ..selectedFloor = '1F'
      ..selectedPositionA = 'A35';
    await c.onPositionAAChanged('A35-2');
    if (waitForList) await pumpEventQueue();
  }

  test('1. not in list: dialog first, no POST before; save -> one POST confirm', () async {
    await selectManualA352();
    await c.processScannedQr(qr('M-OUT'));

    // Dialog before any POST (the MASTER lookup runs in parallel).
    final dialogAt = _events.indexOf('dialog M-OUT');
    final firstPost = _events.indexWhere((e) => e.startsWith('POST'));
    expect(dialogAt, greaterThanOrEqualTo(0));
    expect(dialogAt, lessThan(firstPost));
    expect(api.saves, hasLength(1));
    expect(api.saves.single.confirm, isTrue);
    expect(api.saves.single.mode, 'MANUAL');
    expect(prompts.single.manual, isTrue);
    expect(prompts.single.actual?.positionAA, 'A35-2');
    // MASTER was looked up in parallel and delivered to the open dialog.
    expect(_events, contains('scanInfo M-OUT'));
    expect(prompts.single.masterUpdates?.value?.positionAA, 'A32-2');
    expect(c.scanStatus, FixedAssetScanStatus.mismatchSaved);
  });

  test('2. in list: POST as before, no dialog', () async {
    await selectManualA352();
    await c.processScannedQr(qr('m-in')); // case-insensitive

    expect(prompts, isEmpty);
    expect(api.saves.single.confirm, isFalse);
    expect(c.scanStatus, FixedAssetScanStatus.saved);
  });

  test('3. list not loaded yet: old flow (POST -> requiresConfirmation -> dialog)', () async {
    api.pendingMachines = Completer<List<FixedAssetMachine>>();
    api.serverNeedsConfirm = true;
    await selectManualA352(waitForList: false);

    await c.processScannedQr(qr('M-OUT'));

    expect(_events, [
      'POST M-OUT confirm=false',
      'dialog M-OUT',
      'POST M-OUT confirm=true',
    ]);
  });

  test('4. while the dialog is open, other scans are ignored', () async {
    await selectManualA352();
    final open = Completer<bool>();
    nextAnswer = () => open;

    final first = c.processScannedQr(qr('M-OUT'));
    await pumpEventQueue();
    expect(prompts, hasLength(1));
    expect(c.statusMessage, 'Xác nhận máy M-OUT trước');

    await c.processScannedQr(qr('M-IN')); // another machine
    await c.processScannedQr(qr('M-OUT')); // camera repeat of the same one
    expect(prompts, hasLength(1)); // no second dialog, nothing queued
    expect(api.saves, isEmpty);

    open.complete(false);
    await first;
    expect(api.saves, isEmpty);
    expect(c.scanStatus, FixedAssetScanStatus.locationMismatch);
  });

  test('5. after "Bỏ qua" the same code asks again after 1.2 s', () async {
    await selectManualA352();
    nextAnswer = () => Completer<bool>()..complete(false);

    await c.processScannedQr(qr('M-OUT'));
    expect(prompts, hasLength(1));

    // Still in frame right after: repeat, ignored.
    await c.processScannedQr(qr('M-OUT'));
    expect(prompts, hasLength(1));

    // Out of the frame for > 1.2 s (the 3 s window would still block).
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    await c.processScannedQr(qr('M-OUT'));
    expect(prompts, hasLength(2));
    expect(api.saves, isEmpty);
  });

  test('5b. another code is processed right away after "Bỏ qua"', () async {
    await selectManualA352();
    nextAnswer = () => Completer<bool>()..complete(false);
    await c.processScannedQr(qr('M-OUT'));
    await c.processScannedQr(qr('M-IN'));
    expect(api.saves.single.code, 'M-IN');
  });

  test('6. no silent drop while confirming: a real location change is reported', () async {
    await selectManualA352();
    final open = Completer<bool>();
    nextAnswer = () => open;

    final first = c.processScannedQr(qr('M-OUT'));
    await pumpEventQueue();

    // The user really changes the location while the dialog is up.
    await c.onPositionAAChanged('A35-1');
    open.complete(true);
    await first;
    await pumpEventQueue();

    expect(api.saves, isEmpty); // old context: not saved
    expect(c.scanStatus, FixedAssetScanStatus.failed);
    expect(c.statusMessage, startsWith('Đã bỏ qua M-OUT'));
  });

  test('6b. dropped after a slow POST (location changed) is reported too', () async {
    api.pendingMachines = Completer<List<FixedAssetMachine>>(); // server path
    await selectManualA352(waitForList: false);
    // Change location while the POST is in flight.
    final first = c.processScannedQr(qr('M-X'));
    await c.onPositionAAChanged('A35-1');
    await first;
    await pumpEventQueue();
    expect(api.saves, hasLength(1));
    expect(c.scanStatus, FixedAssetScanStatus.failed);
    expect(c.statusMessage, startsWith('Đã bỏ qua M-X'));
  });
}
