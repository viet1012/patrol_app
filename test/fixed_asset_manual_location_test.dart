import 'package:chuphinh/api/fixed_asset_backend.dart';
import 'package:chuphinh/fixedAsset/fixed_asset_audit_flow.dart';
import 'package:chuphinh/fixedAsset/fixed_asset_controller.dart';
import 'package:chuphinh/fixedAsset/fixed_asset_location.dart';
import 'package:chuphinh/fixedAsset/widgets/fixed_asset_scan_chip.dart';
import 'package:chuphinh/model/fixed_asset_audit_save_response.dart';
import 'package:chuphinh/model/fixed_asset_audit_summary.dart';
import 'package:chuphinh/model/fixed_asset_machine.dart';
import 'package:chuphinh/model/fixed_asset_zone_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _a351 = FixedAssetAuditLocation(
  fac: 'Fac_C',
  floor: '1F',
  positionA: 'A35',
  positionAA: 'A35-1',
);

/// MAP + machines + save double. [map] is fac -> floor -> positionA -> AAs.
class _FakeBackend extends FixedAssetBackend {
  Map<String, Map<String, Map<String, List<String>>>> map = {
    'Fac_C': {
      '1F': {
        'A35': ['A35-1', 'A35-2'],
        'A32': ['A32-1', 'A32-2'],
      },
    },
    'Fac_D': {
      '2F': {
        'A40': ['A40-1'],
      },
    },
  };
  List<FixedAssetMachine> machines = const [
    FixedAssetMachine(machineCode: 'A-474', faName: 'Core Pin'),
  ];
  final List<String> saves = [];
  int checkCalls = 0;

  @override
  Future<List<String>> fetchFacs() async => map.keys.toList();

  @override
  Future<List<String>> fetchFloors({required String fac}) async =>
      (map[fac] ?? const {}).keys.toList();

  @override
  Future<List<String>> fetchPositionA({
    required String fac,
    required String floor,
  }) async => (map[fac]?[floor] ?? const {}).keys.toList();

  @override
  Future<List<String>> fetchPositionAA({
    required String fac,
    required String floor,
    required String positionA,
  }) async => map[fac]?[floor]?[positionA] ?? const [];

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
  }) async => machines;

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
    saves.add('$machineCode@$positionAA');
    return FixedAssetAuditSaveResponse.fromJson({'success': true, 'saved': true});
  }
}

const _qr = 'KVH_A-474_1F_A35-1_Core Pin';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeBackend api;
  late FixedAssetController c;
  var dialogs = 0;

  setUp(() {
    api = _FakeBackend();
    dialogs = 0;
    c = FixedAssetController(
      accountCode: 'user1',
      userName: 'User One',
      confirmMismatch: (_) async {
        dialogs++;
        return true;
      },
      showError: (_) {},
      resetQr: () {},
      api: api,
      zoneLockEnabled: false,
    );
  });

  tearDown(() => c.dispose());

  Future<void> manualEmpty() async {
    c.setLocationMode(FixedAssetLocationMode.manual);
    await pumpEventQueue(); // Fac list (2 facs: nothing auto-selected)
    expect(c.manual.selectedFac, isNull);
  }

  test('1. MANUAL without location: amber status, no POST, first empty field marked', () async {
    await manualEmpty();
    await c.processScannedQr(_qr);

    expect(api.saves, isEmpty);
    expect(c.scanStatus, FixedAssetScanStatus.needsLocation);
    expect(
      FixedAssetScanChip.colorFor(c.scanStatus),
      FixedAssetScanChip.amber,
    );
    expect(c.statusMessage, 'Chưa chọn vị trí. Máy A-474 · QR: 1F/A35-1');
    expect(c.manualMissingField, FixedAssetManualField.fac);
    expect(c.pendingQrLocationLabel, '1F / A35-1');

    // QR without a location: no "· QR" part, no "use the QR's location".
    await c.processScannedQr('A-999');
    expect(c.statusMessage, 'Chưa chọn vị trí. Máy A-999');
    expect(c.pendingQrLocationLabel, isNull);

    // With Fac chosen, the first empty field moves on to Floor.
    await c.onFacChanged('Fac_C');
    await pumpEventQueue();
    // Fac_C has a single floor: the cascade auto-selects it.
    await c.processScannedQr(_qr);
    expect(c.manualMissingField, FixedAssetManualField.positionA);
    expect(api.saves, isEmpty);
  });

  test('1b. repeated detections are never silent (the Auto->Manual case)', () async {
    await c.processScannedQr(_qr); // AUTO (no check stub: fails fast)
    await manualEmpty();
    final tick = c.scanChipTick;
    await c.processScannedQr(_qr); // same QR still in frame
    expect(c.scanStatus, FixedAssetScanStatus.needsLocation);
    expect(c.scanChipTick, greaterThan(tick));
  });

  test('2. "use the QR location": cascade fills 4 fields, QR processed once', () async {
    await manualEmpty();
    await c.processScannedQr(_qr);
    await c.useLocationFromQr();
    await pumpEventQueue();

    expect(c.manual.selectedLocation, _a351);
    expect(api.saves, ['A-474@A35-1']); // exactly one save
    expect(dialogs, 0); // A-474 is in the A35-1 list
    expect(c.scanStatus, FixedAssetScanStatus.saved);
    expect(c.machines.single.machineCode, 'A-474');
  });

  test('3a. no MAP match: error, nothing filled', () async {
    await manualEmpty();
    await c.processScannedQr('KVH_A-474_1F_A99-9_Core Pin');
    await c.useLocationFromQr();

    expect(c.statusMessage, 'Không xác định được vị trí từ QR');
    expect(c.scanStatus, FixedAssetScanStatus.needsLocation);
    expect(c.manual.selectedFac, isNull);
    expect(c.pendingQrLocationLabel, isNull); // not offered again
    expect(api.saves, isEmpty);
  });

  test('3b. several MAP matches: error, nothing filled', () async {
    api.map['Fac_D']!['1F'] = {
      'A35': ['A35-1'],
    };
    await manualEmpty();
    await c.processScannedQr(_qr);
    await c.useLocationFromQr();

    expect(c.statusMessage, 'Không xác định được vị trí từ QR');
    expect(c.manual.selectedFac, isNull);
    expect(api.saves, isEmpty);
  });

  test('4a. chip shows the parsed text; mode change clears it', () async {
    await manualEmpty();
    await c.processScannedQr(_qr);
    expect(c.scanChipText, 'A-474 · 1F/A35-1');
    expect(c.isScanSettled, isTrue);

    c.setLocationMode(FixedAssetLocationMode.auto);
    expect(c.scanChipText, isNull);
  });

  test('5. every received scan changes the status or the chip', () async {
    await manualEmpty();
    final scans = [_qr, _qr, 'A-999', _qr, 'garbage-without-kvh'];
    for (final raw in scans) {
      final before = (c.scanStatus, c.statusMessage, c.scanChipTick);
      await c.processScannedQr(raw);
      final after = (c.scanStatus, c.statusMessage, c.scanChipTick);
      expect(after, isNot(before), reason: 'no feedback for "$raw"');
    }
  });

  testWidgets('4b. chip fades out 2.5 s after a final result', (tester) async {
    Widget chip({required int tick, bool settled = true, String? text}) =>
        MaterialApp(
          home: Scaffold(
            body: FixedAssetScanChip(
              text: text,
              tick: tick,
              status: FixedAssetScanStatus.saved,
              settled: settled,
            ),
          ),
        );
    double opacity() => tester
        .widget<AnimatedOpacity>(find.byType(AnimatedOpacity))
        .opacity;

    await tester.pumpWidget(chip(tick: 0));
    await tester.pumpWidget(chip(tick: 1, settled: false, text: 'A-474 · 1F/A35-1'));
    expect(find.text('A-474 · 1F/A35-1'), findsOneWidget);
    expect(opacity(), 1);

    // Still processing: stays visible.
    await tester.pump(const Duration(seconds: 3));
    expect(opacity(), 1);

    // Final result: hidden 2.5 s later.
    await tester.pumpWidget(chip(tick: 1, text: 'A-474 · 1F/A35-1'));
    await tester.pump(const Duration(milliseconds: 2400));
    expect(opacity(), 1);
    await tester.pump(const Duration(milliseconds: 200));
    expect(opacity(), 0);

    // A repeat (new tick) shows it again.
    await tester.pumpWidget(chip(tick: 2, text: 'A-474 · 1F/A35-1'));
    expect(opacity(), 1);

    // Mode / location change: text null -> hidden now.
    await tester.pumpWidget(chip(tick: 2));
    expect(opacity(), 0);
    await tester.pump(const Duration(seconds: 3));
  });
}
