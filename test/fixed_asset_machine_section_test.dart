import 'package:chuphinh/fixedAsset/widgets/fixed_asset_machine_section.dart';
import 'package:chuphinh/model/fixed_asset_machine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const machines = <FixedAssetMachine>[
    FixedAssetMachine(machineCode: 'MC-001', faName: 'Press Alpha'),
    FixedAssetMachine(machineCode: 'MC-002', faName: 'Grinder'),
    FixedAssetMachine(machineCode: 'mc-003', faName: 'Press Beta'),
    FixedAssetMachine(machineCode: 'MC-004', faName: ''),
    FixedAssetMachine(machineCode: 'XY-005', faName: 'Lathe PRESS'),
  ];

  /// Original (pre-cache) algorithm, kept as the reference order.
  List<String> referenceOrder(String search, Set<String> audited) {
    final query = search.trim().toLowerCase();
    final filtered = query.isEmpty
        ? machines
        : machines.where(
            (m) =>
                m.machineCode.toLowerCase().contains(query) ||
                m.faName.toLowerCase().contains(query),
          );
    bool isAudited(FixedAssetMachine m) {
      final code = m.machineCode.trim().toLowerCase();
      return code.isNotEmpty && audited.contains(code);
    }

    return <String>[
      ...filtered.where(isAudited).map((m) => m.machineCode),
      ...filtered.where((m) => !isAudited(m)).map((m) => m.machineCode),
    ];
  }

  final searchController = TextEditingController();
  tearDownAll(searchController.dispose);

  Future<void> pumpSection(
    WidgetTester tester, {
    required String search,
    required Set<String> audited,
    List<FixedAssetMachine> list = machines,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 800,
            child: FixedAssetMachineSection(
              visible: true,
              machines: list,
              loading: false,
              error: null,
              search: search,
              searchController: searchController,
              auditedMachineCodes: audited,
              onSearchChanged: (_) {},
              onClearSearch: () {},
            ),
          ),
        ),
      ),
    );
  }

  List<String> renderedOrder(WidgetTester tester) {
    final codes = machines.map((m) => m.machineCode).toSet();
    return tester
        .widgetList<Text>(find.byType(Text, skipOffstage: false))
        .map((t) => t.data)
        .whereType<String>()
        .where(codes.contains)
        .toList();
  }

  testWidgets('order matches the original algorithm', (tester) async {
    final audited = <String>{'mc-003', 'xy-005'};
    for (final search in <String>['', 'press', '  MC-00 ', 'zzz']) {
      await pumpSection(tester, search: search, audited: audited);
      expect(
        renderedOrder(tester),
        referenceOrder(search, audited),
        reason: 'search "$search"',
      );
    }
  });

  testWidgets('in-place audited mutation re-sorts on next rebuild', (
    tester,
  ) async {
    final audited = <String>{};
    await pumpSection(tester, search: '', audited: audited);
    expect(renderedOrder(tester).first, 'MC-001');

    audited.add('mc-004'); // same Set instance, mutated like the controller
    await pumpSection(tester, search: '', audited: audited);
    expect(renderedOrder(tester), referenceOrder('', audited));
    expect(renderedOrder(tester).first, 'MC-004');
  });

  testWidgets('new machines list recomputes', (tester) async {
    final audited = <String>{};
    await pumpSection(tester, search: '', audited: audited);
    await pumpSection(
      tester,
      search: '',
      audited: audited,
      list: machines.sublist(0, 2),
    );
    expect(renderedOrder(tester), <String>['MC-001', 'MC-002']);
    expect(find.text('2'), findsOneWidget);
  });
}
